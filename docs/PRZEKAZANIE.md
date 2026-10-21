# Przekazanie projektu (dla nowej sesji Claude)

Przeczytaj ten plik w całości, potem `docs/STAN_DEMO.md` (co jest zrobione, tabela wersji) i ostatnie sekcje
`docs/MECHANIKI.md`. Kod i komentarze są po polsku – odpowiadaj użytkownikowi po polsku.

## Projekt

- **Strefa K-12** – FPS extraction, low poly PS1, Godot **4.6.1**, renderer Compatibility, GDScript.
- Repo: `budownik1203/k-12`. Praca na `main`. Wydania (zip z grą dla Windows) na gałęzi `wydania`.
- Ostatnie wydanie: **v0.16.5**. Na `main` są już poprawki v0.16.6 (opis w STAN_DEMO.md, wiersz
  „Poprawki mapy (v0.16.6)”), **jeszcze nie wydane** – regresja przerwana w 2/3 (do tego miejsca czysto poza
  jednym testem: `--test_v14` „wróg nie zdjął pułapki” – test zależny od losowości AI, do sprawdzenia).

## Jak pracuje użytkownik

- Pisze krótko, po polsku, czasem z literówkami. Oczekuje samodzielnej pracy: wdrożenie, testy, wydanie,
  na końcu krótki raport po polsku z linkiem do zipa.
- Zgłasza błędy zrzutami ekranu z gry (Windows). Prosi też o propozycje zmian – na końcu raportu warto dać
  kilka konkretnych pomysłów, wdraża je zwykle w następnej wiadomości („+ to co proponujesz”).
- **Zasada projektu:** gra ma być wolna, ciężka, realistyczna. Żadnych wygodnych skrótów („weź wszystko”),
  HUD bez wiedzy, której postać nie ma (bez kropki celownika, bez znacznika trafień, czas tylko z zegarkiem,
  wyjścia tylko na mapie). Rzeczy fizyczne obsługuje się ręką: drzwi i meble – przytrzymaj F + mysz.
  Bez leżenia, bez wstrzymywania oddechu.

## Przygotowanie środowiska (świeży kontener)

```bash
bash narzedzia/przygotuj_srodowisko.sh     # Godot 4.6.1 + szablony eksportu + import
export PATH=$HOME/tools:$PATH
godot --headless --path . tests/sprawdz.tscn   # parsowanie wszystkich skryptów (ma być 63+, bez błędów)
```
Po dodaniu nowego skryptu z `class_name` albo zasobu: `godot --headless --path . --import`.

## Testy

- Szybkie: `tests/sprawdz.tscn`, `tests/test_ekwipunek.tscn`, `tests/test_kontrakty.tscn` (headless),
  `tests/test_ui.tscn`, `tests/petla.tscn` (pełna pętla gry), `tests/test_sciany.tscn -- --kadry DIR --ziarna N`
  (rzeczy na ścianach, okna; `--przeglad` robi zrzuty korytarzy do obejrzenia).
- Testy z obrazem przez `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 ...`.
- Tryby rajdu: `scenes/rajd.tscn -- --test_v14 DIR`, `--test_v15`, `--test_v16`, `--test_nakladanie`,
  `--test_zapiecia`, `--test_pulapka`, `--test_mapa`, `--soak 480 --ziarno 31`, `--vm DIR --animacje --<tryb>`
  (mechaniki, przeladowania, gesty, drzwi, granat, poddanie, potrzeby, plecaki, porzucenie, lup, meble,
  ruch_broni, zwloki, ziemia, schody, czynnosci, latarka_przeladowanie). Baza: `scenes/baza.tscn -- --test_kryjowki`.
- Nowy tryb testowy rajdu dopisz do listy trybów z zapisem testowym w `scripts/autoload/gra.gd` (`_ready`),
  inaczej test nadpisze zapis gracza. Przed testami: `rm -rf ~/.local/share/godot/app_userdata/*/zapis_test.json*`.
- **Pełna regresja:** `bash narzedzia/regresja.sh /tmp/reg > /tmp/reg.log` (~1,5 h). Uruchamiać w tle
  i NIGDY równolegle z innymi testami godota – pod obciążeniem testy fizyki/AI dają fałszywe błędy.
  Wynik: `grep -E "TEST|BŁĄD|SCRIPT ERROR|SOAK" /tmp/reg.log`.

## Wydanie

1. Podbij nagłówek `docs/STAN_DEMO.md` i dopisz wiersz wersji; ewentualnie sekcję w `docs/MECHANIKI.md`.
2. Commit na `main` (stopka: `Co-Authored-By: ...` wg ustawień sesji), push.
3. `bash narzedzia/wydanie.sh 0.16.6` – eksport Windows, zip, push na `wydania`, wypisuje link:
   `https://github.com/budownik1203/k-12/raw/wydania/StrefaK12_v0.16.6_Windows.zip`.
   Uwaga: nie przepuszczać wyjścia eksportu przez `head` (zabija godota).

## Mapa kodu (najważniejsze)

- `scripts/autoload/gra.gd` – stan gry, zapis, ustawienia (osobny `user://ustawienia.json`, F11 pełny ekran).
- `scripts/gracz/gracz.gd` – ruch, interakcje (krótkie F = czynność, przytrzymane = chwyt `_chwyt`), stres,
  ciągnięcie zwłok; `bron.gd` – broń, animacje, chwyt Harriesa z latarką; `animacje_akcji.gd` – czynności.
- `scripts/swiat/generator.gd` – generator mapy (komórki, korytarze z ramionami, okna, meble, detale);
  `drzwi.gd` (fizyczne, tylko ręką), `pojemnik.gd` (meble ręką, przeszukiwanie), `przesuwny.gd`, `pulapka.gd`,
  `potykacz.gd`, `wylacznik.gd`, `naklejki.gd`, `kryjowka.gd` (baza – UI w głównym oknie, bo świat jest w SubViewport).
- `scripts/ai/wrog.gd` – AI. `scripts/ui/ekran_ekwipunku.gd` – ekwipunek (duży plik), `hud.gd`, `scena_rajd.gd`
  (scena rajdu + większość testów), `scena_baza.gd`, `menu_pauzy.gd` (wspólna lista ustawień).
- Dane: `assets/dane/przedmioty.json`, `meble.json`.
- Warstwy fizyki: SWIAT=1, POSTACIE=2, HITBOX_WROGA=4, HITBOX_GRACZA=8, INTERAKCJE=16, Przesuwny=32.

## Otwarte sprawy

- Wydać v0.16.6 (po regresji albo na życzenie użytkownika bez niej).
- `--test_v14` – sprawdzić, czy zdejmowanie pułapki przez wroga to błąd, czy losowość testu.
- Zgłoszony „wiszący blok” w korytarzu (zrzut) – przyczyny nie potwierdzono; dodano straż przed lewitującymi
  przedmiotami przesuwnymi. Plakat wiszący w powietrzu – poprawka przez osobną kolizję okien, niepotwierdzona
  na mapie gracza.
