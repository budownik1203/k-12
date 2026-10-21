nr: 06
tytul: Przedmioty
podtytul: Pełny katalog przedmiotów gry (75), mebli w strefie (29) i mebli kryjówki (20): statystyki, opisy, skąd je wziąć, do czego służą.
stempel: ЗАВОД № 7 · WZÓR
---

# Zasady ogólne

- **Rozmiar** w drobnej siatce (kratka ok. 17 px; dawna kratka = 2x2). Przedmioty można obracać [R].
- **Waga** w kg – liczy się do progów obciążenia (18 / 28 / 40 kg); pojemniki redukują wagę zawartości.
- **Cena** w bonach zaopatrzeniowych – cena katalogowa. Skup: Zbrojmistrz 45%, Medyk 50%, Pośrednik 40% (łup 60%), przedstawiciele frakcji 45–55% wybranych kategorii. Broń warta tyle, w jakim jest stanie; łatany pancerz −15%.
- **Ikony** to rysunki techniczne (kategoria = papier i pieczątka): broń (ОДОБРЕНО), części, amunicja (szablon kalibru), pancerze, oporządzenie, medykamenty (czerwony krzyż), żywność (metka z ceną), narzędzia (niebieski blueprint), rupiecie (gazeta).
- **Stany przedmiotu:** zużycie broni (brud → zacięcia), wytrzymałość pancerza, przeterminowanie leków, „nieznany” łup (trzeba obejrzeć), nieprzeliczony magazynek, oznaczenie ★, sprzęt z przydziału (nie do sprzedania).
- Kolumna **Skąd**: handlarze/przedstawiciele (próg reputacji) oraz meble-pojemniki z udziałem w losowaniu i wrogowie.

Ten dokument jest generowany z danych gry skryptem `narzedzia/dokumentacja_przedmioty.py`.

# Broń

Cztery bronie palne. Statystyki strzeleckie – patrz Mechaniki (Broń i walka).

| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |
| --- | --- | --- | --- | --- |
| **PW-9 Kruk** `pw9` | 3x2 · 0.73 kg · 3500 | kaliber 9x18, semi, 380 strz./min, rozrzut 2.4°/0.55°, odrzut 1.90, przeładowanie 2.1 s; dodatki: wylot: Tłumik PBS-9; latarka: Latarka taktyczna ŁT-2 | Pistolet służbowy. Zawodny, ale przynajmniej równie zawodny w obie strony. | Zbrojmistrz; wyposażenie: szabrownicy |
| **PM-63 Rak** `pm63` | 5x3 · 1.80 kg · 14000 | kaliber 9x18, auto/semi, 650 strz./min, rozrzut 3.0°/1.00°, odrzut 1.15, przeładowanie 2.5 s; dodatki: wylot: Tłumik PBS-9; celownik: Kolimator Okular-1; latarka: Latarka taktyczna ŁT-2 | Pistolet maszynowy. Instrukcja obsługi zaleca trzymać go oburącz i modlić się jedną. | Zbrojmistrz; skrzynia wojskowa 1%; wyposażenie: szabrownicy; wyposażenie: najemnicy; wyposażenie: wojskowi |
| **KB-47 Kałach** `kb47` | 8x3 · 3.60 kg · 28000 | kaliber 7.62x39, auto/semi, 600 strz./min, rozrzut 3.6°/0.35°, odrzut 2.30, przeładowanie 2.9 s; dodatki: wylot: Tłumik PBS-1, Hamulec wylotowy KH-1; celownik: Kolimator Okular-1, Luneta PSO-1 4x; chwyt: Chwyt przedni RK-3; latarka: Latarka taktyczna ŁT-2 | Karabinek automatyczny. Strzela zawsze, nawet gdy właściciel już nie może. | Zbrojmistrz; skrzynia wojskowa 1%; wyposażenie: szabrownicy; wyposażenie: najemnicy; wyposażenie: wojskowi |
| **Obrzyn 12/70** `obrzyn` | 6x2 · 2.10 kg · 6500 | kaliber 12/70, semi, 300 strz./min, rozrzut 2.6°/1.80°, odrzut 6.00, przeładowanie 1.2 s; dodatki: latarka: Latarka taktyczna ŁT-2 | Dubeltówka po skróceniu w warunkach domowych. Opinia rzeczoznawcy: nie. | Zbrojmistrz; Szabrownicy; wyposażenie: szabrownicy |

# Dodatki do broni

Montaż polowy (w terenie, z animacją) albo warsztatowy (tylko na stole roboczym w kryjówce).

| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |
| --- | --- | --- | --- | --- |
| **Tłumik PBS-9** `tlumik_9` | 3x1 · 0.25 kg · 9000 | slot wylot, montaż polowy (4 s); hałas ×0.35, obrażenia ×0.95, bez płomienia | Nakręcany w terenie. Strzał brzmi jak trzaśnięcie drzwiami w bloku – czyli normalnie. | Najemnicy (rep. 25); skrzynia 1% |
| **Tłumik PBS-1** `tlumik_762` | 4x1 · 0.45 kg · 16000 | slot wylot, montaż polowy (5 s); hałas ×0.45, odrzut ×0.90, obrażenia ×0.95, bez płomienia | Do karabinka. Nakręcany na gwint, w terenie, w ciemności, drżącymi rękami. | Najemnicy (rep. 45); skrzynia wojskowa 1% |
| **Hamulec wylotowy KH-1** `hamulec` | 2x1 · 0.10 kg · 5000 | slot wylot, montaż polowy (3 s); hałas ×1.25, odrzut ×0.72 | Mniej podrzutu, więcej huku. Sąsiedzi w strefie nie składają skarg. | Zbrojmistrz; Wojsko (rep. 15); skrzynia wojskowa 2% |
| **Kolimator Okular-1** `kolimator` | 2x2 · 0.20 kg · 12000 | slot celownik, montaż warsztat; rozrzut ADS ×0.75 | Czerwona kropka na boczny montaż. Montaż i zerowanie tylko na stole roboczym. | Najemnicy (rep. 20); skrzynia wojskowa 1% |
| **Luneta PSO-1 4x** `luneta` | 4x2 · 0.60 kg · 26000 | slot celownik, montaż warsztat; rozrzut ADS ×0.55, powiększenie | Cztery razy bliżej do problemów. Montaż na stole roboczym, inaczej strzela w sufit. | Wojsko (rep. 55) |
| **Chwyt przedni RK-3** `chwyt` | 1x2 · 0.15 kg · 6000 | slot chwyt, montaż warsztat; odrzut ×0.82, rozrzut z biodra ×0.82 | Pewniejszy chwyt, mniejszy rozrzut z biodra. Wymaga wiercenia łoża – stół roboczy. | Najemnicy (rep. 10); skrzynia wojskowa 1% |
| **Latarka taktyczna ŁT-2** `latarka_taktyczna` | 2x1 · 0.18 kg · 7000 | slot latarka, montaż polowy (3 s); — | Zaciskana na lufie. Świeci tam, gdzie celujesz, więc wiedzą, gdzie celujesz. [L] wł/wył. | Zbrojmistrz; Najemnicy; skrzynia wojskowa 2% |

# Magazynki

Osobne przedmioty; napełnia się je nabój po naboju, znalezione są nieprzeliczone.

| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |
| --- | --- | --- | --- | --- |
| **Magazynek PW-9 (8)** `mag_pw9` | 1x2 · 0.09 kg · 600 | kaliber 9x18, pojemność 8 | Osiem naboi. W raportach zawsze liczone jako dziesięć. | Zbrojmistrz; biurko 5%; skrzynia 6% |
| **Magazynek PM-63 (25)** `mag_pm63` | 1x4 · 0.18 kg · 1500 | kaliber 9x18, pojemność 25 | Długi, prosty, wystający. Jak kolejka po meblościankę. | Zbrojmistrz; skrzynia 4% |
| **Magazynek KB-47 (30)** `mag_kb47` | 2x4 · 0.33 kg · 2200 | kaliber 7.62x39, pojemność 30 | Stalowy, wygięty, niezniszczalny. Przeżyje ciebie i twoich spadkobierców. | Zbrojmistrz; Wojsko; skrzynia 4%; skrzynia wojskowa 7%; przy wojskowi |

# Amunicja

Luzem w stosach (garść albo paczka – rozmiar w siatce rośnie z ilością).

| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |
| --- | --- | --- | --- | --- |
| **9x18 PST** `a_9x18` | 2x3 · 0.01 kg · 25 | obrażenia 48, penetracja 14, stos 50 | Nabój pistoletowy. Przydział: 8 sztuk na kwartał. | Zbrojmistrz; szafka kuchenna 3%; biurko 8%; skrzynia 12%; wyposażenie: szabrownicy; wyposażenie: najemnicy; wyposażenie: wojskowi |
| **7.62x39 PS** `a_762` | 2x3 · 0.02 kg · 70 | obrażenia 56, penetracja 34, stos 60 | Rdzeń stalowy. Zgodny z normą, której nikt nie widział. | Zbrojmistrz; Wojsko; skrzynia 10%; skrzynia wojskowa 11%; wyposażenie: szabrownicy; wyposażenie: najemnicy; przy wojskowi; wyposażenie: wojskowi |
| **7.62x39 BP** `a_762bp` | 2x3 · 0.02 kg · 280 | obrażenia 52, penetracja 48, stos 60 | Przeciwpancerny. Wydawany wyłącznie za okazaniem przepustki, której nie wydaje się nikomu. | Najemnicy (rep. 30); Wojsko (rep. 20); skrzynia wojskowa 3%; przy najemnicy; wyposażenie: wojskowi |
| **12/70 śrut 8,5 mm** `a_12` | 2x3 · 0.05 kg · 55 | obrażenia 30, penetracja 4, 8 śrucin, stos 20 | Osiem kulek nadziei w jednej łusce. | Zbrojmistrz; Szabrownicy; skrzynia 10%; regal 6%; wyposażenie: szabrownicy |

# Leki

Każdy lek działa z animacją i trwa; przeterminowane działają wolniej i czasem wcale.

| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |
| --- | --- | --- | --- | --- |
| **Bandaż** `bandaz` | 2x2 · 0.05 kg · 800 | efekt: krwawienie lekkie, czas 3.0 s, użycia 1 | Zatrzymuje lekkie krwawienie. Ciężkiego nawet nie próbuje. | Medyk; szafka kuchenna 4%; szafa 6%; apteczka scienna 24%; przy szabrownicy |
| **Opatrunek hemostatyczny** `opatrunek` | 2x1 · 0.10 kg · 2600 | efekt: krwawienie ciezkie, czas 5.0 s, użycia 1 | Tamuje ciężkie krwawienie. Z importu, więc na kartki. | Medyk; Najemnicy; skrzynia wojskowa 6%; apteczka scienna 10%; przy najemnicy; przy wojskowi |
| **Szyna Kramera** `szyna` | 1x4 · 0.20 kg · 2200 | efekt: zlamanie, czas 6.0 s, użycia 1 | Unieruchamia złamanie. Unieruchamia też dumę. | Medyk; skrzynia wojskowa 5%; apteczka scienna 8% |
| **Tabletki Bólostop** `bolostop` | 1x2 · 0.03 kg · 1600 | efekt: bol, czas 2.0 s, użycia 4, działa 180 s | Usuwa ból na trzy minuty. Skutki uboczne: patrz ból. | Medyk; apteczka scienna 14% |
| **Apteczka AI-2** `apteczka` | 2x2 · 0.20 kg · 4200 | efekt: leczenie, czas 2.5 s, użycia 100 | Wojskowa apteczka indywidualna. Zawartość niekompletna zgodnie z protokołem. | Medyk; skrzynia wojskowa 6%; apteczka scienna 8%; przy najemnicy; przy wojskowi |

# Pancerze i hełmy

Klasa ochrony, wytrzymałość i strefy ciała. Zużywają się; można je łatać na stole roboczym.

| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |
| --- | --- | --- | --- | --- |
| **Kamizelka milicyjna (kl. 2)** `kamizelka_kl2` | 6x6 · 4.00 kg · 12000 | klasa 2, wytrzymałość 40, chroni: klatka, brzuch | Zatrzymuje pistolet. Karabin traktuje jako sugestię. | Zbrojmistrz; Wojsko; skrzynia wojskowa 1%; wyposażenie: szabrownicy; wyposażenie: najemnicy; wyposażenie: wojskowi |
| **Pancerz wojskowy (kl. 4)** `kamizelka_kl4` | 6x6 · 9.00 kg · 46000 | klasa 4, wytrzymałość 60, chroni: klatka, brzuch | Ciężki jak plan pięcioletni i równie skuteczny przeciwko rzeczywistości. | Wojsko (rep. 40); wyposażenie: najemnicy; wyposażenie: wojskowi |
| **Hełm wz. 67** `helm_wz67` | 4x3 · 1.20 kg · 6500 | klasa 2, wytrzymałość 25, chroni: glowa | Stalowy garnek z paskiem. Dzwoni po trafieniu, żebyś wiedział, że żyjesz. | Zbrojmistrz; Wojsko; skrzynia wojskowa 3%; wyposażenie: najemnicy; wyposażenie: wojskowi |

# Oporządzenie: kamizelki i plecaki

Własne modele 3D i własne zapięcia (rzep, zamek, klapa, ściągacz, zatrzask, guzik).

| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |
| --- | --- | --- | --- | --- |
| **Kamizelka wędkarska** `kamizelka_wedkarska` | 4x4 · 0.60 kg · 5500 | slot kamizelka, siatka 10x4 (32 pól), redukcja wagi 10%, sloty wyposażenia +1 | Dużo kieszonek, zero ochrony. Ryby nie strzelają. | Posrednik; szafa 2% |
| **Kamizelka taktyczna LBV** `kamizelka_lbv` | 6x6 · 1.20 kg · 19000 | slot kamizelka, siatka 14x6 (60 pól), redukcja wagi 15%, sloty wyposażenia +2 | Ładownice na magazynki rozmieszczone przez kogoś, kto kiedyś widział człowieka. | Najemnicy (rep. 15) |
| **Napierśnik ChK-3** `napiersnik` | 4x4 · 0.80 kg · 11000 | slot kamizelka, siatka 16x4 (40 pól), redukcja wagi 10%, sloty wyposażenia +1 | Trzy ładownice na magazynki i kieszeń na resztę życia. Szyty w spółdzielni pracy. | Zbrojmistrz; Wojsko (rep. 10); skrzynia wojskowa 2% |
| **Kamizelka myśliwska** `kamizelka_mysliwska` | 4x6 · 0.90 kg · 8500 | slot kamizelka, siatka 12x6 (40 pól), redukcja wagi 10%, sloty wyposażenia +2 | Kieszeń na nabój, kieszeń na kanapkę, kieszeń na wymówkę dla żony. | Posrednik; szafa 2% |
| **Worek po ziemniakach** `worek` | 4x4 · 0.30 kg · 2000 | slot plecak, siatka 8x8 (64 pól), redukcja wagi 5%; kieszenie: Worek (sciagacz) | Dwa sznurki zamiast szelek. Pachnie jak 1983. | Posrednik; szafa 3% |
| **Plecak turystyczny (24)** `plecak_turystyczny` | 8x8 · 1.50 kg · 16000 | slot plecak, siatka 14x9 (88 pól), redukcja wagi 30%; kieszenie: Komora główna (klapa), Kieszeń boczna (siatka) (sciagacz), Kieszeń boczna (siatka) (sciagacz), Kieszeń przednia (zamek) | Dużo miejsca, mniejsze odciążenie. Pamięta obóz harcerski. | Zbrojmistrz |
| **Plecak szturmowy (12)** `plecak_szturmowy` | 6x6 · 1.00 kg · 15000 | slot plecak, siatka 8x6 (48 pól), redukcja wagi 45%; kieszenie: Kieszeń górna (zamek), Komora główna (zamek) | Mało miejsca, ale ładunek mniej waży. Stelaż z demobilu. | Najemnicy |
| **Chlebak wz. 33** `chlebak` | 4x4 · 0.40 kg · 3500 | slot plecak, siatka 6x6 (32 pól), redukcja wagi 10%; kieszenie: Komora (klapa), Kieszonka (rzep), Kieszonka (rzep) | Mieści bochenek chleba albo trzy granaty. Bochenka nie ma. | Posrednik; szafa 2% |
| **Zasobnik wojskowy wz. 88** `plecak_wojskowy` | 8x10 · 2.40 kg · 34000 | slot plecak, siatka 18x12 (132 pól), redukcja wagi 35%; kieszenie: Komora główna (klapa), Kieszeń boczna (rzep), Ładownica na manierkę (zatrzask) | Komora główna pod klapą, przyszyta kieszeń boczna na rzep i ładownica na manierkę. Na stelażu numer, którego nie ma w żadnej ewidencji. | Wojsko (rep. 25); skrzynia wojskowa 1% |

# Granaty

| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |
| --- | --- | --- | --- | --- |
| **Granat F-1** `granat_f1` | 1x2 · 0.60 kg · 3500 | obrażenia 130, promień 7.5 m, zapalnik 3.6 s; **rzut [G], pułapki** | Obronny, „cytrynka”. Opóźnienie 3–4 s, odłamki do kilkunastu metrów. [G] – rzut (kucając: toczy po ziemi). | Szabrownicy (rep. 35); Wojsko (rep. 20); skrzynia wojskowa 5% |

# Narzędzia i wyposażenie

Sloty wyposażenia: pas + 0–2 z kamizelki (latarka, mapa, kompas).

| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |
| --- | --- | --- | --- | --- |
| **Klucz do piwnicy nr 7** `klucz_piwnica` | 1x2 · 0.02 kg · 5000 | otwiera: wyjscie piwnica, użycia 3; **wyjście przez piwnicę nr 7** | Otwiera wyjście przez piwnice. Piwnica nr 7 nie figuruje w dokumentacji budynku. | Posrednik; Szabrownicy (rep. 15); biurko 3% |
| **Mapa strefy (odbitka)** `mapa` | 2x1 · 0.05 kg · 2500 | **[O] mapa w rękach: plan, wyjścia, strzałki** | Na slocie wyposażenia: [O] – mapa w rękach: plan, odwiedzone pomieszczenia, zauważone strzałki i stan wyjść. Bez mapy – tylko pamięć i strzałki na ścianach. | Posrednik; Szabrownicy; biurko 5%; przy wojskowi |
| **Kompas Azymut** `kompas` | 2x2 · 0.08 kg · 1800 | **pasek kierunków; z mapą – namiar na wyjścia** | Na slocie wyposażenia: pasek kierunków u góry ekranu. Północ zgodna z linią partii. | Posrednik; biurko 3%; skrzynia wojskowa 2%; przy wojskowi |
| **Latarka KZ-3** `latarka` | 3x1 · 0.35 kg · 900 | **lewa ręka, sama albo pod pistoletem (chwyt Harriesa)** | Na slocie wyposażenia (pas, kamizelka). Trzymana w lewej ręce, sama albo pod pistoletem. Świeci, dopóki ktoś nie zobaczy, skąd świeci. | Posrednik; regal 3% |

# Łup, jedzenie i narzędzia codzienne

Wartość w bonach (skup 40–60%), część ma funkcję (jedzenie, narzędzia, pułapki, warsztat).

| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |
| --- | --- | --- | --- | --- |
| **Zegarek Rakieta** `zegarek` | 2x1 · 0.05 kg · 4000 | **z zegarkiem w ekwipunku [H] pokazuje dokładny czas rajdu i okna wyjść** | Spieszy się o 12 lat. | szafa 3%; przy szabrownicy |
| **Wódka Czysta Kordonowa** `wodka` | 1x3 · 0.80 kg · 1500 | głód +0, pragnienie -10, 3.0 s, alkohol; **gasi ból, potem ręce drżą** | Waluta twardsza niż bony. Nie pić w rajdzie (patrz: regulamin, pkt 4). Gasi ból, ale ręce potem drżą. | szafka kuchenna 6%; przy szabrownicy |
| **Papierosy Start** `papierosy` | 2x1 · 0.03 kg · 700 | — | Bez filtra. Bez przyszłości. | Posrednik; szafka kuchenna 7%; szafa 9%; biurko 8%; przy szabrownicy |
| **Konserwa turystyczna** `konserwa` | 2x2 · 0.35 kg · 900 | głód +38, pragnienie -8, 6.0 s | Data ważności: tak. Syci, ale suszy. | Posrednik; szafka kuchenna 15%; regal 6%; przy szabrownicy |
| **Woda w butelce** `woda` | 1x3 · 0.55 kg · 600 | głód +0, pragnienie +45, 3.5 s | Butelka po oranżadzie, korek z gazety. Woda raczej z kranu. | Posrednik; szafka kuchenna 11%; szafa 5%; skrzynia wojskowa 3% |
| **Suchary wojskowe** `suchary` | 2x1 · 0.20 kg · 500 | głód +22, pragnienie -10, 4.0 s | Twarde jak regulamin. Bez popicia stają w gardle. | Posrednik; szafka kuchenna 6%; skrzynia wojskowa 6% |
| **Lampa elektronowa** `lampa_elektronowa` | 1x2 · 0.10 kg · 2200 | — | Serce telewizora. Pośrednik płaci za serca. | biurko 8%; regal 6% |
| **Akumulator 6V** `akumulator` | 3x3 · 6.00 kg · 5500 | **zlecenie Najemników** | Ciężki, pełny kwasu i możliwości. | skrzynia 3%; regal 3% |
| **Kaseta magnetofonowa** `kaseta` | 2x1 · 0.05 kg · 800 | — | Na etykiecie: „NIE SŁUCHAĆ”. Ktoś posłuchał. | szafa 11%; biurko 11% |
| **Teczka akt „Ściśle tajne”** `teczka_akt` | 2x4 · 0.40 kg · 9000 | **zlecenie Wojska (dostawa)** | Zawiera wykaz osób, które zawierają się w wykazie. | biurko 4%; przy najemnicy |
| **Złoty łańcuszek** `lancuszek` | 2x1 · 0.02 kg · 6000 | **zlecenie Szabrowników** | Z Peweksu. Albo z szyi. | szafa 2%; przy najemnicy |
| **Radio tranzystorowe** `radio` | 3x2 · 0.70 kg · 4500 | **zlecenie Wojska (dostawa)** | Łapie tylko jedną stację. Ta stacja łapie ciebie. | szafa 5%; regal 3% |
| **Klucz nastawny** `klucz_nastawny` | 3x1 · 0.80 kg · 1200 | **wyłamanie kłódki narzędziem** | Pasuje do wszystkiego, jeśli uderzyć wystarczająco mocno. | skrzynia 6%; regal 7% |
| **Zwój przewodów** `przewody` | 3x2 · 0.50 kg · 1200 | — | Miedź. Najcenniejszy surowiec strefy po ludziach. | skrzynia 7%; regal 8% |
| **Kartka na mięso** `kartka_mieso` | 2x1 · 0.01 kg · 300 | — | Uprawnia do 2,5 kg mięsa. Mięsa nie ma od 12 lat. | szafka kuchenna 7%; przy szabrownicy |
| **Spirytus salicylowy** `spirytus` | 1x2 · 0.20 kg · 1200 | — | Do użytku zewnętrznego. W strefie wszystko jest zewnętrzne. | szafka kuchenna 5%; apteczka scienna 8% |
| **Maszyna do pisania Łucznik** `maszyna_do_pisania` | 5x4 · 7.50 kg · 8000 | — | Każda ma swój charakter pisma. Każda jest zarejestrowana. | biurko 2% |
| **Kanister z benzyną** `kanister` | 4x5 · 9.00 kg · 5000 | **zlecenie Najemników** | Dwadzieścia litrów etyliny. Kartki na nią wydano w 1981. | regal 2% |
| **Aparat telefoniczny** `telefon` | 3x3 · 1.40 kg · 3500 | — | Rozmowy są nagrywane. Nawet te, których nie ma. | biurko 3% |
| **Gaśnica proszkowa** `gasnica` | 2x5 · 4.00 kg · 2000 | — | Legalizacja ważna do 1986. Proszek ważny do końca świata. | regal 2% |
| **Lornetka 7x50** `lornetka` | 3x2 · 0.90 kg · 6000 | — | Wschodnioniemiecka optyka. Widać przez nią wszystko poza przyszłością. | Szabrownicy (rep. 25); skrzynia wojskowa 2% |
| **Maska przeciwgazowa** `maska_gazowa` | 3x3 · 0.90 kg · 2500 | — | Filtr zużyty. Zapach gumy wieczny. | Szabrownicy (rep. 10); szafa 4% |
| **Wytrychy w etui** `wytrych` | 1x2 · 0.10 kg · 2600 | **otwiera drzwi i kłódki (zręcznościówka, 3 haczyki)** | Komplet haczyków i napinacz. Zamek w drzwiach otwiera cicho, choć nie szybko. | Szabrownicy; biurko 2%; regal 2% |
| **Kombinerki** `kombinerki` | 1x3 · 0.30 kg · 1400 | **wyłamanie kłódki narzędziem** | Narzędzie uniwersalne. Także do uzgadniania stanowisk. | regal 4% |
| **Taśma izolacyjna** `tasma` | 2x2 · 0.10 kg · 900 | użycia 6; **owinięty metal nie brzęczy** | Owinięty taśmą metal nie brzęczy. Owinięta taśmą rzeczywistość też jakoś się trzyma. | Szabrownicy; szafka kuchenna 3%; skrzynia wojskowa 2%; regal 5% |
| **Zestaw do czyszczenia broni** `zestaw_czyszczacy` | 3x1 · 0.40 kg · 4200 | użycia 4; **czyszczenie broni (6 s), mniej zacięć** | Wycior, szczoteczka i olej w puszce po pastylkach. Broń po czyszczeniu zacina się rzadziej. | Zbrojmistrz; Szabrownicy (rep. 10); skrzynia wojskowa 3%; regal 2% |
| **Nieśmiertelnik Sępa** `niesmiertelnik` | 1x2 · 0.02 kg · 3000 | **dowód zlecenia Najemników** | Blaszka na łańcuszku: numer, grupa krwi, wydrapane „SĘP”. Dowód, że dezerter przestał dezerterować. | — |
| **Proch strzelniczy (puszka)** `proch` | 1x2 · 0.40 kg · 400 | **elaboracja amunicji na stole roboczym** | Proch bezdymny w puszce po kakao. Napis „KAKAO” należy traktować z rezerwą. | Szabrownicy; skrzynia 6%; skrzynia wojskowa 3%; regal 3%; przy najemnicy |
| **Prasa do elaboracji** `prasa_elaboracyjna` | 2x2 · 1.40 kg · 3500 | użycia 8; **stół roboczy: 9x18 ×20 / 12/70 ×10 (1 proch), 7,62 ×15 (2 proch)** | Ręczna prasa z matrycami. Przy stole roboczym zamienia proch w naboje. Palce trzymać z dala. | Szabrownicy (rep. 10); skrzynia 1%; regal 1% |
| **Tkanina balistyczna** `tkanina_balistyczna` | 2x2 · 0.60 kg · 4000 | **łata pancerza na stole roboczym** | Pakiet aramidu z rozprutej kamizelki. Przy stole roboczym łata pancerz – nigdy do końca. | Najemnicy (rep. 15); skrzynia wojskowa 2%; przy wojskowi |
| **Farba w sprayu** `farba_spray` | 1x3 · 0.35 kg · 700 | użycia 12; **własne strzałki i znaki na ścianach** | Pomarańczowa, z magazynu wyposażenia szkół. Strzałka, krzyżyk, wykrzyknik – zostają na ścianie do końca rajdu. | Szabrownicy; szafka kuchenna 1%; skrzynia 2%; regal 3% |
| **Drut z kołkami** `drut` | 1x2 · 0.15 kg · 600 | **potykacz z granatem** | Pięć metrów stalowego drutu i dwa kołki. Instrukcja BHP zabrania rozciągania w ciągach komunikacyjnych. | Szabrownicy; skrzynia wojskowa 3%; regal 3% |
| **Klin do drzwi** `klin` | 1x1 · 0.10 kg · 300 | **blokuje drzwi od swojej strony** | Kawałek dębu. Wbity pod drzwi od środka zamienia każde mieszkanie w twierdzę. Na pięć minut. | Szabrownicy; regal 4% |
| **Szklanka** `szklanka` | 1x2 · 0.20 kg · 150 | **pułapka z granatem na klamce** | Szklanka z PRL-owskiej zastawy. Granat F-1 mieści się w niej idealnie – projektanci chyba wiedzieli. | szafka kuchenna 7%; szafa 2% |
| **Ikona w ramie** `ikona` | 3x3 · 1.10 kg · 12000 | — | Pośrednik nie pyta o pochodzenie. Święty też milczy. | szafa 1% |

# Tabele łupu w meblach

Każdy mebel-pojemnik losuje zwykle 1 raz (czasem 2–3, bywa pusto: rozkład 0,1,1,1,2,2,3 → średnio ok. 1,4). Wpis „nic” to pusty los.

**Szafka kuchenna:** Taśma izolacyjna 3%, Woda w butelce 11%, Suchary wojskowe 6%, Konserwa turystyczna 15%, Wódka Czysta Kordonowa 6%, Spirytus salicylowy 5%, Papierosy Start 7%, Kartka na mięso 7%, Bandaż 4%, 9x18 PST 3%, Farba w sprayu 1%, Szklanka 7%, nic 23%

**Szafa:** Woda w butelce 5%, Maska przeciwgazowa 4%, Ikona w ramie 1%, Kamizelka myśliwska 2%, Chlebak wz. 33 2%, Papierosy Start 9%, Zegarek Rakieta 3%, Złoty łańcuszek 2%, Kaseta magnetofonowa 11%, Radio tranzystorowe 5%, Kamizelka wędkarska 2%, Worek po ziemniakach 3%, Bandaż 6%, Szklanka 2%, nic 45%

**Biurko:** Wytrychy w etui 2%, Mapa strefy (odbitka) 5%, Kompas Azymut 3%, Aparat telefoniczny 3%, Maszyna do pisania Łucznik 2%, Teczka akt „Ściśle tajne” 4%, Kaseta magnetofonowa 11%, Papierosy Start 8%, Lampa elektronowa 8%, Klucz do piwnicy nr 7 3%, 9x18 PST 8%, Magazynek PW-9 (8) 5%, nic 41%

**Skrzynia:** Tłumik PBS-9 1%, 7.62x39 PS 10%, 9x18 PST 12%, 12/70 śrut 8,5 mm 10%, Magazynek KB-47 (30) 4%, Magazynek PM-63 (25) 4%, Magazynek PW-9 (8) 6%, Zwój przewodów 7%, Klucz nastawny 6%, Akumulator 6V 3%, Proch strzelniczy (puszka) 6%, Prasa do elaboracji 1%, Farba w sprayu 2%, nic 26%

**Skrzynia wojskowa:** Granat F-1 5%, Suchary wojskowe 6%, Woda w butelce 3%, Zestaw do czyszczenia broni 3%, Taśma izolacyjna 2%, Tłumik PBS-1 1%, Hamulec wylotowy KH-1 2%, Chwyt przedni RK-3 1%, Latarka taktyczna ŁT-2 2%, Kolimator Okular-1 1%, Napierśnik ChK-3 2%, Zasobnik wojskowy wz. 88 1%, Lornetka 7x50 2%, Kompas Azymut 2%, 7.62x39 PS 11%, 7.62x39 BP 3%, Magazynek KB-47 (30) 7%, KB-47 Kałach 1%, PM-63 Rak 1%, Opatrunek hemostatyczny 6%, Apteczka AI-2 6%, Hełm wz. 67 3%, Kamizelka milicyjna (kl. 2) 1%, Szyna Kramera 5%, Proch strzelniczy (puszka) 3%, Tkanina balistyczna 2%, Drut z kołkami 3%, nic 17%

**Apteczka scienna:** Bandaż 24%, Opatrunek hemostatyczny 10%, Tabletki Bólostop 14%, Apteczka AI-2 8%, Szyna Kramera 8%, Spirytus salicylowy 8%, nic 28%

**Regal:** Taśma izolacyjna 5%, Zestaw do czyszczenia broni 2%, Kanister z benzyną 2%, Gaśnica proszkowa 2%, Kombinerki 4%, Wytrychy w etui 2%, Latarka KZ-3 3%, Zwój przewodów 8%, Klucz nastawny 7%, Lampa elektronowa 6%, Akumulator 6V 3%, Radio tranzystorowe 3%, 12/70 śrut 8,5 mm 6%, Konserwa turystyczna 6%, Proch strzelniczy (puszka) 3%, Prasa do elaboracji 1%, Farba w sprayu 3%, Drut z kołkami 3%, Klin do drzwi 4%, nic 28%

# Meble w strefie

Meble stawiane przez generator w zestawach wg typu pomieszczenia. Pojemnik = tabela łupu; osłona = punkt osłony dla AI (niska/wysoka).

| Mebel | Wymiary (m) | Pojemnik (tabela) | Osłona |
| --- | --- | --- | --- |
| Stół `stol` | 1.20 × 0.75 × 0.80 | — | — |
| Krzesło `krzeslo` | 0.45 × 0.90 × 0.45 | — | — |
| Wersalka `wersalka` | 2.02 × 0.85 × 0.85 | — | niska |
| Łóżko `lozko` | 1.94 × 0.85 × 0.90 | — | — |
| Meblościanka `meblosciana` | 2.40 × 2.00 × 0.50 | szafa | wysoka |
| Szafa `szafa` | 1.00 × 1.90 × 0.60 | szafa | wysoka |
| Kuchenka `kuchenka` | 0.56 × 0.87 × 0.60 | — | — |
| Lodówka Mińsk `lodowka` | 0.60 × 1.50 × 0.60 | szafka_kuchenna | wysoka |
| Szafka kuchenna `szafka_kuchenna` | 1.24 × 0.89 × 0.62 | szafka_kuchenna | niska |
| Regał `regal_metalowy` | 1.00 × 1.90 × 0.45 | regal | wysoka |
| Skrzynia wojskowa `skrzynia_wojskowa` | 1.00 × 0.50 × 0.56 | skrzynia_wojskowa | niska |
| Biurko `biurko` | 1.30 × 0.76 × 0.70 | biurko | niska |
| Telewizor Rubin `telewizor` | 0.70 × 1.00 × 0.50 | — | — |
| Worki z piaskiem `worki_piasek` | 1.60 × 0.80 × 0.50 | — | niska |
| Stół warsztatowy `stol_warsztatowy` | 1.80 × 1.02 × 0.70 | regal | niska |
| Żarówka `zarowka` | 0.10 × 0.60 × 0.10 | — | — |
| Krata `krata` | 1.20 × 1.40 × 0.05 | — | — |
| Apteczka ścienna `apteczka_scienna` | 0.40 × 0.45 × 0.14 | apteczka_scienna | — |
| Dywan `dywan` | 2.00 × 0.01 × 1.40 | — | — |
| Znak wyjścia `znak_wyjscie` | 0.64 × 0.32 × 0.05 | — | — |
| Szafka ubraniowa `szafka_metalowa` | 0.50 × 1.80 × 0.45 | szafa | wysoka |
| Skrzynia `skrzynia` | 0.60 × 0.60 × 0.60 | skrzynia | niska |
| Beczka `beczka` | 0.58 × 0.88 × 0.58 | — | niska |
| Kaloryfer `kaloryfer` | 0.75 × 0.60 × 0.13 | — | — |
| Skrzynki pocztowe `skrzynki_pocztowe` | 1.00 × 0.62 × 0.20 | — | — |
| Hydrant `hydrant` | 0.56 × 0.56 × 0.14 | — | — |
| Tablica ogłoszeń `tablica_ogloszen` | 0.84 × 0.62 × 0.03 | — | — |
| Stojak na broń `stojak_bron` | 1.30 × 1.70 × 0.40 | — | — |
| Stół z planem strefy `stol_mapa` | 1.20 × 0.75 × 0.80 | — | — |

# Meble kryjówki (Kwatermistrz)

Skrytka: 20 kolumn, 10 rzędów bazowo, maksymalnie 64. Nowa gra: prycza, szafka metalowa, żarówka (16 rzędów). Druga izba 5 × 7 m: 25 000 bonów.

| Mebel | Cena | Funkcja | Opis |
| --- | --- | --- | --- |
| Szafka ubraniowa | 4500 | skrytka | Szafka ubraniowa na kłódkę. Skrytka +6 rzędów. |
| Regał | 7000 | skrytka | Regał z kątowników. Skrytka +8 rzędów. |
| Skrzynia wojskowa | 6000 | skrytka | Skrzynia po amunicji. Skrytka +6 rzędów. |
| Szafa | 6500 | skrytka | Szafa z odzysku. Skrytka +8 rzędów. |
| Biurko | 3500 | skrytka | Biurko z szufladami. Skrytka +4 rzędy. |
| Lodówka Mińsk | 4000 | skrytka | Lodówka Mińsk (nie chłodzi). Skrytka +4 rzędy. |
| Stojak na broń | 6000 | skrytka | Stojak na broń z odzysku. Skrytka +4 rzędy; pokazuje do 4 sztuk broni ze skrytki. |
| Stół z planem strefy | 3500 | meldunki | Stół z planem strefy i nasłuchem. Przed rajdem: czy jest Sęp, zapowiedziane zdarzenia. |
| Stół warsztatowy | 9000 | warsztat | Stół roboczy z imadłem: montaż kolimatora, lunety i chwytu. |
| Łóżko | 5000 | odpoczynek | Prycza. Sen po rajdzie leczy połowę ran (raz po każdym powrocie). |
| Wersalka | 4000 | odpoczynek | Wersalka. Sen po rajdzie leczy połowę ran (raz po każdym powrocie). |
| Kuchenka | 3500 | kuchnia | Kuchenka na butlę. Jedzenie na ciepło syci o połowę lepiej i nie suszy. |
| Żarówka | 400 | lampa | Goła żarówka pod sufitem. |
| Stół | 1500 | wystrój | Stół. Do kart, map i rozmyślań. |
| Krzesło | 500 | wystrój | Krzesło. Jedno – gości nie przewidziano. |
| Dywan | 1200 | wystrój | Dywan. Tłumi kroki i wyrzuty sumienia. |
| Telewizor Rubin | 2500 | wystrój | Telewizor Rubin. Jeden kanał, i tak nic nie leci. |
| Worki z piaskiem | 800 | wystrój | Worki z piaskiem. Na wszelki wypadek. |
| Beczka | 600 | wystrój | Beczka. Pusta, sprawdzono. |
| Skrzynia | 2500 | skrytka | Skrzynka z desek. Skrytka +3 rzędy. |

# Możliwości rozwoju

- Druga broń długa (strzelba pompowa lub karabin wyborowy), magazynki bębnowe, kolby (nowy slot), amunicja smugowa i śrut breneka.
- Archiwum dokumentów: teczki akt i kasety jako zbieralne fragmenty lore (odsłuch/odczyt w kryjówce).
- Naprawa broni (stan) u Zbrojmistrza lub na stole roboczym.
- Przedmioty biomowe (klucze do konkretnych pomieszczeń, karty dostępu w kompleksie).
- Plecaki z ramą (lepsza redukcja wagi, głośniejsze), torby na udo (szybki dostęp, mała pojemność).

