Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Starting Node.js Backend Server on Port 3000..." -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan

Start-Process cmd -ArgumentList "/k cd /d `"$PSScriptRoot\backend_node`" && node server.js" -WindowStyle Normal

Start-Sleep -Seconds 3

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Launching Flutter App on Edge..." -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan

Set-Location $PSScriptRoot
flutter run -d edge
