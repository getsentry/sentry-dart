#!/bin/sh
# Run from packages/flutter.
# Each backend needs a fresh native-library loader.
set -eu

status=0
flutter test --exclude-tags native-backend \
  --test-randomize-ordering-seed=random \
  --file-reporter json:test-vm.jsonl || status=1

for backend in default_ empty crashpad breakpad inproc none; do
  echo "Testing native backend: $backend"
  SENTRY_TEST_NATIVE_BACKEND="$backend" flutter test \
    test/native/c/sentry_native_test.dart \
    --test-randomize-ordering-seed=random \
    --file-reporter "json:test-native-$backend.jsonl" </dev/null || status=1
done

exit "$status"
