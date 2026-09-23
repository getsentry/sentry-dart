#!/bin/bash
set -euo pipefail

# Build the Flutter example for macOS.
#
# Flutter derives the local SwiftPM package identity from the plugin directory
# basename on macOS. Our package lives in packages/flutter, so Xcode resolves it
# as "flutter" and the build fails with:
#   "unable to override package 'sentry_flutter' because its identity 'flutter'
#    doesn't match override's identity (directory name) 'sentry_flutter'"
# We temporarily rename the package directory so the basename matches the pub
# name (sentry_flutter), build, then always rename it back -- even on failure.
#
# Any extra arguments are forwarded to `flutter build macos`, e.g.:
#   ./scripts/build-macos-example.sh --debug

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

if command -v fvm >/dev/null 2>&1; then
  flutter_cmd="fvm flutter"
else
  flutter_cmd="flutter"
fi

# Preflight: refuse to run from an unexpected state. If packages/sentry_flutter
# already exists, `mv packages/flutter packages/sentry_flutter` would nest the
# directory instead of renaming it, which restore would then corrupt further.
if [ -e packages/sentry_flutter ]; then
  echo "error: packages/sentry_flutter already exists; refusing to rename." >&2
  echo "Move or remove it (it may be left over from an interrupted run)." >&2
  exit 1
fi
if [ ! -d packages/flutter ]; then
  echo "error: packages/flutter not found; run from the repo root." >&2
  exit 1
fi

restore() {
  if [ -d packages/sentry_flutter ]; then
    mv packages/sentry_flutter packages/flutter
  fi
}

# Install the trap only after the rename succeeds so restore never runs against
# a directory it didn't create.
mv packages/flutter packages/sentry_flutter
trap restore EXIT
(
  cd packages/sentry_flutter/example
  $flutter_cmd pub get
  $flutter_cmd build macos "$@"
)
