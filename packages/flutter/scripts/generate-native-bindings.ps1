# This is a PowerShell script instead of a bash script because it needs to run on Windows during local development.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# If running in CI, set up Flutter SDK first (keep version in sync with other scripts).
if ($env:CI)
{
    Write-Host "Running in CI so we need to set up Flutter SDK first"
    $flutterZip = Join-Path $env:TEMP "flutter.zip"
    $flutterDir = Join-Path $env:TEMP "flutter"
    Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.27.3-stable.zip" -OutFile $flutterZip
    if (Test-Path $flutterDir) { Remove-Item -Recurse -Force $flutterDir }
    Expand-Archive -Path $flutterZip -DestinationPath $env:TEMP -Force
    $env:PATH = "$flutterDir\bin;$env:PATH"
    Get-Command flutter | Out-Host
    flutter --version
}
Push-Location "$PSScriptRoot/../"
try
{
    New-Item temp -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

    $props = ConvertFrom-StringData (Get-Content sentry-native/CMakeCache.txt -Raw)
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/getsentry/sentry-native/$($props.version)/include/sentry.h" -OutFile temp/sentry-native.h

    $binding = 'lib/src/native/c/binding.dart'
    dart run ffigen --config ffi-native.yaml
    $content = Get-Content $binding -Raw
    $content | Set-Content -NoNewline -Encoding utf8 $binding
    dart format $binding
    Get-Item $binding
}
finally
{
    Pop-Location
}
