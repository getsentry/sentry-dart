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

binding_path="lib/src/native/java/binding.dart"

# Regenerate the bindings.
dart run jnigen --config ffi-jni.yaml

# Format the generated code so that it passes CI linters.
dart format "$binding_path"