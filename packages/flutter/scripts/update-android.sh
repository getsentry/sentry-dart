#!/usr/bin/env bash
set -euo pipefail

cd $(dirname "$0")/../android
build_gradle='build.gradle'
content=$(cat $build_gradle)

# Regex patterns for Sentry dependencies (both use the same version)
sentry_android_regex='(io\.sentry:sentry-android:)([0-9\.]+(\-[a-z0-9\.]+)?)'
sentry_spotlight_regex='(io\.sentry:sentry-spotlight:)([0-9\.]+(\-[a-z0-9\.]+)?)'

if ! [[ $content =~ $sentry_android_regex ]]; then
    echo "Failed to find the android plugin version in $build_gradle"
    exit 1
fi

case $1 in
get-version)
    echo ${BASH_REMATCH[2]}
    ;;
get-repo)
    echo "https://github.com/getsentry/sentry-java.git"
    ;;
set-version)
    new_version="$2"

    # Update sentry-android
    new_android_dependency="${BASH_REMATCH[1]}$new_version"
    content="${content/${BASH_REMATCH[0]}/$new_android_dependency}"

    # Update sentry-spotlight to match the same version (if present)
    if [[ $content =~ $sentry_spotlight_regex ]]; then
        new_spotlight_dependency="${BASH_REMATCH[1]}$new_version"
        content="${content/${BASH_REMATCH[0]}/$new_spotlight_dependency}"
    fi

    echo "$content" >$build_gradle

    # Regenerate Dart JNI bindings so they stay in sync with the updated Android SDK version
    ../scripts/generate-jni-bindings.sh "$new_version"
    ;;
*)
    echo "Unknown argument $1"
    exit 1
    ;;
esac
