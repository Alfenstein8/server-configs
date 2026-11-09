#!/usr/bin/env bash
# Move every pinned container image in this repo to its newest tag of the same
# shape, editing the .nix files in place. Prints one markdown line per image.
#
#   bump-images.sh [name ...]     # names as the image's last path part, e.g. radarr
#
# "Same shape" means the tag with every digit run treated as a number:
# 6.4.4.10685-ls324 only moves to N.N.N.N-lsN tags, never to develop-* or
# 7.0.0-beta.1. Tags with no dot (latest, pr-3109) are not versions and stay.
# Run from the repo root.
set -euo pipefail

if command -v skopeo >/dev/null; then
  skopeo=skopeo
else
  skopeo="$(nix --extra-experimental-features 'nix-command flakes' build "nixpkgs#skopeo^out" --no-link --print-out-paths)/bin/skopeo"
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

grep -rnoE --include='*.nix' 'image = "[^"]+"' . | sort | while IFS= read -r hit; do
  file=${hit%%:*}
  file=${file#./}
  ref=${hit#*image = \"}
  ref=${ref%\"}

  name=$ref tag=""
  if [[ ${ref##*/} == *:* ]]; then
    name=${ref%:*}
    tag=${ref##*:}
  fi
  short=${name##*/}
  [ $# -eq 0 ] || [[ " $* " == *" $short "* ]] || continue

  full=$name
  [[ ${name%%/*} == *.* ]] || full="docker.io/$name"
  [[ $full != docker.io/* || $full == docker.io/*/* ]] || full="docker.io/library/${full#docker.io/}"

  if [ -z "$tag" ] || [[ $tag != *.* ]]; then
    echo "- $short ($file): \`$ref\` -- skipped, ${tag:-no tag}: not a version tag"
    continue
  fi

  shape=$(sed -E 's/[.]/\\./g; s/[0-9]+/[0-9]+/g' <<<"$tag")
  # Anonymous: every image here is public, and a stale login in
  # ~/.docker/config.json gets ghcr.io (and lscr.io, which is ghcr) refused.
  if ! tags=$($skopeo list-tags --no-creds "docker://$full" 2>&1); then
    echo "- $short ($file): \`$ref\` -- could not list tags: $(head -c 200 <<<"$tags")"
    continue
  fi
  newest=$(jq -r '.Tags[]' <<<"$tags" | grep -E "^$shape\$" | sort -V | tail -n1)

  if [ -z "$newest" ] || [ "$newest" = "$tag" ] ||
    [ "$(printf '%s\n' "$tag" "$newest" | sort -V | tail -n1)" = "$tag" ]; then
    echo "- $short ($file): $tag, newest"
    continue
  fi
  sed -i "s|image = \"${ref//./\\.}\"|image = \"$name:$newest\"|" "$file"
  echo "- **$short** ($file): $tag -> $newest  $(releases "$full")"
done
