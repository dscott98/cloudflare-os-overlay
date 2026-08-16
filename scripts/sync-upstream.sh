#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
submodule="$root/cloudflare-os"
upstream_url="https://github.com/cloudflare/cloudflare-os.git"

if [[ ! -e "$submodule/.git" ]] || ! git -C "$submodule" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "cloudflare-os submodule is not initialized; run: git submodule update --init --recursive" >&2
  exit 1
fi

current_pin=$(node -p "require('$root/UPSTREAM.json').commit")

echo "Fetching upstream from $upstream_url..."
git -C "$submodule" remote set-url origin "$upstream_url" 2>/dev/null || git -C "$submodule" remote add origin "$upstream_url" 2>/dev/null || true
git -C "$submodule" fetch --quiet origin main

latest_sha=$(git -C "$submodule" rev-parse origin/main)

echo "Current pin: $current_pin"
echo "Latest main: $latest_sha"

if [[ "$current_pin" == "$latest_sha" ]]; then
  echo "Overlay is already at latest upstream pin ($latest_sha)."
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "has_update=false" >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi

changelog=$(git -C "$submodule" log --oneline "${current_pin}..${latest_sha}")
commit_count=$(git -C "$submodule" rev-list --count "${current_pin}..${latest_sha}")

echo "Found $commit_count new commit(s) upstream:"
echo "$changelog"

worktree_parent=$(mktemp -d)
worktree="$worktree_parent/candidate"
cleanup() {
  git -C "$submodule" worktree remove --force "$worktree" >/dev/null 2>&1 || true
  rm -rf "$worktree_parent"
}
trap cleanup EXIT

export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-Overlay Sync}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-sync@local}"
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Overlay Sync}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-sync@local}"

echo "Checking out candidate worktree at $latest_sha..."
git -C "$submodule" worktree add --detach "$worktree" "$latest_sha" >/dev/null

echo "Applying overlay patches..."
set +e
patch_output=$(git -C "$worktree" am --3way "$root"/patches/*.patch 2>&1)
patch_status=$?
set -e

if [[ $patch_status -ne 0 ]]; then
  echo "Patch application failed!" >&2
  echo "$patch_output" >&2
  
  cat <<EOF > "$root/sync-report.md"
### ❌ Upstream Sync Failed: Patch Application Conflict

- **Current Pin**: \`${current_pin}\`
- **Proposed Upstream SHA**: [\`${latest_sha}\`](https://github.com/cloudflare/cloudflare-os/commit/${latest_sha})
- **Commits Behind**: ${commit_count}

#### Upstream Commits:
\`\`\`
${changelog}
\`\`\`

#### \`git am\` Error Output:
\`\`\`
${patch_output}
\`\`\`

#### Next Steps to Resolve:
1. In a clean worktree at \`${latest_sha}\`, apply patches manually with \`git am --3way\`.
2. Resolve conflicts and update \`patches/0001-*.patch\` using \`git format-patch\`.
3. Update \`PATCHES.sha256\` with the new patch checksum.
4. Run \`./scripts/verify-release.sh\` to validate.
EOF

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "has_update=true" >> "$GITHUB_OUTPUT"
    echo "sync_status=patch_conflict" >> "$GITHUB_OUTPUT"
    echo "latest_sha=$latest_sha" >> "$GITHUB_OUTPUT"
    echo "commit_count=$commit_count" >> "$GITHUB_OUTPUT"
  fi
  exit 101
fi

echo "Installing candidate dependencies..."
pnpm --dir "$worktree" install --frozen-lockfile

echo "Running linter and typecheck..."
set +e
lint_output=$(pnpm --dir "$worktree" lint 2>&1)
lint_status=$?
set -e

if [[ $lint_status -ne 0 ]]; then
  echo "Lint/Typecheck failed!" >&2
  
  cat <<EOF > "$root/sync-report.md"
### ❌ Upstream Sync Failed: Lint / Typecheck Error

- **Current Pin**: \`${current_pin}\`
- **Proposed Upstream SHA**: [\`${latest_sha}\`](https://github.com/cloudflare/cloudflare-os/commit/${latest_sha})

#### Upstream Commits:
\`\`\`
${changelog}
\`\`\`

#### Lint Output:
\`\`\`
${lint_output}
\`\`\`
EOF

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "has_update=true" >> "$GITHUB_OUTPUT"
    echo "sync_status=lint_failure" >> "$GITHUB_OUTPUT"
    echo "latest_sha=$latest_sha" >> "$GITHUB_OUTPUT"
  fi
  exit 102
fi

echo "Running test suite..."
set +e
test_output=$(pnpm --dir "$worktree" test 2>&1)
test_status=$?
set -e

if [[ $test_status -ne 0 ]]; then
  echo "Tests failed!" >&2
  
  cat <<EOF > "$root/sync-report.md"
### ❌ Upstream Sync Failed: Test Suite Regressions

- **Current Pin**: \`${current_pin}\`
- **Proposed Upstream SHA**: [\`${latest_sha}\`](https://github.com/cloudflare/cloudflare-os/commit/${latest_sha})

#### Upstream Commits:
\`\`\`
${changelog}
\`\`\`

#### Test Failure Summary:
\`\`\`
${test_output}
\`\`\`
EOF

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "has_update=true" >> "$GITHUB_OUTPUT"
    echo "sync_status=test_failure" >> "$GITHUB_OUTPUT"
    echo "latest_sha=$latest_sha" >> "$GITHUB_OUTPUT"
  fi
  exit 103
fi

echo "Candidate passed all checks! Updating pin..."

# Update UPSTREAM.json, README.md, and RELEASES.md
node -e "
  const fs = require('fs');
  const root = '$root';
  const prevSha = '$current_pin';
  const newSha = '$latest_sha';
  const prevShort = prevSha.slice(0, 7);
  const newShort = newSha.slice(0, 7);
  const commitCount = $commit_count;
  const today = new Date().toISOString().slice(0, 10);

  // 1. Update UPSTREAM.json
  const upstreamPath = root + '/UPSTREAM.json';
  const upstreamData = JSON.parse(fs.readFileSync(upstreamPath, 'utf8'));
  upstreamData.commit = newSha;
  fs.writeFileSync(upstreamPath, JSON.stringify(upstreamData, null, 2) + '\n');

  // 2. Compute candidate version from RELEASES.md
  const releasesPath = root + '/RELEASES.md';
  let releases = fs.readFileSync(releasesPath, 'utf8');
  const candidateMatch = releases.match(/0\.1\.0-candidate\.(\d+)/);
  const nextNum = candidateMatch ? parseInt(candidateMatch[1], 10) + 1 : 1;
  const newCandidateVersion = '0.1.0-candidate.' + nextNum;

  // Prepend new candidate entry to RELEASES table
  const newRow = '| \`' + newCandidateVersion + '\` | \`' + newSha + '\` | candidate | Automated upstream sync (' + today + ', ' + commitCount + ' new commits). |';
  releases = releases.replace(
    /(| --- \| --- \| --- \| --- \|\n)/,
    '\$1' + newRow + '\n'
  );
  fs.writeFileSync(releasesPath, releases);

  // 3. Update README.md (badges, commit links, candidate version)
  const readmePath = root + '/README.md';
  let readme = fs.readFileSync(readmePath, 'utf8');
  readme = readme
    .replace(new RegExp('upstream-' + prevShort, 'g'), 'upstream-' + newShort)
    .replace(new RegExp(prevSha, 'g'), newSha)
    .replace(/Candidate \(\`0\.1\.0-candidate\.\d+\` in/, 'Candidate (\`' + newCandidateVersion + '\` in');
  fs.writeFileSync(readmePath, readme);
"

# Update submodule pointer
git -C "$submodule" checkout --quiet "$latest_sha"

cat <<EOF > "$root/sync-report.md"
### ✅ Upstream Sync Succeeded

- **Previous Pin**: \`${current_pin}\`
- **New Upstream SHA**: [\`${latest_sha}\`](https://github.com/cloudflare/cloudflare-os/commit/${latest_sha})
- **Commits Included**: ${commit_count}

#### Included Upstream Commits:
\`\`\`
${changelog}
\`\`\`

#### Test Evidence:
- Patch application: Clean (3-way merge)
- Lint & typecheck: Passed
- Unit & integration tests: Passed
EOF

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "has_update=true" >> "$GITHUB_OUTPUT"
  echo "sync_status=success" >> "$GITHUB_OUTPUT"
  echo "latest_sha=$latest_sha" >> "$GITHUB_OUTPUT"
  echo "commit_count=$commit_count" >> "$GITHUB_OUTPUT"
fi

echo "Upstream sync completed successfully for $latest_sha."
