#!/usr/bin/env bash
# Publishes one version of one app as two GitHub releases:
#   <app>-v<version>  a permanent copy, never changed
#   <app>-latest      always the newest, so each app has one fixed download link
#
# Usage: bash publish.sh <app> <version> <file> ["what changed"]
set -euo pipefail

fail() { echo "publish: $*" >&2; exit 1; }

[ $# -ge 3 ] || fail "usage: bash publish.sh <app> <version> <file> [\"what changed\"]"
app=$1 version=$2 file=$3 notes=${4:-}

[ -f "$file" ] || fail "no such file: $file"
file=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")
cd "$(dirname "$0")"

[[ $app =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "app names are lowercase words joined by hyphens: $app"
[ -f "apps/$app/app.env" ] || fail "no such app: $app. Add apps/$app/app.env first."
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "use a version like 1.2.3: $version"

# shellcheck source=/dev/null
source "apps/$app/app.env"
[[ $file == *."$EXTENSION" ]] || fail "$NAME is published as .$EXTENSION: $file"

versioned=$app-v$version
latest=$app-latest
if gh release view "$versioned" > /dev/null 2>&1; then
  fail "$versioned is already published. Published versions are never replaced."
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
versioned_file=$work/$app-$version.$EXTENSION
latest_file=$work/$app.$EXTENSION
cp "$file" "$versioned_file"
cp "$file" "$latest_file"

body="${notes:+$notes

}SHA-256: $(sha256sum "$file" | cut -d' ' -f1)"

# --latest=false everywhere: GitHub has one "latest" per repo, and it would
# point at whichever app happened to publish last.
gh release create "$versioned" "$versioned_file" --title "$NAME $version" --notes "$body" --latest=false
if gh release view "$latest" > /dev/null 2>&1; then
  gh release upload "$latest" "$latest_file" --clobber
  gh release edit "$latest" --title "$NAME (latest: $version)" --notes "$body"
else
  gh release create "$latest" "$latest_file" --title "$NAME (latest: $version)" --notes "$body" --latest=false
fi

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
echo "Published $NAME $version"
echo "https://github.com/$repo/releases/download/$latest/$app.$EXTENSION"
