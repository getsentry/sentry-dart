#!/usr/bin/env bash
set -euo pipefail

targetDir=$(
  cd $(dirname $0)
  pwd
)
[[ "$targetDir" != "" ]] || exit 1

platform=$1
if [ "$#" -gt 2 ]; then
  shift
  args="$@"
else
  # Use default args if no were given
  case "$platform" in
  ios)
    platform="ipa"
    args="--release"
    ;;

  android)
    platform="apk"
    args="--release --target-platform android-arm64 --split-per-abi"
    ;;

  *)
    echo "Unknown platform: '$platform'"
    exit 1
    ;;
  esac
fi

for app in "$targetDir/perf-test-app-"*; do
  (
    cd $app
    flutter pub get
    if [[ "$1" == "ios" && -f "ios/Podfile" ]]; then
      cd ios
      pod install --repo-update
      cd -
    fi

    flutter build $platform $args
  )
done
