#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

image_registry="ghcr.io"
image_org="app13pie"
image_name="margos"
default_tag="latest"

just build $image_name $default_tag
just ostree-rechunk $image_name $default_tag

alias_tags="$(just generate-build-tags)"
just tag-images $image_name $default_tag $alias_tags

while IFS=' ' read -r -d ' ' tag; do
  podman push --digestfile ./digestfile "${image_name}:${tag}" "${image_registry}/${image_org}/${image_name}:${tag}"
done <<< "$alias_tags "
digest=$(< ./digestfile)

export COSIGN_PASSWORD=""
cosign sign -y --new-bundle-format=false --use-signing-config=false --key ./cosign.key "${image_registry}/${image_org}/${image_name}@${digest}"
