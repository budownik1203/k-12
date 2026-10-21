nr: 08
tytul: Plan rozwoju i historia
podtytul: Dokąd zmierza projekt (roadmapa), jak do tego doszedł (historia wersji 17–21.10.2026) i co się nie udało – z powodami.
stempel: EGZ. NR 2
---

# Roadmapa

Priorytety wynikają z filarów (*Dokument ogólny*): najpierw głębia istniejącej pętli, potem szerokość (biomy).

## Krótko (następne wersje)
| Zadanie | Dlaczego | Zależności |
| --- | --- | --- |
| Wydanie v0.16.6 i sprawdzenie testu `--test_v14` (wróg nie zdjął pułapki) | domknięcie bieżących poprawek | regresja |
| Weryfikacja okna czasowego po spowolnieniu tempa | wolniejszy ruch (v0.15) mógł uczynić okno 10–25 min za ciasnym | sonda `--ekonomia`, rozgrywka |
| Obserwacja „lewitujących” obiektów i plakatów | dwa zgłoszenia bez potwierdzonej przyczyny | zrzuty od gracza |

## Średnio
| Zadanie | Opis |
| --- | --- |
| Zadanie terenowe Sępa | konwój albo ucieczka z teczką do wyjścia zamiast stałej pozycji |
| Podsłuch wroga | rozmowy w spoczynku i radio zdradzające pozycje (z ankiety mechanik) |
| Przekupstwo przy przejściu | opłata u szabrowników zamiast walki |
| Druga broń długa | strzelba pompowa lub karabin wyborowy; kolby, magazynki bębnowe |
| Łom | trzeci sposób na drzwi i kłódki (szybciej niż wytrych, ciszej niż kopniak) |
| Meble na ścianie w kryjówce | tablica z mapą strefy (podgląd wyjść przed rajdem) |
| Archiwum dokumentów | teczki akt i kasety jako fragmenty lore do przeczytania/odsłuchania w kryjówce |

## Daleko
| Zadanie | Opis |
| --- | --- |
| Drugi biom | Zakłady (hale, suwnice) – własny generator pomieszczeń, boss, zlecenia |
| Kolejne biomy | Szpital zakładowy, Ośrodek badawczy (bliżej kompleksu, dziwniejsza fauna) |
| Nowa fauna | drapieżnik polujący słuchem w ciemności (wymusza gaszenie latarki) |
| Większe dystanse | otwarte podwórza między blokami – powrót do wstrzymania oddechu i lunet |
| Fabuła przez przedmioty | stopniowe odsłanianie, co stało się w kompleksie (bez przerywników) |

# Historia wersji

Projekt powstawał bardzo szybko (17–21 października 2026), w rytmie: prośba autora → wdrożenie → testy automatyczne → wydanie → raport z propozycjami.

| Data | Wersja | Najważniejsze |
| --- | --- | --- |
| 17.10 | rdzeń, demo 0.1 | dane przedmiotów, ekwipunek z wagą, model ciała, broń; generator biomu 1, AI, HUD, baza z handlarzami, raporty, dźwięk; testy UI/walki/ewakuacji; fauna (zdziczałe psy), kontener bezpieczny, ubezpieczenie; naprawa nawigacji; oświetlenie per pomieszczenie; korytarze, słuch po drodze dźwięku; grube mury, ciężki ruch, latarka |
| 18.10 | v0.5 – v0.9.8 | panel operatora, dodatki do broni; ankieta mechanik; ekwipunek przezroczysty i w świecie (plecak zdejmowany); wojna frakcji; większa mapa 11x8; **render w stylu Iron Blight**; modele broni i postaci od nowa; bez stałego HUD-u; animacje broni i czynności; przedmioty na ziemi jako modele; meble otwierane; przeszukiwanie ciał; przekładanie ręką; szaber wrogów, zużycie broni |
| 19.10 | v0.9.9 – v0.9.25 | dźwięk; modele z tkaniny (blend shape); drzwi; broń w ruchu; pełzacz; głód i pragnienie, poddawanie się; granaty, zdarzenia, zlecenia; QoL; kieszenie gestem; wytrych; **piętro**; choreografia przeładowań; drobna siatka; ikony-szkice; ragdolle |
| 20.10 | v0.10 – v0.14 | **placówka** (kryjówka z budową, recepcja, frakcje z reputacją); **boss Sęp**, elaboracja, łaty; ślady na ścianach, strzałki do wyjść; pułapka z granatu, spray, mapa; potykacz, zauważanie pułapek |
| 21.10 | v0.14.1 – v0.16.6 | **tempo wolniej i ciężej**, ciągnięcie zwłok; **fizyczne drzwi i przedmioty**, stres; przegląd mechanik (drzwi i meble tylko ręką, czas na zegarku, mapa zamiast listy); pełny ekran; poprawki generatora (okna, światła, detale) |

Szczegółowa lista zmian: `docs/STAN_DEMO.md` (tabela „Zrobione”) i historia commitów repozytorium.

# Co się nie udało i dlaczego

Ta sekcja jest najważniejsza dla dalszej pracy: pokazuje decyzje, do których **nie należy wracać** bez nowego argumentu.

## Interfejs i informacja
| Próba | Co było nie tak | Co zostało |
| --- | --- | --- |
| Lista wyjść [O] z kierunkiem i odległością (v0.13) | wiedza „z powietrza”, sprzeczna z filarem wiedzy zamiast HUD-u | v0.16.0 bez kierunku, v0.16.3 usunięta: stan wyjść na mapie w rękach, czas na zegarku |
| Hit marker i dźwięk trafienia | gracz wiedział o trafieniu bez patrzenia | usunięte (v0.16.0) – o trafieniu mówi świat (krew, zachwianie, okrzyk) |
| Kropka celownika | podpowiedź, której nie ma w ręku; w bazie łapała kliknięcie przy stawianiu mebli | usunięta (v0.16.3 rajd, v0.16.4 baza) |
| Napis „podparta” | informacja tekstowa o stanie, który czuć | usunięty (v0.16.4) |
| Natychmiastowe [T] (licznik naboi) | brak kosztu wiedzy | sprawdzanie trwa i daje przybliżenie |
| Napis drzwi „zamknięte na klucz” z daleka | wiedza bez dotknięcia klamki | stan nieznany do naciśnięcia klamki (v0.16.3) |
| Kółko postępu przy każdej czynności | szum na ekranie | tylko przy czynnościach od ok. 2 s (v0.16.0) |

## Ekwipunek
| Próba | Co było nie tak | Co zostało |
| --- | --- | --- |
| Animowana dłoń przy każdym przełożeniu (v0.9.2–v0.9.15) | zasłaniała ekran, męczyła przy wielu ruchach, wydłużała bez wartości | przedmiot sunie po ekranie w czasie zależnym od wagi i odległości (v0.9.16) |
| Dłoń przy zapięciach (v0.9.17) | zasłaniała chwytany element | wyłączona (v0.9.24) |
| Prostokąty kieszeni z podpisami, pierścienie ze strzałkami | za dużo UI na modelu 3D | delikatna poświata brzegów elementu (v0.9.24) |
| Gruba siatka (kratka = 2x2 drobne) | nierealne proporcje przedmiotów | drobna siatka (v0.9.21) z migracją zapisów |
| „Weź wszystko” | sprzeczne z ciężkim ekwipunkiem | celowo brak |
| Ctrl+klik jako szybki skrót | omijał koszt czasu | trwa jak ręczne przełożenie + chwila (v0.16.4) |
| Obszar otwartej kieszeni łapiący kliknięcia (v0.14) | nie dało się wyjąć przedmiotu z worka | zapinanie nie przechwytuje slotów, test na 9 pojemnikach |
| Plecak turystyczny bez przerw między kieszeniami | przedmiot leżał na dwóch kieszeniach | przerwy w układzie (v0.16.4) |

## Świat i fizyka
| Próba | Co było nie tak | Co zostało |
| --- | --- | --- |
| Krótkie F na drzwiach obok chwytu ręką (v0.16.0–0.16.2) | dwa sposoby na to samo | tylko ręka (v0.16.3); meble tak samo (v0.16.4) |
| Cały poziom jako jedna siatka | renderer Compatibility świeci obiekt kilkoma światłami – dalsze lampy gasły | geometria osobno na pomieszczenie |
| Światła obu kondygnacji naraz | renderer gubił część świateł – korytarz „zapalał się” z bliska | tylko kondygnacja gracza i 40 najbliższych (v0.16.3) |
| Okna budowane w jednym kierunku | w połowie ścian szyba odwrócona – „okno na świat” | orientacja jak ściany (v0.16.3) + test ścian |
| Detale korytarzy wzdłuż obu boków kwadratu skrzyżowania | listwy i puszki z kablem w przejściach (czarne paski, „wiszący przełącznik”) | tylko na murze (v0.16.6) |
| Wyłącznik przyklejany do pierwszej trafionej powierzchni | wisiał na skrzydle drzwi lub szafie | na licu muru (v0.16.6) |
| Kolizja okna w tym samym ciele co mury | plakaty na niewidzialnej płaszczyźnie przed oknem | osobne ciało „Okna” (v0.16.6) |
| Niesienie skrzynki przed oczami | zasłaniała widok („blok w powietrzu”) | na wysokości piersi + straż przed lewitacją (v0.16.3) |
| Panel budowy w świecie 3D (SubViewport) | przyciski nie dostawały kliknięć | panel i wejście w głównym oknie (v0.16.4) |

## Rozgrywka
| Próba | Co było nie tak | Co zostało |
| --- | --- | --- |
| Szybkie tempo (marsz 2,45 m/s, bieg 4,5) | korytarze „przelatywało się”, brak ciężaru | 1,7 / 3,5 m/s (v0.15) |
| Darmowy zestaw startowy do sprzedania | nieskończone bony | sprzęt z przydziału nie do sprzedania (v0.10) |
| Zabójstwa liczone bez udziału gracza | wojna frakcji psuła reputację i nabijała zlecenia | tylko ofiary gracza (v0.11) |
| Statyczne sojusze frakcji | nie dało się zrobić rozejmu ani poddania | stan per oddział |
| Fauna: zdziczałe psy | — | zastąpione pełzaczami (pionowa przestrzeń korytarzy) |
| Leżenie, wstrzymanie oddechu | ciasne wnętrza, brak dużych dystansów | odrzucone przez autora |
| Pęknięte żebro jako osobny stan | dodatkowy system bez potrzeby | zwykłe złamanie klatki, szyna |
| Znaki gracza między rajdami | — | odrzucone przez autora |
| Zamykająca się strefa, ciało poprzednika, zakład z Pośrednikiem | kolizje z istniejącymi systemami | odrzucone w ankiecie |

## Oprawa
| Próba | Co było nie tak | Co zostało |
| --- | --- | --- |
| Render niskiej rozdzielczości (PS1 SubViewport) | zmiana kierunku na referencję Iron Blight | natywna rozdzielczość, pikselowe tekstury (v0.9.x) |
| Kreskowanie krzyżowe w ikonach | mora w małej skali | cieniowanie paskami (v0.9.23) |
| Sprawdzanie magazynka z obrotem broni o 35° | wyglądało jak podmiana broni | lekki przechył (v0.12) |
| Butelka przy piciu szyjką od twarzy | animacja odwrócona | szyjka do ust (v0.16.6) |
| Przeładowanie z latarką: magazynek leciał sam | lewa dłoń trzymała latarkę i nie brała udziału | dłoń z latarką sięga po magazynek (v0.16.3) |

## Testy i proces
| Problem | Lekcja |
| --- | --- |
| Testy godota puszczane równolegle | fałszywe błędy fizyki i AI – regresja zawsze sekwencyjnie |
| Testy losowe (walka, potykacz) | testować mechanizm (np. zatrzymać AI), nie przypadkowy wynik; liczby zabitych tylko informacyjnie |
| Paczka wydania z poprzednim plikiem exe | po eksporcie sprawdzać rozmiar/datę exe przed spakowaniem |
| Statyczna lambda w autoloadzie efektów | uszkodzenie sterty przy wyjściu – sprzątanie w `_exit_tree` |
