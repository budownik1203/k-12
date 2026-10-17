# Stan demo (17.10.2026)

Pierwsze grywalne demo Strefy K-12 według GDD (wersja 3D FPS). Silnik: Godot 4.6, renderer Compatibility.

## Zrobione

| Obszar | Co działa |
| --- | --- |
| Pętla | menu → baza → rajd → ewakuacja albo zgon → raport urzędowy → baza; zapis JSON z kopią zapasową |
| Biom 1: Blokowisko | losowy graf 14–18 pomieszczeń 6x6 m; 8 typów (klatka, korytarz, mieszkanie, kuchnia, administracja, piwnica, magazyn, warsztat); drzwi, szerokie przejścia, okna z widokiem na bloki; ok. 25 typów mebli; lampy sprawne, migające i zepsute; walidacja przechodniości po wypieczeniu nawigacji |
| Wyjścia | 3 typy: główne (brama), na klucz (piwnica nr 7, klucz losowo w biurkach i szafach), czasowe (okno na rusztowanie); odliczanie; lista [O] z kierunkiem |
| Gracz | ruch z bezwładnością zależną od wagi, 4 progi obciążenia, bieg z wytrzymałością, kucanie, wychylenia Q/E, skok, obrażenia od upadku, latarka |
| Rany | 5 części ciała, krwawienie lekkie i ciężkie, złamania, ból (drżenie celownika), leczenie z czasem (5 leków), urazy przenoszone do bazy |
| Broń | 4 bronie (PW-9, PM-63, KB-47, obrzyn), hitscan, celowanie przez przyrządy, odrzut, tryby ognia, przeładowanie zwykłe i szybkie, nabój w komorze, ładowanie pojedyncze strzelby, sprawdzanie amunicji, penetracja kaliber kontra klasa pancerza i zużycie |
| Magazynki (Wardogs) | osobne przedmioty, amunicja luzem w stosach, napełnianie [G] i przeciąganiem z czasem w rajdzie, rozładowanie |
| Ekwipunek | siatki pojemników (kieszenie, kamizelka, plecak, skrytka, kontener bezpieczny), obracanie, stosy, redukcja wagi pojemnika, sloty na ciele, przeszukiwanie ze stopniowym odkrywaniem zawartości |
| Przeciwnicy | Szabrownicy i Najemnicy w oddziałach; wzrok (stożek, oświetlenie gracza, kucanie), słuch, pamięć pozycji; osłony, flankowanie, wychylanie zza osłon, łączność w oddziale, morale i ucieczka, nowy dowódca u najemników; okrzyki z napisami; łup z ciał; rosnące zagrożenie (kolejne grupy) |
| Fauna | zdziczałe psy: reagują na hałas, gonią, gryzą (krwawienie), uciekają ranne |
| Baza | schron chodzony w FPS, 3 handlarzy z ofertą i skupem, leczenie u Medyka, ubezpieczenie u Pośrednika, darmowy zestaw startowy, rozkaz wyjścia z ostrzeżeniami |
| Oprawa | low poly PS1: niska rozdzielczość (1/3), drgające wierzchołki, częściowo afiniczne tekstury, dithering 15-bit, mgła, winieta, ziarno; wszystkie tekstury, modele, ikony i dźwięki generowane kodem |
| Satyra | opisy przedmiotów, komunikaty po śmierci zależne od przyczyny, dopiski w raporcie, powitania handlarzy |

## Świadome uproszczenia demo

- Jedno piętro w rajdzie (bez pionowości), drzwi bez otwierania.
- Brak granatów, zacięć i modyfikacji broni.
- Brak zapisu zawieszającego w trakcie rajdu (wyjście z rajdu = zaginięcie w akcji).
- Sojusze frakcji statyczne, tylko 2 frakcje ludzkie (Wojskowi w kolejnej iteracji).
- Ręce i bronie animowane proceduralnie (bez szkieletu).
- Brak craftu, reputacji u handlarzy i drzewka rozwoju bazy.
- Boss biomu jeszcze nie istnieje.

## Proponowane następne kroki (etap 4 z roadmapy)

1. Wojskowi jako trzecia frakcja z punktami kontrolnymi.
2. Boss biomu 1: dowódca z oddziałem i zadaniem terenowym.
3. Granaty (odłamkowy, dymny) i otwierane drzwi.
4. Pionowość: klatka schodowa jako łącznik pięter (model już istnieje).
5. Modyfikacje broni i craft amunicji w bazie.
6. Kontrakty handlarzy (cele rajdu).
