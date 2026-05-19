#!/usr/bin/env bash
set -euo pipefail

rm -rf "$HOME/Library/Caches/org.swift.swiftpm"
rm -rf "$HOME/Library/org.swift.swiftpm"
rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/*/SourcePackages
