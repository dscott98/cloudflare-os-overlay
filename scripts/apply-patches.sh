#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/clean/cloudflare-os" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
target=$(cd "$1" && pwd)
expected=$(node -p "require('$root/UPSTREAM.json').commit")
actual=$(git -C "$target" rev-parse HEAD)

if [[ "$actual" != "$expected" ]]; then
  echo "Target is $actual; expected pinned upstream $expected" >&2
  exit 1
fi
if [[ -n $(git -C "$target" status --porcelain) ]]; then
  echo "Target worktree is not clean." >&2
  exit 1
fi

verify_checksums() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c PATCHES.sha256
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -c PATCHES.sha256
  else
    echo "Neither sha256sum nor shasum is available" >&2
    exit 1
  fi
}

( cd "$root" && verify_checksums )
git -C "$target" am --3way "$root"/patches/*.patch
printf 'Applied overlay patches to %s\n' "$target"
