@echo off
setlocal

cd /d "%~dp0"

echo [1/3] Building Flutter Windows release...
call flutter build windows --release
if errorlevel 1 (
  echo Build failed.
  exit /b 1
)

echo [2/3] Locating Inno Setup compiler...
set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" (
  echo Inno Setup 6 not found.
  echo Install it from: https://jrsoftware.org/isinfo.php
  exit /b 1
)

echo [3/3] Creating installer EXE...
"%ISCC%" "installer.iss"
if errorlevel 1 (
  echo Installer creation failed.
  exit /b 1
)

echo.
echo Done. Installer generated in: build\installer
exit /b 0
