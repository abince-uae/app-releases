#!/usr/bin/env bash
# Runs publish.sh against a stand-in for the gh command, so nothing reaches GitHub.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

mkdir -p "$work/bin" "$work/repo"
cp "$root/publish.sh" "$work/repo/"
cp -r "$root/apps" "$work/repo/"
mkdir "$work/repo/apps/other-app"
printf 'NAME="Other App"\nEXTENSION=exe\n' > "$work/repo/apps/other-app/app.env"

cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" | tr '
' ' ' >> "$GH_LOG"
echo >> "$GH_LOG"
case "$1 $2" in
  "release view") grep -qx "$3" "$GH_RELEASES" 2>/dev/null ;;
  "release create") echo "$3" >> "$GH_RELEASES"; [ -f "$4" ] || exit 9 ;;
  "release upload") [ -f "$4" ] || exit 9 ;;
  "repo view") echo "someone/app-releases" ;;
esac
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" GH_LOG="$work/gh.log" GH_RELEASES="$work/releases"
touch "$GH_LOG" "$GH_RELEASES"

echo "pretend app" > "$work/build.apk"
echo "pretend app" > "$work/build.exe"
echo "not an app" > "$work/build.zip"

ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; failures=$((failures + 1)); }
publish() { bash "$work/repo/publish.sh" "$@" 2>&1; }
creates() { grep -c "release create" "$GH_LOG"; }

refused() {
  local name=$1 before
  shift
  before=$(creates)
  if publish "$@" > /dev/null; then bad "$name: should be refused"
  elif [ "$(creates)" != "$before" ]; then bad "$name: created a release"
  else ok "$name"; fi
}

has() { if grep -qF -- "$2" <<< "$3"; then ok "$1"; else bad "$1: no '$2' in: $3"; fi; }
hasnt() { if grep -qF -- "$2" <<< "$3"; then bad "$1: found '$2'"; else ok "$1"; fi; }

refused "unknown app" nope 1.0.0 "$work/build.apk"
refused "unsafe app name" "../apps/shuttle-desk" 1.0.0 "$work/build.apk"
refused "version with two parts" shuttle-desk 1.0 "$work/build.apk"
refused "version with a build number" shuttle-desk 1.0.0+1 "$work/build.apk"
refused "missing file" shuttle-desk 1.0.0 "$work/nothing.apk"
refused "wrong file type" shuttle-desk 1.0.0 "$work/build.zip"
refused "too few arguments" shuttle-desk 1.0.0

out=$(publish shuttle-desk 1.0.0 "$work/build.apk" "First version") || bad "first publish failed: $out"
log=$(cat "$GH_LOG")
has "keeps a permanent copy of the version" "release create shuttle-desk-v1.0.0" "$log"
has "names the file with its version" "shuttle-desk-1.0.0.apk" "$log"
has "makes the app's fixed link" "release create shuttle-desk-latest" "$log"
has "the fixed file has no version in its name" "/shuttle-desk.apk" "$log"
has "records the file's checksum" "$(sha256sum "$work/build.apk" | cut -d' ' -f1)" "$log"
has "records what changed" "First version" "$log"
has "prints the download link" "https://github.com/someone/app-releases/releases/download/shuttle-desk-latest/shuttle-desk.apk" "$out"
if [ "$(grep "release create" "$GH_LOG" | grep -c -- "--latest=false")" = 2 ]; then ok "neither release claims the whole repo's latest"; else bad "a release claims the repo's latest"; fi

refused "the same version twice" shuttle-desk 1.0.0 "$work/build.apk"

: > "$GH_LOG"
out=$(publish shuttle-desk 1.1.0 "$work/build.apk") || bad "second publish failed: $out"
log=$(cat "$GH_LOG")
has "a new version keeps its own copy" "release create shuttle-desk-v1.1.0" "$log"
has "a new version replaces the file at the fixed link" "release upload shuttle-desk-latest" "$log"
has "replacing is allowed" "--clobber" "$log"
hasnt "the fixed link is not created twice" "release create shuttle-desk-latest" "$log"

: > "$GH_LOG"
out=$(publish other-app 1.0.0 "$work/build.exe") || bad "other app failed: $out"
log=$(cat "$GH_LOG")
has "a second app gets its own link" "releases/download/other-app-latest/other-app.exe" "$out"
hasnt "a second app leaves the first alone" "shuttle-desk" "$log"
hasnt "no link depends on the repo-wide latest" "releases/latest" "$out"

(cd "$work" && bash "$work/repo/publish.sh" other-app 2.0.0 build.exe > /dev/null 2>&1) && ok "a file path relative to where you are works" || bad "relative file path failed"

if [ "$failures" = 0 ]; then echo "All passed."; else echo "$failures failed."; exit 1; fi
