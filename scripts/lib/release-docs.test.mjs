import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  applyUpstreamPinToDocs,
  insertReleaseRow,
  nextCandidateVersion,
  updateReadmeForPin,
} from './apply-pin-docs.mjs';

const PREV_SHA = 'af56a9d79d8a60ebed8dabb11b075cd88efc1b87';
const NEW_SHA = 'bdc5c85daf5e9c7fc80799c3fe042cd38e25add0';

const RELEASES = [
  '# Overlay releases',
  '',
  '| Overlay version | Upstream commit | Status | Notes |',
  '| --- | --- | --- | --- |',
  '| `0.1.0-candidate.7` | `' + PREV_SHA + '` | candidate | Some notes. |',
  '',
  'A production entry requires a published bundle checksum.',
  '',
].join('\n');

const README = [
  '[![Upstream Pin](https://img.shields.io/badge/upstream-af56a9d-orange)](https://github.com/cloudflare/cloudflare-os/tree/' + PREV_SHA + ')',
  '',
  '- **Upstream commit**: [`' + PREV_SHA + '`](UPSTREAM.json)',
  '- **Status**: Candidate (`0.1.0-candidate.7` in [RELEASES.md](RELEASES.md))',
  '',
  'git checkout ' + PREV_SHA,
  '',
].join('\n');

test('insertReleaseRow places the new row directly under the table header separator', () => {
  const out = insertReleaseRow(RELEASES, '| `NEW` | `SHA` | candidate | row |');
  const lines = out.split('\n');
  // Regression guard: the old implementation inserted above the heading.
  assert.equal(lines[0], '# Overlay releases', 'heading must remain the first line');
  assert.equal(lines[3], '| --- | --- | --- | --- |');
  assert.equal(lines[4], '| `NEW` | `SHA` | candidate | row |');
  assert.ok(lines[5].includes('0.1.0-candidate.7'), 'existing rows stay below the new row');
});

test('insertReleaseRow leaves a table without separator unchanged', () => {
  const malformed = '# Overlay releases\n\nno table here\n';
  assert.equal(insertReleaseRow(malformed, '| r |'), malformed);
});

test('nextCandidateVersion increments the newest candidate number', () => {
  assert.equal(nextCandidateVersion(RELEASES), '0.1.0-candidate.8');
  assert.equal(nextCandidateVersion('# no candidates yet\n'), '0.1.0-candidate.1');
});

test('updateReadmeForPin rewrites short and full SHAs and the candidate version', () => {
  const out = updateReadmeForPin(README, {prevSha: PREV_SHA, newSha: NEW_SHA, newCandidateVersion: '0.1.0-candidate.8'});
  assert.ok(out.includes('upstream-bdc5c85-orange'), 'badge short SHA updated');
  assert.ok(!out.includes('af56a9d'), 'no stale short or full SHA remains');
  assert.ok(out.includes(NEW_SHA), 'full SHA updated');
  assert.ok(out.includes('`0.1.0-candidate.8` in'), 'candidate version updated');
});

test('applyUpstreamPinToDocs updates UPSTREAM.json, RELEASES.md, and README.md together', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'overlay-pin-docs-'));
  try {
    fs.writeFileSync(path.join(dir, 'UPSTREAM.json'), JSON.stringify({repository: 'https://example.com/up.git', commit: PREV_SHA}) + '\n');
    fs.writeFileSync(path.join(dir, 'RELEASES.md'), RELEASES);
    fs.writeFileSync(path.join(dir, 'README.md'), README);

    const result = applyUpstreamPinToDocs({root: dir, prevSha: PREV_SHA, newSha: NEW_SHA, commitCount: 69});

    assert.equal(result.newCandidateVersion, '0.1.0-candidate.8');
    assert.equal(JSON.parse(fs.readFileSync(path.join(dir, 'UPSTREAM.json'), 'utf8')).commit, NEW_SHA);

    const releases = fs.readFileSync(path.join(dir, 'RELEASES.md'), 'utf8').split('\n');
    assert.equal(releases[0], '# Overlay releases', 'heading still first');
    assert.ok(releases[4].includes('`0.1.0-candidate.8`'), 'new row directly under the separator');
    assert.ok(releases[4].includes(NEW_SHA));

    const readme = fs.readFileSync(path.join(dir, 'README.md'), 'utf8');
    assert.ok(readme.includes(NEW_SHA) && !readme.includes(PREV_SHA));
    assert.ok(readme.includes('`0.1.0-candidate.8` in'));
  } finally {
    fs.rmSync(dir, {recursive: true, force: true});
  }
});
