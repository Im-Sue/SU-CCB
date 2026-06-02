# SU-CCB 跨平台安装指南

本文给出 SU-CCB 主仓在三类受支持开发环境中的安装路径：

- Mac native
- Linux native
- Windows-WSL，也就是 WSL2 中的 Ubuntu 22.04+

Win32 native 不承诺可用性。Windows 用户请使用 WSL2；PowerShell 脚本只作为 Console
本地开发辅助，不等价于完整 Win32 native 支持。

本指南面向想在本机复现主仓、运行 Console、执行测试和走 quickstart 的开发者。首次安装时，
建议从头到尾执行一次；后续升级时，优先查看版本矩阵和 release note。

## 版本与入口

安装前先确认当前发行组合，避免主仓、Claude plugin、Codex skills 和 kernel snapshot
漂移导致排错成本上升。

- 主仓入口：[../README.md](../README.md)
- 快速闭环：[quickstart.md](quickstart.md)
- GA-9 canonical 版本矩阵：[.ccb/index/distribution-version-matrix.yaml](.ccb/index/distribution-version-matrix.yaml)
- 版本矩阵人工镜像：[01_架构设计/ccb-plan/2026-05-03-distribution-version-matrix.md](01_架构设计/ccb-plan/2026-05-03-distribution-version-matrix.md)
- Console 脚本与 troubleshooting：[../apps/ccb-console/README.md](../apps/ccb-console/README.md)
- v0.4 v1 规划入口：`/ccb:su-flow`，决策见
  [ADR-0010](.ccb/decisions/ADR-0010-ka10-su-flow-facade-convergence.md)，Claude plugin
  入口见 [su-flow SKILL.md](../su-ccb-claude-plugin/skills/su-flow/SKILL.md)

后续 E10-T4 会补独立 `docs/requirements.md`。在该文件落地前，以本指南中的前置条件和
`package.json` 的 `packageManager` 字段为准。

## 统一前置条件

三平台都需要以下工具：

| 工具 | 最低要求 | 说明 |
|---|---:|---|
| Git | 2.30+ | clone、worktree、版本检查 |
| Node.js | 18+ | 当前 workspace 使用 TypeScript / Vite / Fastify |
| pnpm | 10.25.0 | 由根目录 `package.json` 的 `packageManager` 固定 |
| corepack | Node.js 自带 | 用于激活 pnpm |
| Python | 3.8+ | server dev db 脚本使用 `python3` |
| C/C++ build tools | 平台对应 | node-pty 等 native binding 可能需要重建 |

统一验证命令：

```bash
git --version
node --version
corepack --version
pnpm --version
python3 --version
```

期望结果：

- `node --version` 输出 `v18.x` 或更高。
- `pnpm --version` 输出 `10.25.0`。
- `python3 --version` 输出 `3.8` 或更高。
- `git --version` 输出 `2.30` 或更高。

## Mac native

本段适用于 macOS 原生开发环境，不需要容器。

### 1. 安装系统工具

先安装 Xcode Command Line Tools：

```bash
xcode-select --install
```

如果已经安装，命令可能提示无需重复安装。这是正常情况。

### 2. 安装 Homebrew

如果本机已经有 Homebrew，可跳过安装，直接更新：

```bash
brew update
```

如果没有 Homebrew，请按团队内部标准安装；安装后确认：

```bash
brew --version
```

### 3. 安装 Git 与 nvm

```bash
brew install git nvm
mkdir -p ~/.nvm
```

把 nvm 初始化脚本加入当前 shell。zsh 用户通常写入 `~/.zshrc`：

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"
```

重新打开 shell 后安装 Node.js：

```bash
nvm install 20
nvm use 20
node --version
```

### 4. 启用 corepack 与 pnpm

```bash
corepack enable
corepack prepare pnpm@10.25.0 --activate
pnpm --version
```

如果 `pnpm --version` 不是 `10.25.0`，先解决 pnpm 版本，再继续。

### 5. Mac 注意事项

- 不要在 iCloud Drive、Dropbox 或网络盘目录里运行主仓。
- 建议使用大小写敏感行为稳定的本地 APFS 目录。
- 如果 native binding 异常，优先执行 `pnpm --filter ccb-console-server rebuild node-pty`。
- 如果 shell 找不到 pnpm，重新打开终端并确认 `corepack enable` 是否写入 PATH。

## Linux native

本段以 Ubuntu 22.04+ 为基线。其他发行版可以复用思路，但包管理命令需自行替换。

### 1. 更新系统包

```bash
sudo apt update
sudo apt install -y git curl ca-certificates build-essential python3
```

确认基础工具：

```bash
git --version
python3 --version
gcc --version
```

### 2. 安装 nvm 与 Node.js

如果本机已有团队管理的 Node.js 18+，可以跳过 nvm。否则建议使用 nvm：

```bash
mkdir -p ~/.nvm
```

按团队内部标准安装 nvm 后，重新打开 shell，并运行：

```bash
nvm install 20
nvm use 20
node --version
```

### 3. 启用 corepack 与 pnpm

```bash
corepack enable
corepack prepare pnpm@10.25.0 --activate
pnpm --version
```

无 sudo 权限时，可把 corepack shim 放到用户目录：

```bash
mkdir -p ~/.local/bin
corepack enable --install-directory ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"
pnpm --version
```

把 PATH 写入 `~/.bashrc` 或 `~/.zshrc` 后，重新打开 shell。

### 4. Linux 注意事项

- 仓库路径建议放在本机 ext4 文件系统。
- 不建议在挂载的远程盘、同步盘或权限受限目录运行。
- 如果 `python: command not found`，确认脚本调用的是 `python3`，并检查 `which python3`。
- 如果 Prisma 或 node-pty 二进制缺执行位，先重装依赖，再考虑 `chmod +x`。

## Windows-WSL

本段适用于 Windows 11 或启用 WSL2 的 Windows 10。SU-CCB 不承诺 Win32 native
安装路径；请在 WSL2 Ubuntu 22.04+ 内执行 Linux 流程。

### 1. 安装 WSL2 Ubuntu

在 PowerShell 中确认 WSL：

```powershell
wsl --status
wsl --list --verbose
```

建议使用 Ubuntu 22.04 或更新版本。进入 WSL 后确认：

```bash
cat /etc/os-release
uname -a
```

### 2. 使用 Linux 文件系统

把仓库放在 WSL 的 Linux 文件系统中，例如：

```bash
mkdir -p ~/dev
cd ~/dev
```

不要把主仓 clone 到 `/mnt/c/Users/...` 后再运行安装。Windows 文件系统下的权限、
换行和 native binding 行为更容易产生不可复现问题。

### 3. 安装依赖工具

在 WSL Ubuntu 内执行：

```bash
sudo apt update
sudo apt install -y git curl ca-certificates build-essential python3
```

然后按 Linux native 段安装 nvm、Node.js、corepack 与 pnpm。

### 4. WSL 特定提示

- Git 配置建议在 WSL 内单独设置，不要依赖 Windows Git。
- 避免混用 Windows pnpm 与 WSL pnpm。
- 如果从 Windows 原生目录迁移到 WSL，删除旧 `node_modules` 后重新 `pnpm install`。
- VS Code Remote WSL 可以使用，但终端命令仍应在 WSL shell 内运行。
- Win32 native 不承诺；遇到原生 Windows 路径问题时，先迁移到 WSL Linux 文件系统。

## 共通安装流程

以下步骤在 Mac、Linux、Windows-WSL 三个平台一致。命令默认从希望放置仓库的父目录执行。

### 1. clone 主仓

```bash
git clone <your-succb-repo-url> SU-CCB
cd SU-CCB
```

如果已经有本地仓库：

```bash
cd SU-CCB
git status --short
git branch --show-current
```

开始安装前，建议工作区保持干净。

### 2. 对齐版本矩阵

读取 GA-9 version matrix：

```bash
sed -n '1,120p' docs/.ccb/index/distribution-version-matrix.yaml
```

确认主仓、Claude plugin、Codex skills、kernel snapshot 和 Console 行符合当前任务或 release
要求。安装文档只描述主仓本地安装；分发包升级和 snapshot 同步按版本矩阵另行处理。

### 3. 激活 pnpm

```bash
corepack enable
corepack prepare pnpm@10.25.0 --activate
pnpm --version
```

如果外层 `corepack pnpm ...` 可以运行，但 `pnpm test` 内部报 `pnpm: not found`，
按 Console README 的 corepack troubleshooting 处理。

### 4. 安装依赖

```bash
pnpm install
```

当前不要求 Docker 一键安装，也不引入额外 npm 依赖。依赖版本由 lockfile 和 workspace
package 声明约束。

### 5. 准备本地数据库

```bash
cd apps/ccb-console/server
pnpm run db:prepare
cd ../../..
```

脚本会准备 SQLite dev db。失败时先检查 `python3` 是否可用。

### 6. 运行 smoke

从仓库根目录执行：

```bash
pnpm -r build
pnpm -r test
python3 references/kernel/tools/lint_all.py --legacy-baseline
```

这三条命令是本仓最小健康检查：

- build 覆盖 Console web/server TypeScript 构建。
- test 覆盖 Console web/server 单元与路由测试。
- lint baseline 覆盖 kernel manifest、spec/state 文档和 legacy baseline。

### 7. 启动 dev server

启动后端：

```bash
./apps/ccb-console/scripts/dev-server.sh
```

另开一个 shell 启动前端：

```bash
./apps/ccb-console/scripts/dev-web.sh
```

Windows-WSL 用户也应优先使用 bash 脚本。PowerShell 脚本只服务于已有 Windows 原生辅助路径，
不改变 Win32 native 不承诺的边界。

### 8. 跑 quickstart

安装完成后，按 quickstart 跑一次最小闭环：

```bash
sed -n '1,220p' docs/quickstart.md
```

quickstart 目标是确认 spec、review、execute、archive 的协作链路可以在本机复现。

## Troubleshooting

更多 Console 细节见 [../apps/ccb-console/README.md](../apps/ccb-console/README.md) 的
Troubleshooting 段。这里保留安装阶段最常见问题。

| 症状 | 快速处理 |
|---|---|
| `sh: 1: pnpm: not found` | 重新执行 `corepack enable && corepack prepare pnpm@10.25.0 --activate`，无 sudo 时用 `corepack enable --install-directory ~/.local/bin`。 |
| `python3: command not found` | Ubuntu / WSL 执行 `sudo apt install -y python3`；macOS 执行 `brew install python`。 |
| `Could not locate the bindings file` | 执行 `pnpm --filter ccb-console-server rebuild node-pty`；仍失败时删除各层 `node_modules` 后重新 `pnpm install`。 |
| 从 Windows 原生切到 WSL 后失败 | 在 WSL Linux 文件系统中重新 clone，或删除 Windows 生成的 `node_modules` 后在 WSL 内重装。 |
| `git status --short` 不干净 | 确认是否为本地生成文件、SQLite dev db 或依赖安装产物；不要提交平台生成物。 |

## 维护规则

- 本指南只维护 Mac native、Linux native、Windows-WSL 三段。
- Win32 native 不承诺；后续如果要支持，必须有独立 spec 和真实验证。
- Docker 一键部署不在本任务范围内。
- 英文版和营销内容不在本任务范围内。
- 版本要求变更时，先更新 GA-9 version matrix，再更新本文。
- Console troubleshooting 细节优先收敛到 `apps/ccb-console/README.md`，本文只保留安装主路径。
