# dsh-plugins

One [plugin market index](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-10-02-plugin-market-index-format.md)
for my DeepSeek Harness plugin bundles, so they can be browsed and installed from
**Plugins → Discover** instead of typing four Git specs.

## Use it

Add this URL in **Plugins → Discover → Add index source**:

```text
https://raw.githubusercontent.com/chofuhoyu/dsh-plugins/main/index.json
```

The index lists the packages in [`plugins.txt`](plugins.txt) at the exact versions
and commits the generator saw. Discover installs a listed version through the
normal plugin dialog, so the existing compatibility check, build-script approval,
and trust notice still apply.

## Regenerate

`index.json` is generated, never edited by hand. It needs a DeepSeek Harness
source checkout for the reference generator:

```sh
DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh
```

Commit the regenerated `index.json` (and `icons/`, when large icons are written
beside it) afterward. Release tags such as `v1.2.3` in a plugin repository give
that plugin more than the default-branch version in the index; without tags only
the current version of the default branch is listed.

The `.plugin-market-cache/` directory is a local read cache and is not published.

## Add a plugin

One line in `plugins.txt`: an npm package name or an https Git repository URL.
Then regenerate and commit.
