#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../sentry-native"
file='CMakeCache.txt'
content=$(cat $file)
regex="(version)=([0-9\.]+(\-[a-z0-9\.]+)?)"
if ! [[ $content =~ $regex ]]; then
    echo "Failed to find the plugin version in $file"
    exit 1
fi

case $1 in
get-version)
    echo "${BASH_REMATCH[2]}"
    ;;
get-repo)
    echo "$content" | grep -w repo | cut -d '=' -f 2 | tr -d '\n'
    ;;
set-version)
    newValue="${BASH_REMATCH[1]}=$2"
    echo "${content/${BASH_REMATCH[0]}/$newValue}" >$file
    pwsh ../scripts/generate-native-bindings.ps1 "$2"
    ;;
*)
    echo "Unknown argument $1"
    exit 1
    ;;
esac
