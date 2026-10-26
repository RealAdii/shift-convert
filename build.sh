#!/bin/zsh
set -eu
cd "${0:A:h}"
swift build -c release
mkdir -p dist/Shift.app/Contents/MacOS dist/Shift.app/Contents/Resources
cp .build/release/Shift dist/Shift.app/Contents/MacOS/Shift
cp Info.plist dist/Shift.app/Contents/Info.plist
codesign --force --sign - dist/Shift.app
printf 'Built %s/dist/Shift.app\n' "$PWD"
