nr: 04
tytul: Świat gry: frakcje i przeciwnicy
podtytul: Frakcje strefy, ich przedstawiciele w placówce, zachowania AI w rajdzie, fauna, boss Sęp, reputacja i placówka jako miejsce.
stempel: КОНТРОЛЬ
---

# Przegląd sił w strefie

| Siła | Rola w rajdzie | Rola w placówce | Stosunek do gracza |
| --- | --- | --- | --- |
| Szabrownicy | najliczniejsi, słabo uzbrojeni, szukają łupu, malują fałszywe strzałki | Zenek „Kulawy”: narzędzia, klucz, mapa, granaty, zlecenia | neutralny start (rep. 0), rozejm od +35 |
| Najemnicy | dobrze uzbrojone oddziały, latarki na broni, zorganizowane | kpt. Rys: oporządzenie, dodatki, BP, zlecenia | neutralny start, rozejm od +40 |
| Wojsko | posterunki z worków z piaskiem, obławy, granaty | por. Wrona: pancerze, luneta, plecak wojskowy, zlecenia | neutralny start, rozejm od +50 |
| Dezerterzy (Sęp) | boss z obstawą w głębi strefy | cel zleceń Wojska i Najemników | zawsze wrogo, poza reputacją |
| Fauna (pełzacze) | atakuje wszystkich, po ścianach i sufitach | — | zawsze wrogo |

Wszystkie frakcje ludzkie **walczą także ze sobą**. Cel wroga to najbliższy widoczny przeciwnik – gracz nie ma pierwszeństwa. Strzały NPC są słyszalne i ściągają innych.

# Frakcje ludzkie – dane

| Parametr | Szabrownicy | Najemnicy | Wojsko |
| --- | --- | --- | --- |
| Celność (mnożnik) | 0,50 | 0,75 | 0,70 |
| Czas reakcji (mnożnik) | 1,00 (wolno) | 0,70 (szybko) | 0,80 |
| Morale bazowe | 0,35 | 0,65 | 0,80 |
| Zdrowie | ×1,0 | ×1,0 | ×1,0 |
| Liczebność grupy | 2–3 | 2 | 2 (+ posterunki 2–4 gniazda) |
| Poddawanie się | tak, chętnie | tak | nie (posterunki nie wychodzą) |
| Szaber ciał i łupu | tak | tak | nie |
| Granaty | nie | tak | tak |

## Zestawy wyposażenia (losowane wg wag)

**Szabrownicy:** PW-9 + 2 magazynki (waga 40) · obrzyn 12/70 (35) · PM-63 + 1 magazynek (20) · KB-47 + 1 magazynek + kamizelka kl. 2 (5).
Łup przy sobie: papierosy, konserwa, wódka, kartka na mięso, bandaż, zegarek (rzadko).

**Najemnicy:** KB-47 + 2 mag. + kl. 2 + hełm (40) · PM-63 + 2 mag. + kl. 2 (35) · KB-47 + 3 mag. + kl. 4 + hełm (25).
Łup: opatrunki, apteczki, amunicja BP, łańcuszki, teczki akt, proch.

**Wojsko:** KB-47 + 3 mag. + kl. 4 + hełm (30) · KB-47 na BP + 2 mag. + kl. 2 + hełm (45) · PM-63 + 3 mag. + kl. 2 + hełm (25).
Łup: opatrunki, apteczki, amunicja 7,62, magazynki KB-47, kompas, mapa, tkanina balistyczna.

# AI – stany i zachowania

## Stany
| Stan | Zachowanie |
| --- | --- |
| patrol | chodzi po trasie oddziału, rozgląda się, w oddziale naprzód idzie jeden, reszta osłania |
| czujny | coś usłyszał lub zauważył; nasłuch w miejscu przy odległych strzałach |
| szukanie | idzie do ostatniej znanej pozycji celu, przeczesuje okolicę |
| walka | strzela, szuka osłon, flankuje, wychyla się zza osłon, krótkie skoki do osłon (bieg tylko pod ostrzałem), chowa głowę pod silnym ogniem |
| ucieczka | niskie morale – ucieka (szabrownik z łupem) |
| poddany | rzucił broń, ręce w górze – gracz decyduje: oddaj łup / kup informację i rozejm (300 bonów) / puść |
| posterunek | siedzi w gnieździe z worków, wstaje do strzału, nie wychodzi; po ok. 75 s bez efektu oddział atakujący odpuszcza |
| szaber | po ucichnięciu walki obszukuje świeże ciała i leżące rzeczy (porzucony plecak gracza też) |
| opatrywanie | opatruje się za osłoną albo opatruje rannego kolegę (kilka sekund bez strzelania) |

## Percepcja
- **Wzrok:** stożek widzenia, zależny od oświetlenia celu (lampy, latarka gracza, wyłączniki), kucania, kurzu w powietrzu (zasłania wzrok i psuje celność).
- **Słuch:** dźwięk liczony **po drodze** przez korytarze i drzwi (siatka nawigacji), każdy zakręt tłumi. Blisko – alarm i szukanie, daleko – nasłuch w miejscu.
- **Pamięć:** ostatnia pozycja celu, trzymanie kątów po utracie kontaktu.
- **Ciała:** ciało swojego w zasięgu wzroku → alarm oddziału i poszukiwania w stronę strzelca. W ciemności ciało widać tylko z bliska (latarka na broni pomaga) – stąd sens ciągnięcia zwłok w ciemny kąt.
- **Pułapki:** szansa zauważenia szklanki na klamce albo drutu: bazowo 18%, +do 45% wg światła, +15% gdy czujny/szuka, −15% w walce/ucieczce, wojsko +10%, najemnicy +12% (latarki); zakres 5–85%. Zauważona pułapka jest rozbrajana, a granat trafia do łupu wroga.

## Walka i ciało NPC
- Ciało jak u gracza (5 części), ale **NPC częściej krwawi, pada od szoku przy dużej utracie krwi i ginie od zniszczonego brzucha** (mniej „gąbek na kule”).
- Zachwianie po trafieniu (chwila bez strzału), drgnięcie w kierunku strzału, ragdoll po śmierci (11 brył).
- **Przygniatanie ogniem:** kule obok wroga – chowa się, gorzej celuje, traci morale.
- **Celność spada z dystansem** (rozrzut rośnie z odległością), broń wrogów też się zacina (okrzyk, przerwa w ogniu).
- **Granaty:** wojsko i najemnicy rzucają w schowanego gracza z ostrzeżeniem („Granat!”); wrogowie uciekają przed granatem.
- **Ranny woła o pomoc** – najbliższy kolega podbiega i opatruje (ranny to przynęta dla obu stron).
- **Drzwi:** otwierają tylko te na swojej drodze, zamknięte i zaklinowane wyważają kopniakami (słychać), barykadę z przesuwnych przedmiotów spychają po trochu.
- **Światło:** wróg, który wejdzie do pokoju zapamiętanego jako jasny, a zastanie ciemność, robi się czujny i idzie do wyłącznika.
- **Okrzyki z napisami** (alarm, komendy, ranny, śmierć) – barwa głosu stała dla postaci.

## Oddziały i dynamika rajdu
- Na start: 3–7 grup + 2–4 posterunki wojska, nazwy oddziałów z alfabetu (Alfa-07, Bravo-12…).
- **Rosnące zagrożenie:** co 200–300 s (szybciej przy hałasie) wchodzi nowa grupa szabrowników albo stado fauny.
- **Zdarzenia:** awaria prądu, obława wojska, zrzut skrzyni z racą (słychać z daleka).
- **Najemnicy** po śmierci dowódcy wybierają nowego.
- **Polowanie:** frakcja z reputacją ≤ −40 co 80–120 s wysyła najbliższy wolny oddział na pozycję gracza (zapowiedź w radiu, wpis w raporcie).
- **Ostrzeżenia:** oddział z rozejmem, który zobaczy gracza z bliska, raz ostrzega przed najbliższym zagrożeniem (kto, kierunek, piętro, odległość).

# Boss: Sęp

| Parametr | Wartość |
| --- | --- |
| Kim jest | dezerter z najemników z dwoma ludźmi |
| Pojawienie się | 40% rajdów; **zawsze** przy przyjętym zleceniu na niego (likwidacja albo nieśmiertelnik) |
| Pozycja | najgłębsza wolna część mapy, ≥ 40 m od startu, twarzą ku wejściu (jak posterunek) |
| Wyposażenie | KB-47 z kolimatorem na amunicji BP, pancerz kl. 4, hełm, 3 granaty, czarna skóra |
| Statystyki | zdrowie ×1,8, szybsza reakcja i lepsza celność, nie ucieka i nie poddaje się (do czasu – patrz niżej) |
| Zachowanie | cofa się za obstawę; sam albo poniżej połowy zdrowia ucieka do wyjścia |
| Łup | **Nieśmiertelnik Sępa** |
| Zlecenia | Wojsko – likwidacja (15 000 bonów, rep. +15); Najemnicy – nieśmiertelnik (14 000, rep. +15) |
| Reputacja | dezerterzy nie wpływają na reputację żadnej frakcji |
| Wywiad | stół z mapą i Pośrednik podają, czy Sęp będzie w następnym rajdzie |

# Fauna: pełzacze

Mutanty z organicznych powierzchni: wychudły tułów z żebrami i grzebieniem kręgów, wydłużona czaszka, szczęki z zębami, długie kończyny z trzema pazurami.

- **Cykl:** czai się pod stropem → pełznie po suficie nad ofiarą → zeskakuje z wrzaskiem → gryzie na ziemi (szybki pościg) → ranny (lub po chwili walki) wspina się po ścianie i znika w ciemności pod stropem.
- **Cele:** wszystko, co żyje (gracz i ludzie każdej frakcji) – walka fauny z frakcjami to darmowy chaos do wykorzystania.
- **Pojawianie się:** stada 1–2 na start, 2–3 przy nowych falach („Hałas zwabił faunę strefy.”).
- Przyczyna zgonu w raporcie: „fauna” – „Prosimy nie dokarmiać zwierząt Sobą.”
- *Historia:* w pierwszych wersjach faunę stanowiły **zdziczałe psy**; później zastąpiono je pełzaczami, które wykorzystują pionową przestrzeń korytarzy (sufit, ściany) – patrz *Plan rozwoju i historia*.

# Reputacja

| Zasada | Wartość |
| --- | --- |
| Zakres | −100 … +100 dla każdej frakcji |
| Zabicie członka frakcji | −5 u niej, +1 u pozostałych (tylko gdy ostatni trafił gracz: kula, granat, wykrwawienie po trafieniu) |
| Zlecenie frakcji | +6 … +15 |
| Opisy | zaufany ≥60, przyjazny ≥30, znany ≥10, obojętny ≥−10, podejrzany > −30, wrogi ≤ −30 |
| Ceny | do −15% przy +100, do +25% przy −60 i niżej |
| Brak handlu | ≤ −30 |
| Rozejm w strefie | Szabrownicy +35, Najemnicy +40, Wojsko +50 – oddziały nie strzelają pierwsze; strzał gracza zrywa rozejm całego oddziału |
| Polowanie | ≤ −40: oddziały ruszają na gracza |
| Wiarygodność meldunków | rośnie z reputacją u Wojska |

Reputacja zmusza do **wyboru strony**: zlecenia jednej frakcji zwykle polegają na zabijaniu członków innej.

# Przedstawiciele frakcji w placówce

| Frakcja | Przedstawiciel | Oferta (próg reputacji) | Zlecenia (nagroda, rep.) | Skup |
| --- | --- | --- | --- | --- |
| Szabrownicy | Zenek „Kulawy”, łącznik | wytrych, taśma, mapa, obrzyn, śrut, proch, spray, drut, klin (0); maska, prasa, zestaw czyszczący (10); klucz do piwnicy (15); lornetka (25); granat (35) | 2 najemników (6000, +12); 2 żołnierzy (7000, +14); zegarki ×2 (7500); wódka ×2 (3500); łańcuszek (7000) | łup, klucze, mapy – 55% |
| Najemnicy | kpt. Rys, werbownik | plecak szturmowy, latarka taktyczna, opatrunek (0); chwyt (10); LBV, tkanina (15); kolimator (20); tłumik 9 (25); BP (30); tłumik 7,62 (45) | nieśmiertelnik Sępa (14 000, +15); 3 szabrowników (4500); 2 żołnierzy (8000); kanister, akumulator; zwiad magazynu (3000) | leki, dodatki, amunicja – 45% |
| Wojsko | por. Wrona, oficer łącznikowy | hełm, kl. 2, magazynek KB, 7,62 (0); napierśnik (10); hamulec (15); BP (20); granat (20); plecak wojskowy (25); kl. 4 (40); luneta (55) | Sęp (15 000, +15); 4 szabrowników (5500); 2 najemników (8500); teczka akt, radia ×2; zwiad administracji (3000) | broń, magazynki, pancerze, granaty – 45% |

Każda frakcja daje **dwie oferty zleceń** po każdym rajdzie; razem można mieć najwyżej **3 przyjęte**.

# Placówka – miejsce

- **Kryjówka** (8 x 7 m, beton) + opcjonalnie druga izba 5 x 7 m za 25 000 bonów (Kwatermistrz przebija ścianę).
- **Recepcja** 20 x 14 m: filary, poczekalnia, stragany z plandekami (Zbrojmistrz – krata z okienkiem i stojak z bronią, Medyk – szyba, Pośrednik – kasa, Kwatermistrz), stoliki Szabrowników i Najemników, punkt kontrolny Wojska przy śluzie.
- Handlarze mają **lady z towarem na blacie** – oferta jest widoczna w świecie.

# Możliwości rozwoju

- Zadanie terenowe Sępa (konwój albo ucieczka z teczką do wyjścia) zamiast stałej pozycji.
- Kolejne frakcje w dalszych biomach (np. sekta przy kompleksie, personel badawczy, który został).
- Rozmowy w spoczynku i radio wrogów zdradzające pozycje (podsłuch wroga – częściowo w ankiecie mechanik).
- Przekupstwo szabrowników przy przejściu (opłata zamiast walki) – obecnie istnieje rozejm po poddaniu.
- Więcej gatunków fauny: coś, co poluje słuchem w ciemności (wymusza gaszenie latarki).
