nr: 02
tytul: Rdzeń gry
podtytul: Główna pętla: placówka, recepcja, frakcje, rozkaz wyjścia, generowanie strefy, rajd, ewakuacja i raport. Przegląd z odnośnikami do dokumentów szczegółowych.
stempel: ПРОВЕРЕНО
---

# Pętla w jednym schemacie

```
             ┌───────────────────────── PLACÓWKA ─────────────────────────┐
             │  KRYJÓWKA            KORYTARZ           RECEPCJA            │
             │  skrytka, meble,     ───────────►       handlarze (4),      │
             │  sen, kuchnia,                          przedstawiciele     │
             │  stół roboczy,                          frakcji (3),        │
             │  stół z mapą                            punkt kontrolny     │
             └──────────────────────────────┬─────────────────────────────┘
                                            │  ŚLUZA: rozkaz wyjścia
                                            ▼
                              PRZEMARSZ (generowanie strefy)
                                            ▼
          ┌──────────────────────────── RAJD ─────────────────────────────┐
          │ zwiad → łup → walka / unikanie → pułapki → decyzja o wyjściu  │
          │ wyjścia: brama (zawsze), piwnica nr 7 (klucz), okno (czasowe) │
          └──────────┬───────────────────────────────┬────────────────────┘
                     ▼                               ▼
               EWAKUACJA                    ZGON / ZAGINIĘCIE W AKCJI
                     └──────────────► RAPORT URZĘDOWY ◄┘
                                            ▼
                                      PLACÓWKA …
```

Każdy element pętli ma jedną rolę: **placówka** zamienia łup na możliwości, **rajd** zamienia możliwości i ryzyko na łup, **raport** zamyka rozliczenie i daje graczowi powód do kolejnego wyjścia.

# 1. Placówka

Placówka to jedna chodzona przestrzeń w pierwszej osobie (bez menu-sklepów „z powietrza”): **kryjówka gracza** (beton, 8 x 7 m, opcjonalnie druga izba 5 x 7 m), **korytarz** i **recepcja** (20 x 14 m, filary, poczekalnia).

## Kryjówka
- **Skrytka** – magazyn przedmiotów (siatka 20 kolumn, 10 rzędów bazowo, rośnie z meblami do 64 rzędów).
- **Tryb budowy [B]** – meble kupione u Kwatermistrza stawia się w świecie (podgląd zielony/czerwony z powodem odmowy, siatka 10 cm, obrót co 15°).
- **Funkcje mebli:** skrytka (rzędy), stół roboczy (montaż celowników, elaboracja, łaty pancerza), prycza/wersalka (sen leczy połowę ran raz po rajdzie), kuchenka (posiłek ×1,5 sytości), żarówka (światło), stół z mapą (meldunki przed rajdem), stojak na broń (pokazuje 4 najcenniejsze bronie).
- Szczegóły i ceny: *Przedmioty* (rozdział Meble kryjówki), *Mechaniki* (Placówka).

## Recepcja
- **Handlarze:** Zbrojmistrz (broń, amunicja, podstawowe pancerze), Medyk (leki, pełne leczenie za bony), Pośrednik (oporządzenie cywilne, skup łupu, zlecenia, ubezpieczenie, pewny meldunek), Kwatermistrz (meble, rozbudowa kryjówki).
- **Przedstawiciele frakcji:** Szabrownicy (Zenek „Kulawy”), Najemnicy (kpt. Rys), Wojsko (por. Wrona) – oferta odblokowywana reputacją, zlecenia frakcji, skup wybranych kategorii.
- **Punkt kontrolny Wojska przy śluzie** – wyjście do strefy przez rozkaz wyjścia.
- Szczegóły: *Świat gry: frakcje*, *Balans* (ceny, skup).

# 2. Rozkaz wyjścia

Przy śluzie gracz dostaje formularz z **ostrzeżeniami** (głód, pragnienie, nieleczone rany, puste magazynki, brak broni), listą **rozejmów** z frakcjami i **aktywnymi zleceniami**. Wyjście zużywa jedzenie (głód −10, pragnienie −14). Jeśli gracz nie ma broni, dostaje **zestaw z przydziału** (PW-9, magazynek, 16 naboi, bandaż, kamizelka wędkarska, worek, latarka) – nie do sprzedania.

# 3. Przemarsz i generowanie strefy

Ekran przemarszu z postępem trasy maskuje generowanie mapy. **Ziarno rajdu jest losowane z wyprzedzeniem** – dzięki temu stół z mapą i Pośrednik mogą podać meldunki o *następnym* rajdzie (obecność Sępa, zdarzenia).

Generator (szczegóły: *Mechaniki – Generator strefy*):
1. Siatka 11 x 8 komórek po 9 m (ok. 100 x 72 m) na dwie kondygnacje.
2. Układ: sieć korytarzy (30–50% planszy) i pomieszczenia 5,6–8,3 m z litym murem.
3. Typy pomieszczeń (7): mieszkanie, kuchnia, administracja, warsztat, magazyn, piwnica, klatka schodowa.
4. Przejścia: drzwi w grubych ścianach (0,45 m), szerokie otwory, drzwi między pokojami.
5. Okna na ścianach zewnętrznych, wyjścia (3 typy), posterunki wojska.
6. Meble w zestawach, łup w meblach-pojemnikach, detale korytarzy, lampy, naklejki i strzałki do wyjść.
7. Wypiekanie nawigacji i walidacja przechodniości (każde pomieszczenie osiągalne).
8. Rozmieszczenie wrogów (3–7 grup, 2–4 posterunki), fauny, Sępa (40% rajdów lub pewnie przy zleceniu), zdarzeń.

# 4. Rajd

Rajd trwa zwykle **25–40 minut**. Strefa jest aktywna od pierwszej sekundy: oddziały patrolują, posterunki trzymają gniazda, co 200–300 s może wejść nowa grupa, możliwe zdarzenia (awaria prądu, obława, zrzut zaopatrzenia).

| Element rajdu | Co robi gracz | Dokument |
| --- | --- | --- |
| Orientacja | strzałki na ścianach (też fałszywe), mapa w rękach [O], kompas, własny spray | Mechaniki: Orientacja |
| Łup | meble otwierane ręką, przeszukiwanie z odkrywaniem, zwłoki część po części, łup z ziemi | Mechaniki: Łup i ekwipunek |
| Ekwipunek | sloty na ciele, kamizelka, plecak zdejmowany i rozkładany, kieszenie z zapięciami | Mechaniki: Ekwipunek |
| Walka | broń z przyrządami, odrzut, zacięcia, penetracja, pancerze, granaty | Mechaniki: Broń i walka |
| Ciało | 5 części, krwawienia, złamania, ból, stres, głód, pragnienie, zmęczenie | Mechaniki: Ciało |
| Skradanie | ostrożny krok, kucanie, światło, wyłączniki, hałas zapięć i kroków | Mechaniki: Ruch i hałas |
| Pułapki | granat w szklance, potykacz, klin, barykady | Mechaniki: Pułapki |
| AI | wojna frakcji, poddawanie, rozejm, szaber | Świat gry |

# 5. Wyjścia i ewakuacja

| Wyjście | Warunek | Odliczanie | Uwagi |
| --- | --- | --- | --- |
| Brama na podwórze | zawsze otwarta | 8 s | w najgłębszym pomieszczeniu od startu |
| Piwnica nr 7 | klucz do piwnicy (biurka, szafy, Szabrownicy, Pośrednik) | 5 s | drzwi na klucz, klucz ma 3 użycia |
| Okno na rusztowanie | okno czasowe: otwiera się między 10 a 25 minutą na 5 minut | 6 s | widać na zegarku (z zegarkiem dokładnie) |

Ewakuacja wymaga stania w strefie wyjścia do końca odliczania. **Wyjście z gry w trakcie rajdu = zaginięcie w akcji** (sprzęt przepada, kryjówka zostaje).

# 6. Raport urzędowy

Po rajdzie gracz dostaje **dokument z pieczątką**: wynik (ewakuowany / zgon / zaginięcie), czas, zabici z podziałem na oddziały, wyniesiony łup z wartością, zysk netto (po odjęciu zużytej amunicji i leków), zużycie broni i pancerzy w bonach, kurz na broni, zmiany reputacji, postęp zleceń i **dopiski** (satyryczne notatki o przebiegu: „Pacyfizm odnotowano w aktach.”). Przy zgonie – przyczyna i komunikat (np. „Prosimy nie dokarmiać zwierząt Sobą.”), lista utraconego sprzętu i to, co wróci z ubezpieczenia.

# 7. Postęp gracza

Strefa K-12 nie ma poziomów postaci ani drzewek umiejętności. Postęp to:

1. **Sprzęt** – lepsza broń, pancerze, oporządzenie, dodatki (nie znika sam, ale można go stracić).
2. **Kryjówka** – większa skrytka, funkcje (warsztat, kuchnia, sen), druga izba.
3. **Reputacja** – dostęp do lepszej oferty frakcji, rozejmy w strefie, ostrzeżenia, tańsze ceny.
4. **Wiedza gracza** – nauka układów, sygnałów AI, strzałek, pułapek.

Celowo nie ma „expa”: każda przewaga ma swoje odbicie w świecie i może zostać utracona.

# 8. Zapis gry

- Zapis JSON z kopią zapasową (`user://zapis_k12.json`), wersjonowanie siatek (stare zapisy są przeliczane).
- Ustawienia w osobnym pliku (`user://ustawienia.json`).
- Brak zapisu w trakcie rajdu – stan rajdu nie jest zapisywany.

# Odnośniki

- Szczegóły mechanik → **05 Mechaniki**
- Frakcje, przeciwnicy, placówka → **04 Świat gry**
- Ceny, obrażenia, reputacja → **07 Balans**
- Katalog przedmiotów i mebli → **06 Przedmioty**
- Historia i plany → **08 Plan rozwoju i historia**
