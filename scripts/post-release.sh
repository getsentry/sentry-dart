#!/bin/bash
set -euo pipefail

git checkout main

for pkg in {flutter,logging,dio}; do
  # Restore dependency_overrides in pubspec.yaml
  cat >> $pkg/pubspec.yaml << EOM

dependency_overrides:
  sentry:
    path: ../dart
EOM
done

git diff --quiet || git commit -anm 'meta: Restore post-release dependency_overrides' && git pull --rebase && git push
