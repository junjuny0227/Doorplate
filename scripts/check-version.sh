#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <tag>" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tag="$1"
version="$(sed -nE "s/^[[:space:]]*MARKETING_VERSION:[[:space:]]*['\"]?([^[:space:]'\"#]+)['\"]?[[:space:]]*(#.*)?$/\\1/p" "$repo_root/project.yml")"

if [[ -z "$version" || "$tag" != "v$version" ]]; then
  printf 'Version mismatch: tag=%s, MARKETING_VERSION=%s\n' "$tag" "$version" >&2
  exit 1
fi
