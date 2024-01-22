#!/bin/bash
set -euo pipefail

# Build a release version of the app for a platform and upload debug symbols and source maps.

# Or try out the Alpha version of the Sentry Dart Plugin that does it automatically for you, feedback is welcomed.
# https://github.com/getsentry/sentry-dart-plugin

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
CURRENT_DATE=$(date +%Y-%m-%d_%H-%M-%S)

export SENTRY_RELEASE="$CURRENT_DATE"@"$VERSION"

echo -e "[\033[92mrun\033[0m] $1"

# using 'build' as the base dir because `flutter clean` will delete it, so we don't end up with leftover symbols from a previous build
symbolsDir=build/symbols

if [ "$1" == "ios" ]; then
    flutter build ios --split-debug-info=$symbolsDir --obfuscate
    # see https://github.com/ios-control/ios-deploy (or just install: `brew install ios-deploy`)
    launchCmd='ios-deploy --justlaunch --bundle build/ios/Release-iphoneos/Runner.app'
elif [ "$1" == "android" ]; then
    flutter build apk --split-debug-info=$symbolsDir --obfuscate
    adb install build/app/outputs/flutter-apk/app-release.apk
    launchCmd='adb shell am start -n io.sentry.samples.flutter/io.sentry.samples.flutter.MainActivity'
    echo -e "[\033[92mrun\033[0m] Android app installed"
elif [ "$1" == "web" ]; then
    flutter build web --dart-define=SENTRY_RELEASE="$SENTRY_RELEASE" --source-maps
    buildDir='./build/web/'
    port='8132'
    ls -lah $buildDir
    echo -e "[\033[92mrun\033[0m] Built: $buildDir"
    launchCmd="bash -c '( sleep 3 ; open http://127.0.0.1:$port ) & python3 -m http.server --directory $buildDir $port'"
elif [ "$1" == "macos" ]; then
    flutter build macos --split-debug-info=$symbolsDir --obfuscate
    launchCmd='./build/macos/Build/Products/Release/sentry_flutter_example.app/Contents/MacOS/sentry_flutter_example'
else
    if [ "$1" == "" ]; then
        echo -e "[\033[92mrun\033[0m] Pass the platform you'd like to run: android, ios, web"
    else
        echo -e "[\033[92mrun\033[0m] $1 isn't supported"
    fi
    exit 1
fi

dart run sentry_dart_plugin

echo "Starting the built app: $launchCmd"
eval $launchCmd
