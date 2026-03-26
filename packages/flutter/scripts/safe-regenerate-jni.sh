#!/usr/bin/env bash
set -euo pipefail

# Safe JNI binding regeneration script.
#
# Tries the normal regeneration first (flutter build apk + jnigen).
# If that fails (e.g. binding.dart is incompatible with a new jni version),
# falls back to compiling only the Java/Kotlin plugin code via Gradle,
# creating a stub libs.jar, and running jnigen directly — bypassing
# Dart compilation entirely.
#
# This script is only needed for the maintenance of the jni 0.15.x branch. 
# See https://github.com/getsentry/sentry-dart/issues/3373

cd "$(dirname "$0")/../"

binding_path="lib/src/native/java/binding.dart"

# Use fvm if available, otherwise bare commands.
if command -v fvm &> /dev/null; then
    FLUTTER="fvm flutter"
    DART="fvm dart"
else
    FLUTTER="flutter"
    DART="dart"
fi

echo "=== Attempting normal JNI binding regeneration ==="

# The normal path: build APK (compiles Dart + Java), then run jnigen.
set +e
(
    cd example
    $FLUTTER build apk
)
normal_build=$?
set -e

if [ $normal_build -eq 0 ]; then
    $DART run jnigen --config ffi-jni.yaml
    $DART format "$binding_path"
    echo "=== Normal regeneration succeeded ==="
    exit 0
fi

echo ""
echo "=== Normal regeneration failed (exit code $normal_build), attempting fallback ==="
echo ""

# The normal path failed, likely because the existing binding.dart
# doesn't compile with the current jni package version.
#
# Fallback strategy:
# 1. Clean Gradle build artifacts
# 2. Compile only the sentry_flutter plugin's Java/Kotlin code via Gradle
#    (this does NOT require Dart to compile)
# 3. Create a stub libs.jar so jnigen's Gradle classpath resolution succeeds
#    (libs.jar normally contains compiled Dart code from flutter build apk,
#     but jnigen only needs the Java classes, not the Dart code)
# 4. Run jnigen directly to regenerate binding.dart
# 5. Verify the result by building the full APK

echo "Step 1: Cleaning Gradle build artifacts..."
cd example/android
./gradlew clean
cd ../..

echo "Step 2: Compiling sentry_flutter plugin Java/Kotlin code..."
cd example/android
./gradlew :sentry_flutter:bundleLibCompileToJarRelease
cd ../..

echo "Step 3: Creating stub libs.jar..."
# jnigen's Gradle classpath includes libs.jar (normally produced by flutter build apk).
# It must be a valid jar but doesn't need to contain Dart compiled classes —
# jnigen only reads Java classes from the Sentry Android SDK jars and Maven caches.
stub_dir=$(mktemp -d)
mkdir -p example/build/app/intermediates/flutter/release
jar cf example/build/app/intermediates/flutter/release/libs.jar -C "$stub_dir" .
rm -rf "$stub_dir"

echo "Step 4: Running jnigen..."
$DART run jnigen --config ffi-jni.yaml

echo "Step 5: Formatting generated binding..."
$DART format "$binding_path"

echo "Step 6: Verifying by building example APK..."
set +e
(
    cd example
    $FLUTTER build apk
)
verify_result=$?
set -e

if [ $verify_result -ne 0 ]; then
    echo ""
    echo "=== ERROR: Regenerated bindings do not compile ==="
    echo "=== Manual intervention is needed ==="
    exit 1
fi

echo ""
echo "=== Fallback regeneration succeeded ==="
exit 0
