#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
submodule="$root/cloudflare-os"

if [[ ! -e "$submodule/.git" ]] || ! git -C "$submodule" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "cloudflare-os submodule is not initialized; run: git submodule update --init --recursive" >&2
  exit 1
fi

expected=$(node -p "require('$root/UPSTREAM.json').commit")
actual=$(git -C "$submodule" rev-parse HEAD)
if [[ "$actual" != "$expected" ]]; then
  echo "cloudflare-os submodule is $actual; expected $expected" >&2
  exit 1
fi
if [[ -n $(git -C "$submodule" status --porcelain) ]]; then
  echo "cloudflare-os submodule is not clean." >&2
  exit 1
fi

( cd "$root" && sha256sum -c PATCHES.sha256 )
printf 'Verified upstream pin, clean submodule, and patch checksums.\n'
