#!/usr/bin/env bash
# Cut an Elio release: tag this commit, push the tag, and publish it on GitHub
# with the commits since the last one. Run on fedora, from the repository.
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
cd "$repo"

if [ -n "$(git status --porcelain)" ]; then
    echo "working tree is dirty; commit or stash first" >&2
    exit 1
fi

day=$(date +%Y.%m.%d)
previous=$(git tag --list "elio-*" | sort -V | tail -1)
last_today=$(git tag --list "elio-$day.*" | sort -V | tail -1)

n=1
if [ -n "$last_today" ]; then
    n=$(( ${last_today##*.} + 1 ))
fi

tag="elio-$day.$n"
git tag -a "$tag" -m "$tag"

range="$tag^"
if [ -n "$previous" ]; then
    range="$previous..HEAD"
fi
notes=$(git log --no-merges --pretty='- %s' $range)

git push origin "$tag"
gh release create "$tag" \
    --repo hamishburke/hermes-conduit \
    --title "$tag" \
    --notes "$notes"

echo "released $tag"
echo "install with: $repo/scripts/elio-install.sh"
