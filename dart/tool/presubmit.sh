#!/bin/sh

set -e
set -x

# get current package's dependencies
pub get
# static code analyzer
dartanalyzer --fatal-infos --fatal-warnings ./
# tests
pub run test -p "chrome,vm"
# formatting
dartfmt -n --set-exit-if-changed ./
# pub score
pana
# dry publish
pub publish --dry-run
