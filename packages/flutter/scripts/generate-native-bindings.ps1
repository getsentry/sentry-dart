# This is a PowerShell script instead of a bash script because it needs to run on Windows during local development.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# If running in CI, set up Flutter SDK first (keep version in sync with other scripts).
if ($env:CI)
{
    Write-Host "Running in CI so we need to set up Flutter SDK first"

    $tempRoot = [System.IO.Path]::GetTempPath()
    $flutterDir = Join-Path $tempRoot "flutter"

    if (Test-Path $flutterDir) { Remove-Item -Recurse -Force $flutterDir }

    if ($IsLinux)
    {
        $flutterTar = Join-Path $tempRoot "flutter.tar.xz"
        Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.3-stable.tar.xz" -OutFile $flutterTar
        tar xf $flutterTar -C $tempRoot
    }
    elseif ($IsMacOS)
    {
        $flutterZip = Join-Path $tempRoot "flutter.zip"
        Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.27.3-stable.zip" -OutFile $flutterZip
        Expand-Archive -Path $flutterZip -DestinationPath $tempRoot -Force
    }
    else
    {
        $flutterZip = Join-Path $tempRoot "flutter.zip"
        Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.27.3-stable.zip" -OutFile $flutterZip
        Expand-Archive -Path $flutterZip -DestinationPath $tempRoot -Force
    }

    $binDir = Join-Path $flutterDir "bin"
    $pathSep = if ($IsWindows) { ';' } else { ':' }
    $env:PATH = "$binDir$pathSep$env:PATH"

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
