$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "backup_database.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "AdviserLink backup failed with exit code $LASTEXITCODE."
}
