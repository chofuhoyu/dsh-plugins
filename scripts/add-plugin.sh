#!/bin/sh
# Add a standalone plugin repository as a submodule and to the market source list.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

usage() {
  echo "usage: $0 <git-url> [name]" >&2
  exit 2
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
url=$1
[ -n "$url" ] || usage

name=${2:-}
if [ -z "$name" ]; then
  name=$(basename "$url")
  name=${name%.git}
fi

case "$name" in
  ''|*[!a-zA-Z0-9._-]*)
    echo "add-plugin: invalid submodule name: $name" >&2
    exit 2
    ;;
esac

if [ -e "plugins/$name" ]; then
  echo "add-plugin: plugins/$name already exists" >&2
  exit 1
fi

https_url=$url
case "$url" in
  ../*)
    repo=${url#../}
    repo=${repo%.git}
    origin=$(git remote get-url origin 2>/dev/null || true)
    owner=$(printf '%s\n' "$origin" | sed -E 's#.*[:/]([^/]+)/[^/]+$#\1#')
    if [ -z "$owner" ] || [ "$owner" = "$origin" ]; then
      echo "add-plugin: cannot derive the GitHub owner from origin; pass an HTTPS URL" >&2
      exit 1
    fi
    https_url=$(printf 'https://github.com/%s/%s' "$owner" "$repo")
    ;;
  git@github.com:*)
    repo=${url#git@github.com:}
    repo=${repo%.git}
    https_url=$(printf 'https://github.com/%s' "$repo")
    ;;
  ssh://git@github.com/*)
    repo=${url#ssh://git@github.com/}
    repo=${repo%.git}
    https_url=$(printf 'https://github.com/%s' "$repo")
    ;;
  https://*)
    https_url=${url%.git}
    ;;
esac

case "$https_url" in
  https://*) ;;
  *)
    echo "add-plugin: plugins.txt needs an HTTPS URL, got: $https_url" >&2
    exit 1
    ;;
esac

if grep -Fqx "$https_url" plugins.txt; then
  echo "add-plugin: $https_url is already in plugins.txt" >&2
  exit 1
fi

git submodule add -b "${PLUGIN_BRANCH:-main}" "$url" "plugins/$name"

if ! node -e "const p=require(process.argv[1]); const b=p.dsh&&p.dsh.bundle; if (!b || !(typeof b.patch === 'string' || (Array.isArray(b.patch) && b.patch.length > 0))) process.exit(1)" "$root/plugins/$name/package.json"; then
  echo "add-plugin: plugins/$name/package.json does not declare dsh.bundle" >&2
  echo "add-plugin: fix the package or remove the submodule before continuing" >&2
  exit 1
fi

if [ -s plugins.txt ] && [ "$(tail -c 1 plugins.txt | wc -l | tr -d ' ')" -eq 0 ]; then
  printf '\n' >> plugins.txt
fi
printf '%s\n' "$https_url" >> plugins.txt

printf 'Added %s as plugins/%s\n' "$url" "$name"
printf 'Added %s to plugins.txt\n\n' "$https_url"
printf 'Next:\n'
printf '  1. cd plugins/%s; finish and tag the release; push main and the tag\n' "$name"
printf '  2. ./scripts/check-submodules.sh\n'
printf '  3. DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh\n'
printf '  4. git add .gitmodules plugins/%s plugins.txt index.json\n' "$name"
printf '     git commit -m "[meta] Add %s to the plugin market"\n' "$name"
