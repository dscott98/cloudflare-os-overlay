| `0.1.0-candidate.8` | `81f3c5732bb8ea17dc75209eef9e521d571d50b1` | candidate | Automated upstream sync (2026-09-02, 9 new commits). |
# Overlay releases

| Overlay version | Upstream commit | Status | Notes |
| --- | --- | --- | --- |
| `0.1.0-candidate.7` | `af56a9d79d8a60ebed8dabb11b075cd88efc1b87` | candidate | Extended deployment AI Gateway custom model routing to support non-chat completion endpoints including OpenAI Responses API (`v1/responses` for models like `gpt-5.6-sol`), Anthropic Messages (`v1/messages`), and text completions (`v1/completions`) with dynamic stream protocol resolution and test coverage. |
| `0.1.0-candidate.6` | `af56a9d79d8a60ebed8dabb11b075cd88efc1b87` | candidate | Rebased the deployment AI Gateway custom-model patch onto upstream Workshop scripted agent test suite, parallel integration tests, tool picker scroll fix, and dependency updates; includes 26 upstream commits. |
| `0.1.0-candidate.5` | `1ef6020a42fbabb6d27dd1063db3a075ba95c974` | candidate | Rebased the deployment AI Gateway custom-model patch onto upstream Git backing storage, OT sync, and CodeMirror editor migration (#275); includes 15 upstream commits. |
| `0.1.0-candidate.4` | `6478a1448a11524e2f7c2575ad66fab0bc47c433` | candidate | Rebased the deployment AI Gateway custom-model patch onto upstream export, MCP, observability, and AI binding changes; includes 24 upstream commits. |
| `0.1.0-candidate.2` | `02377767e684aedcbb12f44025cd6331d08b1b50` | candidate | Rebase pin to current upstream; includes dev-server performance improvements (#179), cacheable test tasks (#204), and dependency updates. |
| `0.1.0-candidate.1` | `d0cffe48914adff8b296f596137a8809bde89568` | candidate | Custom AI Gateway model and native-provider routing changes; consolidated patch including Add AI Model dialog management for deployment models. |

A production entry requires a published bundle checksum, detached signature, public-key location, and successful test evidence.
