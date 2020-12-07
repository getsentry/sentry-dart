#!/bin/sh

set -e
set -x

# get current package's dependencies
flutter pub get
# static code analyzer
flutter analyze
# tests
flutter test
# formatting
flutter format -n --set-exit-if-changed ./
# pub score
pana
# dry publish
pub publish --dry-run
