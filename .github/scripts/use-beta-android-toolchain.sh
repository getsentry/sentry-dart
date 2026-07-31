#!/usr/bin/env bash
set -euo pipefail

# Flutter beta enforces a newer Android toolchain than the example pins: Gradle
# 8.14.0, AGP 8.11.1 and KGP 2.2.20 (see DependencyVersionChecker in
# flutter_tools). The example stays on the oldest toolchain we support so the
# stable legs keep covering it, so raise the versions for the beta legs here.
# KGP 2.2.20 no longer supports Kotlin language version 1.7.

GRADLE_VERSION="8.14.3"
AGP_VERSION="8.11.1"
KGP_VERSION="2.2.20"
KOTLIN_LANGUAGE_VERSION="1.8"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
wrapper="$repo_root/packages/flutter/example/android/gradle/wrapper/gradle-wrapper.properties"

sed -E "s|/gradle-[0-9.]+-bin\.zip|/gradle-$GRADLE_VERSION-bin.zip|" "$wrapper" >"$wrapper.tmp"
mv "$wrapper.tmp" "$wrapper"

if ! grep -q "gradle-$GRADLE_VERSION-bin.zip" "$wrapper"; then
  echo "::error::Could not set Gradle $GRADLE_VERSION in $wrapper"
  exit 1
fi

# Consumed by the example's settings.gradle and app/build.gradle.
{
  echo "ANDROID_GRADLE_PLUGIN_VERSION=$AGP_VERSION"
  echo "KOTLIN_ANDROID_PLUGIN_VERSION=$KGP_VERSION"
  echo "KOTLIN_LANGUAGE_VERSION=$KOTLIN_LANGUAGE_VERSION"
} >>"$GITHUB_ENV"
