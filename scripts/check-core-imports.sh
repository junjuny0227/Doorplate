#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# grep's exit 1 means no forbidden imports, not a failed check.
status=0
grep -rnE --include='*.swift' '^[[:space:]]*import[[:space:]]+(AppKit|SwiftUI|Cocoa|UIKit)([[:space:].;]|$)' \
  "$repo_root/Packages/DoorplateCore/Sources" || status=$?
case "$status" in
  0) exit 1 ;;
  1) exit 0 ;;
  *) exit "$status" ;;
esac
