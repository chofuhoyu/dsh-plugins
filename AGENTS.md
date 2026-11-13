# AGENTS.md — dsh-plugins

本仓库是 DSH 插件市场的索引仓库，同时是各插件仓库的开发 superproject。
每个插件仍然是独立的 Git 仓库，以 git submodule 的形式挂在 `plugins/<name>`。
本仓库不存放插件源码；新插件也不允许直接建成 `plugins/<name>` 的普通目录。

## 目录与职责

| 路径 | 作用 |
|---|---|
| `index.json` | 插件市场索引，由脚本生成，不手工编辑。 |
| `plugins.txt` | 索引的源列表，每行一个插件仓库的 HTTPS URL；永远不写本仓库的 URL。 |
| `scripts/build-index.sh` | 用 DSH 的参考生成器重新生成 `index.json`。 |
| `scripts/check-submodules.sh` | 生成索引前的检查：子模块是否干净、是否已推送、是否都列在 `plugins.txt`。 |
| `scripts/add-plugin.sh` | 把一个新的独立插件仓库加入为 submodule，并写入 `plugins.txt`。 |
| `plugins/<name>/` | 插件仓库，代码、测试、tag、README 都在这里。 |

索引安装的是每个插件仓库，不是本 superproject；`index.json` 里的 `source.url` 指向
`plugins.txt` 中的插件仓库，`source.path` 为空。本仓库的 submodule 只服务于开发工作区。

## 准备开发环境

新 clone：

```sh
git clone --recurse-submodules git@github.com:chofuhoyu/dsh-plugins.git
cd dsh-plugins
./scripts/check-submodules.sh
```

已有的 clone：

```sh
git submodule update --init --recursive
```

父仓库可以用相对 URL 解析子模块地址：SSH clone 会继续用 SSH，HTTPS clone 会继续用 HTTPS。

## 日常开发一个插件

```sh
cd plugins/dsh-bark-reminder
git switch main

# 修改代码，运行该插件自己的检查
node scripts/check-client.mjs
node scripts/smoke.mjs

git add <改动的文件>
git diff --staged
git commit -m "[fix] ..."
git push origin main
```

然后回到父仓库，让索引跟上子模块的新提交：

```sh
cd ../..
./scripts/check-submodules.sh
DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh

git add plugins/dsh-bark-reminder index.json
git diff --staged
git commit -m "[meta] Refresh the dsh-bark-reminder pin and the index"
git push
```

父仓库的提交只记录子模块的 gitlink 和生成的索引。插件代码始终在子模块仓库里提交。

## 发布一个插件

1. 在子模块里修改 `package.json` 的 `version`；有 CHANGELOG 的仓库同步更新。
2. 提交版本变更，主题用 `[release] Bump <name> to <version>`。
3. 在该提交上创建附注 tag `v<version>`，并推送分支和 tag：

   ```sh
   git tag -a v0.1.6 -m v0.1.6
   git push origin main v0.1.6
   ```

4. 确认 tag 指向声明该版本的提交，且 `package.json` 的版本与 tag 一致。
5. 回到父仓库，运行 `./scripts/check-submodules.sh`，再运行 `./scripts/build-index.sh`。
6. 把子模块 gitlink 和 `index.json` 放在同一个父仓库提交里：

   ```sh
   git add plugins/dsh-bark-reminder index.json
   git commit -m "[meta] Pin dsh-bark-reminder 0.1.6 and refresh the index"
   git push
   ```

已发布的 tag 永不移动、永不删除；版本写错就发新版本。市场索引按 tag 和默认分支的当前版本
枚举，没有 tag 的旧版本会在下一次发版后从索引里消失。

同一个会话里发布多个插件时，分别在各自子模块里提交、打 tag、推送，最后统一生成一次索引，
把全部 gitlink 和 `index.json` 放进一个父仓库提交。

## 新增一个插件

新插件必须是独立仓库，而不是本仓库里的普通目录。

1. 在 GitHub 新建一个独立仓库，放 `package.json`、`cordis.patch.yml`、README、图标、
   locale 和测试；`package.json` 必须声明 `dsh.bundle`。
2. 在该仓库发布第一个版本并推送 `v<version>` tag。
3. 回到本仓库，添加 submodule 和索引源：

   ```sh
   ./scripts/add-plugin.sh ../dsh-new-plugin.git
   ```

   脚本会：
   - 在 `plugins/dsh-new-plugin` 添加 submodule；
   - 把该仓库的 HTTPS URL 追加到 `plugins.txt`；
   - 检查它确实是一个 `dsh.bundle` 包；
   - 不自动提交。

4. 检查并生成索引：

   ```sh
   ./scripts/check-submodules.sh
   DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh
   ```

5. 提交父仓库：

   ```sh
   git add .gitmodules plugins/dsh-new-plugin plugins.txt index.json
   git diff --staged
   git commit -m "[meta] Add dsh-new-plugin to the market"
   git push
   ```

如果新仓库不在同一个 GitHub owner 下，`add-plugin.sh` 无法把相对/SSH 地址转换成 HTTPS；
直接传 HTTPS URL 即可，或者手工确认 `plugins.txt` 里的 URL。

## 脚本

### `scripts/check-submodules.sh`

在生成索引前运行。它会逐个 fetch 子模块的 `origin`，检查：

- 工作区是否有未提交的改动；
- 当前分支是否有未推送的提交；
- 是否处于 detached HEAD；
- `plugins.txt` 是否包含这个插件仓库。

任何一项失败都会以非零状态退出。不要绕过它去生成索引。

### `scripts/build-index.sh`

```sh
DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh
```

`DSH_REPO` 指向 DeepSeek Harness 源码 checkout，生成器不在 npm 包里。脚本读取
`plugins.txt`，写入 `index.json`。`index.json` 是生成物，不手工编辑；提交前看一遍 diff。

生成器读的是远端默认分支和 tag，所以必须先把子模块提交和 tag 推到远端，再生成索引。

### `scripts/add-plugin.sh`

```sh
./scripts/add-plugin.sh <git-url> [name]
```

`name` 省略时取仓库名的最后一段（去掉 `.git`）。支持 HTTPS、SSH 和相对地址；
相对地址和同 owner 的 SSH 地址会被转换成 HTTPS 写入 `plugins.txt`，因为索引生成器只接受
HTTPS Git URL。

## 提交规则

- 提交信息主题行：`[scope] English imperative sentence`，正文说明改了什么、为什么改。
- 父仓库常用 scope：`[meta]` 子模块 pin 和布局，`[index]` 只改索引，`[docs]` 文档和脚本。
- 插件仓库自己的提交沿用该仓库的习惯；发布提交用 `[release] Bump ...`。
- `git add` 和 `git commit` 分开执行，提交前看 `git diff --staged`；不要 `git commit -a`。
- 先提交并推送子模块，再提交父仓库的 gitlink；父仓库不能记录远端不存在的 SHA。
- 不要用 `git add -f` 绕过 `.gitignore`。
- 旧仓库和旧 tag 不删除；插件迁移或归档时保留历史，旧安装 spec 仍然可用。

## 子模块的边界

- `git grep`、`git log -S` 在父仓库不会进入子模块；用
  `git submodule foreach 'git grep ...'`，或在对应子模块里执行。
- 父仓库的 `git status` 会显示 `modified: plugins/<name> (new commits)`，这是正常的
  gitlink 变化，不是插件文件被父仓库跟踪。
- `git clone` 不带 `--recurse-submodules` 只会得到空的 `plugins/<name>` 目录。
- 父仓库 pin 的是开发快照，索引 `source.commit` 是发布提交；两者可以不同。子模块在 tag
  之后又有文档提交时，父 pin 会比索引里的发布提交更新，这是预期行为。
