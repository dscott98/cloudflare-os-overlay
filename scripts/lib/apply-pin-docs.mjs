#!/usr/bin/env node
/**
 * Update the overlay's release documents (UPSTREAM.json, RELEASES.md, README.md) after an
 * upstream pin bump. Extracted from scripts/sync-upstream.sh so the release-row insertion
 * and the README rewrite are unit-testable (scripts/lib/release-docs.test.mjs).
 */

import fs from 'node:fs';

/** Compute the next candidate version from the newest row of a RELEASES.md table. */
export function nextCandidateVersion(releases) {
  const candidateMatch = releases.match(/0\.1\.0-candidate\.(\d+)/);
  const nextNum = candidateMatch ? parseInt(candidateMatch[1], 10) + 1 : 1;
  return `0.1.0-candidate.${nextNum}`;
}

/**
 * Insert a new release-table row directly under the table's header separator line.
 *
 * The row must land after the `| --- | --- | --- | --- |` separator (as the newest entry),
 * never above the `# Overlay releases` heading. An earlier inline implementation anchored on
 * a regex whose first alternative was empty, so it matched at offset 0 and silently put the
 * row above the heading; release-docs.test.mjs keeps that failure from returning.
 */
export function insertReleaseRow(releases, newRow) {
  return releases.replace(
      /^(\| --- \| --- \| --- \| --- \|\n)/m,
      `$1${newRow}\n`,
  );
}

/** Rewrite a README's upstream pin references (badge text, full SHAs) and candidate version. */
export function updateReadmeForPin(readme, {prevSha, newSha, newCandidateVersion}) {
  const prevShort = prevSha.slice(0, 7);
  const newShort = newSha.slice(0, 7);
  return readme
      .replace(new RegExp(`upstream-${prevShort}`, 'g'), `upstream-${newShort}`)
      .replace(new RegExp(prevSha, 'g'), newSha)
      .replace(/Candidate \(`0\.1\.0-candidate\.\d+` in/, `Candidate (\`${newCandidateVersion}\` in`);
}

/** Apply a pin bump to UPSTREAM.json, RELEASES.md, and README.md under `root`. */
export function applyUpstreamPinToDocs({root, prevSha, newSha, commitCount}) {
  const today = new Date().toISOString().slice(0, 10);

  // 1. Update UPSTREAM.json.
  const upstreamPath = `${root}/UPSTREAM.json`;
  const upstreamData = JSON.parse(fs.readFileSync(upstreamPath, 'utf8'));
  upstreamData.commit = newSha;
  fs.writeFileSync(upstreamPath, JSON.stringify(upstreamData, null, 2) + '\n');

  // 2. Insert a new candidate row at the top of the RELEASES.md table.
  const releasesPath = `${root}/RELEASES.md`;
  let releases = fs.readFileSync(releasesPath, 'utf8');
  const newCandidateVersion = nextCandidateVersion(releases);
  const newRow = '| `' + newCandidateVersion + '` | `' + newSha + '` | candidate | Automated upstream sync ('
      + today + ', ' + commitCount + ' new commits). |';
  releases = insertReleaseRow(releases, newRow);
  fs.writeFileSync(releasesPath, releases);

  // 3. Update README.md (badges, commit links, candidate version).
  const readmePath = `${root}/README.md`;
  const readme = fs.readFileSync(readmePath, 'utf8');
  fs.writeFileSync(readmePath, updateReadmeForPin(readme, {prevSha, newSha, newCandidateVersion}));

  return {newCandidateVersion};
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i];
    if (!key.startsWith('--')) throw new Error(`Expected --flag, got "${key}"`);
    args[key.slice(2)] = argv[i + 1];
  }
  return args;
}

function main(argv) {
  const args = parseArgs(argv);
  const required = ['root', 'prev-sha', 'new-sha', 'commit-count'];
  for (const key of required) {
    if (!args[key]) throw new Error(`Missing required argument --${key}`);
  }
  const {newCandidateVersion} = applyUpstreamPinToDocs({
    root: args.root,
    prevSha: args['prev-sha'],
    newSha: args['new-sha'],
    commitCount: parseInt(args['commit-count'], 10),
  });
  process.stdout.write(`Updated release docs to ${newCandidateVersion}.\n`);
}

// Run as a CLI only when invoked directly (tests import the functions instead).
if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  main(process.argv.slice(2));
}
