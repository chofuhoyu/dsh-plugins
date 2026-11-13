#!/bin/sh
# Check every plugin submodule before regenerating the market index.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

if [ ! -f .gitmodules ]; then
  echo 'check-submodules: .gitmodules not found' >&2
  exit 1
fi

paths=$(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
if [ -z "$paths" ]; then
  echo 'check-submodules: no submodules registered' >&2
  exit 1
fi

fail=0
for path in $paths; do
  name=$(basename "$path")
  dir=$root/$path

  if [ ! -e "$dir/.git" ]; then
    echo "FAIL $name: submodule is not initialized (run git submodule update --init --recursive)" >&2
    fail=1
    continue
  fi

  if ! git -C "$dir" fetch --quiet origin; then
    echo "FAIL $name: cannot fetch origin" >&2
    fail=1
    continue
  fi

  dirty=$(git -C "$dir" status --porcelain)
  if [ -n "$dirty" ]; then
    echo "FAIL $name: uncommitted changes" >&2
    printf '%s\n' "$dirty" | sed 's/^/  /' | head -5 >&2
    fail=1
  fi

  branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  if [ -z "$branch" ]; then
    echo "FAIL $name: detached HEAD (check out the plugin's branch before continuing)" >&2
    fail=1
    continue
  fi

  upstream=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  if [ -z "$upstream" ]; then
    echo "FAIL $name: $branch has no upstream (set one with git push -u)" >&2
    fail=1
    continue
  fi

  ahead=$(git -C "$dir" rev-list --count "$upstream..HEAD")
  behind=$(git -C "$dir" rev-list --count "HEAD..$upstream")
  if [ "$ahead" -ne 0 ]; then
    echo "FAIL $name: $ahead unpushed commit(s) on $branch" >&2
    fail=1
  fi
  if [ "$behind" -ne 0 ]; then
    echo "WARN $name: $behind commit(s) behind $upstream" >&2
  fi

  version=$(node -e "const p=require(process.argv[1]); process.stdout.write(String(p.version ?? '?'))" "$dir/package.json" 2>/dev/null || echo '?')
  tags=$(git -C "$dir" tag --points-at HEAD | paste -sd, - 2>/dev/null || true)
  [ -n "$tags" ] || tags='no tag at HEAD'

  url=$(git config -f .gitmodules --get "submodule.$path.url" 2>/dev/null || true)
  repo=$(basename "${url:-$path}")
  repo=${repo%.git}
  if ! grep -Eq "^https?://[^[:space:]]*/${repo}(\.git)?/?$" "$root/plugins.txt"; then
    echo "FAIL $name: no HTTPS URL ending in /$repo in plugins.txt" >&2
    fail=1
  fi

  printf '%-28s %-10s %-18s %s\n' "$name" "$version" "$tags" "$(git -C "$dir" rev-parse --short HEAD)"
done

if [ "$fail" -ne 0 ]; then
  echo 'check-submodules: fix the failures above before running build-index.sh' >&2
  exit 1
fi

echo 'check-submodules: ok'
