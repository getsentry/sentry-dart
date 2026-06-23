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

# Build the example app so the Android library jars (including this plugin's
# classes) are compiled and available on jnigen's gradle classpath.
#
# Note: when bumping `jni`/`jnigen` to an incompatible major version, the
# committed binding can no longer compile against the new runtime, so this
# `flutter build apk` fails before jnigen runs. In that case, first build just
# the plugin's library jar to give jnigen its classpath:
#   (cd example/android && ./gradlew :sentry_flutter:bundleLibCompileToJarRelease)
# then run `dart run tool/jnigen.dart` directly.
cd example
flutter build apk
cd -

# Regenerate the bindings. We use a programmatic entry point (instead of a
# `--config` YAML) so a custom visitor can drop setters that JNIgen would
# otherwise emit with a getter/setter nullability mismatch. See tool/jnigen.dart.
dart run tool/jnigen.dart

# Format the generated code so that it passes CI linters.
dart format "$binding_path"
