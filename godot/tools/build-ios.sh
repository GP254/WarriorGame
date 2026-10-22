#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
engine="${GODOT_BIN:-godot}"
mkdir -p "$project_dir/builds/ios"
"$engine" --headless --path "$project_dir" --editor --import --quit
"$engine" --headless --path "$project_dir" --export-debug iOS
# This creates an unsigned simulator build. Device signing is configured in Xcode.
host_arch="$(uname -m)"
xcodebuild -project "$project_dir/builds/ios/AshenBanner.xcodeproj" \
  -scheme AshenBanner -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$project_dir/builds/DerivedData" \
  CODE_SIGNING_ALLOWED=NO ARCHS="$host_arch" ONLY_ACTIVE_ARCH=YES build
