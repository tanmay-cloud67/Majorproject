@echo off
title Launch Indian Meal Nutrition Health App
echo ====================================================
echo Starting Node.js Backend Server (Port 3000)...
echo ====================================================
start "Nutrition Backend Server" cmd /k "cd /d %~dp0backend_node && node server.js"

echo Waiting 3 seconds for backend server to start...
timeout /t 3 /nobreak > nul

echo ====================================================
echo Launching Flutter Application...
echo ====================================================
cd /d %~dp0
flutter run -d edge

pause
