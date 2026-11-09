---
name: update-server
description: Update the homeserver's flake inputs (nixpkgs and the rest) and its pinned Podman images, then read the changelogs of what moved and report anything to watch out for before deploying.
disable-model-invocation: true
---

# Update the server

You update `flake.lock` and the pinned container images here, on the
workstation, and hand back a **verdict**: is this update safe to deploy, and
what must Alfred do around it? The server pulls and switches later; you never
deploy.

## 1. Update and build

From the repo root, on a clean `main` (or a branch made for the update):

```sh
.agents/skills/update-server/update-report.sh            # all inputs
.agents/skills/update-server/update-report.sh nixpkgs    # just some
```

It builds the current system, runs `nix flake update`, moves every pinned
`image = "…:tag"` to its newest tag of the same shape (`bump-images.sh`), builds
again and writes a report directory (path printed last; the header of
`update-report.sh` says what each file holds). The first run downloads a lot; give it up to an hour. Done when it
prints the report path.

If the **new** system fails to build, that failure is the first finding: read
`build-new.log`, find the cause (usually a removed or renamed option, or a
package dropped from nixpkgs) and report it with the fix. Carry on with the
other steps for what you can still see.

## 2. Triage what moved

Read every file in the report. Sort each change into one of these buckets:

- **Deployed service, major or minor bump** — a package behind something in the
  `imports` of `configuration.nix` or `services/default.nix` (Immich, Forgejo,
  Grafana, Jellyfin, Paperless, Home Assistant, PostgreSQL, Authelia, ...).
  These get a changelog read.
- **Release-notes entries** — every added line in `release-notes.diff` that
  touches a module this repo uses (grep the repo for the option or service
  name). Backward-incompatible sections first.
- **Container images** (`containers.md`) — an image whose app version moved
  goes in the first bucket. linuxserver tags are
  `<upstream version>-ls<build>`: when only the `-ls` number moved it is an
  image rebuild (base packages), one line, no reading. Images listed as skipped (no tag,
  `latest`, `pr-3109`) are not pinned to a version: mention them, and check that
  a bumped app still works with its unpinned companion (tubearchivist with
  `tubearchivist-es` and `redis`).
- **Everything else** — libraries, patch bumps, unused packages. One line in the
  report as a count; no reading.

Non-nixpkgs inputs (`inputs.md`): open the compare link and skim the commits for
anything that touches what this repo uses. `nixpkgs-legacy1` is pinned and never
moves; `hyggr` deploys its own app, so only changes to its NixOS module matter
(options `services/hyggr.nix` sets).

## 3. Read the changelogs

For every package and image in the first bucket, read the upstream release
notes for **every** version between old and new (GitHub releases,
`CHANGELOG.md`, the project's blog; for a linuxserver image, the upstream app's
releases, not only `docker-<app>`). Look for:

- breaking changes, removed config keys, changed defaults;
- **one-way migrations**: database schema upgrades, data format changes, anything
  where rolling back the NixOS generation would not roll the data back;
- required manual steps (reindex, re-login, re-pair clients);
- PostgreSQL or another database changing **major** version: NixOS does not
  migrate the data for you.

Cross-check each hit against this repo's config: a removed option only matters
if it is set here. Also go through `warnings.txt`: each new warning names an
option or package to change in a file here.

Done when every package in the first bucket has a changelog verdict, even if
that verdict is "nothing relevant".

## 4. Report

Reply with:

1. **Verdict**: deploy / deploy with the steps below / hold — one line why.
2. **Before or after switching**: numbered manual steps (backups to take,
   migrations to run, settings to change), each with the version that demands it
   and a link to the changelog entry.
3. **Config to change**: each warning or removed option, with the file and the
   fix.
4. **What moved**: inputs with their dates; images with old -> new tags;
   notable version bumps (old -> new); a count of the rest.

Leave `flake.lock` and the image tags modified and uncommitted. To hold back
one image, revert its line (`git diff` shows each bump). Offer to make the config fixes
and commit the update on a branch; do it only when asked.
