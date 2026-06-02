#!/usr/bin/env bash
set -euo pipefail

fail() {
  local name="$1"
  local detail="$2"
  local guide="$3"
  echo "PREREQ_FAIL: ${name} ${detail}" >&2
  echo "安装提示: ${guide}" >&2
  exit 1
}

ok() {
  echo "PREREQ_OK: $1"
}

command_required() {
  local name="$1"
  local command_name="$2"
  local guide="$3"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    fail "${name}" "required command '${command_name}' not found" "${guide}"
  fi
}

first_version() {
  local raw="$1"
  local version
  version="$(printf "%s\n" "${raw}" | grep -Eo '[0-9]+([.][0-9]+)+' | head -n 1 || true)"
  if [[ -z "${version}" ]]; then
    version="$(printf "%s\n" "${raw}" | grep -Eo '[0-9]+' | head -n 1 || true)"
  fi
  printf "%s" "${version}"
}

version_ge() {
  local actual="$1"
  local required="$2"
  local actual_major actual_minor actual_patch required_major required_minor required_patch
  IFS=. read -r actual_major actual_minor actual_patch <<<"${actual}"
  IFS=. read -r required_major required_minor required_patch <<<"${required}"
  actual_minor="${actual_minor:-0}"
  actual_patch="${actual_patch:-0}"
  required_minor="${required_minor:-0}"
  required_patch="${required_patch:-0}"

  if (( actual_major != required_major )); then
    (( actual_major > required_major ))
    return
  fi
  if (( actual_minor != required_minor )); then
    (( actual_minor > required_minor ))
    return
  fi
  (( actual_patch >= required_patch ))
}

check_version() {
  local name="$1"
  local command_name="$2"
  local min_version="$3"
  local guide="$4"
  command_required "${name}" "${command_name}" "${guide}"
  local raw actual
  raw="$("${command_name}" --version 2>&1 || true)"
  actual="$(first_version "${raw}")"
  if [[ -z "${actual}" ]] || ! version_ge "${actual}" "${min_version}"; then
    fail "${name}" "required >= ${min_version}, found ${actual:-unknown}" "${guide}"
  fi
  ok "${name} ${actual} >= ${min_version}"
}

check_pnpm() {
  command_required "corepack" "corepack" "Node.js 18+ 自带 corepack；执行 corepack enable"
  local raw actual source
  if command -v pnpm >/dev/null 2>&1; then
    raw="$(pnpm --version 2>&1 || true)"
    source="pnpm"
  else
    raw="$(corepack pnpm --version 2>&1 || true)"
    source="corepack pnpm"
  fi
  actual="$(first_version "${raw}")"
  if [[ -z "${actual}" ]] || ! version_ge "${actual}" "10.25.0"; then
    fail "pnpm" "required >= 10.25.0, found ${actual:-unknown}" "corepack enable && corepack prepare pnpm@10.25.0 --activate"
  fi
  ok "pnpm ${actual} >= 10.25.0 via ${source}"
}

check_build_tools() {
  command_required "gcc" "gcc" "macOS 执行 xcode-select --install；Ubuntu/WSL 执行 sudo apt install -y build-essential"
  command_required "g++" "g++" "macOS 执行 xcode-select --install；Ubuntu/WSL 执行 sudo apt install -y build-essential"
  command_required "make" "make" "macOS 执行 xcode-select --install；Ubuntu/WSL 执行 sudo apt install -y build-essential"
  ok "gcc/g++/make present"
}

check_wsl_if_windows() {
  local kernel_name
  kernel_name="$(uname -s 2>/dev/null || true)"
  if [[ "${OS:-}" == "Windows_NT" || "${kernel_name}" =~ MINGW|MSYS|CYGWIN ]]; then
    fail "WSL" "required for Windows execution; Win32 native is not supported" "在 PowerShell 执行 wsl --install -d Ubuntu-22.04，然后在 WSL 内重跑本脚本"
  fi
  if [[ -r /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version; then
    ok "WSL detected"
  else
    ok "WSL not required on this platform"
  fi
}

check_version "Node" "node" "18" "使用 nvm install 20 && nvm use 20"
check_pnpm
check_version "git" "git" "2.30" "macOS 执行 brew install git；Ubuntu/WSL 执行 sudo apt install -y git"
check_version "python3" "python3" "3.8" "macOS 执行 brew install python；Ubuntu/WSL 执行 sudo apt install -y python3"
check_build_tools
check_wsl_if_windows

ok "all prerequisites satisfied"
