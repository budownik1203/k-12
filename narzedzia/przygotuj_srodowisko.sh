#!/bin/bash
# Przygotowanie świeżej sesji (kontener Linux): Godot 4.6.1 + szablony eksportu Windows.
# Użycie: bash narzedzia/przygotuj_srodowisko.sh   (potem: export PATH=$HOME/tools:$PATH)
set -e
T=$HOME/tools
mkdir -p $T && cd $T
if [ ! -x $T/godot ]; then
  curl -L -o godot.zip https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64.zip
  unzip -o godot.zip && mv -f Godot_v4.6.1-stable_linux.x86_64 godot && chmod +x godot
fi
TD=$HOME/.local/share/godot/export_templates/4.6.1.stable
if [ ! -f $TD/windows_release_x86_64.exe ]; then
  curl -L -o templates.tpz https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz
  mkdir -p $TD && unzip -o templates.tpz -d /tmp/tpl && cp -r /tmp/tpl/templates/* $TD/
fi
which xvfb-run >/dev/null || (apt-get update && apt-get install -y xvfb)
cd "$(dirname "$0")/.." && $T/godot --headless --path . --import >/dev/null 2>&1 || true
echo "Gotowe: $T/godot $($T/godot --version)"
