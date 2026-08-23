@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
set "BACKEND=%ROOT%backend"

echo Starting SmartSpot...
echo.

where node >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js was not found on PATH.
    echo Install Node.js 18 or newer, then run this script again.
    pause
    exit /b 1
)

where npm >nul 2>&1
if errorlevel 1 (
    echo ERROR: npm was not found on PATH.
    pause
    exit /b 1
)

where flutter >nul 2>&1
if errorlevel 1 (
    echo ERROR: Flutter was not found on PATH.
    echo Install Flutter and enable the Windows desktop target, then run this script again.
    pause
    exit /b 1
)

if not exist "%BACKEND%\node_modules" (
    echo Installing backend dependencies...
    pushd "%BACKEND%"
    call npm install
    if errorlevel 1 (
        popd
        echo ERROR: Backend dependency installation failed.
        pause
        exit /b 1
    )
    popd
)

if not exist "%BACKEND%\.env" (
    echo Creating backend environment file...
    copy /Y "%BACKEND%\.env.example" "%BACKEND%\.env" >nul
)

echo Getting Flutter dependencies...
pushd "%ROOT%"
call flutter pub get
if errorlevel 1 (
    popd
    echo ERROR: Flutter dependency installation failed.
    pause
    exit /b 1
)
popd

echo Launching backend on http://localhost:3000...
start "SmartSpot Backend" /D "%BACKEND%" cmd /k "npm run dev"

timeout /t 2 /nobreak >nul

echo Launching Flutter Windows app...
start "SmartSpot Flutter" /D "%ROOT%" cmd /k "flutter run -d windows"

echo.
echo SmartSpot is starting in two new windows.
echo Close those windows to stop the backend and Flutter app.
pause
endlocal