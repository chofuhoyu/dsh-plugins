#!/bin/sh
# Regenerate index.json from plugins.txt with the DSH reference generator.
# The generator lives in the DeepSeek Harness source checkout, not in an npm package.
# Push plugin commits and tags before running this: the generator reads remotes.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
dsh=${DSH_REPO:-/Users/ryohai/Code/deepseek-harness}

# The index sources are the plugin repositories themselves. Listing this superproject
# would produce no packages because the generator cannot read submodule contents.
market_url=$(git -C "$root" remote get-url origin 2>/dev/null \
  | sed -e 's#^git@github.com:#https://github.com/#' -e 's#\.git$##' || true)
if [ -n "$market_url" ] && grep -Fqx "$market_url" "$root/plugins.txt"; then
  echo "build-index: plugins.txt lists this superproject; list the plugin repositories instead" >&2
  exit 2
fi

exec pnpm --dir "$dsh" --filter @deepseek-ai/dsh-plugin-market-generator start \
  --input "$root/plugins.txt" \
  --output "$root/index.json" \
  --title "ChofuhoYu DSH Plugins" \
  --description "Personal DeepSeek Harness plugin bundles by chofu, distributed through GitHub."
