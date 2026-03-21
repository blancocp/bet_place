#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC_DIR="$HOME/.cursor/plans"
DEST_DIR="$ROOT_DIR/docs/plans"

mkdir -p "$DEST_DIR"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "No existe $SRC_DIR (nada que respaldar)."
  exit 0
fi

shopt -s nullglob
plans=("$SRC_DIR"/*.plan.md)
shopt -u nullglob

if [[ ${#plans[@]} -eq 0 ]]; then
  echo "No hay archivos *.plan.md en $SRC_DIR."
  exit 0
fi

for f in "${plans[@]}"; do
  cp -f "$f" "$DEST_DIR/"
done

echo "Respaldados ${#plans[@]} planes en $DEST_DIR"

