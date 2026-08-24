@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
set "BACKEND=%ROOT%backend"

echo Starting SmartSpot...
echo.

rem Auto-detect Flutter at G:\Flutter\flutter\bin if not present in PATH
where flutter >nul 2>&1
if errorlevel 1 (
    if exist "G:\Flutter\flutter\bin" (
        echo Adding G:\Flutter\flutter\bin to session PATH...
        set "PATH=G:\Flutter\flutter\bin;%PATH%"
    )
)

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
    echo Please add G:\Flutter\flutter\bin to your system PATH.
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

echo Launching local backend on http://localhost:3000 (Cloud backend: https://smartspot-backend-55n9.onrender.com)...
start "SmartSpot Backend" /D "%BACKEND%" cmd /k "npm run dev"

timeout /t 2 /nobreak >nul

echo.
echo Select Flutter Target Device:
echo [1] Chrome Web (Recommended - works without Visual Studio C++)
echo [2] Edge Web
echo [3] Windows Desktop (Requires Visual Studio with C++ workload)
echo.
set "TARGET_DEVICE=chrome"
set /p DEVICE_CHOICE="Enter choice [1-3] (default 1): "

if "%DEVICE_CHOICE%"=="2" set "TARGET_DEVICE=edge"
if "%DEVICE_CHOICE%"=="3" set "TARGET_DEVICE=windows"

echo Launching Flutter app on %TARGET_DEVICE%...
start "SmartSpot Flutter" /D "%ROOT%" cmd /k "set PATH=G:\Flutter\flutter\bin;%%PATH%% && flutter run -d %TARGET_DEVICE%"

echo.
echo SmartSpot is starting in two new windows.
echo Close those windows to stop the backend and Flutter app.
pause
endlocal