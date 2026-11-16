@echo off
REM AdviserLink - One-click Setup for Windows
REM Run as Administrator

echo ============================================
echo  AdviserLink Complete Setup
echo  Thesis/Capstone Advising System - ISU Echague
echo ============================================
echo.

REM Get the directory where this script is located
set "BASE_DIR=%~dp0"
REM Remove trailing backslash
if "%BASE_DIR:~-1%"=="\" set "BASE_DIR=%BASE_DIR:~0,-1%"

REM 1. Check MySQL (XAMPP)
echo [1/6] Checking MySQL...
if not exist "C:\xampp\mysql\bin\mysql.exe" (
    echo ERROR: XAMPP MySQL not found at C:\xampp\mysql\bin\mysql.exe
    echo Install XAMPP from https://www.apachefriends.org/
    pause
    exit /b 1
)
echo OK: MySQL found

REM 2. Start MySQL service (if not running)
echo [2/6] Starting MySQL...
net start mysql 2>nul || echo MySQL may already be running

REM 3. Import database schema
echo [3/6] Importing database schema...
C:\xampp\mysql\bin\mysql.exe -u root -e "CREATE DATABASE IF NOT EXISTS adviserlink_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
C:\xampp\mysql\bin\mysql.exe -u root adviserlink_db < "%BASE_DIR%\database\schema.sql"
if %errorlevel% neq 0 (
    echo ERROR: Schema import failed
    pause
    exit /b 1
)
echo OK: Database ready

REM 4. Setup Backend
echo [4/6] Setting up Backend...
cd /d "%BASE_DIR%\backend"
if not exist "venv" (
    python -m venv venv
    echo OK: Virtual environment created
)
call venv\Scripts\activate
pip install -r requirements.txt >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Failed to install Python dependencies
    pause
    exit /b 1
)
echo OK: Backend dependencies installed

if not exist ".env" (
    copy .env.example .env
    echo OK: .env created
)

REM 5. Seed demo data
echo [5/6] Seeding demo users...
python seed_demo_scenario.py --reset
echo OK: Demo users ready

REM 6. Setup Web
echo [6/6] Setting up Web...
cd /d "%BASE_DIR%\web"
npm install >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Failed to install web dependencies
    pause
    exit /b 1
)
echo OK: Web dependencies installed

echo.
echo ============================================
echo  SETUP COMPLETE!
echo ============================================
echo.
echo NEXT: Open 3 terminals and run:
echo.
echo TERMINAL 1 - Backend:
echo   cd "%BASE_DIR%\backend"
echo   venv\Scripts\activate
echo   uvicorn main:app --reload --host 0.0.0.0 --port 8000
echo.
echo TERMINAL 2 - Web:
echo   cd "%BASE_DIR%\web"
echo   npm run dev
echo.
echo TERMINAL 3 - Mobile:
echo   cd "%BASE_DIR%\mobile"
echo   flutter create .
echo   flutter pub get
echo   flutter run
echo.
echo DEMO LOGINS (password: test1234):
echo   Student: juan.delacruz@isu.edu.ph
echo   Adviser: maria.santos@isu.edu.ph
echo   Admin:   admin@isu.edu.ph
echo.
echo MOBILE API URL (emulator): http://10.0.2.2:8000
echo.
pause