#!/usr/bin/env bash
# Runs the Flutter Android integration tests with a hard cap so a hung test
# fails fast with diagnostics instead of eating the full job timeout.
# See https://github.com/getsentry/sentry-java/issues/5518 for a known hang
# (replay close deadlock on the Android main thread).
#
# Must run from packages/flutter/example with an emulator attached via adb.

timeout -k 30 1200 flutter test integration_test/all.dart --dart-define SENTRY_AUTH_TOKEN_E2E="${SENTRY_AUTH_TOKEN_E2E:-}" --verbose
rc=$?
if [ "$rc" = "124" ]; then
  echo "::error::flutter test hung and was killed after 20 minutes - capturing diagnostics"
  echo "::group::hang diagnostics (thread dump + logcat)"
  pid=$(adb shell pidof io.sentry.flutter.sample) || true
  if [ -n "$pid" ]; then
    adb shell run-as io.sentry.flutter.sample kill -3 "$pid" || true
    sleep 5
    adb root || true
    sleep 2
    adb shell "cat /data/anr/trace_*" || true
  fi
  adb logcat -d -t 1000 || true
  echo "::endgroup::"
fi
exit "$rc"
