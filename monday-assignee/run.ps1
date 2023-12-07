using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

Import-Module "A4Monday"
$VerbosePreference = "Continue"

# Write to the Azure Functions log stream.
Write-Verbose "PowerShell HTTP trigger function processed a request."

#Verify challenge token if needed
Confirm-ChallengeToken -Body $Request.Body -Method $Request.Method

$jsonString = $Request.Body | ConvertTo-Json -depth 10
Write-Verbose $jsonString

Set-MondayApiToken

#Extract monday Item details
$boardId = $Request.Body.Event.boardId
$itemId = $Request.Body.Event.pulseId
$itemName = $Request.Body.Event.pulseName

$currentMondayItem = Get-A4MondayItem -BoardID $boardId -GetColumnID | Where-Object { $_.id -eq $itemId } 

$sponsoringBubbleName = $currentMondayItem | Select-Object -ExpandProperty "status"

$projectId = Get-ClockifyProjectIdByBubbleName -WorkspaceId $env:CLOCKIFY_WORKSPACE_ID -ProjectName $env:PROJECT_NAME -MondayBubbleName $sponsoringBubbleName

$currentAssigneesFromMonday = @()
$currentMondayItem.PSObject.Properties | ForEach-Object { 
  $currentValue = $_.Value
  if ($currentValue -ne $null -and $currentValue.ID) {
    $currentValue.ID | ForEach-Object {
      $email = Get-A4MondayUser -UserID $_ | Select-Object -ExpandProperty "email"
      $clockifyId = Get-ClockifyUserByEmail -WorkspaceId $env:CLOCKIFY_WORKSPACE_ID -UserEmail $email | Select-Object -ExpandProperty "id"
      $currentAssigneesFromMonday += $clockifyId
    }
  }
}

$nextAssignees = ($currentAssigneesFromMonday | Select-Object -Unique)
Update-ClockifyAsignees -WorkspaceId $env:CLOCKIFY_WORKSPACE_ID -ProjectId $projectId -TaskName $itemName -Assignees $nextAssignees 
