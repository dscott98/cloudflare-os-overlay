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

# Verify the checked artifacts are also an applicable ordered series, without changing the pinned
# submodule. A checksum alone cannot detect a patch whose context no longer applies to the pin.
worktree_parent=$(mktemp -d)
worktree="$worktree_parent/candidate"
cleanup() {
  git -C "$submodule" worktree remove --force "$worktree" >/dev/null 2>&1 || true
  rm -rf "$worktree_parent"
}
trap cleanup EXIT

git -C "$submodule" worktree add --detach "$worktree" "$expected" >/dev/null
git -C "$worktree" am --3way "$root"/patches/*.patch >/dev/null

# Test the exact reconstructed candidate, not the clean upstream submodule. `lint` includes the
# type/build check in this workspace; `test` runs the repository's unit and integration suites.
pnpm --dir "$worktree" install --frozen-lockfile
pnpm --dir "$worktree" lint
pnpm --dir "$worktree" test

printf 'Verified upstream pin, clean submodule, patch checksums, patch application, and tests.\n'
