#!/bin/sh
# Скачивает Godot 4.7.2 (headless-запуск) в $1 (по умолчанию ./.godot-bin). Для CI.
set -e
DEST="${1:-.godot-bin}"
VER=4.7.2
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) BIN="Godot_v${VER}-stable_linux.x86_64" ;;
  aarch64|arm64) BIN="Godot_v${VER}-stable_linux.arm64" ;;
  *) echo "Неизвестная архитектура $ARCH"; exit 1 ;;
esac
mkdir -p "$DEST"
if [ ! -x "$DEST/$BIN" ]; then
  curl -sSL -o "$DEST/godot.zip" "https://github.com/godotengine/godot/releases/download/${VER}-stable/${BIN}.zip"
  unzip -o -q "$DEST/godot.zip" -d "$DEST"
  rm "$DEST/godot.zip"
  chmod +x "$DEST/$BIN"
fi
ln -sf "$BIN" "$DEST/godot"
"$DEST/godot" --headless --version
