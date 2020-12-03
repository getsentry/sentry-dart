#!/bin/sh

set -e
set -x

flutter pub get
flutter analyze ./
flutter test test
flutter format -n --set-exit-if-changed ./
