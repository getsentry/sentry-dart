#!/usr/bin/env bash
set -euo pipefail

# SwiftPM can leave partial binary target artifacts behind on macOS runners,
# causing later Sentry Cocoa resolves to fail with "already exists".
rm -rf "$HOME/Library/Caches/org.swift.swiftpm"
rm -rf "$HOME/Library/org.swift.swiftpm"
rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/*/SourcePackages
