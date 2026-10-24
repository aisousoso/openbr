@echo off
setlocal
title OpenBR - open UDP 7777

rem Re-run this script elevated if it is not already running as administrator.
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo Removing old OpenBR firewall rule (if any)...
netsh advfirewall firewall delete rule name="OpenBR UDP 7777" >nul 2>&1

echo Adding inbound UDP 7777 rule for all network profiles...
netsh advfirewall firewall add rule name="OpenBR UDP 7777" dir=in action=allow protocol=UDP localport=7777 profile=any

if %errorlevel% equ 0 (
    echo.
    echo OK: OpenBR UDP 7777 is now allowed through Windows Firewall.
    echo You can close this window and try connecting from the phone.
) else (
    echo.
    echo ERROR: could not create the firewall rule.
)

echo.
pause
