#!/usr/bin/env bash
set -euo pipefail

cd perf_test_console_plain
dart pub get
cd ..
dart compile exe perf_test_console_plain/bin/perf_test_console_plain.dart -o ./perf_test_console_plain.bin

cd perf_test_console_sentry
dart pub get
cd ..
dart compile exe perf_test_console_sentry/bin/perf_test_console_sentry.dart -o ./perf_test_console_sentry.bin
