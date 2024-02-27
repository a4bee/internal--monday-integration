New-Variable -Name A4MondayURL -Value 'https://api.monday.com/v2/' -Scope Script -Force -Option ReadOnly
New-Variable -Name ApiTokenFile -Value $env:APPDATA\A4Monday\apitoken.txt -Scope Script -Force -Option ReadOnly
Import-Module PSGraphQL
Function Set-A4MondayApiToken {
  Param(
    [parameter(Mandatory)]
    $ApiToken,
    [switch]$Persistent,
    [switch]$Force,
    [switch]$AsPlainText
  )

  if ($ApiToken.GetType().Name -eq 'SecureString') {
    Write-Verbose 'ApiToken in secure string'
    $SecureApiToken = $ApiToken
  }
  else {
    Write-Verbose 'ApiToken in string'
    try {
      $SecureApiToken = ConvertTo-SecureString -AsPlainText:$AsPlainText -String $ApiToken -Force -ErrorAction Stop
    }
    Catch {
      Write-Error 'Error in convertion to the SecureString format. If you use a plain text format please use the -AsPlainText parameter.'
      return
    }
  }    
    
  if ($Persistent) {
    If (!(Test-Path $ApiTokenFile -PathType Leaf) -or $Force) {
      New-Item $ApiTokenFile -Force | Out-Null
      $SecureApiToken  | ConvertFrom-SecureString | Out-File $ApiTokenFile
    }
    else {
      Write-Error 'Token is already saved, please use the -force to overwrite it.'
      return
    }

  }

  New-Variable -Name A4MondayApiToken -Value $SecureApiToken -Scope Script -Force -Option ReadOnly
}

function Get-A4MondayHeader {
  if (-not $Script:A4MondayApiToken) {
    if (Test-Path $ApiTokenFile -PathType Leaf) {
      $ApiToken = Get-Content $ApiTokenFile | ConvertTo-SecureString
      New-Variable -Name A4MondayApiToken -Value $ApiToken -Scope Script -Force -Option ReadOnly
    }
    else {
      Throw 'You have to set an ApiToken. Use the Set-A4MondayApiToken function.'
    }
  }
  if (-not $Script:MondayApiVersion) {
    New-Variable -Name APIversion -Value "2024-01" -Scope Script -Force -Option ReadOnly #Setting 2024-01 API version as default
  }
  else {
    New-Variable -Name APIversion -Value $Script:MondayApiVersion -Scope Script -Force -Option ReadOnly #Can be overwritten with $Script:MondayApiVersion
  }
      
  return @{
    Authorization = (New-Object pscredential -ArgumentList 'dump', $A4MondayApiToken).GetNetworkCredential().Password
    'API-Version' = ($APIversion)
  }
}

Function Move-A4MondayItemToGroup {
  Param(
    [parameter(Mandatory)]  $ItemID,
    [parameter(Mandatory)]  $GroupID
  )

  $query = @"
  mutation{
      move_item_to_group(item_id:$ItemID group_id:"$GroupID"){
          id
      }
  }
"@

  Return(Invoke-A4MondayQuery -Query $Query )
}

Function Set-A4MondayTextColumnValue {
  Param(
    [parameter(Mandatory)]  $ItemID,
    [parameter(Mandatory)]  $BoardID,
    [parameter(Mandatory)]  $ColumnID,
    [parameter(Mandatory)]  $Value,
    [switch]                $create_labels_if_missing #create new status if not present
    
  )
  if ($create_labels_if_missing) {
    $query = @"
  mutation{
    change_simple_column_value(item_id:$ItemID, board_id:$BoardID, column_id: "$ColumnID", value:"$Value", create_labels_if_missing: true)
      {
        name
      }
    }
"@
  }
  else {
    $query = @"
  mutation{
    change_simple_column_value(item_id:$ItemID, board_id:$BoardID, column_id: "$ColumnID", value:"$Value")
      {
        name
      }
    }
"@
  } 
  Return(Invoke-A4MondayQuery -Query $Query )
}

Function Get-A4MondayUser {
  # TODO: Get all if no user id is provided, Email and UserID are exclude each other
  Param(
    [Parameter(ParameterSetName = "UserID")] [int[]]       $UserID,
    [Parameter(ParameterSetName = "Email")] [string[]]    $Email
  )
  $Filter = ''
  if ($UserID) {
    $Filter = "(ids: [$( $UserID -join ', ' )])"
  }
  elseif ($Email) {
    $Filter = "(emails: [`"$( $Email -join '`", `"' )`"])"
  }

  $query = @"
  query {
    users $Filter {
        created_at
        email
        id
        is_guest 
    }
}
"@

  Return((Invoke-A4MondayQuery -Query $query).data.users)
}

function Add-A4MondayBoardSubscriber {
  Param(
    [Parameter(Mandatory = $true)] $BoardID,
    [Parameter(ParameterSetName = "UserID", Mandatory = $true)]  $UserID,
    [Parameter(ParameterSetName = "Email", Mandatory = $true)] [string[]] $Email
  )

  If ($null -ne $Email) {
    $UserID = (Get-A4MondayUser -Email $Email).data.users.id
  }
      
  $UserID = ($UserID) -join ','

  $query = "
          mutation{
                add_subscribers_to_board(board_id:$BoardID kind:subscriber user_ids:[$UserID]) {
                  id
                  name
                  is_guest
                }
          }"

  Return((Invoke-A4MondayQuery -Query $query).data.add_subscribers_to_board)
}

Function Get-A4MondayBoardSubscriber {
  Param(
    [Parameter(Mandatory = $true)][long]     $BoardID
  )
  $Query = @"
  query {
    boards (ids: $BoardID) {
      subscribers {
        id
        name
        email
      }
      }
    }
"@
  $Subscribers = (Invoke-A4MondayQuery -Query $Query).data.boards.subscribers
  Return $Subscribers
}

Function Get-A4MondayBoardName {
  Param(
    [Parameter(Mandatory = $true)][long] $BoardID
  )
  $Query = @"
  query {
    boards (ids: $BoardID) {
      name
      }
    }
"@
  $BoardName = (Invoke-A4MondayQuery -Query $Query).data.boards.name
  Return $BoardName
}

Function Invoke-A4MondayQuery {
  Param(
    [Parameter(mandatory = $true)] $Query
  )
  $result = $null
  $result = Invoke-GraphQLQuery -Query $Query -Headers (Get-A4MondayHeader) -Uri $A4MondayURL
  Return($result)
}

Function Get-A4MondayGroupID {
  Param(
    [Parameter(Mandatory = $true)][long]     $BoardID,  
    [Parameter(Mandatory = $true)][string]  $GroupName
  )
  $Query = @"
    query {
      boards (ids: $BoardID) {
        groups{
          id
          title
        }
      }
    }
"@
  $Groups = (Invoke-A4MondayQuery -Query $Query).data.boards.groups
  Return ($Groups | Where-Object title -EQ $GroupName | Select-Object -ExpandProperty id)
}

Function Get-A4MondayValueOfColumn {
  Param(
    [Parameter(Mandatory = $True)] $column_value
  )

  if ($null -eq ($column_value.value) -or '' -eq ($column_value.value) ) {
    return $column_value.value
  }
  #write-host $column_value.type -ForegroundColor Green

  $Value = switch ($column_value.column.type) {
    'boolean' {
      if (($column_value.value | ConvertFrom-Json).checked -eq 'true') {
        $true
      }
      else {
        $false
      }
    }
    'multiple-person' { 
      $PersonObj = New-Object psobject
      $PersonObj | Add-Member -MemberType NoteProperty -Name 'Text' -Value ($column_value.text)
      $PersonObj | Add-Member -MemberType NoteProperty -Name ID -Value (($column_value.value | ConvertFrom-Json).personsAndTeams.id)
      $PersonObj
    }
    'people' {
      $PersonObj = New-Object psobject
      $PersonObj | Add-Member -MemberType NoteProperty -Name 'Text' -Value ($column_value.text)
      $PersonObj | Add-Member -MemberType NoteProperty -Name ID -Value (($column_value.value | ConvertFrom-Json).personsAndTeams.id)
      $PersonObj
    }
    'date' {
      if ($column_value.text -eq '') {
        $null
      }
      else {
        [datetime]($column_value.text)
      }
    }
    'last_updated' {
      $Updater = New-Object psobject
      $Updater | Add-Member -MemberType NoteProperty -Name 'Updated_at' ($column_value.text)
      $Updater | Add-Member -MemberType NoteProperty -Name UpdaterID (($column_value.value | ConvertFrom-Json).updater_id)
      $Updater
    }
    'creation_log' {
      $Creator = New-Object psobject
      $Creator | Add-Member -MemberType NoteProperty -Name 'Created_at' ($column_value.text)
      $Creator | Add-Member -MemberType NoteProperty -Name CreatorID (($column_value.value | ConvertFrom-Json).creator_id)
      $Creator
    }
    Default { $column_value.text }
  }
  Return $Value
}

Function New-A4MondayComment {
  Param(
    [Parameter(Mandatory = $true)][long]    $ItemID,  
    [Parameter(Mandatory = $true)][string]  $Comment
  )
  $Query = @"
 mutation {
  create_update (item_id: $ItemID, body: "$Comment") {
    id  
    body
  }
}
"@

  try {
    $response = Invoke-A4MondayQuery -Query $query
  }
  catch {
    Write-Host "item_id: $ItemID, body: $Comment"
    Write-Host $_
    Return
  }
  finally {
    if ($null -ne $response.errors) {
      Write-Host "item_id: $ItemID, body: $Comment"
      Write-Host $response.errors.message
    }
  }
  Return
}

Function New-A4MondayBoard {
  Param(
    [Parameter(Mandatory = $true)][string]    $Name,  
    [Parameter(Mandatory = $true)]            $UserID,
    [Parameter(Mandatory = $false)][string]   $BoardType = 'share', #Default = share, can also be 'public' or 'private'
    [Parameter(Mandatory = $false)][string]   $Folder = '10821400'
  )
  $UserID = ($UserID) -join ','
  $Query = @"
 mutation {
  create_board (board_name: "$Name", board_kind: $BoardType, folder_id: $Folder, board_subscriber_ids: [$UserID]) {
      id
      name
  }
}
"@
  Return((Invoke-A4MondayQuery -Query $query).data.create_board)
}

Function New-A4MondayItem {
  Param(
    [Parameter(Mandatory = $true)][long]    $BoardID,
    [Parameter(Mandatory = $true)][string]  $ItemName,
    [Parameter(Mandatory = $true)][string]  $GroupID
  )
  ####TODO find out how to set value in columns during item creation
  $Query = @"
 mutation {
  create_item (board_id: $BoardID, group_id: "$GroupID", item_name: "$ItemName"){
      id
  }
}
"@
  Return((Invoke-A4MondayQuery -Query $query).data.create_item)
}


Function Get-A4MondayItem {
  #TODO: Set wchich properties we have to get for column values. 
  [CmdletBinding(DefaultParameterSetName = 'AllItems')]
  Param(
    [Parameter(Mandatory = $true)][long]                      $BoardID,
    [Parameter(ParameterSetName = 'GroupID', Mandatory = $False)][string]   $GroupID,
    [Parameter(ParameterSetName = 'GroupName', Mandatory = $False)][string] $GroupName,
    [Parameter(ParameterSetName = 'AllItems')][switch] $GetGroups, #We gave to get groups in separately query because monday.com is complaining about complexity of the query. 
    [Parameter()][switch] $GetColumnID
  )

  if ('' -ne $GroupName) {
    $GroupID = Get-A4MondayGroupID -BoardID $BoardID -GroupName $GroupName
  }

  do {
    if ('' -ne $GroupID) {
      $query = @"
        query {
          boards(ids: $BoardID) {
            groups(ids: "$GroupID") {
              items_page$items_page_parameters {
                cursor
                items {
                  subitems {
                    name
                    id
                  }
                  name
                  id
                  creator {
                    id
                    email
                  }
                  group {
                    title
                  }
                  column_values {
                    column {
                      id
                      title
                      type
                    }
                    text
                    value
                  }
                }
              }
            }
          }
        }
"@
      $Response = Invoke-A4MondayQuery -Query $query
      $Cursor = $Response.data.boards.groups.items_page.cursor
      if ($Cursor) {
        $items_page_parameters = "(cursor: `"$Cursor`")"
      }
      $Items += $Response.data.boards.groups.items_page.items
    }
    else {  
      $query = @"
        query {
          boards(ids: $BoardID) {
            items_page$items_page_parameters {
              cursor
              items {
                subitems {
                  name
                  id
                }
                name
                id
                creator {
                  id
                  email
                }
                group {
                  title
                }
                column_values {
                  column {
                    id
                    title
                    type
                  }
                  text
                  value
                }
              }
            }
          }
        }
"@
      $Response = Invoke-A4MondayQuery -Query $query
      $Cursor = $Response.data.boards.items_page.cursor
      if ($Cursor) {
        $items_page_parameters = "(cursor: `"$Cursor`")"
      }
      $Items += $Response.data.boards.items_page.items
    }
  }while ($null -ne $Cursor)

  $outObjects = Foreach ($Item in $Items) {
    $i = 1
    $OutObj = New-Object psobject 
    $OutObj | Add-Member -MemberType NoteProperty -Name 'id' -Value ($Item.id)
    $OutObj | Add-Member -MemberType NoteProperty -Name 'name' -Value ($Item.name)
    $OutObj | Add-Member -MemberType NoteProperty -Name 'Group' -Value ($Item.group.title)
    $CreatorObj = New-Object psobject -Property @{'id' = $Item.Creator.id; 'email' = $Item.Creator.email }
    $OutObj | Add-Member -MemberType NoteProperty -Name 'Creator' -Value $CreatorObj
    Foreach ($column_value in $Item.column_values) {
      if ($GetColumnID) {
        $ColumnName = $column_value.column.id
      }
      else {
        $ColumnName = $column_value.column.title
      }
      if ($ColumnName -like 'Subitems') { #Subitems have to be handled separately
        continue
      }
      if ($null -eq $OutObj.$ColumnName) {
        $OutObj | Add-Member -MemberType NoteProperty -Name $ColumnName -Value (Get-A4MondayValueOfColumn -column_value $column_value)
      }
      else {
        Write-Verbose "Multiple columns of the same name $ColumnName, adding i= $i to the name to avoid errors"
        $i++
        $OutObj | Add-Member -MemberType NoteProperty -Name "$($ColumnName)[$($i)]" -Value (Get-A4MondayValueOfColumn -column_value $column_value)
      }
          
    }
    if ($null -ne $Item.subitems) {

      $OutObj | Add-Member -MemberType NoteProperty -Name 'Subitems' -Value $Item.subitems
    }
    $OutObj
  }
  if ($GetGroups) {
    $Groups = (Invoke-A4MondayQuery -Query "query{boards(ids:$BoardID){groups{id title items{id}}}}").data.boards.groups
    Foreach ($Group in $Groups) {
      $outObjects | Where-Object id -In ($Group.items.id) | ForEach-Object { $_ | Add-Member -MemberType NoteProperty -Name 'Group' -Value ($Group.title) }
    }
  }
  Return($outObjects)  

}