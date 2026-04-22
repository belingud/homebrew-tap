#!/bin/bash

set -euo pipefail

FORMULA_FILE="Formula/gptcomet.rb"
SOURCE_REPO="${SOURCE_REPO:-../gptcomet}"

if [ ! -d "$SOURCE_REPO/.git" ]; then
    echo "Error: Git repository not found at $SOURCE_REPO" >&2
    exit 1
fi

version="$(git -C "$SOURCE_REPO" tag --sort=-version:refname | head -n 1 | sed 's/^v//')"

if [ -z "$version" ]; then
    echo "Error: No git tag found in $SOURCE_REPO" >&2
    exit 1
fi

revision="$(git -C "$SOURCE_REPO" rev-list -n 1 "v$version")"

if [ -z "$revision" ]; then
    echo "Error: Failed to resolve revision for v$version" >&2
    exit 1
fi

perl -0pi -e "s/tag:\\s+\"v[^\"]*\"/tag:      \"v$version\"/" "$FORMULA_FILE"
perl -0pi -e "s/revision:\\s+\"[^\"]*\"/revision: \"$revision\"/" "$FORMULA_FILE"
perl -0pi -e "s/version\\s+\"[^\"]*\"/version \"$version\"/" "$FORMULA_FILE"

echo "Updated $FORMULA_FILE to version $version ($revision)"
