#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <version> <sha256 file> <tap folder>" >&2
}

if [[ $# -ne 3 ]]; then
  usage
  exit 2
fi

version="$1"
sha256_file="$2"
tap_folder="$3"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="$repo_root/packaging/homebrew/doorplate.rb.template"

if [[ ! -f "$sha256_file" ]]; then
  echo "Error: sha256 file not found: $sha256_file" >&2
  exit 1
fi
if [[ ! -f "$template" ]]; then
  echo "Error: cask template not found: $template" >&2
  exit 1
fi
if [[ ! -d "$tap_folder/Casks" ]]; then
  echo "Error: tap folder must contain a Casks directory: $tap_folder" >&2
  exit 1
fi

sha256="$(awk 'NR == 1 { print $1 }' "$sha256_file")"
if [[ ! "$sha256" =~ ^[[:xdigit:]]{64}$ ]]; then
  echo "Error: invalid SHA-256 in $sha256_file" >&2
  exit 1
fi

output="$tap_folder/Casks/doorplate.rb"
sed -e "s/{{VERSION}}/$version/g" -e "s/{{SHA256}}/$sha256/g" "$template" > "$output"
