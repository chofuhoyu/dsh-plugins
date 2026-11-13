#!/bin/sh
# Regenerate index.json from plugins.txt with the DSH reference generator.
# The generator lives in the DeepSeek Harness source checkout, not in an npm package.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
dsh=${DSH_REPO:-/Users/ryohai/Code/deepseek-harness}

exec pnpm --dir "$dsh" --filter @deepseek-ai/dsh-plugin-market-generator start \
  --input "$root/plugins.txt" \
  --output "$root/index.json" \
  --title "ChofuhoYu DSH Plugins" \
  --description "Personal DeepSeek Harness plugin bundles by chofu, distributed through GitHub."
