# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## Overlay release workflow

The end-to-end sync workflow is documented in `.agents/skills/cloudflare-os-overlay-release/SKILL.md`. The on-disk helpers are:

- `./scripts/verify-release.sh` — single-gate verification (submodule pin, clean tree, `PATCHES.sha256`, patch application via `git am --3way`, `pnpm lint`, `pnpm test`).
- `./scripts/sync-upstream.sh` — fetch + pin + patch application + tests + auto-update `UPSTREAM.json`, `RELEASES.md`, `README.md` via `scripts/lib/apply-pin-docs.mjs`.
- `./scripts/apply-pin-docs.sh /path/to/clean/checkout` — apply overlay patches to a separately cloned Cloudflare OS tree.

## Sharp edges

- `scripts/lib/release-docs.test.mjs` is pinned to the previous candidate version (`0.1.0-candidate.N`) and short SHA of the prior pin. When a human bump increments the candidate or rewrites the README/RELEASES fixtures, update that test in the same commit so `node --test scripts/lib/release-docs.test.mjs` stays green.
- `git am --3way` against upstream `main` can succeed with a clean apply even when the patch was generated from an older base. Re-format patches from the new pinned SHA (`git format-patch <new-sha>..HEAD --output-directory patches`) so `@@` line offsets and `index` lines stay accurate, and regenerate `PATCHES.sha256` accordingly.
- The overlay stays deployment-independent: hostname, Access, Worker naming, and Cloudflare resource creation are owned by the downstream starter/deployment task and must never appear in overlay source configuration.
