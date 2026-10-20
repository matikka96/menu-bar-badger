#!/bin/bash
set -euo pipefail

project=$1
scheme=$2
derived=$3
build_number=$4

bundle_id=com.matikka96.MenuBarBadger
destination=/Applications/MenuBarBadger.app
backup=/Applications/.MenuBarBadger.app.previous

if [ -n "$(git status --porcelain)" ]; then
    echo "make install stopped: the working tree has uncommitted changes. Commit or stash them first." >&2
    exit 1
fi
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != main ]; then
    echo "make install stopped: the branch is '$branch'. Install from 'main' only." >&2
    exit 1
fi

xcodebuild -project "$project" -scheme "$scheme" -configuration Release -derivedDataPath "$derived" \
    CURRENT_PROJECT_VERSION="$build_number" -quiet build
product="$derived/Build/Products/Release/MenuBarBadger.app"

if pgrep -f "$destination/Contents/MacOS/" >/dev/null; then
    osascript -e "tell application id \"$bundle_id\" to quit"
    for _ in $(seq 1 100); do
        pgrep -f "$destination/Contents/MacOS/" >/dev/null || break
        sleep 0.1
    done
    if pgrep -f "$destination/Contents/MacOS/" >/dev/null; then
        echo "make install stopped: the running copy did not quit in 10 s." >&2
        exit 1
    fi
fi

rm -rf "$backup"
[ -e "$destination" ] && mv "$destination" "$backup"
if ditto "$product" "$destination"; then
    rm -rf "$backup"
else
    rm -rf "$destination"
    [ -e "$backup" ] && mv "$backup" "$destination"
    echo "make install stopped: the copy failed. The previous app is back in place." >&2
    exit 1
fi
open "$destination"
