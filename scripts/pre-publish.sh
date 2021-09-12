#!/bin/bash

set -euo pipefail

GITHUB_SHA=${GITHUB_SHA:=$(git rev-parse HEAD)}

sed -i 's;^\(\s*\)base-path:.*;\1base-path: "https://blog.rogryza.me";g' config.yml
sed -i 's;^\(\s*\)git-ref:.*;\1git-ref: "'"$GITHUB_SHA"'";g' config.yml

if [ ! -f wrangler.toml ]; then
  sed 's;^account_id\s*=.*;account_id = "'"$WRANGLER_ACCOUNT_ID"'";g' \
    wrangler.example.toml > wrangler.toml
  sed -i 's;^zone_id\s*= .*;zone_id = "'"$WRANGLER_ZONE_ID"'";g' wrangler.toml
fi
