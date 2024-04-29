#!/usr/bin/env bash
set -euo pipefail

if [[ -n ${CI:+x} ]]; then
    echo "Running in CI so we need to set up Flutter SDK first"
    curl -Lv https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.13.3-stable.zip --output /tmp/flutter.zip
    unzip -q /tmp/flutter.zip -d /tmp
    export PATH=":/tmp/flutter/bin:$PATH"
    which flutter
    flutter --version
fi

cocoa_version="${1:-$(./scripts/update-cocoa.sh get-version)}"

cd "$(dirname "$0")/../"

# Remove dependency on script exit (even in case of an error).
trap "dart pub remove ffigen" EXIT

# Currently we add the dependency only when the code needs to be generated because it depends
# on Dart SDK 3.2.0 which isn't available on with Flutter stable yet.
# Leaving the dependency in pubspec would block all contributors.
# As for why this is coming from a fork - because we need a specific version of ffigen including PR 607 but not PR 601
# which starts generating code not compatible with Dart SDK 2.17. The problem is they were merged in the wrong order...
dart pub add 'dev:ffigen:{"git":{"url":"https://github.com/getsentry/ffigen","ref":"6aa2c2642f507eab3df83373189170797a9fa5e7"}}'

# Download Cocoa SDK (we need the headers)
temp="cocoa_bindings_temp"
rm -rf $temp
mkdir -p $temp
curl -Lv --fail-with-body https://github.com/getsentry/sentry-cocoa/releases/download/$cocoa_version/Sentry.xcframework.zip -o $temp/Sentry.xcframework.zip
subdir="Sentry.xcframework/macos-arm64_x86_64/Sentry.framework"
unzip -q $temp/Sentry.xcframework.zip "$subdir/*" -d $temp
mv "$temp/$subdir" $temp/Sentry.framework

dart run ffigen --config ffi-cocoa.yaml
sed -i.bak 's|final class|class|g' lib/src/native/cocoa/binding.dart
sed -i.bak 's|static int startProfilerForTrace_(SentryCocoa _lib, SentryId? traceId)|static int startProfilerForTrace_(SentryCocoa _lib, SentryId1? traceId)|g' lib/src/native/cocoa/binding.dart
rm lib/src/native/cocoa/binding.dart.bak
