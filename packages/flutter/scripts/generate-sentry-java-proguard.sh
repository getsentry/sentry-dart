#!/usr/bin/env bash
set -euo pipefail

# NOTE: This script is required while the following issue isn't completed https://github.com/dart-lang/native/issues/681
#
# Regenerates the io.sentry.* R8/ProGuard keep rules in android/proguard-rules.pro
# from the JNI class list in tool/jnigen.dart, so the two never drift apart.
#
# Usage:
#   scripts/generate-sentry-java-proguard.sh          # regenerate the file in place
#   scripts/generate-sentry-java-proguard.sh --check  # exit 1 if the file is out of date, don't modify it
#
# Only replaces the block between the "# AUTO-GENERATED-START" and
# "# AUTO-GENERATED-END" markers in proguard-rules.pro; everything else in the
# file (NDK-layer rules, keepattributes, etc.) is left untouched.

# Move to the Flutter package root (…/flutter).
cd "$(dirname "$0")/../"

jnigen_dart="tool/jnigen.dart"
proguard_file="android/proguard-rules.pro"
start_marker="# AUTO-GENERATED-START"
end_marker="# AUTO-GENERATED-END"

if ! grep -q "$start_marker" "$proguard_file" || ! grep -q "$end_marker" "$proguard_file"; then
    echo "error: $proguard_file is missing $start_marker/$end_marker markers" >&2
    exit 1
fi

classes=$(./scripts/list-jni-sentry-classes.sh)

generated=$(
    while IFS= read -r class; do
        [[ -z "$class" ]] && continue
        printf -- '-keep,includedescriptorclasses class %s { *; }\n' "$class"
        printf -- '-keep,includedescriptorclasses class %s$* { *; }\n' "$class"
    done <<<"$classes"
)

tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

# `gen` is passed via the environment rather than `awk -v` because BSD awk
# (macOS's /usr/bin/awk) rejects `-v` values containing a literal newline;
# ENVIRON isn't run through that escape parser, so it works on both.
export gen="$generated"
awk -v start="$start_marker" -v end="$end_marker" '
    $0 ~ start { print; print ENVIRON["gen"]; in_block=1; next }
    $0 ~ end { in_block=0; print; next }
    in_block { next }
    { print }
' "$proguard_file" >"$tmp_file"

if [[ "${1:-}" == "--check" ]]; then
    if diff -u "$proguard_file" "$tmp_file"; then
        echo "$proguard_file is up to date with $jnigen_dart"
        exit 0
    else
        echo "" >&2
        echo "error: $proguard_file is out of date with $jnigen_dart" >&2
        echo "run scripts/generate-sentry-java-proguard.sh to fix" >&2
        exit 1
    fi
fi

mv "$tmp_file" "$proguard_file"
trap - EXIT
echo "Updated $proguard_file from $jnigen_dart"
