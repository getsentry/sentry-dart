#!/usr/bin/env bash

set -euo pipefail

detect_repo_root() {
  local git_root
  if command -v git >/dev/null 2>&1; then
    if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
      echo "${git_root}"
      return 0
    fi
  fi

  # Fallback to script directory's parent (repo layout assumption)
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "$(cd "${script_dir}/.." && pwd)"
}

REPO_ROOT="$(detect_repo_root)"

DOC="${REPO_ROOT}/docs/sdk-versions.md"

print_usage() {
  cat <<'USAGE'
Usage: scripts/update-sdk-versions-table.sh <flutter_version>

Arguments:
  <flutter_version>   Required. The Sentry Flutter SDK version (e.g., 9.9.9 or 9.5.0-beta.1).
USAGE
}

# Parse flags (support -h/--help only for now)
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      print_usage
      exit 0
      ;;
  esac
done

# Positional argument: Flutter version (required)
FLUTTER_VERSION=${1:-}
if [[ -z "${FLUTTER_VERSION}" ]]; then
  echo "Error: Missing required <flutter_version> argument." >&2
  echo >&2
  print_usage >&2
  exit 2
fi

ANDROID_VERSION="$(${REPO_ROOT}/packages/flutter/scripts/update-android.sh get-version)"
COCOA_VERSION="$(${REPO_ROOT}/packages/flutter/scripts/update-cocoa.sh get-version)"
JS_VERSION="$(${REPO_ROOT}/packages/flutter/scripts/update-js.sh get-version)"
NATIVE_VERSION="$(${REPO_ROOT}/packages/flutter/scripts/update-native.sh get-version)"

ROW="| ${FLUTTER_VERSION} | ${ANDROID_VERSION} | ${COCOA_VERSION} | ${JS_VERSION} | ${NATIVE_VERSION} |"

# Task 6: Bootstrap docs file if missing
if [[ ! -f "${DOC}" ]]; then
  {
    echo '# SDK Versions'
    echo
    echo 'This document shows which version of the various Sentry SDKs are used in which Sentry Flutter SDK version.'
    echo
    echo '## Version Table'
    echo
    echo '| Sentry Flutter SDK | Sentry Android SDK | Sentry Cocoa SDK | Sentry JavaScript SDK | Sentry Native SDK |'
    echo '| ------------------ | ------------------ | ---------------- | --------------------- | ----------------- |'
    echo "${ROW}"
  } > "${DOC}"
  exit 0
fi

# Always insert the new row directly below the table separator of the first table
awk -v row="$ROW" '
  BEGIN { in_table=0; inserted=0 }
  {
    print $0
    if (!in_table && $0 ~ /^\| Sentry Flutter SDK \|/) {
      in_table=1
      next
    }
    if (in_table && !inserted && $0 ~ /^\| *-+ *\|/) {
      print row
      inserted=1
      in_table=0
    }
  }
  END {
    if (!inserted) {
      # If no header/separator found, append at end for robustness
      print row
    }
  }
' "$DOC" >"$DOC.tmp"

mv "$DOC.tmp" "$DOC"

exit 0


