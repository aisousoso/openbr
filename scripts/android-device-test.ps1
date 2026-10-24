# OpenBR - Android device smoke test helper.
#
# Installs the APK, launches it, captures device info, a screenshot, and logcat
# into build/device-test-<timestamp>/. Run from the repository root:
#
#   powershell -ExecutionPolicy Bypass -File scripts/android-device-test.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/android-device-test.ps1 -ApkPath build/OpenBR-release.apk
#
# This script does not modify the game. It only uses adb.

[CmdletBinding()]
param(
    [string]$ApkPath = "build/OpenBR.apk",
    [string]$Package = "org.openbr.game",
    [string]$Activity = "com.godot.game.GodotApp",
    [int]$WaitSeconds = 8,
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $RepoRoot "project.godot"))) {
    $RepoRoot = (Get-Location).Path
}

function Find-Adb {
    $candidates = @()
    if ($env:ANDROID_HOME) { $candidates += (Join-Path $env:ANDROID_HOME "platform-tools\adb.exe") }
    if ($env:ANDROID_SDK_ROOT) { $candidates += (Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe") }
    $candidates += "C:\Users\AISOU\AppData\Local\Temp\opencode\openbr-tools\android-sdk\platform-tools\adb.exe"
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "adb not found. Set ANDROID_HOME or add platform-tools to PATH."
}

$Adb = Find-Adb
$ApkFull = if ([System.IO.Path]::IsPathRooted($ApkPath)) { $ApkPath } else { Join-Path $RepoRoot $ApkPath }

Write-Host "adb: $Adb"
$deviceLines = & $Adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\sdevice$" }
if (-not $deviceLines) {
    Write-Host ""
    Write-Host "No Android device detected." -ForegroundColor Yellow
    Write-Host "1. Enable Developer options and USB debugging on the phone."
    Write-Host "2. Connect the USB cable and accept the RSA prompt."
    Write-Host "3. Run: adb devices -l"
    exit 2
}

Write-Host "Devices:"
$deviceLines | ForEach-Object { Write-Host "  $_" }

if (-not $SkipInstall) {
    if (-not (Test-Path $ApkFull)) { throw "APK not found: $ApkFull" }
    Write-Host "Uninstalling old $Package (signature switch safety)..."
    & $Adb uninstall $Package 2>$null | Out-Null
    Write-Host "Installing $ApkFull ..."
    & $Adb install -r $ApkFull
    if ($LASTEXITCODE -ne 0) { throw "adb install failed with exit code $LASTEXITCODE" }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $RepoRoot "build\device-test-$stamp"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$props = [ordered]@{
    "ro.product.manufacturer" = (& $Adb shell getprop ro.product.manufacturer).Trim()
    "ro.product.model"        = (& $Adb shell getprop ro.product.model).Trim()
    "ro.build.version.release"= (& $Adb shell getprop ro.build.version.release).Trim()
    "ro.build.version.sdk"    = (& $Adb shell getprop ro.build.version.sdk).Trim()
    "ro.product.cpu.abi"      = (& $Adb shell getprop ro.product.cpu.abi).Trim()
    "wm.size"                 = (& $Adb shell wm size).Trim()
}
$props.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value } |
    Set-Content -Path (Join-Path $outDir "device-info.txt") -Encoding UTF8
$props.GetEnumerator() | ForEach-Object { Write-Host ("  {0}: {1}" -f $_.Key, $_.Value) }

& $Adb logcat -c
Write-Host "Launching $Package/$Activity ..."
& $Adb shell am start -n "$Package/$Activity"
Start-Sleep -Seconds $WaitSeconds

$focus = (& $Adb shell dumpsys window displays 2>$null | Select-String "mCurrentFocus" | Select-Object -First 1)
$focus | Out-File -FilePath (Join-Path $outDir "window-focus.txt") -Encoding UTF8

& $Adb shell screencap -p /sdcard/openbr-screen.png | Out-Null
& $Adb pull /sdcard/openbr-screen.png (Join-Path $outDir "screen.png") | Out-Null
& $Adb shell rm /sdcard/openbr-screen.png | Out-Null

& $Adb logcat -d -v time | Out-File -FilePath (Join-Path $outDir "logcat.txt") -Encoding UTF8
$godotLines = & $Adb logcat -d -v time | Select-String -Pattern "godot|Godot|OpenBR|org.openbr" | Select-Object -Last 40
$godotLines | Out-File -FilePath (Join-Path $outDir "logcat-godot.txt") -Encoding UTF8

Write-Host ""
Write-Host "Captured:"
Write-Host "  $outDir\device-info.txt"
Write-Host "  $outDir\screen.png"
Write-Host "  $outDir\logcat.txt"
Write-Host "  $outDir\logcat-godot.txt"
if ($focus) { Write-Host "Focus: $focus" }
Write-Host ""
Write-Host "Now complete the manual checklist in docs/TESTING.md."
Write-Host "If the app is not in the foreground, check logcat-godot.txt for a crash."
