#!/usr/bin/env bash
set -euo pipefail

# Prints the io.sentry.* classes that jnigen binds to, one per line.
#
# The list lives in tool/jnigen.dart's `classes:` entry, which is the single
# source of truth for the Android bindings. generate-sentry-java-proguard.sh
# and verify-proguard-mapping.sh both read it from here so they can't drift
# apart.
#
# Extraction is scoped to the `classes:` list on purpose: tool/jnigen.dart also
# mentions io.sentry class names in `_excludedMethods`, and those must not be
# picked up.
#
# Usage:
#   scripts/list-jni-sentry-classes.sh

# Move to the Flutter package root (…/flutter).
cd "$(dirname "$0")/../"

jnigen_dart="tool/jnigen.dart"

if [[ ! -f "$jnigen_dart" ]]; then
    echo "error: $jnigen_dart not found" >&2
    exit 1
fi

classes=$(
    sed -n '/classes: const \[/,/^[[:space:]]*\]/p' "$jnigen_dart" |
        grep -oE "'io\.sentry\.[^']+'" |
        tr -d "'" ||
        true
)

# Guard against tool/jnigen.dart being reformatted into a shape this extraction
# no longer understands: failing loudly is better than generating empty keep
# rules and silently letting R8 strip every bound class.
if [[ -z "$classes" ]]; then
    echo "error: found no io.sentry.* classes in $jnigen_dart's 'classes:' list" >&2
    exit 1
fi

echo "$classes"
