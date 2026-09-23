#!/bin/bash
set -euo pipefail

# Build the Flutter example for macOS. The package directory matches its
# SwiftPM identity, so no temporary directory rename is needed.
# Extra arguments are forwarded to `flutter build macos`.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/../packages/sentry_flutter/example"

if command -v fvm >/dev/null 2>&1; then
  flutter_cmd="fvm flutter"
else
  flutter_cmd="flutter"
fi

$flutter_cmd pub get
$flutter_cmd build macos "$@"
