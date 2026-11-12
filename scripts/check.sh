#!/usr/bin/env bash
# Validação estática do OFFSCOPE: build do Rojo, type-check (luau-lsp) e lint (selene).
# Uso: ./scripts/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS=".tooling/globalTypes.d.luau"
if [ ! -f "$DEFS" ]; then
	mkdir -p .tooling
	echo "→ baixando definições de tipo do Roblox (luau-lsp)"
	curl -sSL -o "$DEFS" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi

echo "→ rojo build"
rojo build default.project.json -o .tooling/offscope.rbxl >/dev/null

echo "→ rojo sourcemap"
rojo sourcemap default.project.json -o sourcemap.json >/dev/null

echo "→ luau-lsp analyze"
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions="$DEFS" \
	--ignore="ServerPackages/**" --ignore="Packages/**" src

echo "→ selene"
selene src

echo "✓ tudo certo"
