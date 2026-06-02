# SU-CCB 运行依赖

本文固定主仓本地安装与验证所需依赖。版本组合以 GA-9 版本矩阵为基线：

- Canonical YAML：[.ccb/index/distribution-version-matrix.yaml](.ccb/index/distribution-version-matrix.yaml)
- 安装指南：[install.md](install.md)
- 前置检查脚本：[../scripts/check-prerequisites.sh](../scripts/check-prerequisites.sh)

Windows 用户只承诺 Windows-WSL 路径；Win32 native 不在当前支持范围内。

## CCB 入口要求

安装完成后，面向使用者的新规划入口是 `/ccb:su-flow`。本入口由 Claude plugin 分发，
用于启动 v0.4 v1 SingleTaskScheduler planning flow；旧入口只应出现在明确的
deprecation、历史或兼容说明中。

## 依赖表

| name | min_version | why | 安装命令 | 验证命令 |
|---|---:|---|---|---|
| Node.js | 18 | Console web/server、TypeScript、Vite、Fastify 运行时 | macOS/Linux/WSL 推荐 `nvm install 20 && nvm use 20` | `node --version` |
| pnpm via corepack | 10.25.0 | workspace 包管理；根 `package.json` 固定 `pnpm@10.25.0` | `corepack enable && corepack prepare pnpm@10.25.0 --activate` | `corepack --version && pnpm --version` |
| git | 2.30 | clone、worktree、版本矩阵和变更审计 | macOS: `brew install git`；Ubuntu/WSL: `sudo apt install -y git` | `git --version` |
| python3 | 3.8 | Console server dev db 与辅助脚本 | macOS: `brew install python`；Ubuntu/WSL: `sudo apt install -y python3` | `python3 --version` |
| gcc/g++/make | present | node-pty 等 native binding rebuild；Linux/WSL 对应 build-essential | macOS: `xcode-select --install`；Ubuntu/WSL: `sudo apt install -y build-essential` | `gcc --version && g++ --version && make --version` |
| WSL | WSL2 Ubuntu 22.04+ | Windows 执行面只承诺 WSL；不承诺 Win32 native | PowerShell: `wsl --install -d Ubuntu-22.04` | WSL 内执行 `cat /etc/os-release` |

## 推荐安装顺序

1. 先安装平台基础工具：Git、Python、C/C++ build tools。
2. 再安装 nvm，并通过 nvm 安装 Node.js 20。
3. 使用 corepack 激活 `pnpm@10.25.0`。
4. 在主仓根目录运行 `scripts/check-prerequisites.sh`。
5. 检查通过后执行 `pnpm install`、`pnpm -r build`、`pnpm -r test`。

## 自动检查

从仓库根目录执行：

```bash
scripts/check-prerequisites.sh
```

成功时每一项输出 `PREREQ_OK:`。失败时脚本 fail fast，输出 `PREREQ_FAIL:` 并返回非 0。

常见失败示例：

```text
PREREQ_FAIL: Node required >= 18
```

按提示安装对应依赖后重新运行脚本。不要通过修改 `package.json` 或降级 lockfile 来绕过依赖要求。

## 平台边界

- Mac native、Linux native、Windows-WSL 是当前安装文档覆盖的三条路径。
- Windows-WSL 指 WSL2 Ubuntu 22.04+；Windows 原生 PowerShell 不承诺完整执行能力。
- Docker 一键安装、GitHub Actions 自动检查和英文版文档不在当前 E10-T4 范围内。
- 依赖版本变更时，先更新 GA-9 version matrix，再同步本文与安装指南。
