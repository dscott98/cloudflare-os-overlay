# Cloudflare OS overlay

This repository is a reviewable overlay for a pinned upstream [Cloudflare OS](https://github.com/cloudflare/cloudflare-os) revision. It deliberately contains patches and release metadata, not a modified copy of upstream source or deployment credentials.

## Current release candidate

- Upstream: [`d0cffe48914adff8b296f596137a8809bde89568`](UPSTREAM.json)
- Local delta: three ordered patches in [`patches/`](patches/)
- Integrity manifest: [`PATCHES.sha256`](PATCHES.sha256)

## Independently reproduce the source tree

No trust in this repository's Git history is required. Clone upstream directly, verify this overlay's published checksum/signature, then apply the readable patches:

```sh
git clone https://github.com/cloudflare/cloudflare-os.git
cd cloudflare-os
git checkout d0cffe48914adff8b296f596137a8809bde89568

# From a verified overlay release directory:
sha256sum -c PATCHES.sha256
git am --3way patches/*.patch
```

The result is the candidate source tree. Configure secrets in your own account; this overlay never contains credentials or deployment state.

## Local maintainer workflow

The `cloudflare-os` submodule is an unmodified source pin. Do not edit it in place. Use `scripts/apply-patches.sh` on a separate clean clone/worktree to produce a build candidate.

```sh
./scripts/verify-release.sh
./scripts/apply-patches.sh /path/to/clean/cloudflare-os
```

Read `.agents/skills/cloudflare-os-overlay-release/SKILL.md` before changing the pin or patch series.

## Packaging a release

A release archive must include only `UPSTREAM.json`, `patches/`, `PATCHES.sha256`, `RELEASES.md`, and this README. Publish a SHA-256 checksum and a detached signature from a documented public key. Do not include the upstream submodule, dependencies, `.dev.vars`, secrets, or local build output.
