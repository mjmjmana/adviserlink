#!/usr/bin/env pwsh
# AdviserLink - Complete Setup Script (PowerShell)
# Run as Administrator in PowerShell

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AdviserLink Complete Setup" -ForegroundColor Cyan
Write-Host "  Thesis/Capstone Advising System - ISU Echague" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Get the directory where this script is located
$basePath = $PSScriptRoot
$mysqlExe = "C:\xampp\mysql\bin\mysql.exe"

# 1. Check MySQL
Write-Host "[1/6] Checking MySQL..." -ForegroundColor Yellow
if (-not (Test-Path $mysqlExe)) {
    Write-Host "ERROR: XAMPP MySQL not found at $mysqlExe" -ForegroundColor Red
    Write-Host "Install XAMPP from https://www.apachefriends.org/" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "OK: MySQL found" -ForegroundColor Green

# 2. Start MySQL
Write-Host "[2/6] Starting MySQL..." -ForegroundColor Yellow
try { net start mysql } catch { Write-Host "MySQL may already be running" -ForegroundColor Gray }

# 3. Import schema
Write-Host "[3/6] Importing database schema..." -ForegroundColor Yellow
& $mysqlExe -u root -e "CREATE DATABASE IF NOT EXISTS adviserlink_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
$schemaPath = Join-Path $basePath "database\schema.sql"
& $mysqlExe -u root adviserlink_db -e "source `"$schemaPath`";"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Schema import failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "OK: Database ready" -ForegroundColor Green

# 4. Backend setup
Write-Host "[4/6] Setting up Backend..." -ForegroundColor Yellow
Set-Location (Join-Path $basePath "backend")
if (-not (Test-Path "venv")) {
    python -m venv venv
    Write-Host "OK: Virtual environment created" -ForegroundColor Green
}
& .\venv\Scripts\Activate.ps1
pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install Python dependencies" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "OK: Backend dependencies installed" -ForegroundColor Green

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "OK: .env created" -ForegroundColor Green
}

# 5. Seed demo data
Write-Host "[5/6] Seeding demo users..." -ForegroundColor Yellow
python seed_demo_scenario.py --reset
Write-Host "OK: Demo users ready" -ForegroundColor Green

# 6. Web setup
Write-Host "[6/6] Setting up Web..." -ForegroundColor Yellow
Set-Location (Join-Path $basePath "web")
npm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install web dependencies" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "OK: Web dependencies installed" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SETUP COMPLETE!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT: Open 3 terminals and run:" -ForegroundColor Yellow
Write-Host ""
Write-Host "TERMINAL 1 - Backend:" -ForegroundColor Cyan
Write-Host "  cd `"$basePath\backend`""
Write-Host "  venv\Scripts\activate"
Write-Host "  uvicorn main:app --reload --host 0.0.0.0 --port 8000"
Write-Host ""
Write-Host "TERMINAL 2 - Web:" -ForegroundColor Cyan
Write-Host "  cd `"$basePath\web`""
Write-Host "  npm run dev"
Write-Host ""
Write-Host "TERMINAL 3 - Mobile:" -ForegroundColor Cyan
Write-Host "  cd `"$basePath\mobile`""
Write-Host "  flutter create ."
Write-Host "  flutter pub get"
Write-Host "  flutter run"
Write-Host ""
Write-Host "DEMO LOGINS (password: test1234):" -ForegroundColor Green
Write-Host "  Student: juan.delacruz@isu.edu.ph"
Write-Host "  Adviser: maria.santos@isu.edu.ph"
Write-Host "  Admin:   admin@isu.edu.ph"
Write-Host ""
Write-Host "MOBILE API URL (emulator): http://10.0.2.2:8000" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"