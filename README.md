# Strefa K-12

Taktyczny shooter PvE z mechaniką extraction, w pierwszej osobie, w stylu low poly PS1.
Alternatywny blok wschodni, strefa kwarantanny wokół kompleksu badawczego, 12 lat po zamknięciu.
Wchodzisz do losowo składanej strefy, zbierasz łup i albo się ewakuujesz, albo tracisz wszystko.

> Stan: **pierwsze grywalne demo** – biom 1 (Blokowisko), pełna pętla baza → rajd → raport.
> Szczegóły: [docs/STAN_DEMO.md](docs/STAN_DEMO.md).

| | |
| --- | --- |
| ![Rajd](docs/zrzuty/rajd_przeciwnicy.png) | ![Warsztat](docs/zrzuty/rajd_warsztat.png) |
| ![Baza](docs/zrzuty/baza.png) | ![Ekwipunek](docs/zrzuty/ekwipunek.png) |

## Uruchomienie

**Gotowa gra:** `StrefaK12_demo_Windows.zip` (albo wersja Linux) – rozpakuj i uruchom `StrefaK12.exe`. Nie trzeba instalować Godota. Build można też zrobić samemu (sekcja Budowanie).

**Ze źródeł:** Godot **4.6** (renderer Compatibility). Otwórz folder w menedżerze projektów, poczekaj na import, F5.

## Sterowanie

| Klawisz | Akcja |
| --- | --- |
| WSAD, Shift, Ctrl, Spacja | ruch, bieg, kucanie, skok |
| Q / E | wychylenie zza osłony |
| LPM / PPM | strzał / celowanie przez przyrządy |
| R | przeładowanie (przytrzymaj: szybkie, magazynek leci na ziemię); przy zacięciu – usunięcie zacięcia |
| B / T | tryb ognia / sprawdzenie amunicji (bez licznika na HUD) |
| 1 / 2 / 3 | broń główna / pistolet (drugie wciśnięcie: pistolet z latarką) / sama latarka |
| F | interakcja (przeszukaj, rozmawiaj, otwórz) |
| Tab | panel operatora; „Otwórz” przy plecaku/kontenerze: postać zdejmuje go i rozkłada przed sobą (sloty we wnętrzu); w sklepie Tab zamyka |
| Tab, Tab | szybkie zerknięcie na kamizelkę (ładownice pod ręką) |
| G | napełnij magazynki z amunicji luzem |
| L | latarka: wyjmij do lewej ręki (z pistoletem albo samą) / włącz–wyłącz; z latarką taktyczną na broni włącza ją |
| O | lista wyjść z kierunkiem i odległością |
| 4–9 | pasek szybkiego dostępu: leki z kamizelki i kieszeni (układa się sam) |
| H | spójrz na zegarek (zdrowie na tarczy) |
| J | obejrzyj broń z bliska, zakładanie i zdejmowanie dodatków |
| X | przerwij leczenie lub napełnianie (przerywa też strzał i zmiana broni) |
| Esc | pauza (w rajdzie czas płynie dalej) |
| F1 | plansza ze sterowaniem |

Latarka, mapa i kompas działają tylko na slotach wyposażenia (pas + 0–2 z kamizelki). Mapa daje odległości
do wyjść w liście [O], kompas – pasek kierunków u góry ekranu. Amunicja luzem to garść (1x1), większy stos robi się
pudełkiem (1x2). Kamizelki i plecaki mają przegródki (osobne ładownice i kieszenie).

W ekwipunku: przeciąganie myszą, **R** obraca, **Ctrl+LPM** przenosi (w rajdzie kolejka – dłoń przekłada po kolei),
**Shift+LPM** dzieli stos na pół, **PPM** menu (użyj, rozładuj, napełnij, wyjmij magazynek, załóż, wyrzuć, podziel).
Szafki, szuflady i skrzynie otwiera się w świecie (**F**), zawartość odkrywa się stopniowo – po ciemku wolniej.
Ciała przeszukuje się po kieszeniach; pancerz i hełm z ciała zdejmuje się kliknięciem (trwa). Zamknięte na kłódkę
skrzynie i szafki wyłamuje się (z kombinerkami lub kluczem nastawnym szybciej). Przytrzymany ruch przy rozłożonym
plecaku – zrywasz się i plecak zostaje na ziemi (podejdź i **F**, żeby go założyć). Amunicję upuść na magazynek, żeby go napełnić
(nabój po naboju, z kółkiem postępu), a magazynek na broń, żeby go włożyć. Lek upuszczony na część ciała
w panelu zdrowia leczy właśnie ją.
Dodatek (tłumik, latarka taktyczna, hamulec) upuszczony na broń montuje się w terenie z animacją; zdejmuje się z menu
**PPM** na broni. Kolimator, lunetę i chwyt montuje się tylko przy stole roboczym w schronie (podejdź i wciśnij **F**). Przedmiot upuszczony poza slotami i siatkami albo **Del** na wskazanym – ląduje na ziemi.

## Pętla gry

1. **Baza** (schron, chodzony w pierwszej osobie): Zbrojmistrz, Medyk i Pośrednik, skrytka w szafkach,
   leczenie, ubezpieczenie, darmowy zestaw startowy, gdy nie masz broni.
2. **Rajd**: losowa sieć szerokich korytarzy z pomieszczeniami bloku oddzielonymi grubym murem (mieszkania, kuchnie, piwnice, magazyny, warsztaty),
   szabrownicy i najemnicy z taktycznym AI, pełzacze (mutanty chodzące po ścianach), łup w szafkach i na zwłokach.
3. **Wyjścia**: brama (zawsze), piwnica nr 7 (na klucz z rajdu), okno na rusztowanie (tylko w oknie czasowym).
4. **Raport urzędowy**: przeżycie albo zgon, z komunikatem zależnym od przyczyny i dopiskami z przebiegu rajdu.

## Struktura projektu

| Folder | Zawartość |
| --- | --- |
| `scenes/` | sceny: menu, baza, rajd, raport (treść budowana w kodzie) |
| `scripts/autoload/` | `Dane` (baza przedmiotów), `Gra` (stan, zapis), `Sterowanie`, `Dzwiek`, `PsxMaterialy` |
| `scripts/core/` | przedmiot, siatka, ekwipunek (waga z redukcją), ciało i rany, balistyka, modele, widok 3D |
| `scripts/gracz/` | gracz (ruch, postawy, leczenie, interakcje) i broń (strzelanie, przeładowania) |
| `scripts/ai/` | przeciwnicy ludzcy, oddziały, fauna |
| `scripts/swiat/` | generator biomu, pojemniki z łupem, wyjścia, efekty, migające lampy |
| `scripts/ui/` | HUD, ekran ekwipunku, handel, menu pauzy, sceny |
| `assets/dane/` | `przedmioty.json` (przedmioty, tabele łupu, frakcje), `meble.json` |
| `assets/` | tekstury, modele `.glb`, ikony, dźwięki, czcionki |
| `narzedzia/` | generatory assetów w Pythonie (tekstury, modele, meble, ikony, dźwięki) |
| `tests/` | testy automatyczne |
| `shaders/` | shader PS1 (drgające wierzchołki, afiniczne tekstury) i post-process (dithering) |

Wszystkie assety są generowane kodem: `python3 narzedzia/generuj_tekstury.py`, `generuj_ikony.py`,
`generuj_dzwieki.py`, a w katalogu `narzedzia/`: `generuj_modele.py` i `generuj_meble.py`.
Nowe przedmioty dodaje się w `assets/dane/przedmioty.json` (ikona: `generuj_ikony.py`).

## Testy

```
godot --headless --path . res://tests/sprawdz.tscn            # parsowanie wszystkich skryptów
godot --headless --path . res://tests/test_ekwipunek.tscn     # siatki, stosy, waga, zapis
godot --path . res://tests/test_ui.tscn                       # przeciąganie w ekwipunku
godot --headless --path . res://scenes/rajd.tscn -- --test --ziarno 31   # generator + spójność nawigacji
godot --headless --path . res://scenes/rajd.tscn -- --walka   # starcie z oddziałem
godot --headless --path . res://scenes/rajd.tscn -- --test --sluch   # kto reaguje na strzał ze środka mapy
godot --path . res://scenes/rajd.tscn -- --zrzuty <katalog>   # zrzuty ekranu
godot --headless --path . res://scenes/rajd.tscn -- --test_bron   # klawisze broni i latarki
godot --path . res://scenes/rajd.tscn -- --posterunek <katalog>  # posterunki wojska i korytarze
godot --path . res://scenes/rajd.tscn -- --postacie <plik.png>   # przeciwnicy w pozach
godot --path . res://scenes/rajd.tscn -- --vm <katalog>          # fazy przeładowania
```

Testy używają osobnego pliku zapisu i nie ruszają zapisu gracza.

## Budowanie

```
godot --headless --path . --export-release "Windows Desktop" build/windows/StrefaK12.exe
godot --headless --path . --export-release "Linux" build/linux/StrefaK12.x86_64
```

Wymaga szablonów eksportu Godota 4.6.1.

## Licencje

Kod i assety: autorzy projektu. Czcionki DejaVu: licencja w `assets/fonty/LICENCJA.txt`.
