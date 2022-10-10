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
  echo "Building $app"

  # Support caching if this is running in CI.
  if [[ -n ${CI+x} && $app == *-plain && -f $APP_PLAIN ]]; then
    echo "Cached app exists: $APP_PLAIN - skipping build"
    continue
  fi

  (
    echo "::group::Flutter build $app"
    cd $app
    flutter pub get
    if [[ "$1" == "ios" && -f "ios/Podfile" ]]; then
      cd ios
      pod install --repo-update
      cd -
    fi
    flutter build $target $args
    echo '::endgroup::'
  )

  if [[ "$1" == "ios" ]]; then
    flJob="$(basename $app)"
    flJob=${flJob//-/_}
    (
      echo "::group::Fastlane build $app"
      cd $targetDir
      fastlane "build_$flJob" --verbose
      echo '::endgroup::'
    )
  fi
done
