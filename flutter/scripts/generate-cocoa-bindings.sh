#!/usr/bin/env bash
set -euo pipefail

if [[ -n ${CI:+x} ]]; then
    echo "Running in CI so we need to set up Flutter SDK first"
    curl -Lv https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.27.3-stable.zip --output /tmp/flutter.zip
    unzip -q /tmp/flutter.zip -d /tmp
    export PATH=":/tmp/flutter/bin:$PATH"
    which flutter
    flutter --version
fi

cocoa_version="${1:-$(./scripts/update-cocoa.sh get-version)}"

cd "$(dirname "$0")/../"

# Download Cocoa SDK (we need the headers)
temp="temp"
rm -rf $temp
mkdir -p $temp
curl -Lv --fail-with-body https://github.com/getsentry/sentry-cocoa/releases/download/$cocoa_version/Sentry.xcframework.zip -o $temp/Sentry.xcframework.zip
subdir="Sentry.xcframework/macos-arm64_arm64e_x86_64/Sentry.framework"
unzip -q $temp/Sentry.xcframework.zip "$subdir/*" -d $temp
mv "$temp/$subdir" $temp/Sentry.framework

binding="lib/src/native/cocoa/binding.dart"
dart run ffigen --config ffi-cocoa.yaml
sed -i.bak 's|static int startProfilerForTrace_(SentryCocoa _lib, SentryId? traceId)|static int startProfilerForTrace_(SentryCocoa _lib, SentryId1? traceId)|g' $binding
rm $binding.bak
dart format $binding
