---
name: cloudflare-os-overlay-release
description: Maintains a Cloudflare OS customization as an upstream-pinned, independently verifiable overlay release. Use when syncing cloudflare/cloudflare-os, updating an upstream pin, rebasing or regenerating local patches, producing signed patch bundles, or reviewing overlay release provenance. Does not deploy infrastructure.
---

# Cloudflare OS Overlay Release

Maintain downstream changes so consumers can independently obtain the upstream source, inspect a small local delta, and reproduce a release.

## Non-negotiable rules

- Treat `cloudflare/cloudflare-os` as the source of truth; never develop on a long-lived merged fork branch.
- Pin every candidate and release to an immutable upstream commit SHA.
- Prefer configuration, external Gatekeepers, and Blueprints over edits to upstream source.
- Keep unavoidable upstream edits as small, ordered `git format-patch` files.
- Never package secrets, credentials, `.dev.vars`, or generated local state.
- Never auto-deploy an upstream update. This skill prepares a reviewed candidate only.

## Repository layout

Use an overlay/wrapper repository rather than altering the upstream clone:

```text
cloudflare-os/              # upstream submodule or clean checkout, pinned by SHA
patches/                    # ordered 0001-*.patch files (only if required)
deployment/                 # non-secret configuration templates
UPSTREAM.json               # upstream URL + pinned commit
RELEASES.md                 # overlay release → upstream SHA mapping
```

## Update workflow

1. Fetch `https://github.com/cloudflare/cloudflare-os.git` as `upstream`.
2. Record the proposed `upstream/main` SHA and summarize commits since the current pin.
3. In a clean worktree, check out that exact SHA.
4. Apply `patches/*.patch` with `git am --3way`.
5. If conflicts occur, stop and report them. Update only the affected patch(es); do not merge upstream into a downstream branch.
6. Run the documented upstream build/test suite and overlay tests.
7. Update `UPSTREAM.json`, `RELEASES.md`, and the submodule pointer only after review.
8. Create a candidate PR containing the pin change, patch revisions, test results, and upstream change summary.

## Creating or revising patches

Start from the pinned clean upstream commit. Make one focused change per commit, then generate ordered patches:

```sh
git format-patch <upstream-sha> --output-directory ../patches
```

Patch commit messages must explain: purpose, affected upstream extension boundary, and why config/Gatekeeper/Blueprint alternatives were insufficient.

## Verifiable release bundle

Publish a versioned tarball containing only:

```text
UPSTREAM.json               # { "repository", "commit" }
patches/*.patch
deployment/*.example.*
RELEASES.md
README.md                    # independent verification/application commands
SHA256SUMS
SIGNATURE                    # signature over the bundle or checksum manifest
```

Consumers must be able to:

1. Clone upstream directly.
2. Check out the SHA in `UPSTREAM.json`.
3. Verify checksum and signature using the published public key.
4. Inspect and apply only `patches/*.patch` with `git am --3way`.
5. Configure their own secrets and deploy from their own account.

## Required release evidence

For every candidate/release report:

- overlay version and upstream repository + full SHA
- ahead/behind count and included upstream commit range
- patch list with patch SHA-256 hashes
- patch-application result
- build/test commands and results
- bundle checksum, signature method, and public-key location
- explicit statement that no secrets were included

## Do not

- force-push or rewrite published release tags
- silently absorb patches into a fork merge commit
- claim reproducibility without a full upstream SHA and bundle checksum
- treat a successful patch apply as sufficient validation
