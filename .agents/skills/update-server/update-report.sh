#!/usr/bin/env bash
# Update the flake and report what changed, for the update-server skill.
#
#   update-report.sh [--no-build] [--no-containers] [input ...]
#
# Run from the repo root, with no uncommitted changes. Inputs default to all of
# them (`nix flake update`). Also bumps the pinned container images
# (bump-images.sh). Builds the system before and after, so the first run
# downloads a lot. Leaves flake.lock and the bumped image tags uncommitted;
# everything else goes in a report directory, printed at the end:
#   inputs.md         each input that moved: old -> new rev, dates, compare URL
#   containers.md     each pinned image: old -> new tag and where its changelog is
#   closure.txt       nix store diff-closures old new: every version change
#   warnings.txt      evaluation warnings the new build has and the old didn't
#   release-notes.diff  lines added to NixOS's release notes between the revs
#   build-old.log, build-new.log
set -euo pipefail

build=1 containers=1
while [ $# -gt 0 ]; do
  case $1 in
    --no-build) build=0 ;;
    --no-containers) containers=0 ;;
    *) break ;;
  esac
  shift
done
here=$(dirname "$(readlink -f "$0")")

nix() { command nix --extra-experimental-features 'nix-command flakes' "$@"; }

[ -f flake.lock ] || { echo "run from the repo root" >&2; exit 2; }
# Clean, so what this run changed is exactly `git diff` afterwards.
if ! git diff --quiet HEAD; then
  echo "uncommitted changes; commit or stash them first" >&2
  exit 2
fi

host=homeserver
cfg=".#nixosConfigurations.$host.config"
out=$(mktemp -d "${TMPDIR:-/tmp}/update-server.XXXXXX")
cp flake.lock "$out/old.lock"

# Warnings as printed by nix, one per line, deduplicated.
warnings() { grep -E 'evaluation warning|trace: warning|^warning:' "$1" | sed 's/\x1b\[[0-9;]*m//g' | sort -u; }

build_system() { # build_system <old|new>
  echo "building the $1 system..." >&2
  if nix build "$cfg.system.build.toplevel" --out-link "$out/$1" -L 2>"$out/build-$1.log"; then
    return 0
  fi
  echo "the $1 system failed to build; tail of $out/build-$1.log:" >&2
  tail -n 30 "$out/build-$1.log" >&2
  return 1
}

old_release=$(nix eval --raw "$cfg.system.nixos.release" 2>>"$out/eval.log")
if [ $build = 1 ]; then
  build_system old || { echo "fix the current system first; flake.lock untouched" >&2; exit 1; }
fi

echo "updating flake.lock..." >&2
nix flake update "$@" 2>&1 | sed 's/^/  /' >&2
cp flake.lock "$out/new.lock"

if [ $containers = 1 ]; then
  echo "bumping container images..." >&2
  "$here/bump-images.sh" >"$out/containers.md"
else
  echo "(skipped: --no-containers)" >"$out/containers.md"
fi

# --- inputs.md ----------------------------------------------------------------
jq -rn --slurpfile o "$out/old.lock" --slurpfile n "$out/new.lock" '
  def node($l; $name): $l.nodes[$l.nodes[$l.root].inputs[$name]];
  def day: if . then todate[0:10] else "?" end;
  def url($l; $a; $b):
    if $l.type == "github" then "https://github.com/\($l.owner)/\($l.repo)/compare/\($a)...\($b)"
    elif $l.type == "git" then "\($l.url | sub("\\.git$"; ""))/compare/\($a)...\($b)"
    else "(\($l.type): no compare link)" end;
  ($n[0].nodes[$n[0].root].inputs | keys[]) as $name
  | (node($o[0]; $name).locked // {}) as $a
  | (node($n[0]; $name).locked) as $b
  | select($b and $a.rev != $b.rev)
  | "- **\($name)**: \($a.rev // "new" | .[0:10]) (\($a.lastModified | day)) -> \($b.rev[0:10]) (\($b.lastModified | day))\n  \(url($b; $a.rev; $b.rev))"
' >"$out/inputs.md"
[ -s "$out/inputs.md" ] || echo "(no input moved)" >"$out/inputs.md"

# --- release-notes.diff -------------------------------------------------------
# The root's nixpkgs, which need not be the node called "nixpkgs".
nixpkgs_rev() { jq -r '.nodes[.nodes[.root].inputs.nixpkgs].locked.rev' "$1"; }
old_rev=$(nixpkgs_rev "$out/old.lock")
new_rev=$(nixpkgs_rev "$out/new.lock")
new_release=$(nix eval --raw "$cfg.system.nixos.release" 2>>"$out/eval.log")
: >"$out/release-notes.diff"
if [ "$old_rev" != "$new_rev" ]; then
  for rel in $(printf '%s\n' "$old_release" "$new_release" | sort -u); do
    f="nixos/doc/manual/release-notes/rl-${rel/./}.section.md"
    for side in old new; do
      rev=$old_rev; [ $side = new ] && rev=$new_rev
      curl -fsS "https://raw.githubusercontent.com/NixOS/nixpkgs/$rev/$f" >"$out/rl-$rel-$side.md" 2>/dev/null || : >"$out/rl-$rel-$side.md"
    done
    diff -u --label "$f@${old_rev:0:10}" --label "$f@${new_rev:0:10}" \
      "$out/rl-$rel-old.md" "$out/rl-$rel-new.md" >>"$out/release-notes.diff" || true
  done
fi
[ -s "$out/release-notes.diff" ] || echo "(no change to the NixOS release notes)" >"$out/release-notes.diff"

# --- build, closure.txt, warnings.txt -----------------------------------------
status=ok
if [ $build = 1 ]; then
  if build_system new; then
    nix store diff-closures "$out/old" "$out/new" >"$out/closure.txt"
  else
    status="NEW SYSTEM FAILED TO BUILD (see build-new.log)"
    echo "(new system did not build)" >"$out/closure.txt"
  fi
  comm -13 <(warnings "$out/build-old.log") <(warnings "$out/build-new.log") >"$out/warnings.txt" || true
  [ -s "$out/warnings.txt" ] || echo "(no new evaluation warnings)" >"$out/warnings.txt"
else
  status="skipped (--no-build)"
  echo "(skipped: --no-build)" | tee "$out/closure.txt" >"$out/warnings.txt"
fi

count() { grep -v '^(' "$2" | grep -cE "$1" || true; }

cat <<EOF
NixOS $old_release -> $new_release, build: $status
report: $out
  inputs.md           $(count '^- ' "$out/inputs.md") inputs moved
  containers.md       $(count ' -> ' "$out/containers.md") images bumped
  closure.txt         $(count ':' "$out/closure.txt") packages changed
  warnings.txt        $(count . "$out/warnings.txt") new warnings
  release-notes.diff  $(count '^\+[^+]' "$out/release-notes.diff") lines added
EOF
