#!/bin/bash
# AdviserLink - Automated Setup Script for Linux/macOS
# Run with: bash setup.sh

set -e

echo "============================================"
echo "  AdviserLink Setup Script"
echo "  Thesis/Capstone Advising System - ISU Echague"
echo "============================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} $1 found: $($1 --version 2>/dev/null | head -1)"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} $1 not found!"
        return 1
    fi
}

echo "[1/8] Checking prerequisites..."

check_cmd python3 || { echo "Install Python 3.10+"; exit 1; }
check_cmd node || { echo "Install Node.js 18+"; exit 1; }
check_cmd npm || { echo "Install npm"; exit 1; }

if command -v flutter >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Flutter found: $(flutter --version | head -1)"
else
    echo -e "${YELLOW}[WARN]${NC} Flutter not in PATH. Install from https://flutter.dev"
fi

if command -v mysql >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} MySQL client found"
elif command -v mariadb >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} MariaDB client found"
else
    echo -e "${YELLOW}[WARN]${NC} MySQL/MariaDB client not found. Install mysql-client."
fi

echo ""
echo "[2/8] Setting up database..."
echo "Make sure MySQL/MariaDB is running!"

read -p "MySQL root password (press Enter if none): " -s MYSQL_ROOT_PASS
echo ""

MYSQL_CMD="mysql -u root"
if [ -n "$MYSQL_ROOT_PASS" ]; then
    MYSQL_CMD="mysql -u root -p$MYSQL_ROOT_PASS"
fi

$MYSQL_CMD -e "CREATE DATABASE IF NOT EXISTS adviserlink_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK]${NC} Database created"
    $MYSQL_CMD adviserlink_db < database/schema.sql 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} Schema imported"
    else
        echo -e "${RED}[ERROR]${NC} Schema import failed"
    fi
else
    echo -e "${RED}[ERROR]${NC} Database creation failed. Check MySQL is running and credentials."
fi

echo ""
echo "[3/8] Setting up Backend..."
cd backend

if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}[OK]${NC} Virtual environment created"
fi

source venv/bin/activate
pip install -r requirements.txt
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK]${NC} Python dependencies installed"
else
    echo -e "${RED}[ERROR]${NC} Failed to install Python dependencies"
    exit 1
fi

if [ ! -f ".env" ]; then
    cp .env.example .env
    echo -e "${GREEN}[OK]${NC} .env created from .env.example"
    echo -e "${YELLOW}[IMPORTANT]${NC} Edit backend/.env with your settings!"
else
    echo -e "${GREEN}[OK]${NC} .env already exists"
fi

echo ""
echo "[4/8] Seeding demo data..."
python seed_demo_users.py
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK]${NC} Demo users seeded"
else
    echo -e "${YELLOW}[WARN]${NC} Demo seeding failed (maybe already seeded)"
fi

cd ..

echo ""
echo "[5/8] Setting up Web (React)..."
cd web
npm install
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK]${NC} Web dependencies installed"
else
    echo -e "${RED}[ERROR]${NC} Failed to install web dependencies"
    exit 1
fi
cd ..

echo ""
echo "[6/8] Setting up Mobile (Flutter)..."
cd mobile
flutter pub get
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK]${NC} Flutter dependencies installed"
else
    echo -e "${RED}[ERROR]${NC} Failed to install Flutter dependencies"
    exit 1
fi

flutter pub run flutter_launcher_icons:main
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK]${NC} App icons generated"
else
    echo -e "${YELLOW}[WARN]${NC} Icon generation failed (run manually later)"
fi
cd ..

echo ""
echo "[7/8] Configuring Android for local network access..."
echo ""
echo "IMPORTANT: Edit mobile/android/app/src/main/AndroidManifest.xml"
echo "Add these inside <application> tag:"
echo '  android:usesCleartextTraffic="true"'
echo "And add this permission before <application>:"
echo '  <uses-permission android:name="android.permission.INTERNET"/>'
echo ""

echo "[8/8] Starting backend for verification..."
cd backend
source venv/bin/activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
cd ..
sleep 3

echo ""
echo "============================================"
echo "  SETUP COMPLETE!"
echo "============================================"
echo ""
echo "NEXT STEPS:"
echo "1. Edit backend/.env with your JWT_SECRET and settings"
echo "2. Backend API: http://localhost:8000/docs"
echo "3. Web App:     cd web && npm run dev (then open http://localhost:5173)"
echo "4. Mobile:      cd mobile && flutter run"
echo "5. Demo login:  juan.delacruz@isu.edu.ph / test1234"
echo ""
echo "Backend running in background (PID: $BACKEND_PID)"
echo "Press Ctrl+C to stop it, or run 'kill $BACKEND_PID'"
echo ""
echo "For deployment to another PC or phone, see DEPLOYMENT_GUIDE.md"
echo ""
read -p "Press Enter to stop backend and exit..."
kill $BACKEND_PID 2>/dev/null
echo "Done."