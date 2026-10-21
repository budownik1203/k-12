nr: 01
tytul: Dokument ogólny
podtytul: Zarys całości: czym jest Strefa K-12, dla kogo, jakie ma filary i co ją wyróżnia na tle gatunku.
stempel: ZATWIERDZONO
---

# Strefa K-12 w jednym akapicie

**Strefa K-12** to taktyczna strzelanka PvE z mechaniką *extraction* w pierwszej osobie, w stylistyce low poly z ery PS1, osadzona w alternatywnym bloku wschodnim. Gracz – kontraktowy „operator” – wychodzi z placówki przy granicy strefy kwarantanny, wchodzi do za każdym razem inaczej złożonego budynku (biom 1: Blokowisko), szuka łupu, unika albo walczy z frakcjami i fauną, a potem musi **wyjść żywy** przez jedno z wyjść. Śmierć oznacza utratę wszystkiego, co miał przy sobie. Zdobyty łup sprzedaje się w placówce, za bony kupuje lepszy sprzęt, meble do kryjówki i reputację u frakcji – i wraca do strefy.

Gra jest **celowo wolna, ciężka i fizyczna**: rzeczy obsługuje się ręką (drzwi, szafki, kieszenie plecaka), czynności trwają i odsłaniają gracza, a interfejs nie podaje wiedzy, której postać nie mogłaby mieć.

| Cecha | Opis |
| --- | --- |
| Gatunek | taktyczny FPS, extraction, PvE, survival-lite |
| Perspektywa | pierwsza osoba (ręce i broń w kadrze), bez trzeciej osoby |
| Tryb | jednoosobowy, rajdy 25–40 minut |
| Silnik | Godot 4.6.1, renderer Compatibility (OpenGL), GDScript |
| Platforma | Windows (wydania), Linux (z kodu źródłowego) |
| Stan | grywalne demo, wersja v0.16.6, jeden biom, pełna pętla gry |
| Język gry | polski (z wtrąceniami rosyjskimi w dokumentach i graffiti) |
| Grafika | low poly, pikselowe tekstury (~64 px/m), oświetlenie per piksel – styl „Iron Blight” |

![Rajd – przeciwnicy w korytarzu (zrzut z wczesnej wersji)](../zrzuty/rajd_przeciwnicy.png)

# Wizja i fantazja gracza

Gracz ma czuć się jak **człowiek z przydziału, wysłany tam, gdzie nikt rozsądny nie chodzi**. Nie jest superżołnierzem: jest ciężko obładowany, męczy się, drżą mu ręce, gdy kule świszczą obok głowy, a każde otwarcie zapiętej kieszeni słychać na korytarzu. Siła gracza wynika z **przygotowania, cierpliwości i informacji**, a nie z refleksu.

Trzy obrazy, które mają zostać w głowie:

1. **Ciemny korytarz bloku z lat 80.** – lamperia, lastryko, migająca świetlówka, strzałka „BRAMA →” wymalowana sprayem przez poprzednika. Słychać kroki za drzwiami. Gracz powoli, ręką, uchyla skrzydło na szparę.
2. **Kucanie nad zwłokami** – rozpinanie rzepów kamizelki zabitego najemnika, przekładanie magazynków do własnej ładownicy, wiedząc, że hałas grzebania słyszy cały oddział piętro niżej.
3. **Raport urzędowy po powrocie** – sucha, biurokratyczna notatka z pieczątką: „Ostrzeżenie! Zawartość ołowiu w organizmie przekroczyła normę zakładową.”

# Filary projektu

## 1. Ciężar i fizyczność
Wszystko, co postać robi rękami, **trwa i ma koszt**. Przeładowanie to choreografia lewej dłoni, napełnianie magazynka idzie nabój po naboju, plecak trzeba zdjąć, położyć i rozpiąć. Drzwi i meble otwiera się chwytem i ruchem myszy (powoli = cicho). Gracz chodzi wolno (1,7 m/s), rozpędza się ciężko, a obciążenie zmienia wszystko – od tempa po zadyszkę. Szczegóły: *Dokument mechanik*.

## 2. Wiedza zamiast HUD-u
Nie ma minimapy, znacznika trafień, kropki celownika ani listy wyjść „z powietrza”. Zdrowie widać na zegarku na nadgarstku, czas – tylko jeśli ma się zegarek, drogę – ze strzałek na ścianach, mapy trzymanej w rękach i kompasu. Liczba naboi w magazynku jest nieznana, dopóki się go nie sprawdzi. To, czego postać nie wie, gracz też musi zdobyć.

## 3. Strefa żyje bez gracza
Frakcje walczą ze sobą, szabrownicy obszukują ciała, ranni wołają o pomoc, oddziały trzymają kąty, a fauna poluje na wszystkich. Dźwięk niesie się korytarzami (liczony po drodze, nie w linii prostej). Gracz jest tylko jednym z uczestników – czasem najlepiej przeczekać cudzą strzelaninę i zebrać to, co zostało.

## 4. Ryzyko i nagroda extraction
Każdy rajd to decyzja: wyjść teraz z tym, co mam, czy iść głębiej? Śmierć = utrata sprzętu (poza kontenerem bezpiecznym i ubezpieczeniem). Wyjścia są trzy rodzaje: zawsze otwarte, na klucz i czasowe – każde z innym ryzykiem.

## 5. Satyra biurokratycznego absurdu
Ton gry to **czarny humor PRL-owskiej biurokracji**: opisy przedmiotów („Spieszy się o 12 lat.”), powitania handlarzy, komunikaty zgonu i raporty z pieczątkami. Humor nigdy nie łamie realizmu rozgrywki – jest w tekstach, nie w mechanice.

# Co wyróżnia Strefę K-12

| Cecha | Na tle gatunku (Tarkov, Stalker, Iron Blight, Ready or Not) |
| --- | --- |
| Ręczna obsługa świata | drzwi, szuflady, szafy, wieka skrzyń otwierane chwytem i ruchem myszy; prędkość ruchu = głośność |
| Kieszenie jako fizyczne zapięcia | rzep, zamek, klapa, ściągacz, zatrzask – każde otwiera się gestem, ma swoją głośność; otwarte kieszenie gubią zawartość w biegu |
| Brak informacji „za darmo” | bez kropki celownika, hit markera, minimapy; czas tylko z zegarkiem, wyjścia na mapie w rękach |
| Generowane budynki | każdy rajd to inny budynek (2 kondygnacje, 30–60 pomieszczeń), z korytarzami, piwnicami, oknami, meblami w zestawach |
| Proceduralna oprawa | wszystko generowane kodem: modele, tekstury, dźwięki, ikony-szkice w stylu dokumentacji technicznej bloku wschodniego |
| AI z życiem własnym | wojna frakcji, poddawanie się, opatrywanie rannych, szaber, impas na posterunkach, ostrzeżenia sojuszników |
| Pułapki z codziennych rzeczy | granat w szklance na klamce, potykacz z drutu, klin pod drzwi, barykady z mebli, gaszenie światła |
| Klimat | alternatywny PRL / blok wschodni lat 80., satyra urzędowa, a nie postapokaliptyczny chaos |

# Odbiorca

- Gracze **Escape from Tarkov, Stalkera, Ready or Not, Iron Blight**, którzy lubią powolne, napięte tempo i znaczenie każdej decyzji.
- Gracze ceniący **immersję fizyczną** bardziej niż wygodę.
- Polski (i środkowoeuropejski) odbiorca, który rozpozna realia: kartki na mięso, Pewex, meblościanka, lastryko.
- Gra jednoosobowa: dla graczy, którzy chcą klimatu extraction **bez PvP**.

# Pętla gry w skrócie

```
MENU → PLACÓWKA (kryjówka, recepcja: handlarze i frakcje, zlecenia)
     → ROZKAZ WYJŚCIA (ostrzeżenia: głód, rany, magazynki)
     → PRZEMARSZ (generowanie mapy)
     → RAJD (zwiad, łup, walka, pułapki, wyjście)
     → EWAKUACJA albo ZGON / ZAGINIĘCIE
     → RAPORT URZĘDOWY (łup, straty, reputacja, dopiski)
     → PLACÓWKA (sprzedaż, leczenie, meble, reputacja) → …
```

Szczegóły każdego etapu: *Rdzeń gry*. Liczby i ekonomia: *Balans*.

# Zawartość demo (v0.16.6)

| Obszar | Zawartość |
| --- | --- |
| Biomy | 1 – Blokowisko (dwie kondygnacje, ok. 100 x 72 m, 30–60 pomieszczeń, 7 typów pomieszczeń) |
| Frakcje | Szabrownicy, Najemnicy, Wojsko + boss Sęp (dezerter z obstawą) |
| Fauna | pełzacze – mutanty chodzące po ścianach i sufitach |
| Broń | 4: PW-9, PM-63, KB-47, obrzyn 12/70; 7 dodatków w 4 slotach |
| Przedmioty | 75 rodzajów (broń, amunicja, magazynki, leki, pancerze, oporządzenie, łup, narzędzia) |
| Placówka | kryjówka z budowaniem (20 rodzajów mebli), recepcja: 4 handlarzy + 3 przedstawicieli frakcji |
| Systemy | ciało z 5 częściami, krwawienia, złamania, ból, stres, głód i pragnienie, obciążenie, reputacja, zlecenia, ubezpieczenie, elaboracja amunicji, łatanie pancerzy |

![Placówka – recepcja z handlarzami](../zrzuty/baza.png)

# Zasady nadrzędne (dla każdej nowej funkcji)

1. **Czy postać mogłaby to wiedzieć?** Jeśli nie – nie pokazujemy tego na ekranie.
2. **Czy to ma koszt?** Każda czynność trwa, hałasuje albo odsłania. Brak wygodnych skrótów typu „weź wszystko”.
3. **Jeden sposób na jedną rzecz.** Jeśli drzwi otwiera ręka, nie ma osobnego przycisku do otwierania.
4. **Strefa nie czeka.** Menu pauzy nie zatrzymuje rajdu.
5. **Humor w słowach, realizm w mechanice.**
6. **Nie dublować systemów.** Nowa mechanika musi mieć styk z istniejącymi (tabele „Styk z istniejącym” w dokumencie mechanik).

Świadomie **nie robimy**: leżenia, wstrzymywania oddechu, zapisu w trakcie rajdu, PvP, trzeciej osoby, automatycznego „weź wszystko”, znaczników na mapie, które postać nie mogłaby mieć.

# Mapa dokumentacji

| Nr | Dokument | Zawartość |
| --- | --- | --- |
| 01 | Dokument ogólny | ten dokument |
| 02 | Rdzeń gry | pętla: placówka – recepcja – frakcje – rajd – generowanie – raport (przegląd z odnośnikami) |
| 03 | Lore | świat, historia Zakładu i strefy, ton, nazewnictwo |
| 04 | Świat gry: frakcje i przeciwnicy | frakcje, przedstawiciele, AI, fauna, boss, placówka |
| 05 | Mechaniki | wszystkie systemy z liczbami, możliwościami rozwoju i nieudanymi próbami |
| 06 | Przedmioty | pełny katalog 75 przedmiotów, meble, tabele łupu |
| 07 | Balans | ekonomia, obrażenia, pancerze, ciało, tempo, reputacja |
| 08 | Plan rozwoju i historia | roadmapa, historia wersji, co się nie udało i dlaczego |
| 09 | Dla Claude AI | jak dalej rozwijać projekt: środowisko, testy, wydania, konwencje kodu |
