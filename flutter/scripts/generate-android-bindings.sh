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

# jnigen requires building the app first
pushd example
flutter build apk
popd

dart run jnigen --config ./ffi-jni.yaml
