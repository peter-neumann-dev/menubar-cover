#!/bin/bash
# Usage: ./build.sh [--install | --release]
#   --install  copies the app to ~/Applications and restarts it
#   --release  signs ad-hoc (no personal certificate in the download) and zips the app for a GitHub release
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64
APP="build/MenuBar Cover.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Library/LaunchAgents"
cp .build/release/MenuBarCover "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/dev.peter-neumann.MenuBarCover.agent.plist "$APP/Contents/Library/LaunchAgents/"
mkdir -p "$APP/Contents/Resources"
xcrun actool Icon/AppIcon.icon --compile "$APP/Contents/Resources" --platform macosx --minimum-deployment-target 15.0 \
    --app-icon AppIcon --output-partial-info-plist build/icon-partial.plist > /dev/null

# A real certificate keeps the Accessibility/Screen Recording grants valid across rebuilds.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')
[[ "${1:-}" == "--release" ]] && IDENTITY="-"
codesign --force --timestamp=none --sign "${IDENTITY:--}" "$APP"

case "${1:-}" in
    --install)
        pkill -x MenuBarCover || true
        rm -rf ~/Applications/"MenuBar Cover.app"
        mkdir -p ~/Applications
        cp -R "$APP" ~/Applications/
        open ~/Applications/"MenuBar Cover.app"
        ;;
    --release)
        VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
        ZIP="build/MenuBar-Cover-$VERSION.zip"
        rm -f "$ZIP"
        ditto -c -k --keepParent "$APP" "$ZIP"
        echo "$ZIP"
        ;;
esac
