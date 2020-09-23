#!/bin/bash
set -e

# Build a release version of the app for a platform and upload symbols

export SENTRY_PROJECT=flutter
export SENTRY_ORG=sentry-test
# export SENTRY_LOG_LEVEL=debug
export OUTPUT_FOLDER_WEB=./build/web/

export SENTRY_RELEASE=$(date +%Y-%m-%d_%H-%M-%S)

echo -e "[\033[92mrun\033[0m] $1"

if [ "$1" == "ios" ]; then
    flutter build ios --dart-define=SENTRY_RELEASE=$SENTRY_RELEASE --split-debug-info=symbols --obfuscate
    # TODO: Install the iOS app via CLI
    #.. install build/ios/Release-iphoneos/Runner.app
elif [ "$1" == "android" ]; then
    flutter build apk --dart-define=SENTRY_RELEASE=$SENTRY_RELEASE --split-debug-info=symbols --obfuscate
    adb install build/app/outputs/flutter-apk/app-release.apk 
    adb shell am start -n io.sentry.flutter.example/io.sentry.flutter.example.MainActivity
    echo -e "[\033[92mrun\033[0m] Android app installed"
elif [ "$1" == "web" ]; then
    # Uses dart2js
    flutter build web --dart-define=SENTRY_RELEASE=$SENTRY_RELEASE
    ls -lah $OUTPUT_FOLDER_WEB
    echo -e "[\033[92mrun\033[0m] Built: $OUTPUT_FOLDER_WEB"
else
    if [ "$1" == "" ]; then
        echo -e "[\033[92mrun\033[0m] Pass the platform you'd like to run: android, ios, web"
    else
        echo -e "[\033[92mrun\033[0m] $1 isn't supported"
    fi
    exit
fi

if [ "$1" == "web" ]; then
    echo -e "[\033[92mrun\033[0m] Uploading sourcemaps for $SENTRY_RELEASE"
    sentry-cli releases new $SENTRY_RELEASE

    sentry-cli releases files $SENTRY_RELEASE upload-sourcemaps . \
        --ext dart \
        --rewrite

    pushd $OUTPUT_FOLDER_WEB
    sentry-cli releases files $SENTRY_RELEASE upload-sourcemaps . \
        --ext map \
        --ext js \
        --rewrite

    sentry-cli releases finalize $SENTRY_RELEASE

    python3 -m http.server 8132
    popd
else
    echo -e "[\033[92mrun\033[0m] Uploading debug information files"
    # directory 'symbols' contain the Dart debug info files but to include platform ones, use current dir.
    sentry-cli upload-dif --org $SENTRY_ORG --project $SENTRY_PROJECT .
fi

