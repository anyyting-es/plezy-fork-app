@echo off
REM Build script for Aniting backend (Windows)
setlocal

set SCRIPT_DIR=%~dp0
set BACKEND_DIR=%SCRIPT_DIR%aniting-backend
set BUILD_DIR=%SCRIPT_DIR%build\windows\x64\runner

cd /d "%BACKEND_DIR%"

echo Downloading Go dependencies...
go mod download
if errorlevel 1 (
    echo Failed to download dependencies
    exit /b 1
)

echo Building for Windows amd64...
set GOOS=windows
set GOARCH=amd64
go build -o "%SCRIPT_DIR%aniting-backend-temp.exe" .
if errorlevel 1 (
    echo Build failed
    exit /b 1
)

echo.
echo Build complete.
echo.

if exist "%BUILD_DIR%\Debug" (
    copy /Y "%SCRIPT_DIR%aniting-backend-temp.exe" "%BUILD_DIR%\Debug\aniting-backend.exe" >nul
    echo Copied to %BUILD_DIR%\Debug\aniting-backend.exe
)

if exist "%BUILD_DIR%\Release" (
    copy /Y "%SCRIPT_DIR%aniting-backend-temp.exe" "%BUILD_DIR%\Release\aniting-backend.exe" >nul
    echo Copied to %BUILD_DIR%\Release\aniting-backend.exe
)

del "%SCRIPT_DIR%aniting-backend-temp.exe"

echo Ready.
endlocal
