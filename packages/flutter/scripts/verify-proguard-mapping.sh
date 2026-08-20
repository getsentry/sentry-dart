#!/usr/bin/env bash
set -euo pipefail

# Verifies that R8 actually honors the keep rules generated from ffi-jni.yaml,
# rather than just checking that proguard-rules.pro is textually in sync (see
# generate-sentry-java-proguard.sh --check). Builds the example app in release
# mode (minifyEnabled) and checks the resulting R8 mapping.txt: every
# io.sentry.* class listed in ffi-jni.yaml must map to itself, i.e. R8 did not
# rename or strip it.
#
# Usage:
#   scripts/verify-proguard-mapping.sh

# Move to the Flutter package root (…/flutter).
cd "$(dirname "$0")/../"
flutter_root="$(pwd)"

ffi_jni_yaml="ffi-jni.yaml"
mapping_file="example/build/app/outputs/mapping/release/mapping.txt"

# Extract the io.sentry.* entries from ffi-jni.yaml's `classes:` list. Kept in
# sync with the same extraction in generate-sentry-java-proguard.sh.
classes=$(awk '
    /^classes:/ { in_classes=1; next }
    in_classes && /^[^[:space:]]/ { in_classes=0 }
    in_classes && /^[[:space:]]*-[[:space:]]*io\.sentry\./ {
        sub(/^[[:space:]]*-[[:space:]]*/, "")
        print
    }
' "$ffi_jni_yaml")

if [[ -z "$classes" ]]; then
    echo "error: found no io.sentry.* classes in $ffi_jni_yaml" >&2
    exit 1
fi

cd example
flutter build apk --release --target-platform=android-x64
cd "$flutter_root"

if [[ ! -f "$mapping_file" ]]; then
    echo "error: $mapping_file not found -- did the release build run with minifyEnabled?" >&2
    exit 1
fi

failures=()
while IFS= read -r class; do
    [[ -z "$class" ]] && continue
    # A class-level mapping.txt entry looks like "original.Name -> obfuscated:".
    # When R8 keeps the original name, obfuscated == original.
    if ! grep -qxF "$class -> $class:" "$mapping_file"; then
        failures+=("$class")
    fi
done <<<"$classes"

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "error: the following io.sentry.* classes were renamed or stripped by R8:" >&2
    for class in "${failures[@]}"; do
        echo "  - $class" >&2
        grep -F "$class" "$mapping_file" >&2 || echo "    (not present in $mapping_file at all)" >&2
    done
    echo "" >&2
    echo "Check that android/proguard-rules.pro still keeps these classes; run scripts/generate-sentry-java-proguard.sh if it's out of date." >&2
    exit 1
fi

echo "All io.sentry.* classes from $ffi_jni_yaml map to themselves in $mapping_file"
