# dsh-plugins

One [plugin market index](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-10-02-plugin-market-index-format.md)
for my DeepSeek Harness plugin bundles, and the superproject that keeps their
repositories together for development.

Each plugin still lives in its own GitHub repository. This repository adds those
repositories as Git submodules under `plugins/`, so one clone gives you the index and
all plugin code in one workspace. The market installs from each plugin repository,
never from this superproject.

## Use the index

Add this URL in **Plugins → Discover → Add index source**:

```text
https://raw.githubusercontent.com/chofuhoyu/dsh-plugins/main/index.json
```

The index lists the packages in [`plugins.txt`](plugins.txt) at the exact versions and
commits the generator saw. Discover installs a listed version through the normal plugin
dialog, so the existing compatibility check, build-script approval, and trust notice
still apply.

## Layout

```text
dsh-plugins/
├── index.json                  generated market index
├── plugins.txt                 one HTTPS URL per plugin repository
├── scripts/
│   ├── add-plugin.sh           add a new plugin repository as a submodule
│   ├── build-index.sh          regenerate index.json
│   └── check-submodules.sh     preflight before regenerating the index
├── plugins/
│   ├── dsh-always-auto/        submodule
│   ├── dsh-bark-reminder/      submodule
│   ├── dsh-cua-switch/         submodule
│   └── dsh-review-relay/       submodule
└── AGENTS.md                   development and release rules
```

The submodule URLs are relative (`../dsh-*.git`), so an SSH clone keeps using SSH and an
HTTPS clone works without SSH keys.

## Develop

Clone with submodules:

```sh
git clone --recurse-submodules git@github.com:chofuhoyu/dsh-plugins.git
cd dsh-plugins
```

For an existing clone:

```sh
git submodule update --init --recursive
```

Work inside one plugin repository:

```sh
cd plugins/dsh-bark-reminder
git switch main
# edit, run that plugin's checks
git add <changed files>
git diff --staged
git commit -m "[fix] ..."
git push origin main
```

Then refresh the index from the superproject:

```sh
cd ../..
./scripts/check-submodules.sh
DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh
git add plugins/dsh-bark-reminder index.json
git commit -m "[meta] Refresh the dsh-bark-reminder pin and the index"
git push
```

The parent commit records the submodule pointer and the regenerated index; plugin code
is committed inside the plugin repository.

## Release a plugin

Inside the plugin repository, bump `package.json`, commit it, create the annotated tag
on that commit, and push both the branch and the tag:

```sh
git add package.json
git commit -m "[release] Bump dsh-bark-reminder to 0.1.6"
git tag -a v0.1.6 -m v0.1.6
git push origin main v0.1.6
```

Then run `./scripts/check-submodules.sh` and `./scripts/build-index.sh` in the
superproject, and commit the plugin pointer together with `index.json`.

Tags are the published versions. Do not move or delete them; publish a new version
instead.

## Add a plugin

A new plugin is always a new standalone repository, never a normal directory in this
repository.

```sh
./scripts/add-plugin.sh ../dsh-new-plugin.git
```

The script adds `plugins/dsh-new-plugin` as a submodule, appends the repository's HTTPS
URL to `plugins.txt`, and verifies that the package declares `dsh.bundle`. It does not
commit. After the plugin has a pushed release tag:

```sh
./scripts/check-submodules.sh
DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh
git add .gitmodules plugins/dsh-new-plugin plugins.txt index.json
git commit -m "[meta] Add dsh-new-plugin to the market"
git push
```

## Regenerate the index

`index.json` is generated, never edited by hand. It needs a DeepSeek Harness source
checkout for the reference generator:

```sh
DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh
```

Commit the regenerated `index.json` (and `icons/`, when large icons are written beside
it) afterward. Release tags such as `v1.2.3` in a plugin repository give that plugin more
than the default-branch version in the index; without tags only the current version of
the default branch is listed.

The generator reads remote default branches and tags, so push plugin commits and tags
before regenerating. The `.plugin-market-cache/` directory is a local read cache and is
not published.

## Scripts

| Script | Use |
|---|---|
| `scripts/add-plugin.sh <git-url> [name]` | Add a standalone plugin repository as a submodule and to `plugins.txt`. |
| `scripts/check-submodules.sh` | Check that every submodule is clean, pushed, on a branch, and listed in `plugins.txt`. |
| `scripts/build-index.sh` | Regenerate `index.json` from `plugins.txt` with the DSH reference generator. |

See [`AGENTS.md`](AGENTS.md) for the full workflow, commit conventions, and submodule
boundaries.
