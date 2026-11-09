#!/usr/bin/env bash
# Move every enabled container image to its newest tag of the same shape,
# editing the .nix files in place. Prints one markdown line per image.
#
#   bump-images.sh [container ...]    # names as in oci-containers.containers
#
# The list of images comes from the evaluated config, so a module commented
# out of configuration.nix is left alone and a new one is picked up as soon as
# it is imported. Each image is then edited where it is written as a string
# literal, `image = "repo:tag";`. One built from variables, or from another
# file, is reported for bumping by hand.
#
# "Same shape" means the tag with every digit run treated as a number:
# 6.4.4.10685-ls324 only moves to N.N.N.N-lsN tags, never to develop-* or
# 7.0.0-beta.1. Tags with no dot (latest, pr-3109) are not versions, and a
# digest (@sha256:...) is a deliberate pin; both stay. Run from the repo root.
set -euo pipefail

nix() { command nix --extra-experimental-features 'nix-command flakes' "$@"; }

if command -v skopeo >/dev/null; then
  skopeo=skopeo
else
  skopeo="$(nix build "nixpkgs#skopeo^out" --no-link --print-out-paths)/bin/skopeo"
fi

releases() { # where the image's changelog lives, as best guessed
  case $1 in
    lscr.io/linuxserver/*) echo "https://github.com/linuxserver/docker-${1##*/}/releases" ;;
    ghcr.io/*) echo "https://github.com/${1#ghcr.io/}/releases" ;;
    docker.io/library/*) echo "https://hub.docker.com/_/${1##*/}" ;;
    docker.io/*) echo "https://hub.docker.com/r/${1#docker.io/}" ;;
    *) echo "(find the changelog)" ;;
  esac
}

# shellcheck disable=SC2001 # a character class, not one substitution
ere() { sed 's/[][\.*^$+?(){}|]/\\&/g' <<<"$1"; } # escape for grep -E / sed -E

# image -> the containers using it, one image per line: "<image> <name>,<name>".
# tryEval: a container can exist with no image -- prometheus.nix sets options
# on every name in splitCgroupContainers, so one whose module is commented out
# but still listed there has none. The build's assertion catches that; here it
# is just not an image.
images=$(nix eval --json .#nixosConfigurations.homeserver.config.virtualisation.oci-containers.containers \
  --apply 'cs: builtins.mapAttrs (_: c: (builtins.tryEval c.image).value) cs' |
  jq -r --args '$ARGS.positional as $only
    | to_entries | map(select(.value != false))
    | map(select(($only | length) == 0 or (.key | IN($only[]))))
    | group_by(.value)[] | "\(.[0].value) \(map(.key) | join(","))"' "$@")

while read -r ref names; do
  [ -n "$ref" ] || continue
  if [[ $ref == *@* ]]; then
    echo "- $names: \`$ref\` -- pinned by digest, left alone"
    continue
  fi

  name=$ref tag=""
  if [[ ${ref##*/} == *:* ]]; then
    name=${ref%:*}
    tag=${ref##*:}
  fi
  if [ -z "$tag" ] || [[ $tag != *.* ]]; then
    echo "- $names: \`$ref\` -- ${tag:-no tag}: not a version tag, left alone"
    continue
  fi

  literal="(image[[:space:]]*=[[:space:]]*\")$(ere "$ref")\""
  files=$(grep -rlE --include='*.nix' "$literal" . | sed 's|^\./||' | sort) || true
  if [ -z "$files" ]; then
    echo "- **$names**: \`$ref\` -- not written as \`image = \"$ref\"\` in any file; bump it by hand"
    continue
  fi
  where=$(paste -sd, <<<"$files")

  full=$name
  [[ ${name%%/*} == *.* ]] || full="docker.io/$name"
  [[ $full != docker.io/* || $full == docker.io/*/* ]] || full="docker.io/library/${full#docker.io/}"

  shape=$(sed -E 's/[.]/\\./g; s/[0-9]+/[0-9]+/g' <<<"$tag")
  # Anonymous: every image here is public, and a stale login in
  # ~/.docker/config.json gets ghcr.io (and lscr.io, which is ghcr) refused.
  if ! tags=$($skopeo list-tags --no-creds "docker://$full" 2>&1); then
    echo "- $names ($where): \`$ref\` -- could not list tags: $(head -c 200 <<<"$tags")"
    continue
  fi
  newest=$(jq -r '.Tags[]' <<<"$tags" | grep -E "^$shape\$" | sort -V | tail -n1) || true

  if [ -z "$newest" ] || [ "$newest" = "$tag" ] ||
    [ "$(printf '%s\n' "$tag" "$newest" | sort -V | tail -n1)" = "$tag" ]; then
    echo "- $names ($where): $tag, newest"
    continue
  fi
  while read -r f; do
    sed -i -E "s|$literal|\\1$name:$newest\"|" "$f"
  done <<<"$files"
  echo "- **$names** ($where): $tag -> $newest  $(releases "$full")"
done <<<"$images"
