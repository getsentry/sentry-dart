#!/usr/bin/env bash
set -euo pipefail

targetDir=$(
  cd $(dirname $0)
  pwd
)
[[ "$targetDir" != "" ]] || exit 1

if [ "$#" -gt 2 ]; then
  shift
  args="$@"
  target=$1
else
  # Use default args if no were given
  case "$1" in
  ios)
    target="ipa"
    args="--release --no-codesign"
    ;;

  android)
    target="apk"
    args="--release --target-platform android-arm64 --split-per-abi"
    ;;

  *)
    echo "Unknown platform: '$1'"
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

    flutter build $target $args

    if [[ "$1" == "ios" ]]; then
      flJob="$(basename $app)"
      flJob=${flJob//-/_}
      (
        cd $targetDir
        fastlane "build_$flJob"
      )
    fi
  )
done
