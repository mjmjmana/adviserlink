param(
    [string]$TaskName = "AdviserLink Daily Database Backup",
    [string]$At = "2:00AM"
)

$ErrorActionPreference = "Stop"
$backupScript = Join-Path $PSScriptRoot "backup_database.ps1"
if (-not (Test-Path $backupScript)) {
    throw "Backup script not found: $backupScript"
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$backupScript`""
$trigger = New-ScheduledTaskTrigger -Daily -At $At
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Creates and verifies an AdviserLink database backup." -Force | Out-Null
Write-Host "Registered '$TaskName' at $At for the current Windows user."
Write-Host "The user must be signed in for the task to run. Check Task Scheduler history after the first run."
