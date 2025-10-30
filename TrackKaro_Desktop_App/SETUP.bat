@echo off
echo ========================================
echo Track-Karo Desktop App Setup
echo ========================================
echo.

:: Check if Windows version is compatible
ver | find "10.0" >nul
if %errorlevel% equ 0 (
    echo ✅ Windows 10/11 detected - Compatible!
) else (
    echo ❌ This app requires Windows 10 or Windows 11
    echo Please upgrade your operating system
    pause
    exit /b 1
)

:: Check if running from correct folder
if not exist "new_app.exe" (
    echo ❌ Setup Error: new_app.exe not found
    echo Please run this setup from the TrackKaro_Desktop_App folder
    pause
    exit /b 1
)

echo.
echo 🚀 Setting up Track-Karo Desktop App...
echo.

:: Create desktop shortcut (optional)
set /p createShortcut="Create desktop shortcut? (y/n): "
if /i "%createShortcut%"=="y" (
    echo Creating desktop shortcut...
    powershell "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\Track-Karo.lnk'); $Shortcut.TargetPath = '%cd%\new_app.exe'; $Shortcut.WorkingDirectory = '%cd%'; $Shortcut.Description = 'Track-Karo Bus Management System'; $Shortcut.Save()"
    echo ✅ Desktop shortcut created
)

:: Create start menu shortcut (optional)  
set /p createStartMenu="Add to Start Menu? (y/n): "
if /i "%createStartMenu%"=="y" (
    echo Creating Start Menu shortcut...
    if not exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Track-Karo\" mkdir "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Track-Karo\"
    powershell "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Track-Karo\Track-Karo.lnk'); $Shortcut.TargetPath = '%cd%\new_app.exe'; $Shortcut.WorkingDirectory = '%cd%'; $Shortcut.Description = 'Track-Karo Bus Management System'; $Shortcut.Save()"
    echo ✅ Start Menu shortcut created
)

echo.
echo ========================================
echo ✅ Setup Complete!
echo ========================================
echo.
echo Track-Karo Desktop App is ready to use.
echo.

if /i "%createShortcut%"=="y" (
    echo You can now run the app from:
    echo • Desktop shortcut: "Track-Karo"
) else (
    echo To run the app:
    echo • Double-click "new_app.exe" in this folder
)

if /i "%createStartMenu%"=="y" (
    echo • Start Menu: Track-Karo
)

echo • Or run "new_app.exe" directly from this folder
echo.
echo 📋 System Requirements Met:
echo • Windows 10/11 ✅
echo • Internet connection required for full functionality
echo.
echo 🆘 Need help? Check README.txt for troubleshooting
echo.

set /p runNow="Run Track-Karo now? (y/n): "
if /i "%runNow%"=="y" (
    echo Starting Track-Karo...
    start "" "new_app.exe"
)

echo.
echo Thank you for using Track-Karo!
pause