nr: 07
tytul: Balans
podtytul: Liczby, które trzymają grę w ryzach: ekonomia bonów, obrażenia i pancerze, ciało, tempo, AI, reputacja. Z uzasadnieniem i znanymi problemami.
stempel: PN-72/M-0312
---

# Zasady balansu

1. **Każdy rajd ma się „opłacać” tylko przy rozsądnym ryzyku.** Sam spacer po łatwy łup nie może pokryć utraty dobrego zestawu.
2. **Sprzęt jest celem, nie nagrodą za czas.** Brak doświadczenia postaci – progres = sprzęt, kryjówka, reputacja.
3. **Nie ma darmowych pieniędzy.** Każda pętla „kup–sprzedaj” musi tracić (skup 40–60% ceny, przydział nie do sprzedania).
4. **Czas jest zasobem.** Wolny ruch i czynności sprawiają, że okno czasowe i zagrożenie rosnące z czasem realnie naciskają.
5. **Wrogowie giną szybciej niż gracz rozsądnie uzbrojony, ale nie „od jednego”.** NPC padają od szoku przy dużej utracie krwi, żeby nie były gąbkami na kule.

# Ekonomia

## Start i stałe koszty
| Pozycja | Wartość |
| --- | --- |
| Bony na start | 12 000 |
| Zestaw z przydziału (gdy brak broni) | PW-9 + magazynek, 16 naboi 9x18, bandaż, kamizelka wędkarska, worek, latarka – nie do sprzedania |
| Wyjście do strefy | głód −10, pragnienie −14 |
| Pełne leczenie u Medyka | 18 bonów za każdy brakujący punkt zdrowia (np. 100 HP braku = 1 800) |
| Ubezpieczenie przedmiotu | 18% ceny katalogowej, min. 300 |
| Pewny meldunek u Pośrednika | 1 800 |
| Rozejm/informacja od poddanego | 300 |
| Druga izba kryjówki | 25 000 |

## Skup
| Kto | Co skupuje | Procent ceny |
| --- | --- | --- |
| Zbrojmistrz | broń, magazynki, amunicja, pancerze, pojemniki, dodatki, granaty | 45% |
| Medyk | leki | 50% |
| Pośrednik | prawie wszystko | 40% (łup 60%) |
| Szabrownicy | łup, klucze, mapy | 55% |
| Najemnicy | leki, dodatki, amunicja | 45% |
| Wojsko | broń, magazynki, pancerze, granaty | 45% |

Broń warta tyle, w jakim jest stanie (55–100%), zakurzona taniej; łatany pancerz −15%; przeterminowane leki taniej.

## Łup w strefie
Sonda ekonomiczna (`--ekonomia`, v0.10): łup w meblach na mapę ma wartość katalogową **1,3–1,6 mln bonów**, co przy skupie daje **ok. 0,5 mln** – ale realnie gracz wynosi ułamek (pojemność, czas, ryzyko). Meble losują 0–3 razy (średnio ok. 1,4), część losów to „nic” (30–60% w tabelach). Kosztowności celowo tańsze: łańcuszek 6 000, zegarek 4 000, teczka 9 000, ikona 12 000.

## Ceny reputacji
Mnożnik ceny u przedstawiciela: `1 − 0,15·clamp(rep/100) + 0,25·clamp(−rep/60)` → −15% przy +100, +25% przy −60.

## Zlecenia
| Typ | Zakres nagród | Reputacja |
| --- | --- | --- |
| Eliminacja (2–4 osoby) | 4 500 – 8 500 | +10 … +14 |
| Boss (Sęp / nieśmiertelnik) | 14 000 – 15 000 | +15 |
| Dostawa | 3 500 – 9 500 | +8 … +12 |
| Zwiad | 3 000 | +6 |

Maksymalnie 3 aktywne. Zabójstwa liczą się tylko wtedy, gdy ostatni trafił gracz.

## Rzemiosło
| Rzecz | Koszt | Efekt | Opłacalność |
| --- | --- | --- | --- |
| Elaboracja 9x18 | 1 proch (400) | 20 naboi (500 kat.) | lekko na plus, sens tylko z prochu z łupu |
| Elaboracja 12/70 | 1 proch | 10 naboi (550) | j.w. |
| Elaboracja 7,62 | 2 proch (800) | 15 naboi (1 050) | j.w. |
| Prasa | 3 500 | 8 użyć | — |
| Łata pancerza | tkanina (4 000) | pełna wytrzymałość do maks. −10% za łatę | jedyny sposób przedłużenia życia pancerza |

# Walka

## Amunicja
| Nabój | Obrażenia | Penetracja | Uwagi |
| --- | --- | --- | --- |
| 9x18 PST | 48 | 14 | kl. 2 przebija z trudem, kl. 4 prawie wcale |
| 7,62x39 PS | 56 | 34 | kl. 2 przebija pewnie, pełną kl. 4 prawie nigdy (7%), zużytą – często |
| 7,62x39 BP | 52 | 48 | kl. 4 przebija często |
| 12/70 śrut | 30 × 8 śrucin | 4 | zabójczy z bliska bez pancerza, bezużyteczny na pancerz |
| Granat F-1 | 130 | odłamki | promień 7,5 m, szarpie pancerz |

## Penetracja – przykłady (pełna wytrzymałość pancerza)
Próg = klasa × 10 × (0,45 + 0,55 × w/max). Szansa = 0,5 + (pen − próg)/14, 3–97%.

| Pancerz | Próg | 9x18 (14) | 7,62 PS (34) | 7,62 BP (48) |
| --- | --- | --- | --- | --- |
| kl. 2 (hełm, kamizelka milicyjna) | 20 | 7% | 97% | 97% |
| kl. 4 (pancerz wojskowy) | 40 | 3% | 7% | 97% |
| kl. 4 zużyta do połowy | ~29 | 3% | 86% | 97% |

Wniosek: **pistolety na pancerz to strata amunicji**, PS rozbija kl. 2 i zużyte kl. 4, BP to jedyna odpowiedź na wojsko w pełnych płytach. Zużycie pancerza przy przebiciu `pen × 0,12`, przy zatrzymaniu `obr × 0,07`.

## Ciało (gracz i NPC)
| Część | HP | Śmierć przy 0? |
| --- | --- | --- |
| Głowa | 35 | tak |
| Klatka | 85 | tak |
| Brzuch | 70 | NPC tak, gracz nie (krwawi) |
| Ręce | 60 | nie (drżenie, wolniejsze czynności) |
| Nogi | 65 | nie (kulenie, wolniej) |

Krwawienie lekkie 0,55 HP/s, ciężkie 1,7 HP/s. Pełne zdrowie 315 HP. Strzał 7,62 w klatkę bez pancerza = 56 → 2 trafienia w klatkę zabijają (z krwawieniem i szokiem zwykle szybciej).

## Wrogowie
| Frakcja | Celność | Reakcja | Morale | Typowy zestaw |
| --- | --- | --- | --- | --- |
| Szabrownicy | 0,50 | 1,00 | 0,35 | PW-9 / obrzyn, bez pancerza |
| Najemnicy | 0,75 | 0,70 | 0,65 | KB-47 / PM-63, kl. 2, hełm |
| Wojsko | 0,70 | 0,80 | 0,80 | KB-47 (często BP), kl. 2–4, hełm |
| Sęp | podniesiona | szybsza | nie ucieka (do ½ HP) | KB-47 BP + kolimator, kl. 4, hełm, ×1,8 HP, 3 granaty |

Rozrzut wroga rośnie z dystansem (`d/14`), ostrzał gracza obniża celność (przygniecenie). Fala zagrożenia co 200–300 s (szybciej przy hałasie). Impas z posterunkiem po ~75 s, ominięcie gniazda na 2 min.

# Tempo i ciało gracza

| Parametr | Wartość | Uzasadnienie |
| --- | --- | --- |
| Marsz / bieg / kucanie | 1,7 / 3,5 / 0,85 m/s | rajd 25–40 min na mapie ~100 × 72 m, dwie kondygnacje |
| Progi obciążenia | 18 / 28 / 40 kg | zestaw lekki (pistolet, kamizelka) ~8 kg; KB-47 + kl. 4 + plecak z łupem szybko > 28 kg |
| Głód / pragnienie | −0,012/s, −0,02/s (bieg do ×1,8 / ×2,5) | jedno jedzenie i woda na rajd przy rozsądnym tempie |
| Okno czasowe wyjścia | otwiera się w 10–25 min, trwa 5 min | wymaga planu albo zegarka |
| Odliczanie ewakuacji | brama 8 s, piwnica 5 s, okno 6 s | brama najłatwiejsza, ale najdłużej się czeka |
| Stres | 0–1, opada powoli | przygniecenie ogniem ma realny koszt dla gracza |

# Reputacja

| Zdarzenie | Zmiana |
| --- | --- |
| Zabicie członka frakcji | −5 u niej, +1 u pozostałych |
| Zlecenie frakcji | +6 … +15 |
| Rozejm | Szabrownicy ≥ 35, Najemnicy ≥ 40, Wojsko ≥ 50 |
| Brak handlu | ≤ −30 |
| Polowanie na gracza | ≤ −40 (co 80–120 s oddział na pozycję gracza) |

Przykład: 8 zabitych szabrowników i dwa zlecenia Wojska na ich eliminację (+12 każde): Szabrownicy −40 (próg polowania), Najemnicy +8, Wojsko +8 +24 = +32 (blisko rozejmu przy 50). Zlecenia wymuszają **wybór strony**.

# Znane problemy balansu i do obserwacji

- **Sprzedaż łupu u Pośrednika po 60%** jest najlepszą ścieżką – handel frakcjami (55%) ma sens tylko przez reputację.
- **Obrzyn** bardzo mocny z bliska na nieopancerzonych (szabrownicy), słaby na wojsko – zamierzone, ale wymaga obserwacji w ciasnych mapach.
- **Kl. 4 + BP u wojska** robi z późnej gry wyścig zbrojeń – BP u Najemników od rep. 30, u Wojska od 20.
- **Testy walki** (`--walka`) dają zmienną liczbę zabitych (losowość) – używane informacyjnie, nie jako twardy próg.
- Wolniejsze tempo (v0.15) wydłużyło rajd – okna czasowe i fale nie zostały przeskalowane; do sprawdzenia, czy okno 10–25 min nie jest za ciasne.

# Jak balansować (procedura)

1. Zmiana w danych: `assets/dane/przedmioty.json` (ceny, obrażenia, penetracja, tabele łupu, zestawy frakcji), `scripts/core/frakcje_bazy.gd` (oferty, progi, zlecenia), `scripts/ui/handel_ui.gd` (skup), `scripts/core/meble_kryjowki.gd` (meble).
2. Sonda: `scenes/rajd.tscn -- --ekonomia --ziarno 5` (wartość łupu na mapę), `--walka` (przebieg starcia), `--soak 480` (zachowanie AI bez gracza).
3. Regeneracja katalogu: `python3 narzedzia/dokumentacja_przedmioty.py`, PDF-y: `python3 narzedzia/dokumentacja_pdf.py`.
