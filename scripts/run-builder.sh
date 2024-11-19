#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR/..

for pkg in {dart,drift,flutter,hive,isar,sqflite,}; do
  # Navigate into package
  cd $pkg
  flutter clean
  flutter pub get
  ## Run build_runner
  flutter pub run build_runner build --delete-conflicting-outputs
  ## Run tests
  flutter test
  cd ..
done