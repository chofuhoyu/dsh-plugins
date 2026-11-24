# dsh-plugins

这是一个[插件市场索引](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-10-02-plugin-market-index-format.md)，
收录我的 DeepSeek Harness 插件 bundle；同时它也是一个 monorepo（Git submodule
父项目），把这些插件仓库放在一起开发。

每个插件仍然是独立的 GitHub 仓库。本仓库以 Git submodule 的形式把这些仓库挂到
`plugins/` 下，所以克隆一次就能同时拿到索引和全部插件代码。市场从各个插件仓库安装，
从不安装这个父项目。

## 使用索引

在 **Plugins → Discover → Add index source** 中填入下面的 URL：

```text
https://raw.githubusercontent.com/chofuhoyu/dsh-plugins/main/index.json
```

索引按生成器实际读到的版本和提交，列出 [`plugins.txt`](plugins.txt) 中的包。在 Discover
中安装列出的版本仍走普通的插件对话框，所以兼容性检查、构建脚本审批和信任提示照常生效。

## 目录结构

```text
dsh-plugins/
├── index.json                  生成的市场索引
├── plugins.txt                 每行一个插件仓库的 HTTPS URL
├── scripts/
│   ├── add-plugin.sh           把新插件仓库添加为 submodule
│   ├── build-index.sh          重新生成 index.json
│   └── check-submodules.sh     重新生成索引前的检查
├── plugins/
│   ├── dsh-always-auto/        submodule
│   ├── dsh-bark-reminder/      submodule
│   ├── dsh-cua-switch/         submodule
│   ├── dsh-review-relay/       submodule
│   └── dsh-search-workspace/   submodule
└── AGENTS.md                   开发与发布规则
```

子模块地址是相对路径（`../dsh-*.git`），因此 SSH clone 会继续使用 SSH，HTTPS clone
不配 SSH 密钥也能工作。

## 开发

带 submodule 克隆仓库：

```sh
git clone --recurse-submodules git@github.com:chofuhoyu/dsh-plugins.git
cd dsh-plugins
```

已有的 clone：

```sh
git submodule update --init --recursive
```

在某个插件仓库里开发：

```sh
cd plugins/dsh-bark-reminder
git switch main
# 修改代码，运行该插件自己的检查
git add <改动的文件>
git diff --staged
git commit -m "[fix] ..."
git push origin main
```

然后回到 monorepo 根目录刷新索引：

```sh
cd ../..
./scripts/check-submodules.sh
DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh
git add plugins/dsh-bark-reminder index.json
git commit -m "[meta] Refresh the dsh-bark-reminder pin and the index"
git push
```

父仓库的提交记录子模块指针和重新生成的索引；插件代码在插件仓库里提交。

## 发布插件

在插件仓库里改 `package.json` 的版本并提交，在该提交上创建附注 tag（annotated tag），
然后推送分支和 tag：

```sh
git add package.json
git commit -m "[release] Bump dsh-bark-reminder to 0.1.6"
git tag -a v0.1.6 -m v0.1.6
git push origin main v0.1.6
```

然后在 monorepo 根目录运行 `./scripts/check-submodules.sh` 和
`./scripts/build-index.sh`，把插件指针和 `index.json` 放在同一个提交里。

tag 即已发布的版本。不要移动或删除 tag；版本写错就发新版本。

## 新增插件

新插件始终是独立仓库，绝不建成这个仓库里的普通目录。

```sh
./scripts/add-plugin.sh ../dsh-new-plugin.git
```

脚本会把 `plugins/dsh-new-plugin` 添加为 submodule，把该仓库的 HTTPS URL 追加到
`plugins.txt`，并确认这个包声明了 `dsh.bundle`。它不会自动提交。等插件有了已推送的
发布 tag 后：

```sh
./scripts/check-submodules.sh
DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh
git add .gitmodules plugins/dsh-new-plugin plugins.txt index.json
git commit -m "[meta] Add dsh-new-plugin to the market"
git push
```

## 重新生成索引

`index.json` 是生成物，永远不要手工编辑。参考生成器需要一份 DeepSeek Harness 源码
checkout：

```sh
DSH_REPO=/path/to/deepseek-harness ./scripts/build-index.sh
```

之后提交重新生成的 `index.json`（如果生成器在它旁边写了 `icons/`，也一并提交）。插件
仓库里的 `v1.2.3` 这类发布 tag 会让索引为该插件额外列出对应的版本，而不只是默认分支
的版本；没有 tag 时就只列出默认分支的当前版本。

生成器读的是远端默认分支和 tag，所以重新生成之前要先推送插件的提交和 tag。
`.plugin-market-cache/` 是本地读取缓存，不会发布。

## 脚本

| 脚本 | 用途 |
|---|---|
| `scripts/add-plugin.sh <git-url> [name]` | 把一个独立的插件仓库添加为 submodule，并写入 `plugins.txt`。 |
| `scripts/check-submodules.sh` | 检查每个子模块是否干净、已推送、位于分支上，并已列在 `plugins.txt` 中。 |
| `scripts/build-index.sh` | 用 DSH 参考生成器从 `plugins.txt` 重新生成 `index.json`。 |

完整的流程、提交约定和子模块边界见 [`AGENTS.md`](AGENTS.md)。
