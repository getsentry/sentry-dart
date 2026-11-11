#!/bin/sh
# Run from a Dart package directory, optionally with --coverage to also
# write coverage/lcov.info.
set -eu

coverage=false
if [ "$#" -eq 1 ] && [ "$1" = '--coverage' ]; then
  coverage=true
elif [ "$#" -ne 0 ]; then
  echo "Usage: $0 [--coverage]" >&2
  exit 2
fi

if [ "$coverage" = false ]; then
  exec dart test -p vm --test-randomize-ordering-seed=random --chain-stack-traces
fi

dart test -p vm --test-randomize-ordering-seed=random --chain-stack-traces \
  --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage \
  --out=coverage/lcov.info --packages=.dart_tool/package_config.json \
  --report-on=lib
