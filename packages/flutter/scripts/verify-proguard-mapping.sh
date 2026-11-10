#!/usr/bin/env bash
set -euo pipefail

# NOTE: unlike generate-sentry-java-proguard.sh, this script stays useful even after
# https://github.com/dart-lang/native/issues/681 is completed and jnigen generates the
# keep rules itself -- it verifies R8's actual behavior, not just that the rules exist,
# which guards against R8 upgrades, jnigen bugs, or conflicting rules elsewhere in
# proguard-rules.pro.
#
# Verifies that R8 actually honors the keep rules generated from the JNI class
# list, rather than just checking that proguard-rules.pro is textually in sync
# (see generate-sentry-java-proguard.sh --check). Builds the example app in
# release mode (minifyEnabled) and checks the resulting R8 mapping.txt: every
# io.sentry.* class listed in tool/jnigen.dart, and every nested class of it
# (Outer$Inner), must map to itself, i.e. R8 did not rename or strip it. The
# nested-class check exists because the outer-class check alone wouldn't
# catch a regression that drops the `$*` keep rule -- nested classes rename
# independently of their enclosing class.
#
# Usage:
#   scripts/verify-proguard-mapping.sh

# Move to the Flutter package root (…/flutter).
cd "$(dirname "$0")/../"
flutter_root="$(pwd)"

jnigen_dart="tool/jnigen.dart"
mapping_file="example/build/app/outputs/mapping/release/mapping.txt"

classes=$(./scripts/list-jni-sentry-classes.sh)

cd example
flutter build apk --release --target-platform=android-x64
cd "$flutter_root"

if [[ ! -f "$mapping_file" ]]; then
    echo "error: $mapping_file not found -- did the release build run with minifyEnabled?" >&2
    exit 1
fi

failures=()
nested_failures=()
while IFS= read -r class; do
    [[ -z "$class" ]] && continue
    # A class-level mapping.txt entry looks like "original.Name -> obfuscated:".
    # When R8 keeps the original name, obfuscated == original.
    if ! grep -qxF "$class -> $class:" "$mapping_file"; then
        failures+=("$class")
    fi

    # Nested classes (Outer$Inner) get their own class-level entry and are
    # not covered by the check above, so verify them independently. Skip
    # classes with a "$$" component (e.g. Outer$$ExternalSyntheticLambda0):
    # those are R8/D8-synthesized lambda/bridge helpers, not classes jnigen
    # binds to, and R8 legitimately renames them regardless of keep rules.
    escaped_class="${class//./\\.}"
    while IFS= read -r nested_line; do
        [[ -z "$nested_line" ]] && continue
        original="${nested_line%% -> *}"
        [[ "$original" == *'$$'* ]] && continue
        obfuscated="${nested_line#* -> }"
        obfuscated="${obfuscated%:}"
        if [[ "$original" != "$obfuscated" ]]; then
            nested_failures+=("$nested_line")
        fi
    done < <(grep -E "^${escaped_class}\\\$" "$mapping_file" || true)
done <<<"$classes"

if [[ ${#failures[@]} -gt 0 || ${#nested_failures[@]} -gt 0 ]]; then
    if [[ ${#failures[@]} -gt 0 ]]; then
        echo "error: the following io.sentry.* classes were renamed or stripped by R8:" >&2
        for class in "${failures[@]}"; do
            echo "  - $class" >&2
            grep -F "$class" "$mapping_file" >&2 || echo "    (not present in $mapping_file at all)" >&2
        done
    fi
    if [[ ${#nested_failures[@]} -gt 0 ]]; then
        echo "error: the following nested io.sentry.*\$* classes were renamed by R8:" >&2
        for nested_line in "${nested_failures[@]}"; do
            echo "  - $nested_line" >&2
        done
    fi
    echo "" >&2
    echo "Check that android/proguard-rules.pro still keeps these classes (including the \$* nested-class rule); run scripts/generate-sentry-java-proguard.sh if it's out of date." >&2
    exit 1
fi

echo "All io.sentry.* classes from $jnigen_dart, including nested classes, map to themselves in $mapping_file"
