# Stan demo (17.10.2026)

Pierwsze grywalne demo Strefy K-12 według GDD (wersja 3D FPS). Silnik: Godot 4.6, renderer Compatibility.

## Zrobione

| Obszar | Co działa |
| --- | --- |
| Pętla | menu → baza → rajd → ewakuacja albo zgon → raport urzędowy → baza; zapis JSON z kopią zapasową |
| Biom 1: Blokowisko | siatka komórek 9x9 m: sieć korytarzy 3,2 m (30–50% planszy, za każdym razem inna) i pomieszczenia 5,6–8,3 m oddzielone litym murem; drzwi w grubych ścianach, część pomieszczeń prowadzi dalej do kolejnych, czasem sąsiednie pokoje łączą drzwi; głębiej korytarze przechodzą w piwniczne; 7 typów pomieszczeń; meble zestawami (wersalka z telewizorem naprzeciw, meblościanka, stół z krzesłami na dywanie, ciąg kuchenny, rząd biurek, regały pod ścianami, skrzynie w narożnikach, kaloryfery pod oknami); okna z widokiem na bloki; ok. 25 typów mebli; lampy sprawne, migające i zepsute; walidacja przechodniości po wypieczeniu nawigacji |
| Wyjścia | 3 typy: główne (brama), na klucz (piwnica nr 7, klucz losowo w biurkach i szafach), czasowe (okno na rusztowanie); odliczanie; lista [O] z kierunkiem |
| Gracz | ciężki ruch (rozpędzanie i hamowanie w m/s² zależne od obciążenia, kołysanie głowy w rytm kroków, przechył, ugięcie po lądowaniu), 4 progi obciążenia, bieg z wytrzymałością, kucanie, wychylenia Q/E, skok, obrażenia od upadku, latarka |
| Rany | 5 części ciała, krwawienie lekkie i ciężkie, złamania, ból (drżenie celownika), leczenie z czasem i animacją rąk (5 leków), panel zdrowia jak w Tarkovie (lek na wybraną część ciała), przerywanie [X], urazy przenoszone do bazy |
| Broń | 4 bronie (PW-9, PM-63, KB-47, obrzyn), płomień z lufy, łuski, kopnięcie kamery, pogłos strzału, znacznik trafienia, krew na ścianach, wróg drga po trafieniu i pada w kierunku strzału, hitscan, celowanie przez przyrządy, odrzut, tryby ognia, przeładowanie zwykłe i szybkie, nabój w komorze, ładowanie pojedyncze strzelby, sprawdzanie amunicji, penetracja kaliber kontra klasa pancerza i zużycie |
| Magazynki (Wardogs) | osobne przedmioty, amunicja luzem w stosach, napełnianie nabój po naboju z kółkiem postępu i animacją ([G] wszystkie po kolei, przeciąganie amunicji na magazynek), przerwanie zostawia włożone naboje, rozładowanie |
| Latarka | przedmiot trzymany w lewej ręce: z pistoletem (chwyt Harriesa) albo sama; karabin chowa latarkę; snop z soczewki (jasny środek z cieniem + szeroka poświata), pulsująca żarówka |
| Animacje | przeładowanie lewą ręką (wyjęcie, sięgnięcie do kamizelki, włożenie, zamek przy pustej komorze), broń opuszczona w biegu, ręce przy leczeniu i napełnianiu |
| Modele wrogów | stawy łokci i kolan, dłonie na broni (kinematyka odwrotna), chód ze zgięciem kolan, przyklęk, celowanie tułowiem, rozglądanie się, przeładowanie z magazynkiem w dłoni, odrzut, osuwanie przy śmierci, smugi pocisków, latarki na broni najemników |
| HUD | pasek szybkiego dostępu [1-9] budowany z ekwipunku, kółko postępu akcji, znacznik trafienia, zapas magazynków pod ręką, stany ciała |
| Ekwipunek | wygląd rozpiętego oporządzenia (płótno, kieszenie z przeszyciem, naszywki), sloty wokół sylwetki, wyrzucanie przeciągnięciem poza sloty, siatki pojemników (kieszenie, kamizelka, plecak, skrytka, kontener bezpieczny), obracanie, stosy, redukcja wagi pojemnika, sloty na ciele, przeszukiwanie ze stopniowym odkrywaniem zawartości |
| Przeciwnicy | Szabrownicy i Najemnicy w oddziałach; wzrok (stożek, oświetlenie gracza, kucanie), słuch liczony po drodze dźwięku przez korytarze i drzwi (zakręty tłumią), blisko: alarm i szukanie, daleko: nasłuch w miejscu; pamięć pozycji; osłony, flankowanie, wychylanie zza osłon, łączność w oddziale, morale i ucieczka, nowy dowódca u najemników; okrzyki z napisami; łup z ciał; rosnące zagrożenie (kolejne grupy) |
| Fauna | zdziczałe psy: reagują na hałas, gonią, gryzą (krwawienie), uciekają ranne |
| Baza | schron chodzony w FPS, 3 handlarzy z ofertą i skupem, leczenie u Medyka, ubezpieczenie u Pośrednika, darmowy zestaw startowy, rozkaz wyjścia z ostrzeżeniami |
| Oprawa | low poly PS1: niska rozdzielczość (1/3), drgające wierzchołki, częściowo afiniczne tekstury, dithering 15-bit, mgła, winieta, ziarno; wszystkie tekstury, modele, ikony i dźwięki generowane kodem |
| Satyra | opisy przedmiotów, komunikaty po śmierci zależne od przyczyny, dopiski w raporcie, powitania handlarzy |

## Świadome uproszczenia demo

- Jedno piętro w rajdzie (bez pionowości), drzwi bez otwierania.
- Obraz 3D w 1/2 rozdzielczości (wcześniej 1/3) i słabsza mgła – cel widać z kilkunastu metrów.
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
