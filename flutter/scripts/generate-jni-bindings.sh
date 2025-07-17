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

# Ensure the Android Gradle wrapper exists. jnigen relies on it to resolve
# compile classpaths. The wrapper script (gradlew/gradlew.bat) is usually
# Git-ignored, so it won't be present on a fresh clone/CI checkout. Run a
# minimal Flutter build in the example app to have Flutter regenerate the
# wrapper if it is missing.
if [[ ! -f example/android/gradlew ]]; then
  echo "Gradle wrapper not found – generating via \`flutter build apk --debug\`."
  pushd example >/dev/null
  # We don't need a release build, a fast debug build is sufficient to
  # trigger wrapper + dependency resolution.
  flutter build apk --debug --no-pub --quiet || flutter build apk --debug --quiet
  popd >/dev/null
fi

# Regenerate the bindings.
dart run jnigen --config ffi-jni.yaml

# Format the generated code so that it passes CI linters.
dart format "$binding_path"
