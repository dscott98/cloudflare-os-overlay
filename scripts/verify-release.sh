#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
expected=$(node -p "require('$root/UPSTREAM.json').commit")
actual=$(git -C "$root/cloudflare-os" rev-parse HEAD)

if [[ "$actual" != "$expected" ]]; then
  echo "cloudflare-os submodule is $actual; expected $expected" >&2
  exit 1
fi

( cd "$root" && sha256sum -c PATCHES.sha256 )
printf 'Verified upstream pin and patch checksums.\n'
