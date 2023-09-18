#!/bin/bash
set -euo pipefail

GITHUB_BRANCH="${1}"
COMMIT_MESSAGE="${2}"

if [[ $(git status) == *"nothing to commit"* ]]; then
    echo "Nothing to commit."
else
    echo "Changed some code. Going to push the changes."
    git config --global user.name 'Sentry Github Bot'
    git config --global user.email 'bot+github-bot@sentry.io'
    git fetch
    git checkout ${GITHUB_BRANCH}
    git commit -am ${COMMIT_MESSAGE}
    git push --set-upstream origin ${GITHUB_BRANCH}
fi
