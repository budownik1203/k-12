#!/bin/bash
# Wydanie: eksport Windows, zip, gałąź `wydania`. Użycie: bash narzedzia/wydanie.sh 0.16.6
set -e
V=$1; [ -z "$V" ] && { echo "podaj wersję"; exit 1; }
export PATH=$HOME/tools:$PATH
R="$(cd "$(dirname "$0")/.." && pwd)"
cd "$R" && rm -f build/windows/StrefaK12.exe && mkdir -p build/windows
godot --headless --path . --export-release "Windows Desktop" build/windows/StrefaK12.exe > /tmp/eksport.log 2>&1 || true
test -f build/windows/StrefaK12.exe || { echo "eksport nie wyszedł – /tmp/eksport.log"; exit 1; }
P=/tmp/pak_k12; rm -rf $P; mkdir -p $P/StrefaK12; cp build/windows/StrefaK12.exe $P/StrefaK12/
Z=/tmp/StrefaK12_v${V}_Windows.zip; rm -f $Z; (cd $P && zip -q -9 -r $Z StrefaK12)
W=/tmp/wyd_k12; rm -rf $W; git clone -q --branch wydania --single-branch "$(git remote get-url origin)" $W
cd $W && rm -f StrefaK12_*.zip && cp $Z . && sed -i -E "s/v[0-9]+\.[0-9]+\.[0-9]+/v${V}/g" README.md
git add -A && git commit -q -m "Wydanie v${V}" && git push -q origin wydania
echo "https://github.com/budownik1203/k-12/raw/wydania/StrefaK12_v${V}_Windows.zip"
