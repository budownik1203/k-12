#!/bin/bash
# Pełna regresja (~1,5 h, testy kolejno – równolegle dają fałszywe błędy). Użycie: bash narzedzia/regresja.sh [katalog_wyników] > log; szukać "BŁĄD" / "SCRIPT ERROR".
export PATH=$HOME/tools:$PATH
cd "$(dirname "$0")/.."
O=${1:-/tmp/regresja}; rm -rf $O; mkdir -p $O
X='xvfb-run -a -s "-screen 0 1920x1080x24"'
run(){ n=$1; shift; echo "=== $n" ; eval "$X timeout 900 godot --path . --rendering-driver opengl3 $*" 2>&1 | grep -E "TEST|KIESZENIE|BŁĄD|OK|BLAD|BŁĄD|FAIL|SCRIPT ERROR|Parse Error|wynik|PASS|NIE" | grep -v "^ *at:" | tail -12; }
rm -rf ~/.local/share/godot/app_userdata/*/zapis_test.json*
run sprawdz "--headless tests/sprawdz.tscn"
run sciany "tests/test_sciany.tscn -- --kadry $O/sc --ziarna 20"
run latarka "scenes/rajd.tscn -- --vm $O/lat --animacje --latarka_przeladowanie"
run ui "tests/test_ui.tscn"
run petla "tests/petla.tscn"
run ekw "--headless tests/test_ekwipunek.tscn"
run kontr "--headless tests/test_kontrakty.tscn"
run kryj "scenes/baza.tscn -- --test_kryjowki"
run test31 "scenes/rajd.tscn -- --test --ziarno 31"
run walka "scenes/rajd.tscn -- --walka"
run frakcje "scenes/rajd.tscn -- --frakcje"
run boss "scenes/rajd.tscn -- --test_boss --boss --ziarno 3"
run rep "scenes/rajd.tscn -- --test_reputacji --ziarno 3"
run sprawdzm "scenes/rajd.tscn -- --test_sprawdz $O/spr"
run mapa "scenes/rajd.tscn -- --test_mapa $O/mapa --ziarno 3"
run pulapka "scenes/rajd.tscn -- --test_pulapka $O/pul --ziarno 3"
run v14 "scenes/rajd.tscn -- --test_v14 $O/v14 --ziarno 3"
run v15 "scenes/rajd.tscn -- --test_v15 $O/v15 --ziarno 3"
run v16 "scenes/rajd.tscn -- --test_v16 $O/v16 --ziarno 3"
run nakl "scenes/rajd.tscn -- --test_nakladanie $O/nak --ziarno 3"
run zapiecia "scenes/rajd.tscn -- --test_zapiecia $O/zap"
run ewak "scenes/rajd.tscn -- --ewakuacja --zrzuty_raport $O/rap"
for m in mechaniki przeladowania gesty drzwi granat poddanie potrzeby plecaki porzucenie lup meble ruch_broni zwloki ziemia schody; do
 run vm_$m "scenes/rajd.tscn -- --vm $O/vm_$m --animacje --$m"
done
run ekon "scenes/rajd.tscn -- --ekonomia --ziarno 5"
rm -rf ~/.local/share/godot/app_userdata/*/zapis_test.json*
timeout 900 godot --headless --path . scenes/rajd.tscn -- --soak 480 --ziarno 31 2>&1 | grep -E "SOAK t=480|SOAK drzwi|SCRIPT ERROR" | cut -c1-300
echo KONIEC
