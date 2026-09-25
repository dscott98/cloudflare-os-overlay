# Cloudflare OS Overlay

[![CI](https://github.com/dscott98/cloudflare-os-overlay/actions/workflows/ci.yml/badge.svg)](https://github.com/dscott98/cloudflare-os-overlay/actions)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Upstream Pin](https://img.shields.io/badge/upstream-a43210a-orange)](https://github.com/cloudflare/cloudflare-os/tree/a43210a79720c50381f0f7e9719cff21ef0db74e)

A verifiable, reproducible overlay for [Cloudflare OS](https://github.com/cloudflare/cloudflare-os) that adds **deployment-managed custom AI Gateway models** without maintaining a messy, long-lived fork or leaking credentials.

---

## Why this exists

1. **Clean Overlay Pattern**: Instead of maintaining a diverging git fork with merge conflicts and untracked changes, this repo provides an immutable upstream commit pin and an ordered, checksum-verified patch series (`patches/`).
2. **Zero-Credential AI Gateway Routing**: Deployment administrators can configure and publish custom LLM models (OpenRouter, private endpoints, custom providers) directly through Cloudflare AI Gateway. Upstream API keys stay securely inside AI Gateway—ordinary users can use the models from the UI without ever seeing or needing personal API keys.

---

## Current release candidate

- **Upstream commit**: [`a43210a79720c50381f0f7e9719cff21ef0db74e`](UPSTREAM.json)
- **Local delta**: Consolidated patch in [`patches/`](patches/)
- **Integrity manifest**: [`PATCHES.sha256`](PATCHES.sha256)
- **Status**: Candidate (`0.1.0-candidate.10` in [RELEASES.md](RELEASES.md))

---

## Deployment AI Gateway Model Setup

Deployment-managed AI Gateway model configuration is integrated natively into the existing **Add AI Model** dialog. An administrator navigates to **AI providers** → **Add provider**, selects **Deployment AI Gateway model**, and provides the upstream model ID, display name, provider route, and relative endpoint path (e.g. `v1/chat/completions`, `v1/responses`, `v1/messages`, or `v1/completions`).

![Deployment AI Gateway model dialog](docs/ai-gateway-model-dialog.png)

*The screenshot above illustrates local UI setup with non-secret placeholder Gateway values.*

- **Admin-only configuration**: The dialog and edit/delete controls are visible only to administrators when deployment AI Gateway mode is enabled (`CF_AI_GATEWAY`, `CF_AI_GATEWAY_ACCOUNT_ID`, and either the Workers AI binding or `CF_AI_GATEWAY_API_TOKEN`).
- **User access**: Non-admin users can select and prompt any published model from chat without administrative privileges or API keys.
- **Protocol compatibility & Multi-Endpoint Support**: Deployment models automatically resolve the appropriate streaming and payload protocol based on the configured endpoint path:
  - **OpenAI Chat Completions** (`v1/chat/completions` or `chat/completions`): standard chat completion models with multi-turn messages and tool calling.
  - **OpenAI Responses API / Reasoning Models** (`v1/responses` or `responses`): models using OpenAI's Responses API format, such as `gpt-5.6-sol`, `gpt-5.6-luna`, `gpt-5.6-terra`, and OpenAI reasoning models (`o1`, `o3-mini`). Automatically activates reasoning effort and native input file payload bridging.
  - **Anthropic Messages** (`v1/messages` or `messages`): routes to Anthropic Messages stream handling, supporting Anthropic document blocks and extended thinking.
  - **OpenAI Completions** (`v1/completions` or `completions`): standard prompt completion endpoints.
- **Unified architecture**: Implements backend storage, authorization, RPC capabilities, AI Gateway proxy routing, dynamic stream protocol resolution, and the native Add AI Model dialog UI workflow.

---

## Non-Chat & Reasoning Model Support (e.g. GPT-5.6-SOL)

Prefer upstream's native model-provider accounts for catalog models. Use deployment AI Gateway models when a deployment needs to publish a shared route, including custom endpoints absent from the native catalog; the supported protocols are listed in [Deployment AI Gateway Model Setup](#deployment-ai-gateway-model-setup). For the Nymbus deployment, use OpenRouter only when necessary, including Gemini if genuinely needed; do not assume a Gemini CLI or a native Google account is available.

With this overlay:
1. **Configuring in Admin UI**: For a deployment-managed route whose model requires the Responses API, set the endpoint path to `v1/responses`.
2. **Automatic Protocol Dispatch**: The backend detects `responses` and automatically dispatches to the `openai-responses` stream handler, enabling reasoning effort (`medium` by default), stateless ZDR payload formatting, and encrypted reasoning history propagation across turns.
3. **Attachment Bridging**: Document and PDF attachments are automatically bridged to native OpenAI `input_file` format rather than being rejected by chat-only image schemas.

---

## Quickstart: Independently reproduce & run

No trust in this repository's Git history is required. You can clone the pinned upstream source separately, verify the published patch checksums, and apply them:

```sh
# 1. Clone this overlay repository
git clone https://github.com/dscott98/cloudflare-os-overlay.git
cd cloudflare-os-overlay
overlay_dir=$(pwd)

# 2. Clone the pinned upstream source into a candidate directory
git clone https://github.com/cloudflare/cloudflare-os.git ../cloudflare-os-candidate
cd ../cloudflare-os-candidate
git checkout a43210a79720c50381f0f7e9719cff21ef0db74e

# 3. Verify patch checksums and apply the patch series
( cd "$overlay_dir" && ( command -v sha256sum >/dev/null && sha256sum -c PATCHES.sha256 || shasum -a 256 -c PATCHES.sha256 ) )
git am --3way "$overlay_dir"/patches/*.patch
```

### Run locally with Wrangler & workerd

From your reconstructed `cloudflare-os-candidate` directory:

Prerequisites:
- Node.js 24+
- [pnpm](https://pnpm.io/) 11.17.0 (pinned by upstream workspace)

```sh
pnpm install --frozen-lockfile
pnpm run-local
```

Open [http://localhost:8787](http://localhost:8787). Register with username `admin` to access administrator features.

For active frontend development with Vite HMR:
```sh
# Terminal 1: Backend
pnpm dev-server

# Terminal 2: Frontend
pnpm dev-client
```
Open [http://localhost:3000](http://localhost:3000).

To run the full test suite:
```sh
pnpm test
```

---

## Maintainer Verification Workflow

Maintainers can verify the pinned submodule, patch application, linting, and complete test suite in an isolated worktree with a single command:

```sh
git submodule update --init --recursive
./scripts/verify-release.sh
```

To apply the overlay patches to a target clean worktree:
```sh
./scripts/apply-patches.sh /path/to/clean/cloudflare-os
```

---

## License

This project is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
