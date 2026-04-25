@echo off
REM Flutter Windows Release build size optimization script
REM Strip debug symbols and clean up build artifacts
REM Usage: flutter build windows --release ^&^& scripts\strip_windows_release.bat

echo === Windows Release Size Optimization ===
echo.

set APP_PATH=build\windows\x64\runner\Release

if not exist "%APP_PATH%" (
    echo Not found: %APP_PATH%
    echo Please run first: flutter build windows --release
    exit /b 1
)

for /f "tokens=*" %%i in ('powershell -Command "(Get-ChildItem -Recurse '%APP_PATH%' | Measure-Object -Property Length -Sum).Sum / 1MB"') do set BEFORE=%%i
echo Before: %BEFORE% MB
echo.

REM Delete unnecessary files
echo Cleaning up...
del /f /q "%APP_PATH%\*.pdb" 2>nul
del /f /q "%APP_PATH%\data\*" 2>nul
del /f /q "%APP_PATH%\debug-info\*" 2>nul
for /d %%i in ("%APP_PATH%\debug-info") do rmdir /s /q "%%i" 2>nul

echo.
for /f "tokens=*" %%i in ('powershell -Command "(Get-ChildItem -Recurse '%APP_PATH%' | Measure-Object -Property Length -Sum).Sum / 1MB"') do set AFTER=%%i
echo === Done ===
echo Before: %BEFORE% MB
echo After:  %AFTER% MB
