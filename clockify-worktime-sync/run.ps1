# Input bindings are passed in via param block.
param($Timer)

$VerbosePreference = "Continue"

Set-MondayApiToken

$mondayTasks = get-a4mondayitem -BoardID $env:MONDAY_BOARD_ID -GetColumnID
$allClockifyTasks = Get-ClockifyTasks -WorkspaceId $env:CLOCKIFY_WORKSPACE_ID -ProjectId $env:CLOCKIFY_PROJECT_ID

foreach ($task in $mondayTasks) {
    $taskName = $task.name
    Write-Verbose "Calculating time for $taskName ..."

    $id = $task | Select-Object -ExpandProperty $env:COLUMN_ID

    $clockifyTask = ($allClockifyTasks | Where-Object { $_.name -eq "$id $taskName" })

    $duration = $clockifyTask | Select-Object -ExpandProperty "duration"
    $floatDuration = 0.0
    $manDays = 0.0
    $pattern = "PT([0-9]+)H([0-9]*)?M?([0-9]*)?S?"

    if (($null -ne $duration) -and ($duration -match $pattern)) {
        $h = $matches[1] ?? 0
        $m = $matches[2] ?? 0
        $s = $matches[3] ?? 0

        $totalTime = New-TimeSpan -Hours $h -Minutes $m -Seconds $s

        $floatDuration = $totalTime.TotalHours
        $manDays = ([Math]::Round(($floatDuration / 8), 1)) 
    }

    Write-Verbose "Total time for $taskName is $floatDuration h, which is $manDays man days."
    Set-A4MondayTextColumnValue -ItemID $task.id -BoardID $env:MONDAY_BOARD_ID -ColumnID $env:DURATION_COLUMN_ID -Value $manDays
}

