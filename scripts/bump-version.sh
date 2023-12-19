#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR/..

OLD_VERSION="${1}"
NEW_VERSION="${2}"

echo "Current version: ${OLD_VERSION}"
echo "Bumping version: ${NEW_VERSION}"

for pkg in {dart,flutter,logging,dio,file,sqflite,drift,hive,isar}; do
  # Bump version in pubspec.yaml
  perl -pi -e "s/^version: .*/version: $NEW_VERSION/" $pkg/pubspec.yaml
  # Bump sentry dependency version in pubspec.yaml
  perl -pi -e "s/sentry: .*/sentry: $NEW_VERSION/" $pkg/pubspec.yaml
done

# Bump version in version.dart
perl -pi -e "s/sdkVersion = '.*'/sdkVersion = '$NEW_VERSION'/" */lib/src/version.dart
# Bump version in flutter example
perl -pi -e "s/^version: .*/version: $NEW_VERSION/" flutter/example/pubspec.yaml
