#!/usr/bin/env bash
# 跨仓一致性检查（umbrella）。
# 仅在 4 仓平级摆放时手动 / 集成运行；不进任何单仓 CI（否则单仓 fresh clone 会因缺 sibling 失败）。
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORIEL="$ROOT/su-oriel"; PLUGIN="$ROOT/su-ccb-claude-plugin"; CODEX="$ROOT/su-ccb-codex-skills"
fail=0

echo "[umbrella] 1/3 console generated drift（从 plugin schema 重生 console 产物应无 diff）"
( cd "$ORIEL/server" && pnpm run generate:all >/dev/null 2>&1 && git -C "$ORIEL" diff --exit-code -- server/src/generated ) \
  && echo "  ✓ no drift" || { echo "  ✗ console generated drift"; fail=1; }

echo "[umbrella] 2/3 plugin 独立 regenerate（plugin 产物应无 diff）"
( cd "$PLUGIN" && node scripts/generate-schema-validators.mjs >/dev/null 2>&1 \
   && node scripts/generate-capability-outcome-policy.mjs >/dev/null 2>&1 \
   && git -C "$PLUGIN" diff --exit-code -- lib ) \
  && echo "  ✓ no drift" || { echo "  ✗ plugin generated drift"; fail=1; }

echo "[umbrella] 3/3 codex resolver 两布局测试"
( cd "$CODEX" && node --test skills/ccb-execute/scripts/__tests__/resolve-same-group-peer.test.mjs >/dev/null 2>&1 ) \
  && echo "  ✓ codex resolver ok" || { echo "  ✗ codex resolver"; fail=1; }

[ "$fail" = 0 ] && echo "[umbrella] ALL GREEN" || { echo "[umbrella] FAILED"; exit 1; }
