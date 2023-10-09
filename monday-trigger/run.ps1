using namespace System.Net

param($Request, $TriggerMetadata)
Import-Module "A4Monday"
$VerbosePreference = "Continue"

# Input bindings are passed in via param block.
Write-Verbose "PowerShell HTTP trigger function processed a request."

#Verify challenge token if needed
Confirm-ChallengeToken -Body $Request.Body  -Method $Request.Method

Write-Verbose "Request body from monday webhook:"
$jsonString = $Request.Body | ConvertTo-Json -depth 10
Write-Verbose $jsonString

#Extract monday Item details
$boardId = $Request.Body.Event.boardId
$groupId = $Request.Body.Event.groupId
$itemId = $Request.Body.Event.pulseId
$editedColumnId = $env:COLUMN_ID
$itemName = $Request.Body.Event.pulseName

Set-MondayApiToken

$tasks = Get-A4MondayItem -BoardID $boardId -GroupID $groupId -GetColumnID
$allIds = $tasks | Select-Object -ExpandProperty $env:COLUMN_ID
$nextId = ($allIds | Measure-Object -Maximum).Maximum + 1


#Create next ID for created item
$idTitle = "$nextId" + " " + "$itemName"
Set-A4MondayTextColumnValue -ItemID $itemId -BoardID $boardId -ColumnID "$editedColumnId" -Value $nextId

#Create new Clockify task with previously generated unique ID
Add-ClockifyTask -WorkspaceId $env:CLOCKIFY_WORKSPACE_ID -ProjectId $env:CLOCKIFY_PROJECT_ID -TaskName $idTitle

