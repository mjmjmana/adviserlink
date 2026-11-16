@echo off
REM AdviserLink - Automated Setup Script for Windows
REM Run as Administrator for best results

echo ============================================
echo  AdviserLink Setup Script
echo  Thesis/Capstone Advising System - ISU Echague
echo ============================================
echo.

REM Check if running as admin
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running as Administrator
) else (
    echo [WARN] Not running as Administrator - some steps may fail
    echo.
)

echo.
echo [1/8] Checking prerequisites...

REM Check Python
python --version >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Python found: & python --version
) else (
    echo [ERROR] Python not found! Install from https://python.org (3.10+)
    pause
    exit /b 1
)

REM Check Node.js
node --version >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Node.js found: & node --version
) else (
    echo [ERROR] Node.js not found! Install from https://nodejs.org (18+)
    pause
    exit /b 1
)

REM Check Flutter
flutter --version >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Flutter found: & flutter --version
) else (
    echo [WARN] Flutter not in PATH. Add C:\flutter\bin to PATH and restart terminal.
)

REM Check MySQL (XAMPP)
if exist "C:\xampp\mysql\bin\mysql.exe" (
    echo [OK] XAMPP MySQL found
) else if exist "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" (
    echo [OK] MySQL found
) else (
    echo [WARN] MySQL not detected. Install XAMPP from https://www.apachefriends.org/
)

echo.
echo [2/8] Setting up database...
echo Make sure MySQL is running in XAMPP Control Panel!
pause

mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS adviserlink_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
if %errorLevel% == 0 (
    echo [OK] Database created
    mysql -u root -p adviserlink_db < database\schema.sql
    if %errorLevel% == 0 (
        echo [OK] Schema imported
    ) else (
        echo [ERROR] Schema import failed
    )
) else (
    echo [ERROR] Database creation failed. Check MySQL is running and root password.
)

echo.
echo [3/8] Setting up Backend...
cd backend
if not exist "venv" (
    python -m venv venv
    echo [OK] Virtual environment created
)
call venv\Scripts\activate
pip install -r requirements.txt
if %errorLevel% == 0 (
    echo [OK] Python dependencies installed
) else (
    echo [ERROR] Failed to install Python dependencies
)

if not exist ".env" (
    copy .env.example .env
    echo [OK] .env created from .env.example
    echo [IMPORTANT] Edit backend\.env with your settings!
) else (
    echo [OK] .env already exists
)

echo.
echo [4/8] Seeding demo data...
python seed_demo_users.py
if %errorLevel% == 0 (
    echo [OK] Demo users seeded
) else (
    echo [WARN] Demo seeding failed (maybe already seeded)
)

cd ..

echo.
echo [5/8] Setting up Web (React)...
cd web
npm install
if %errorLevel% == 0 (
    echo [OK] Web dependencies installed
) else (
    echo [ERROR] Failed to install web dependencies
)
cd ..

echo.
echo [6/8] Setting up Mobile (Flutter)...
cd mobile
flutter pub get
if %errorLevel% == 0 (
    echo [OK] Flutter dependencies installed
) else (
    echo [ERROR] Failed to install Flutter dependencies
)

flutter pub run flutter_launcher_icons:main
if %errorLevel% == 0 (
    echo [OK] App icons generated
) else (
    echo [WARN] Icon generation failed (run manually later)
)
cd ..

echo.
echo [7/8] Configuring Android for local network access...
echo.
echo IMPORTANT: Edit mobile/android/app/src/main/AndroidManifest.xml
echo Add these inside <application> tag:
echo   android:usesCleartextTraffic="true"
echo And add this permission before <application>:
echo   <uses-permission android:name="android.permission.INTERNET"/>
echo.
pause

echo.
echo [8/8] Verification...
echo.
echo Starting backend test...
cd backend
call venv\Scripts\activate
timeout /t 2 >nul
start "AdviserLink API" cmd /k "uvicorn main:app --reload --host 0.0.0.0 --port 8000"
cd ..
timeout /t 3 >nul

echo.
echo ============================================
echo  SETUP COMPLETE!
echo ============================================
echo.
echo NEXT STEPS:
echo 1. Edit backend\.env with your JWT_SECRET and settings
echo 2. Backend API: http://localhost:8000/docs
echo 3. Web App:     cd web && npm run dev (then open http://localhost:5173)
echo 4. Mobile:      cd mobile && flutter run
echo 5. Demo login:  juan.delacruz@isu.edu.ph / test1234
echo.
echo For deployment to another PC or phone, see DEPLOYMENT_GUIDE.md
echo.
pause