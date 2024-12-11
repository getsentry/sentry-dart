#!/usr/bin/env bash
set -euo pipefail

cd $(dirname "$0")/../ios

get_podspec_version() {
  local file='sentry_flutter.podspec'
  local content=$(cat $file)
  regex="('Sentry/HybridSDK', *)'([0-9\.]+(\-[a-z0-9\.]+)?)'"
  if ! [[ $content =~ $regex ]]; then
    echo "Failed to find the plugin version in $file"
    exit 1
  else
    echo "${BASH_REMATCH[2]}"
  fi
}

set_podspec_version() {
  local file='sentry_flutter.podspec'
  local content=$(cat $file)
  regex="('Sentry/HybridSDK', *)'([0-9\.]+(\-[a-z0-9\.]+)?)'"
  if ! [[ $content =~ $regex ]]; then
    echo "Failed to find the plugin version in $file"
    exit 1
  else
    newValue="${BASH_REMATCH[1]}'$1'"
    echo "${content/${BASH_REMATCH[0]}/$newValue}" >$file
  fi
}

set_spm_version() {
  local file='sentry_flutter/Package.swift'
  local content=$(cat $file)
  regex="(url: *['\"]https://github.com/getsentry/sentry-cocoa['\"], *from: *)['\"]([0-9\.]+(-[a-z0-9\.]+)?)['\"]"
  if ! [[ $content =~ $regex ]]; then
    echo "Failed to find the plugin version in $file"
    exit 1
  else
    newValue="${BASH_REMATCH[1]}\"$1\""
    echo "${content/${BASH_REMATCH[0]}/$newValue}" >$file
  fi
}

case $1 in
get-version)
    echo $(get_podspec_version)
    ;;
get-repo)
    echo "https://github.com/getsentry/sentry-cocoa.git"
    ;;
set-version)
    set_podspec_version "$2"
    set_spm_version "$2"
#    ../scripts/generate-cocoa-bindings.sh "$2"
    ;;
*)
    echo "Unknown argument $1"
    exit 1
    ;;
esac
