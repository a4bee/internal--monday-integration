using namespace System.Collections.Generic
using namespace System.Linq

$A4beeBubblesMapping = @{
    "Board"              = "A4BEEBoard"
    "Communication & PR" = "A4BEEBoard"
    "Consulting"         = "A4BEEConsulting"
    "SW Engineering"     = "A4BEESWENGINEERING"
    "IS Engineering"     = "A4BEEISE"
    "Finance"            = "A4BEEFinance"
    "Digital Lab"        = "A4BEELab"
    "Operations"         = "A4BEEOperations"
    "People & Culture"   = "A4BEEPeople&Culture"
    "Revenue & Growth"   = "A4BEERevenueGrowth"
}

function Get-A4beeBubblesMapping {
    param (
        [Parameter(Mandatory = $true)] 
        [string]$BubbleName
    )

    $ClockifyBubbleName = $null
    if ( $A4beeBubblesMapping.ContainsKey($BubbleName) ) {
        $ClockifyBubbleName = $A4beeBubblesMapping[$BubbleName]
    }

    return $ClockifyBubbleName
}

function Send-Response {
    param (
        [Parameter(Mandatory = $true)] 
        [HttpStatusCode]$StatusCode,
        [Parameter(Mandatory = $true)] 
        [string]$Body
    )

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

function Select-NewClockifyAssignees {
    param (
        [string[]]$AllAssignees = @(),
        [string[]]$PrevAssignees = @(),
        [string[]]$NewAssignees = @()
    )

    $nextAssignees = $AllAssignees | Where-Object { $PrevAssignees -NotContains $_ }
    $nextAssignees = $nextAssignees + $NewAssignees

    return ($nextAssignees | Select-Object -Unique)
}

function Get-CurrentlyLoggedInClockifyUserId {
    $clockifyApiToken = Get-ClockifyApiToken
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("x-api-key", $clockifyApiToken)
    
    $response = Invoke-RestMethod 'https://api.clockify.me/api/v1/user' -Method 'GET' -Headers $headers
    return $response.id
}

function Add-ClockifyTask {
    param (
        [Parameter(Mandatory = $true)] 
        [string]$WorkspaceId,
        [Parameter(Mandatory = $true)] 
        [string]$ProjectId,
        [Parameter(Mandatory = $true)] 
        [string]$TaskName
    )

    $currentlyLoggedInClockifyUserId = Get-CurrentlyLoggedInClockifyUserId

    $clockifyApiToken = Get-ClockifyApiToken
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("x-api-key", $clockifyApiToken)
    $headers.Add("Content-Type", "application/json")

    $body = "{`n  `"assigneeId`":`"$currentlyLoggedInClockifyUserId`", `n  `"assigneeIds`": [],`n  `"estimate`": `"PT0S`",`n  `"name`": `"$TaskName`",`n  `"status`": `"ACTIVE`",`n  `"statusEnum`": `"ACTIVE`",`n  `"userGroupIds`": []`n}"

    $response = Invoke-RestMethod "https://api.clockify.me/api/v1/workspaces/$WorkspaceId/projects/$ProjectId/tasks" -Method 'POST' -Headers $headers -Body $body
    $response | ConvertTo-Json
    Write-Verbose $response
}

function Get-ClockifyUserByEmail {
    param (
        [Parameter(Mandatory = $true)] 
        [string]$WorkspaceId,
        [Parameter(Mandatory = $true)] 
        [string]$UserEmail
    )

    $clockifyApiToken = Get-ClockifyApiToken
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("x-api-key", $clockifyApiToken)

    $response = Invoke-RestMethod "https://api.clockify.me/api/v1/workspaces/$WorkspaceId/users?email=$UserEmail" -Method 'GET' -Headers $headers

    return $response
}

function Get-ClockifyClientIdByName {
    param (
        [Parameter(Mandatory = $true)] 
        [string]$WorkspaceId,
        [Parameter(Mandatory = $true)] 
        [string]$ClientName
    )

    $clockifyApiToken = Get-ClockifyApiToken
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("x-api-key", $clockifyApiToken)
    $headers.Add("Content-Type", "application/json")
    $strictNameSearch = $true

    $response = Invoke-RestMethod "https://api.clockify.me/api/v1/workspaces/$WorkspaceId/clients?name=$ClientName&strict-name-search=$strictNameSearch" -Method 'GET' -Headers $headers

    $clientId = ($response ?? [PSCustomObject]@{}).id

    return $clientId
}

function Get-ClockifyProjectIdByName {
    param (
        [Parameter(Mandatory = $true)] 
        [string]$WorkspaceId,
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        [Parameter(Mandatory = $true)]
        [string]$ProjectName
    )
    
    $clockifyApiToken = Get-ClockifyApiToken
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("x-api-key", $clockifyApiToken)
    $headers.Add("Content-Type", "application/json")
    $strictNameSearch = $true
    
    $response = Invoke-RestMethod "https://api.clockify.me/api/v1/workspaces/$WorkspaceId/projects?clients=$ClientId&name=$ProjectName&strict-name-search=$strictNameSearch" -Method 'GET' -Headers $headers 

    $projectId = ($response ?? [PSCustomObject]@{}).id

    return $projectId
}

function Get-ClockifyTaskByName {
    param (
        [Parameter(Mandatory = $true)] 
        [string]$WorkspaceId,
        [Parameter(Mandatory = $true)] 
        [string]$ProjectId,
        [Parameter(Mandatory = $true)] 
        [string]$TaskName
    )
    $clockifyApiToken = Get-ClockifyApiToken
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("x-api-key", $clockifyApiToken)
    $strictNameSearch = $true

    $response = Invoke-RestMethod "https://api.clockify.me/api/v1/workspaces/$WorkspaceId/projects/$ProjectId/tasks?name=$TaskName&strict-name-search=$strictNameSearch" -Method 'GET' -Headers $headers

    return $response
}

function Get-ClockifyTasks {
    param (
        [Parameter(Mandatory = $true)] 
        [string]$WorkspaceId,
        [Parameter(Mandatory = $true)] 
        [string]$ProjectId
    )
    $clockifyApiToken = Get-ClockifyApiToken
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("x-api-key", $clockifyApiToken)

    $response = Invoke-RestMethod "https://api.clockify.me/api/v1/workspaces/$WorkspaceId/projects/$ProjectId/tasks?page-size=0" -Method 'GET' -Headers $headers
    $response 
}

function Update-ClockifyAsignees {
    param (
        [Parameter(Mandatory = $true)] 
        [string]$WorkspaceId,
        [Parameter(Mandatory = $true)] 
        [string]$ProjectId,
        [Parameter(Mandatory = $true)]
        [string[]]$Assignees,
        [Parameter(Mandatory = $true)] 
        [string]$TaskName
    )

    $clockifyApiToken = Get-ClockifyApiToken
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("x-api-key", $clockifyApiToken)
    $headers.Add("Content-Type", "application/json")

    $TaskId = Get-ClockifyTaskByName -WorkspaceId $WorkspaceId -ProjectId $ProjectId -TaskName $TaskName | Select-Object -ExpandProperty "id"

    $body = @{
        "name"        = $TaskName
        "assigneeIds" = $Assignees
    }

    $body = ConvertTo-Json $body
    $response = Invoke-RestMethod "https://api.clockify.me/api/v1/workspaces/$WorkspaceId/projects/$ProjectId/tasks/$TaskId" -Method 'PUT' -Headers $headers -Body $body

    return $response
}

function Confirm-ChallengeToken {
    param (
        [Parameter(Mandatory = $true)] 
        [hashtable]$Body,
        [Parameter(Mandatory = $true)] 
        [string]$Method
    )
    $challengeToken = $Body.challenge

    # Respond with challenge Token
    if ($challengeToken -and $Method -eq "POST") {
        $statusCode = [HttpStatusCode]::OK

        $bodyString = ConvertTo-Json $Body

        Send-Response -Body $bodyString -StatusCode $statusCode
    }
}

function Get-ClockifyApiToken {
    return $env:PROFILE -eq "dev" ? $env:CLOCKIFY_API_TOKEN : (Get-AzKeyVaultSecret -VaultName "monday-clockify-keys" -Name "ClockifyApiKey" -AsPlainText)
}

function Set-MondayApiToken {
    #Get monday api token from key vault
    $mondayApiToken = $env:PROFILE -eq "dev" ? $env:MONDAY_API_TOKEN : (Get-AzKeyVaultSecret -VaultName "monday-clockify-keys" -Name "MondayApiKey" -AsPlainText)

    Set-A4MondayApiToken -AsPlainText -ApiToken $mondayApiToken
}