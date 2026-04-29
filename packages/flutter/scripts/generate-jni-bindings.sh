#!/usr/bin/env bash
set -euo pipefail

if [[ -n ${CI:+x} ]]; then
    echo "Running in CI – setting up Flutter SDK first"
    # Note: keep version in sync with other binding generation scripts.
    curl -Lv https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.3-stable.tar.xz --output /tmp/flutter.tar.xz
    tar xf /tmp/flutter.tar.xz -C /tmp
    export PATH="/tmp/flutter/bin:$PATH"
    which flutter
    flutter --version
fi

# Move to the Flutter package root (…/flutter).
cd "$(dirname "$0")/../"

cd example
flutter build apk
cd -

# Regenerate the bindings (uses custom visitor to exclude methods with
# getter/setter nullability mismatches).
dart run tool/generate_jni.dart --config ffi-jni.yaml
