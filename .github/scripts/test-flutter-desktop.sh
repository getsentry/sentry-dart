#!/usr/bin/env bash
# Run from packages/flutter, optionally with --coverage (requires lcov).
# Each backend needs a fresh native-library loader.
set -eo pipefail

coverage_args=()
if [[ $# -eq 1 && "$1" == '--coverage' ]]; then
  coverage_args=(--coverage)
elif [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--coverage]" >&2
  exit 2
fi

status=0
flutter test --exclude-tags native-backend \
  --test-randomize-ordering-seed=random \
  "${coverage_args[@]}" --file-reporter json:test-vm.jsonl || status=1

coverage_files=()
if [[ ${#coverage_args[@]} -gt 0 && -f coverage/lcov.info ]]; then
  mv coverage/lcov.info coverage/lcov-vm.info
  coverage_files+=(coverage/lcov-vm.info)
fi

for backend in default_ empty crashpad breakpad inproc none; do
  echo "Testing native backend: $backend"
  SENTRY_TEST_NATIVE_BACKEND="$backend" flutter test \
    test/native/c/sentry_native_test.dart \
    --test-randomize-ordering-seed=random \
    "${coverage_args[@]}" \
    --file-reporter "json:test-native-$backend.jsonl" || status=1

  if [[ ${#coverage_args[@]} -gt 0 && -f coverage/lcov.info ]]; then
    mv coverage/lcov.info "coverage/lcov-native-$backend.info"
    coverage_files+=("coverage/lcov-native-$backend.info")
  fi
done

if [[ ${#coverage_args[@]} -gt 0 ]]; then
  merge_args=()
  for file in "${coverage_files[@]}"; do
    merge_args+=(--add-tracefile "$file")
  done
  lcov "${merge_args[@]}" --output-file coverage/lcov.info || status=1
fi

exit "$status"
