#!/bin/sh
# 從 Noto Sans TC 產生只含遊戲用字的子集字型（需要 fonttools）。
# 用法：tools/subset_font.sh <NotoSansTC[wght].ttf>
set -e
cd "$(dirname "$0")/.."
SRC="$1"
TMP=$(mktemp -d)
fonttools varLib.instancer "$SRC" wght=500 -o "$TMP/inst.ttf"
cat scripts/*.gd > "$TMP/text.txt"
printf '%s' ' !"#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_abcdefghijklmnopqrstuvwxyz{|}~，。：；！？（）［］「」、…　' >> "$TMP/text.txt"
pyftsubset "$TMP/inst.ttf" --text-file="$TMP/text.txt" --output-file=fonts/NotoSansTC-subset.ttf
rm -rf "$TMP"
