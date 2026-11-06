#!/usr/bin/env bash
# Tests how sentry-native.cmake fetches sentry-native (configure step only).
# Needs cmake, git and network access. Usage: fetch-test.sh [work-dir]
# https://github.com/getsentry/sentry-dart/issues/3969
set -uo pipefail

native_dir="$(cd "$(dirname "$0")/.." && pwd)"
work="${1:-$(mktemp -d)}"
mkdir -p "$work"
failures=0

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) expected_default=zip ;;
*) expected_default=git ;;
esac

# Native path in a form cmake understands, also on Windows.
to_cmake_path() {
  if command -v cygpath >/dev/null; then cygpath -m "$1"; else echo "$1"; fi
}

pass() { echo "PASS: $1"; }
fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

# Copies the sentry-native dir, applying sed expressions to CMakeCache.txt.
make_variant() {
  local name=$1
  shift
  local dir="$work/$name-native"
  rm -rf "$dir"
  mkdir -p "$dir"
  cp "$native_dir"/*.cmake "$native_dir/CMakeCache.txt" "$dir/"
  for expr in "$@"; do sed -i.bak "$expr" "$dir/CMakeCache.txt"; done
  echo "$dir"
}

# Configures a minimal project that includes the variant. Output in $work/$name.log.
configure() {
  local name=$1 native=$2
  local project="$work/$name-project" build="$work/$name-build"
  rm -rf "$project" "$build"
  mkdir -p "$project/plugin"
  printf 'cmake_minimum_required(VERSION 3.23)\nproject(fetch_test C CXX)\nadd_subdirectory(plugin)\n' >"$project/CMakeLists.txt"
  echo "include(\"$(to_cmake_path "$native")/sentry-native.cmake\")" >"$project/plugin/CMakeLists.txt"
  cmake -S "$project" -B "$build" >"$work/$name.log" 2>&1
}

# 1. The pinned hash must match the published release zip.
version=$(sed -n 's/^version=//p' "$native_dir/CMakeCache.txt")
repo=$(sed -n 's/^repo=//p' "$native_dir/CMakeCache.txt")
pinned=$(sed -n 's/^sha256=//p' "$native_dir/CMakeCache.txt")
# macOS has shasum but no sha256sum.
if command -v sha256sum >/dev/null; then sha256=(sha256sum); else sha256=(shasum -a 256); fi
actual=$(curl -fsSL "$repo/releases/download/$version/sentry-native.zip" | "${sha256[@]}" | cut -d ' ' -f 1)
if [[ -n "$pinned" && "$pinned" == "$actual" ]]; then
  pass "pinned sha256 matches the $version release zip"
else
  fail "pinned sha256 '$pinned' does not match the $version release zip ('$actual')"
fi

# 2. The default method depends on the platform.
unset SENTRY_NATIVE_FETCH_METHOD
export SENTRY_NATIVE_BACKEND=breakpad
if configure default "$native_dir" && grep -q "Fetching Sentry native version: $version .*($expected_default)" "$work/default.log"; then
  pass "default method is $expected_default and configures"
else
  fail "default method is not $expected_default or configure failed, see $work/default.log"
  tail -20 "$work/default.log"
fi

# 3. The zip is extracted without .git and with the expected sources.
if [[ "$expected_default" == zip ]]; then
  src="$work/default-build/_deps/sn-src"
  if [[ -f "$src/CMakeLists.txt" && ! -e "$src/.git" ]]; then
    pass "zip sources extracted without .git"
  else
    fail "zip sources missing or contain .git in $src"
  fi
fi

# 4. Reconfiguring reuses the sources instead of downloading again.
if [[ "$expected_default" == zip ]]; then
  cmake -S "$work/default-project" -B "$work/default-build" >"$work/reconfigure.log" 2>&1
  if ! grep -q "Downloading" "$work/reconfigure.log"; then
    pass "reconfigure does not download again"
  else
    fail "reconfigure downloaded again, see $work/reconfigure.log"
  fi
fi

# 5. A failed download falls back to git. The repo does not exist, so the git
# fallback itself is expected to fail; only the switch is asserted.
export SENTRY_NATIVE_FETCH_METHOD=zip
bad_repo=$(make_variant bad-repo 's#^repo=.*#repo=https://github.com/getsentry/does-not-exist#')
configure bad-repo "$bad_repo" || true
if grep -q "Falling back to fetching sentry-native with git" "$work/bad-repo.log"; then
  pass "failed download falls back to git"
else
  fail "no fallback to git after a failed download, see $work/bad-repo.log"
fi

# 6. A hash mismatch is an error and must not fall back.
bad_hash=$(make_variant bad-hash 's#^sha256=.*#sha256=0000000000000000000000000000000000000000000000000000000000000000#')
if configure bad-hash "$bad_hash"; then
  fail "configure succeeded with a wrong sha256"
elif grep -q "hash mismatch" "$work/bad-hash.log" && ! grep -q "Falling back" "$work/bad-hash.log"; then
  pass "hash mismatch fails without falling back"
else
  fail "hash mismatch not reported correctly, see $work/bad-hash.log"
fi

# 7. An unknown method is rejected.
SENTRY_NATIVE_FETCH_METHOD=nope configure unknown "$native_dir" && fail "unknown fetch method was accepted" || {
  grep -q "Unknown SENTRY_NATIVE_FETCH_METHOD" "$work/unknown.log" && pass "unknown fetch method is rejected" || fail "unexpected error for unknown method"
}

echo "$failures failure(s)"
exit $((failures > 0))
