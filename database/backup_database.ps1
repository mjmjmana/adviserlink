$ErrorActionPreference = "Stop"
$backend = Join-Path $PSScriptRoot "..\backend"
$python = Join-Path $backend "venv\Scripts\python.exe"

if (-not (Test-Path $python)) {
    throw "Backend virtual environment not found. Create it and install backend requirements first."
}

Push-Location $backend
try {
    & $python "backup_database.py"
    if ($LASTEXITCODE -ne 0) {
        throw "AdviserLink database backup failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
