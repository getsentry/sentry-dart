# This is a PowerShell script instead of a bash script because it needs to run on Windows during local development.
Push-Location "$PSScriptRoot/../"
try
{
    New-Item temp -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

    $props = ConvertFrom-StringData (Get-Content sentry-native/CMakeCache.txt -Raw)
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/getsentry/sentry-native/$($props.version)/include/sentry.h" -OutFile temp/sentry-native.h

    $binding = 'lib/src/native/c/binding.dart'
    dart run ffigen --config ffi-native.yaml
    $content = Get-Content $binding -Raw
    $content = $content -replace 'final class', 'class'
    $content | Set-Content -NoNewline -Encoding utf8 $binding
    dart format $binding
}
finally
{
    Pop-Location
}
