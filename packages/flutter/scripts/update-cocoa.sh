#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../darwin"

spm_repo='https://github.com/getsentry/sentry-apple-binaries'
version_pattern='[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?'
regex="(url: *['\"]$spm_repo['\"], *)(exact|revision): *['\"]($version_pattern)['\"]"

get_spm_version() {
  local file='sentry_flutter/Package.swift'
  local content
  content=$(cat "$file")
  if ! [[ $content =~ $regex ]]; then
    echo "Failed to find the plugin version in $file"
    exit 1
  else
    echo "${BASH_REMATCH[3]}"
  fi
}

set_spm_version() (
  local version="$1"
  if ! [[ $version =~ ^$version_pattern$ ]]; then
    echo "Invalid Cocoa version: $version" >&2
    exit 1
  fi

  local file='sentry_flutter/Package.swift'
  local content
  content=$(cat "$file")
  if ! [[ $content =~ $regex ]]; then
    echo "Failed to find the plugin version in $file" >&2
    exit 1
  fi
  local new_pin="${BASH_REMATCH[1]}exact: \"$version\""
  local new_manifest="${content/${BASH_REMATCH[0]}/$new_pin}"

  # An annotated tag has both a tag object and a peeled commit. SwiftPM pins the commit.
  local tag="refs/tags/$version"
  local revision
  if ! revision=$(git ls-remote --exit-code "$spm_repo" "$tag" "$tag^{}" | awk -v tag="$tag" '
    $2 == tag { revision = $1 }
    $2 == tag "^{}" { peeled = $1 }
    END { print (peeled ? peeled : revision) }
  ') || ! [[ $revision =~ ^[0-9a-f]{40}$ ]]; then
    echo "Could not resolve the sentry-apple-binaries commit for $version" >&2
    exit 1
  fi

  local lockfiles
  lockfiles=(../example/{ios,macos}/Runner{.xcodeproj/project,}.xcworkspace/xcshareddata/swiftpm/Package.resolved)
  local staging_dir
  staging_dir=$(mktemp -d)
  trap 'rm -rf -- "$staging_dir"' EXIT

  # Prepare all lockfiles before changing any pins. Keep Xcode's key formatting.
  local index
  for index in "${!lockfiles[@]}"; do
    jq -e --arg version "$version" --arg revision "$revision" '
      if ([.pins[] | select(.identity == "sentry-apple-binaries")] | length) != 1 then
        error("expected exactly one sentry-apple-binaries pin")
      else
        (.pins[] | select(.identity == "sentry-apple-binaries") | .state) |=
          (.revision = $revision | .version = $version)
      end
    ' "${lockfiles[index]}" | sed -E 's/^([[:space:]]*"[^"]+"):/\1 :/' > "$staging_dir/$index"
  done

  printf '%s\n' "$new_manifest" > "$file"
  for index in "${!lockfiles[@]}"; do
    cat "$staging_dir/$index" > "${lockfiles[index]}"
  done
)

case $1 in
get-version)
    get_spm_version
    ;;
get-repo)
    echo "https://github.com/getsentry/sentry-cocoa.git"
    ;;
set-version)
    set_spm_version "$2"
    ;;
*)
    echo "Unknown argument $1"
    exit 1
    ;;
esac
