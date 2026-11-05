#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$repo_root/scripts/check-version.sh" "$@"
cd "$repo_root"
version="${1#v}"

xcodegen generate
xcodebuild -project Doorplate.xcodeproj -scheme Doorplate -configuration Release \
  -derivedDataPath build/release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- build

mkdir -p dist
rm -rf dist/Doorplate.app
ditto build/release/Build/Products/Release/Doorplate.app dist/Doorplate.app
codesign --verify --deep --strict dist/Doorplate.app

# Replace any prior archive rather than updating its entries in place.
rm -f "dist/Doorplate-$version.zip"
(cd dist && ditto -c -k --keepParent Doorplate.app "Doorplate-$version.zip" \
  && shasum -a 256 "Doorplate-$version.zip" > "Doorplate-$version.zip.sha256")
