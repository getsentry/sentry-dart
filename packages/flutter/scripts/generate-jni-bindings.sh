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

# jnigen 0.14.2 bundles kotlinx-metadata-jvm 0.9.0, which refuses Kotlin metadata
# newer than 2.1.0, so the example's default KGP 2.2.20 aborts the summarizer. Only
# the summarized API shape matters here and it is the same either way. Flutter 3.47
# raised its KGP floor to 2.2.20, so waive that check too -- as a Gradle property
# rather than `flutter build --android-skip-build-dependency-validation`, because
# jnigen resolves the compile classpath through a Gradle run of its own that never
# sees the flutter flag. Drop both once jni/jnigen can move past 0.14.2, see
# https://github.com/getsentry/sentry-dart/issues/3373
export KOTLIN_ANDROID_PLUGIN_VERSION="${KOTLIN_ANDROID_PLUGIN_VERSION:-2.1.21}"
export ORG_GRADLE_PROJECT_skipDependencyChecks=true

cd example
flutter build apk
cd -

# Regenerate the bindings.
dart run jnigen --config ffi-jni.yaml

# Format the generated code so that it passes CI linters.
dart format "$binding_path"

# Regenerate proguard rules so they stay in sync with the JNI class list.
./scripts/generate-sentry-java-proguard.sh
