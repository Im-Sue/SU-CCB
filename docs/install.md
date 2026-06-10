# SU-CCB 跨平台安装指南

本文面向想在本机复现 SU-CCB 主仓、运行 SU-Oriel 控制台、执行跨仓检查和走 quickstart 的开发者。

SU-CCB 现在是 multi-repo + submodule 布局：根仓只放文档中枢、协调脚本和 submodule 版本绑定；控制台在 `su-oriel/`，协议内核在 `su-ccb-claude-plugin/references/kernel/`，根目录不是 pnpm workspace。

支持环境：

- macOS native
- Linux native
- Windows-WSL

Win32 native 不承诺可用性。Windows 用户请在 WSL 内执行 Linux 流程。

## 版本与入口

版本要求以顶层 README 的 [环境与版本](../README.md#versions) 为唯一真相源；本文不重复维护 Python / Node.js / pnpm / git 的具体数字，避免文档漂移。

常用入口：

- 主仓总览：[../README.md](../README.md)
- 开发者闭环演示：[quickstart.md](quickstart.md)
- SU-Oriel 控制台：[https://github.com/Im-Sue/SU-Oriel#quick-eval](https://github.com/Im-Sue/SU-Oriel#quick-eval)
- Claude plugin 安装：[https://github.com/Im-Sue/su-ccb-claude-plugin#install](https://github.com/Im-Sue/su-ccb-claude-plugin#install)
- Codex skills 安装：[https://github.com/Im-Sue/su-ccb-codex-skills#install](https://github.com/Im-Sue/su-ccb-codex-skills#install)
- 底层 bridge：[https://github.com/SeemSeam/claude_codex_bridge#readme](https://github.com/SeemSeam/claude_codex_bridge#readme)

## 统一前置条件

三平台都需要：

- Git
- Node.js + corepack + pnpm
- Python CLI（`python3`）
- C/C++ build tools
- `tmux`
- `ccb` / `ccbd`，由 `claude_codex_bridge` 安装
- Claude CLI / Codex CLI，并完成各自登录鉴权

先安装系统工具，再 clone 仓库并运行本仓检查脚本。脚本会检查自动可验证项，并把无法自动验证的项单独列为提示。

```bash
bash scripts/check-prerequisites.sh
```

输出约定：

- `PREREQ_OK`：脚本已自动验证通过。
- `PREREQ_FAIL`：缺失或版本不满足，脚本退出非零。
- `PREREQ_NOTE: 仅提示 / 需手动确认`：脚本无法自动验证的状态，不影响退出码。

手动项包括：Claude / Codex CLI 是否已登录、当前项目是否已 `/ccb:su-init`、`ccb@SU-CCB` plugin 是否已在系统级 Claude Code 启用。CLI 存在不等于这些状态已经完成。

## macOS native

安装 Xcode Command Line Tools：

```bash
xcode-select --install
```

用 Homebrew 或团队标准工具安装 Git、nvm、Python、tmux，并安装满足 [版本表](../README.md#versions) 的 Node.js：

```bash
brew update
brew install git nvm python tmux
nvm install --lts
nvm use --lts
corepack enable
PNPM_VERSION="<README.md#versions 中声明的 pnpm 版本>"
corepack prepare "pnpm@${PNPM_VERSION}" --activate
```

如果本机已有满足版本表的工具链，可以跳过重复安装。

## Linux native

Ubuntu / Debian 系统可用 apt 安装基础工具：

```bash
sudo apt update
sudo apt install -y git curl ca-certificates build-essential python3 tmux
```

再用 nvm 或团队标准工具安装满足 [版本表](../README.md#versions) 的 Node.js，并启用 pnpm：

```bash
nvm install --lts
nvm use --lts
corepack enable
PNPM_VERSION="<README.md#versions 中声明的 pnpm 版本>"
corepack prepare "pnpm@${PNPM_VERSION}" --activate
```

无 sudo 权限时，可把 corepack shim 放到用户目录：

```bash
mkdir -p ~/.local/bin
corepack enable --install-directory ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"
```

## Windows-WSL

在 PowerShell 里安装或确认 WSL：

```powershell
wsl --status
wsl --list --verbose
```

进入 WSL 后，把仓库放在 Linux 文件系统中，例如：

```bash
mkdir -p ~/dev
cd ~/dev
```

不要把主仓 clone 到 `/mnt/c/Users/...` 后再运行安装。Windows 文件系统下的权限、换行和 native binding 行为更容易产生不可复现问题。

在 WSL 内按 Linux native 段安装工具链。避免混用 Windows Git / pnpm 与 WSL Git / pnpm。

## 共通安装流程

以下步骤在 macOS、Linux、Windows-WSL 三个平台一致。

### 1. clone 主仓与 submodule

HTTPS：

```bash
git clone --recursive https://github.com/Im-Sue/SU-CCB.git
cd SU-CCB
```

SSH：

```bash
git clone --recursive git@github.com:Im-Sue/SU-CCB.git
cd SU-CCB
```

如果已经 clone 但没有拉 submodule：

```bash
git submodule update --init --recursive
```

开始安装前建议确认工作区干净：

```bash
git status --short
git branch --show-current
```

### 2. 安装底层 bridge

按 [claude_codex_bridge README](https://github.com/SeemSeam/claude_codex_bridge#readme) 安装 `ccb` / `ccbd`，执行其 `./install.sh install`。安装后重开 shell，再运行：

```bash
ccb --print-version
tmux -V
```

不要在自动检查脚本里使用 `ccb version`；它会联网检查更新。

### 3. 安装系统级 plugin / 用户级 skills

按组件 README 操作，不在本文复制命令：

- Claude plugin：[su-ccb-claude-plugin#install](https://github.com/Im-Sue/su-ccb-claude-plugin#install)
- Codex skills：[su-ccb-codex-skills#install](https://github.com/Im-Sue/su-ccb-codex-skills#install)

安装顺序建议：先装 bridge、plugin、skills，再启动 CCB / SU-Oriel。这样派生 agent 才能继承系统级 plugin 与用户级 skills。

### 4. 运行前置检查

```bash
bash scripts/check-prerequisites.sh
```

该脚本只验证可自动判断的工具链与平台状态；末尾的 `PREREQ_NOTE` 是手动自查清单，不代表失败。

### 5. 安装并构建 SU-Oriel 控制台

根仓没有 pnpm workspace；依赖安装和构建在 `su-oriel/` 内完成：

```bash
cd su-oriel
pnpm install
pnpm build
pnpm test
cd ..
```

首次启动后端时，`su-oriel/scripts/dev-server.sh` 会按需要准备本地 SQLite dev db。

### 6. 跑协议内核 lint

协议内核在 Claude plugin 子仓：

```bash
python3 su-ccb-claude-plugin/references/kernel/tools/lint_all.py
```

### 7. 跑跨仓一致性检查

四个仓都齐全时，从根仓运行：

```bash
bash scripts/check-cross-repo.sh
```

### 8. 启动 SU-Oriel dev server / web

后端：

```bash
cd su-oriel
./scripts/dev-server.sh
```

另开一个 shell 启动前端：

```bash
cd su-oriel
./scripts/dev-web.sh
```

停止时回到对应终端按 `Ctrl-C`。CCB / agent / tmux 运行时的收尾命令是 `ccb kill`，残留时用 `ccb kill -f`。

### 9. 跑 quickstart

安装完成后，按 quickstart 跑一次开发者最小闭环：

```bash
sed -n '1,220p' docs/quickstart.md
```

quickstart 目标是确认 spec、review、execute、archive 的协作链路可以在本机复现。

## Troubleshooting

更多控制台细节见 [SU-Oriel README](https://github.com/Im-Sue/SU-Oriel#quick-eval) 与本仓 `su-oriel/README.md`。这里保留安装阶段最常见问题。

| 症状 | 快速处理 |
|---|---|
| `pnpm: not found` | 重新执行 `corepack enable` 并按 [版本表](../README.md#versions) 激活 pnpm；无 sudo 时使用 `corepack enable --install-directory ~/.local/bin`。 |
| `python3: command not found` | Ubuntu / WSL 执行 `sudo apt install -y python3`；macOS 执行 `brew install python`。 |
| `ccb: command not found` | 按 [claude_codex_bridge README](https://github.com/SeemSeam/claude_codex_bridge#readme) 安装 bridge，重开 shell 后重试。 |
| `tmux: command not found` | macOS 执行 `brew install tmux`；Ubuntu / WSL 执行 `sudo apt install -y tmux`。 |
| `Could not locate the bindings file` | 进入 `su-oriel/` 后执行 `pnpm --filter su-oriel-server rebuild node-pty`；仍失败时删除 `su-oriel/server/node_modules`、`su-oriel/web/node_modules` 后重装。 |
| 从 Windows 原生切到 WSL 后失败 | 在 WSL Linux 文件系统中重新 clone，或删除 Windows 生成的 `node_modules` 后在 WSL 内重装。 |
| `git status --short` 不干净 | 确认是否为本地生成文件、SQLite dev db 或依赖安装产物；不要提交平台生成物。 |

## 维护规则

- 本指南只维护 macOS native、Linux native、Windows-WSL 三段。
- Win32 native 不承诺；后续如果要支持，必须有独立 spec 和真实验证。
- Docker 一键部署不在本任务范围内。
- 版本要求变更时，先更新顶层 README 的 [环境与版本](../README.md#versions)，本文只链接。
- 控制台 troubleshooting 细节优先收敛到 SU-Oriel README；本文只保留安装主路径。
