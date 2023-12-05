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
$sponsoringBubbleName = $Request.Body.Event.value.label.text

$sponsoringBubbleNameClkTag = Get-A4beeBubblesMapping -BubbleName $sponsoringBubbleName
Write-Verbose "Sponsoring bubble name clockify tag: $sponsoringBubbleNameClkTag"

$clientId = Get-ClockifyClientIdByName -WorkspaceId $env:CLOCKIFY_WORKSPACE_ID -ClientName $sponsoringBubbleNameClkTag
$projectId = Get-ClockifyProjectIdByName -WorkspaceId $env:CLOCKIFY_WORKSPACE_ID -ClientId $clientId -ProjectName $env:PROJECT_NAME

#Create new Clockify task with previously generated unique ID
Add-ClockifyTask -WorkspaceId $env:CLOCKIFY_WORKSPACE_ID -ProjectId $projectId -TaskName $itemName

