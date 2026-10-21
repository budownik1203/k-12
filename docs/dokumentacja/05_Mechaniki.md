nr: 05
tytul: Dokument mechanik
podtytul: Wszystkie systemy gry: jak działają, liczby, dlaczego tak, gdzie w kodzie, co można rozwinąć i co wcześniej się nie udało.
stempel: ОТК · SPRAWDZONO
---

# Jak czytać

Każdy system ma te same części: **Co to** (opis z perspektywy gracza), **Liczby**, **Dlaczego** (cel projektowy), **Kod** (gdzie szukać), **Rozwój** (pomysły) i **Historia** (wcześniejsze wersje, które nie wyszły, i powód). Wartości liczbowe zebrane razem są też w dokumencie *Balans*.

# 1. Ruch i postawa

**Co to.** Ruch ciężki i bez poślizgu: szybkie zatrzymanie, wolne rozpędzanie (zwłaszcza z obciążeniem), kołysanie głowy w rytm kroków, przechył przy skręcie, ugięcie po lądowaniu. Kucanie, wychylenia Q/E, skok, przełażenie przez niskie przeszkody, ostrożny krok, obrażenia od upadku.

**Liczby.**
| Parametr | Wartość |
| --- | --- |
| Marsz | 1,7 m/s (w tył ×0,65, bokiem ×0,82) |
| Bieg (trucht) | 3,5 m/s, męczy (wytrzymałość 0–100) |
| Kucanie | 0,85 m/s, wzrost oczu 0,98 m (stojąc 1,62 m) |
| Ostrożny krok [Alt] | 0,9 m/s, prawie bezgłośny |
| Przełażenie [spacja przy przeszkodzie] | przeszkody do 1,15 m, wolne i głośne, bez strzelania |
| Ciągnięcie zwłok [Z] | 0,55 m/s, broń schowana, szuranie słychać, męczy |
| Progi obciążenia | lekki < 18 kg, obciążony < 28 kg, przeciążony < 40 kg, krytyczny ≥ 40 kg |
| Zmęczenie rajdem | po 30 min w strefie siły wracają coraz wolniej |

**Dlaczego.** Wolny ruch czyni z każdego korytarza decyzję i nadaje wagę mapie (rajd 25–40 min). Obciążenie zamienia łup w realny koszt mobilności.

**Kod.** `scripts/gracz/gracz.gd` (`_ruch`, `prog_obciazenia`, `_przelaz`, `ostroznie`), stałe `PREDKOSC_*`.

**Rozwój.** Zmęczenie nóg przy złamaniu (już spowalnia), ślizganie na rozlanych płynach, przejścia przez okna.

**Historia.** Do v0.15 marsz 2,45 m/s, bieg 4,5 m/s, kucanie 1,2 – rajd był za szybki, korytarze „przelatywało się”. Użytkownik chciał gry „wolniejszej, bardziej ociężałej” – tempo obniżono dla gracza i wrogów. **Leżenie** i **wstrzymywanie oddechu** świadomie odrzucone (leżenie łamie skalę ciasnych wnętrz i AI; wstrzymanie oddechu bez dużych dystansów nie ma sensu).

# 2. Interakcja: krótkie F i chwyt

**Co to.** [F] krótko = czynność (przeszukaj, rozmawiaj, zdejmij pułapkę, wyjmij klin, szarpnij klamkę). [F] przytrzymane (> 0,22 s albo ruch myszy) = **chwyt**: mysz porusza chwyconą rzeczą. Przy celowniku ikonka: otwarta dłoń (można coś zrobić) albo zaciśnięta ze strzałkami (można chwycić i przesunąć). Podświetlenie obiektu narożnikami.

**Dlaczego.** „Jeden sposób na jedną rzecz”: fizyczne rzeczy obsługuje ręka, a szybkość ręki = hałas.

**Kod.** `gracz.gd` (`_obsluz_chwyt`, `_interakcje`, `rodzaj_celu`), obiekty mają `tekst_interakcji`, `interakcja`, a chwytne `chwyc`, `chwyc_ruch`, `pusc_chwyt`, `mozna_chwycic`, `przejmuje_mysz`.

**Historia.** Do v0.16.2 drzwi otwierało też krótkie F (dwa sposoby na to samo). W v0.16.3 drzwi tylko ręką; w v0.16.4 to samo dla mebli. Kropka celownika usunięta (v0.16.3) – zostały tylko ikonki dłoni. Wcześniej (v0.9.19–v0.16.0) HUD przez błąd był stale ukryty (ekran ekwipunku liczył się jako otwarty).

# 3. Drzwi

**Co to.** Skrzydła w otworach: fornir, emalia z szybą, skaj z guzikami, metalowe z nitami (wg typu pomieszczenia). **Otwieranie tylko ręką:** przytrzymaj F i pchnij/pociągnij myszą – powoli cicho (szpara do podglądu), szybko głośno; puszczone skrzydło toczy się siłą rozpędu i może trzasnąć. Zamknięte na klucz albo zaklinowane z drugiej strony **nie wyglądają inaczej** – dopiero naciśnięcie klamki (ciche szarpnięcie) to zdradza. Wtedy: wytrych (zręcznościówka) albo kopniaki (hałas, drzazgi). Podsłuch pod drzwiami (niepewny: ±1 osoba, 20% ciszy). Drewniane drzwi przestrzeliwane, metalowe nie. Skrzydło nie przechodzi przez ludzi i opiera się o przesuwne przedmioty (barykada).

**Liczby.** Wytrych: 3 haczyki w komplecie, metalowe drzwi węższy zakres (±7° zamiast ±12°). Klin: blokuje od swojej strony, wróg wyważa jak zamknięte.

**Kod.** `scripts/swiat/drzwi.gd`, `scripts/ui/wytrych_ui.gd`.

**Rozwój.** Łom jako trzeci sposób (szybszy od wytrycha, cichszy od kopniaków), zamki szyfrowe w biomie wojskowym, okienko w drzwiach do podglądu.

**Historia.** v0.9.11: klamka (F), uchylanie kucając. v0.16.0: fizyczne skrzydło przy przytrzymaniu. v0.16.3: tylko ręką + nieznany stan zamka (wcześniej napis zdradzał „zamknięte na klucz” z daleka). v0.16.4: po otwarciu zamka wytrychem trzymany LPM od razu strzelał – sterowanie wraca dopiero po puszczeniu przycisku.

# 4. Meble i przeszukiwanie

**Co to.** Meble-pojemniki (szafa, szafka ubraniowa, meblościanka, szafka kuchenna, lodówka, biurko z szufladami, skrzynie z wiekiem, apteczka ścienna) **otwiera ręka** (F + mysz do siebie; od siebie domyka). Otwarty mebel przeszukuje krótkie F: postać zwraca się ku wnętrzu, przy niskich przyklęka, kafelki zawartości leżą we wnętrzu modelu, **zawartość odkrywa się stopniowo** (czas wg rozmiaru przedmiotu i światła – po ciemku 2× dłużej, przedmioty jako cienie). Grzebanie słyszą wrogowie. Kłódki: wytrych (cicho) albo wyłamanie narzędziem (kombinerki, klucz nastawny) lub kolbą (długo, głośno). Pierwsze otwarcie starego mebla wzbija kurz. Zamknięcie ekwipunku zostawia mebel otwarty.

**Zwłoki:** przeszukiwane część po części (kieszenie kurtki, spodni, ładownice, chlebak); broń wypada z rąk i leży obok; pancerz i hełm trzeba odpiąć i zdjąć (animacja). Zabity pada jako ragdoll (11 brył) – każda część ciała to pole przeszukania.

**Kod.** `scripts/swiat/pojemnik.gd`, `scripts/swiat/modele_mebli.gd`, `scripts/ai/ragdoll.gd`.

**Historia.** Do v0.16.3 mebel otwierał się jednym F razem z przeszukaniem; zamknięcie ekwipunku domykało mebel. Zmienione na rękę dla spójności z drzwiami.

# 5. Ekwipunek

**Co to.** Sloty na ciele (broń główna, pistolet, hełm, pancerz, kamizelka, plecak, 1–4 sloty wyposażenia: pas + 0–2 z kamizelki, kieszenie spodni 8x2, kontener bezpieczny 4x4). Drobna siatka (kratka 17 px), obracanie [R], stosy, dzielenie Shift+klik, redukcja wagi pojemnika. Ekran ekwipunku **nie zatrzymuje gry**.

- **Plecak na plecach jest niedostępny** – przeładowanie, leki, napełnianie i podnoszenie sięgają tylko do kamizelki i kieszeni. Pełny wgląd: **Zdejmij** – postać przyklęka, kładzie plecak przed sobą zapięty, każdą kieszeń otwiera się osobno. Rozłożony plecak zostaje na ziemi, gdy gracz ucieka albo dostanie kulę (wraca się po niego, F zakłada). Wrogowie mogą go zabrać.
- **Kieszenie z zapięciami (gest myszą):** klamra/zatrzask/guzik – klik; klapa, rzep, kołnierz – przeciągnięcie w górę (szybko = głośno); zamek – suwak w bok; ściągacz – odciągnięcie blokady sznurka od środka na zewnątrz. Zapinanie odwrotnie. Stan zapamiętany przy pojemniku i w zapisie. Opcja „proste otwieranie kieszeni” (klik).
- **Głośność zapięć:** rzep słychać przez pokój, zamek i guzik cicho.
- **Otwarte kieszenie gubią zawartość** w biegu, przy skoku, upadku i trafieniu (rzep/zatrzask 3,5%, guzik 3%, zamek 1,5%, klapa 5%, ściągacz 4,5% na zdarzenie).
- **Szybkie zerknięcie na kamizelkę** (2× Tab) – tylko ładownice; trwa chwilę; podsumowanie zawartości plecaka.
- **Przekładanie trwa** wg wagi, rozmiaru i odległości (0,35–1,5 s), przedmiot sunie po ekranie; trafienie w trakcie – wypada. Ctrl+klik ustawia kolejkę (tyle co ręcznie + 0,6 s na wymacanie miejsca).
- **Przeciąganie z podświetleniem celu:** niebieski – składanie (amunicja ↔ magazynek, dodatek na broń, magazynek do broni), pomarańczowy – stos, biały – zamiana miejscami / włożenie do pojemnika.
- **Łup z ziemi chwytany ręką** przy otwartym ekwipunku; upuszczony poza oknami ląduje pod kursorem.
- **Nieznane przedmioty** („metalowy drobiazg”, „pakunek”) – obejrzenie z animacją, po ciemku się nie da; **nieprzeliczone magazynki** („pełny?”, „~½+”, „mało”).
- **Brzęk luźnego metalu** w plecaku przy biegu (słyszą wrogowie), taśma izolacyjna wycisza.
- Oznaczanie ★ (nie wyrzucisz przypadkiem), podgląd wagi po wzięciu łupu.

**Dlaczego.** Ekwipunek ma być **ciężki i odsłaniający** – zarządzanie nim w rajdzie to ryzyko. Celowo **nie ma „weź wszystko”**.

**Kod.** `scripts/core/ekwipunek.gd`, `siatka.gd`, `przedmiot.gd`, `scripts/ui/ekran_ekwipunku.gd` (największy plik), `siatka_ui.gd`, `modele_oporzadzenia.gd` (modele 3D pojemników z blend shape), `rozlozenie_3d.gd`.

**Historia (co nie wyszło).**
- v0.9.2: **animowana dłoń przy każdym przełożeniu** (sięga, chwyta, niesie łukiem) – wyglądało efektownie, ale zasłaniało ekran, myliło przy szybkich ruchach i wydłużało każdą czynność bez wartości. Zastąpione w v0.9.16 przesuwaniem przedmiotu po ekranie.
- v0.9.17: **dłoń przy zapięciach** – wyłączona w v0.9.24 (zasłaniała element, który się chwyta).
- v0.9.16–0.9.23: **prostokąty kieszeni z podpisami i pierścienie ze strzałkami** – za dużo „UI” na modelu; zastąpione subtelną poświatą krawędzi chwytanego elementu (v0.9.24).
- v0.9.21: **gruba siatka** (dawna kratka = 2x2 nowe) – przedmioty miały nierealne proporcje (bandaż jak magazynek). Migracja zapisów skryptem `narzedzia/rozdrobnij_siatki.py`.
- Błędy przechwytywania: obszar otwartej kieszeni łapał kliknięcia w sloty (v0.14), siatki mebla i kamizelki nachodziły na siebie (v0.16.1), obrócony przedmiot nie wchodził na własne miejsce (v0.16.1), plecak turystyczny miał kieszenie bez przerw – przedmiot leżał na dwóch naraz (v0.16.4).

# 6. Broń i walka

**Co to.** Hitscan z rozrzutem, celowanie przez przyrządy (przezierne), odrzut na sprężynach (szarpnięcie i powrót z przestrzeleniem, profil pistolet/karabin/obrzyn), wzór odrzutu w serii, bezwładność broni (cięższa zostaje w tyle przy obrocie), oddech i drżenie (zmęczenie, rany, stres, alkohol), lufa przy ścianie blokuje strzał, podparcie broni o krawędź (odrzut ok. −40%, ręce prawie się nie męczą). Tryby ognia [B], nabój w komorze, przeładowanie zwykłe i szybkie (stary magazynek spada), ładowanie pojedyncze obrzyna, **sprawdzanie amunicji [T] trwa** (okienka magazynka). Zacięcia (rzadkie, częstsze przy seriach i brudzie) usuwane [R] choreografią. Zużycie: każdy strzał brudzi (tłumik bardziej), kurz po rajdzie. Broń nisko [V] (swoboda, złożenie 1,7× dłużej) / wysoko (ręce się męczą). Zmęczenie rąk przy długim celowaniu.

**Przeładowania jako choreografia** (lewa dłoń, magazynek, naboje, łuski jako obiekty): KB-47 – magazynek wychylany na zaczepie, rączka zamka przeciągana; PW-9/PM-63 – magazynek w osi chwytu, dobicie dłonią, zamek górą; obrzyn – dźwignia, lufy opadają, wyciąg podnosi łuski, dłoń wyjmuje je i wkłada naboje. Z latarką w lewej ręce (chwyt Harriesa) dłoń z latarką sięga po magazynek, snop ucieka na podłogę.

**Liczby (broń).**
| Broń | Kaliber | Tryby | RPM | Rozrzut biodro / ADS | Odrzut | Przeładowanie | Magazynek |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PW-9 Kruk | 9x18 | pojedynczy | 380 | 2,4° / 0,55° | 1,9 | 2,1 s | 8 |
| PM-63 Rak | 9x18 | auto, pojedynczy | 650 | 3,0° / 1,0° | 1,15 | 2,5 s | 25 |
| KB-47 Kałach | 7,62x39 | auto, pojedynczy | 600 | 3,6° / 0,35° | 2,3 | 2,9 s | 30 |
| Obrzyn 12/70 | 12/70 | pojedynczy | 300 | 2,6° / 1,8° (śrut 3,8°) | 6,0 | 1,2 s / nabój | 2 lufy |

**Penetracja.** Pancerz klasy K o wytrzymałości w/max ma skuteczną klasę `K · (0,45 + 0,55·w/max)`, próg = klasa·10. Szansa przebicia = `0,5 + (penetracja − próg)/14`, ograniczona do 3–97%. Przebicie: 82% obrażeń, pancerz traci `pen·0,12`. Zatrzymanie: 12% obrażeń + 1 (stłuczenie: ból, drżenie, wybity oddech), pancerz traci `obr·0,07` (odłamek: `obr·0,35+1`). 3 kule zatrzymane przez płytę w 25 s → pęknięte żebro (złamanie klatki).

**Hełm:** rykoszet ok. 35% (zależnie od stanu) z ogłuszeniem; śmiertelny strzał w głowę w hełmie – hełm przyjmuje kulę i niszczy się, gracz przeżywa ogłuszony. Bez hełmu strzał w głowę zabija.

**Dodatki (4 sloty):** wylot (tłumiki PBS-9 / PBS-1: hałas ×0,35/×0,45, bez płomienia; hamulec KH-1: odrzut ×0,72, hałas ×1,25), celownik (kolimator: rozrzut ADS ×0,75; luneta PSO 4x: ×0,55, zoom), chwyt (RK-3: odrzut i rozrzut z biodra ×0,82), latarka taktyczna. Polowe zakłada się w terenie (3–5 s z animacją), celowniki i chwyt tylko na stole roboczym.

**Granat F-1:** obrażenia 130, promień 7,5 m, zapalnik 3,6 s; [G] rzut, kucając toczy; odbicia, odłamki szarpią pancerz, ogłuszenie, wyważa drzwi.

**Odczucie strzału:** płomień z lufy (gwiazda z płatkami, przy celowaniu pusty środek), dym, łuski, kopnięcie kamery, pogłos wg pomieszczenia, odległe trafienia słychać z opóźnieniem, krew na ścianach, dziury po kulach wg materiału (do 200 na rajd), kurz w powietrzu przy serii w ciasnym pomieszczeniu (zasłania wzrok wrogów).

**Kod.** `scripts/gracz/bron.gd`, `przeladowania.gd`, `choreografia.gd`, `scripts/core/balistyka.gd`, `scripts/swiat/granat.gd`, `efekty.gd`.

**Rozwój.** Druga broń długa (strzelba pompowa, karabin wyborowy), magazynki bębnowe, kolby, naprawa broni u Zbrojmistrza, amunicja smugowa.

**Historia.** Natychmiastowe [T] zastąpione sprawdzaniem trwającym chwilę (ankieta mechanik). **Znacznik trafienia (hit marker) i dźwięk trafienia** usunięte w v0.16.0 – o trafieniu mówi tylko to, co widać i słychać. Napis „podparta” usunięty w v0.16.4. W v0.12 sprawdzanie magazynka obracało broń o 35° do kamery – wyglądało jak podmiana broni; poprawione na lekki przechył.

# 7. Ciało, zdrowie i leczenie

**Co to.** 5 części ciała (głowa 35, klatka 85, brzuch 70, ręce 60, nogi 65 HP). Krwawienie lekkie (0,55 HP/s) i ciężkie (1,7 HP/s), złamania (ręce – drżenie, nogi – kulenie, klatka – szybsze męczenie), ból (drżenie celownika), stłuczenie po zatrzymanej kuli, ogłuszenie. Śmierć: zniszczona głowa lub klatka albo wykrwawienie. Leczenie z animacją rąk i czasem, na wybraną część ciała (panel ciała), przerywane [X], kolejka do 3 czynności. Urazy przenoszone do bazy (Medyk leczy za bony, prycza połowę raz po rajdzie).

| Lek | Efekt | Czas | Użycia |
| --- | --- | --- | --- |
| Bandaż | lekkie krwawienie | 3 s | 1 |
| Opatrunek hemostatyczny | ciężkie krwawienie | 5 s | 1 |
| Szyna Kramera | złamanie | 6 s | 1 |
| Bólostop | ból na 180 s | 2 s | 4 |
| Apteczka AI-2 | +20 HP na raz | 2,5 s | 100 HP |

Przeterminowane leki (30% w szafkach, lata 1974–1986) działają wolniej i czasem wcale.

**Stres (0–1):** kule obok głowy (smuga toru przez kadr, rozmycie, szarpnięcie głowy), trafienia, bliskie wybuchy → drżenie broni, serce i szybki oddech, czynności wolniejsze; opada powoli. **Przygniecenie:** ostrzał tuż obok – ciemne obrzeża kadru (tunel widzenia), gorsza celność.

**Głód i pragnienie (0–100):** spadają w rajdzie (głód 0,012/s, pragnienie 0,02/s, szybciej w biegu); niskie spowalniają odzyskiwanie sił, zerowe odbierają zdrowie z brzucha. Wyjście do strefy kosztuje −10 / −14. Jedzenie i picie z animacją (konserwa +38 głodu −8 pragnienia, suchary +22/−10, woda +45 pragnienia, wódka −10 pragnienia, gasi ból, ręce drżą).

**Kod.** `scripts/core/cialo.gd`, `gracz.gd` (`_potrzeby`, `stres`, `przygniecenie`), `animacje_akcji.gd`, `scripts/ui/panel_ciala.gd`.

**Historia.** Pęknięte żebro miało być osobnym stanem (mniej wytrzymałości do bazy) – użytkownik zdecydował, że to **zwykłe złamanie leczone szyną**. Animacja picia miała butelkę odwróconą (szyjka od twarzy) – poprawione w v0.16.6.

# 8. Ruch, hałas i skradanie

**Co to.** Kroki wg podłoża (lastryko, parkiet ze skrzypnięciem, kafle, beton – po 4 warianty, też u wrogów), szelest ubrania, zadyszka przy niskiej wytrzymałości (słyszalna), brzęk metalu, głośność zapięć, otwieranie drzwi i mebli wg prędkości ręki, grzebanie w meblach, przeładowania w fazach. **Dźwięk niesie się po drodze** (siatka nawigacji, zakręty tłumią), okluzja zza ścian, pogłos wg pomieszczenia słuchacza. Światło: lampy sprawne, migające, zepsute, światła awaryjne, wyłączniki przy wejściach (ciemny pokój jako zasadzka – ale wróg zauważy zgaszone światło). Latarka trzymana w lewej ręce (sama albo pod pistoletem), taktyczna na broni – świeci tam, gdzie celujesz, więc wiedzą, gdzie celujesz.

**Kod.** `scripts/autoload/dzwiek.gd`, `Balistyka.odleglosc_dzwieku`, `Gra.emituj_halas`, `scripts/swiat/wylacznik.gd`, `migotanie.gd`.

# 9. Orientacja i wiedza

**Co to.** Brak minimapy i znaczników. Narzędzia:
- **Strzałki sprayem** do wyjść co ok. 12 m wzdłuż ścieżek ze startu i z 8 losowych punktów (kolory wg wyjścia), też fałszywe strzałki szabrowników (do 3 na mapę, z podpisem „kurza łapka”).
- **Własny spray** (12 użyć): strzałki, krzyżyk, wykrzyknik – zostają do końca rajdu.
- **Mapa strefy** na slocie wyposażenia: [O] wyjmuje ją do rąk (broń schowana, marsz powoli), plan widać po rozłożeniu kartki – odwiedzone pomieszczenia (też piętro), zauważone strzałki, wyjścia i ich stan.
- **Kompas** na slocie: pasek kierunków u góry ekranu; znaczniki wyjść tylko z rozłożoną mapą (mapa + kompas = namiar).
- **Zegarek [H]:** podniesienie nadgarstka – zdrowie na tarczy (krzyżyk zielony/żółty/czerwony, miga przy krwawieniu); z zegarkiem Rakieta w ekwipunku dokładny czas rajdu i okna czasowe wyjść, bez niego „ok. N min”.
- **Meldunki** przed rajdem: stół z mapą w kryjówce (przekłamania maleją z reputacją u Wojska), Pośrednik (pewny meldunek za 1800 bonów).
- **Podsłuch** pod drzwiami (niepewny).

**Historia.** v0.13: [O] pokazywało listę wyjść z kierunkiem i odległością. v0.16.0: bez kierunku i odległości. v0.16.3: lista usunięta całkowicie – „zegarek i mapa to rzeczy, nie nakładki”. Kompas pokazywał kierunki wyjść przy samej liście – też usunięte. **Znaki gracza zostające na kolejny rajd o tym samym ziarnie** – odrzucone przez użytkownika.

# 10. Pułapki i przygotowanie terenu

| Pułapka | Zastawienie | Działanie | Kontra |
| --- | --- | --- | --- |
| Granat w szklance | F-1 + szklanka, PPM na granat przy zamkniętych drzwiach (≤1,8 m), 5 s | otwarcie drzwi zrzuca szklankę, łyżka odskakuje, wybuch po 2,3–2,8 s; działa na każdego | rozbrojenie F od strony pułapki (4,5 s; po ciemku 1,8× dłużej, 12% porażki) |
| Potykacz | granat + drut z kołkami, 7 s, w poprzek przejścia | kto zahaczy nogą (stopy < 0,22 m nad drutem) – wybuch | przeskoczenie, zdjęcie przy kołku z granatem; drut skrzy się w świetle latarki |
| Klin | z ekwipunku pod drzwi | drzwi zablokowane od drugiej strony | wyważanie kopniakami (słychać) |
| Barykada | przesuwne przedmioty przed drzwiami | skrzydło się opiera | wróg napiera i spycha (głośno) |
| Ciemność | wyłącznik światła | wrogowie gorzej widzą | wróg zapala światło, gdy zauważy |

Wybuch strąca szklanki z klamek do 6 m i szarpie druty do 4 m (łańcuch), trzaśnięcie drzwi może strącić szklankę z sąsiednich. Wrogowie mogą zauważyć pułapkę (patrz *Świat gry*) i zabrać granat. Zabójstwa z pułapek zaliczane graczowi.

**Kod.** `scripts/swiat/pulapka.gd`, `potykacz.gd`, `drzwi.gd` (klin), `przesuwny.gd`.

# 11. Przedmioty fizyczne (przesuwne)

**Co to.** Skrzynki (14 kg), krzesła (5 kg), beczki (32 kg), szafki (42 kg) jako bryły fizyczne przy ścianach pomieszczeń. Przytrzymaj F – lekkie (< 15 kg) niesiesz na wysokości piersi, ciężkie ciągniesz po podłodze (wolno, szuranie słychać, spowalnia marsz). Zasłaniają przed kulami i wzrokiem, tworzą barykady. Wrogowie odpychają je z drogi. Straż przed „lewitacją”: przedmiot zawieszony w powietrzu sam spada na podłogę.

**Historia.** v0.16.3: zgłoszony „blok w powietrzu” – niesiona skrzynka szła przed oczy i zasłaniała widok; teraz na wysokości piersi.

# 12. Placówka: kryjówka, handel, zlecenia

- **Tryb budowy [B]** w kryjówce (podgląd, siatka 10 cm, obrót 15°, dociąganie do ścian, przestawianie i zabieranie; zabranie mebla, które ucięłoby przedmioty w skrytce, jest odrzucane).
- **Skrytka:** 20 kolumn × (10 + rzędy z mebli), maks. 64.
- **Stół roboczy:** montaż celowników i chwytu; **elaboracja** (prasa 8 użyć: 9x18 ×20 / 12/70 ×10 za 1 proch, 7,62 ×15 za 2 proch); **łaty pancerza** tkaniną (pełna wytrzymałość do nowego maksimum −10% za łatę, wartość −15%).
- **Sen** na pryczy/wersalce: połowa ran raz po każdym powrocie. **Kuchenka:** jedzenie ×1,5 sytości, woda jako herbata.
- **Zlecenia:** dostawa, eliminacja, zwiad, wyjście; po 2 od każdej frakcji + Pośrednik, maks. 3 przyjęte; zabójstwa liczą się tylko ofiary gracza.
- **Ubezpieczenie** u Pośrednika: 18% ceny (min. 300) – przy zgonie przedmiot wraca pocztą (bez naboi).
- **Zestaw z przydziału** przy braku broni (nie do sprzedania).
- **Kontener bezpieczny** – zawartość przetrwa śmierć.

**Historia.** Darmowy zestaw startowy był **maszynką do bonów** (sprzedaj → weź nowy) – od v0.10 sprzęt z przydziału jest nie do sprzedania. Do v0.11 zabójstwa w wojnie frakcji (bez udziału gracza) psuły reputację i nabijały zlecenia. W v0.16.4 przyciski listy budowy nie działały (panel był w podglądzie 3D bez myszy), a kropka na środku ekranu bazy łapała kliknięcie LPM.

# 13. Generator strefy

**Co to.** Siatka GW×GH = 11×8 komórek po 9 m. Korytarze (szerokość 3,2 m) to kwadrat w środku komórki + ramiona do sąsiadów. Pomieszczenia losowej wielkości (5,6–8,3 m) w obrębie komórki, mur gruby (drzwi z korytarza w murze 0,45 m, otwór 1,2 x 2,1 m), część pomieszczeń łączą drzwi albo szerokie otwory. Wysokość 3,0 m, strop 0,6 m (lity – kule, odłamki, wzrok i światło nie przechodzą), piętro na 3,6 m, klatka schodowa z biegiem 18 stopni. Typy pomieszczeń losowane wg głębokości (bliżej startu mieszkania i kuchnie, głębiej piwnice, magazyny, warsztaty). Okna na ścianach zewnętrznych (do 2 na pomieszczenie). Meble w zestawach wg typu, łup losowany z tabel (*Przedmioty*). Detale korytarzy (rury, listwy, puszki z kablami, zacieki, śmieci) tylko na murze. Naklejki z atlasu (35 wzorów) kładzione tylko na płaskiej ścianie. Walidacja: po wypieczeniu nawigacji każde pomieszczenie musi być osiągalne.

**Wydajność.** Geometria osobno dla każdego pomieszczenia (renderer Compatibility oświetla obiekt najwyżej kilkunastoma światłami), widoczność ok. 46 m, świecą tylko światła kondygnacji gracza i najwyżej 40 najbliższych, cienie od 3 najbliższych lamp.

**Kod.** `scripts/swiat/generator.gd`, `scripts/ui/scena_rajd.gd` (`_generuj_kondygnacje`, `_przedmioty_i_wylaczniki`), `naklejki.gd`.

**Historia (błędy, które wyszły w grze).** Okna w połowie kierunków ścian odwrócone licem na zewnątrz (przez otwór widać było pustkę i budynek od środka) – v0.16.3. Lampy „zapalały się” dopiero z bliska (za dużo świateł obu kondygnacji naraz) – v0.16.3. Listwy i puszki z kablem w skrzyżowaniach biegły przez przejścia (czarne paski na podłodze, „wiszący przełącznik”), wyłącznik przyklejał się do skrzydła drzwi, plakaty wisiały na niewidzialnej kolizji okna – v0.16.6. Pierwotnie cały poziom był jedną siatką – dalsze lampy gasły (limit świateł na obiekt).

# 14. Oprawa i technika

- Styl **Iron Blight**: pełna rozdzielczość, oświetlenie per piksel, tonemapping filmic, bloom, MSAA; pikselowe są **tekstury** (~64 px/m, ostre piksele).
- **Wszystko generowane kodem:** modele (bryły fazowane i walce), tekstury (Python), dźwięki (Python), ikony-szkice (render 3D → rysunek tuszem z paskami cieniowania, pieczątki, papier wg kategorii).
- Dźwięk: kroki, pogłos, okluzja, głosy wrogów, tło strefy (brzęczenie świetlówek, kapanie, skrzypienie, odległe strzelaniny, wiatr), dron napięcia.
- Ustawienia: czułość, FOV, głośność, kołysanie kamery, skala renderu, skala interfejsu, odwrócona oś Y, cienie, wygładzanie, samouczek, FPS, proste kieszenie, **pełny ekran (F11 / Alt+Enter)**.

**Historia.** Wczesne wersje renderowały świat w **niskiej rozdzielczości (SubViewport w stylu PS1, skalowany bez wygładzania)**. Kierunek zmieniono na styl Iron Blight (referencja wskazana przez autora): natywna rozdzielczość okna, oświetlenie per piksel, a „pikselowość” przeniesiona do tekstur. Mechanizm SubViewport został (`scripts/core/widok.gd`). Ikony: kreskowanie krzyżowe dawało morę w małej skali – zastąpione paskami (v0.9.23).

# 15. Odrzucone pomysły (z ankiety 32 propozycji)

| Pomysł | Dlaczego odrzucony |
| --- | --- |
| Zamykająca się strefa | dubluje wyjście czasowe i rosnące zagrożenie |
| Ciało poprzednika (odzyskiwanie sprzętu) | kłóci się z ubezpieczeniem u Pośrednika |
| Zakład z Pośrednikiem | koliduje z kontraktami handlarzy |
| Znaki gracza na kolejny rajd | odrzucone przez użytkownika |
| Leżenie | skala wnętrz, AI, czytelność |
| Wstrzymanie oddechu | bez dużych dystansów nie ma sensu (do powrotu przy większych mapach) |
| „Weź wszystko” | sprzeczne z filarem ciężkiego ekwipunku |
