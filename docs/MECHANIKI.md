# Wybrane mechaniki (ankieta 18.10.2026)

Z 32 propozycji wybrane do realizacji. Przy każdej: co już jest w grze lub w planie, żeby się nie dublowało.

| Mechanika | Opis | Styk z istniejącym / planowanym |
| --- | --- | --- |
| Podsłuch wroga | Rozmowy i radio wrogów zdradzają pozycje i zamiary, gdy podejdziesz cicho | rozszerza istniejące okrzyki z napisami; nowe: rozmowy w spoczynku i komunikaty radiowe |
| Przygniatanie ogniem | Ogień gracza obniża celność i morale wrogów | AI już chowa głowę pod silnym ogniem; nowe: mierzalny poziom przygniecenia, spadek celności, wpływ na morale i skoki do osłon |
| Zacięcia i stan broni | Zużycie i brud → zacięcia, usuwane sekwencją ruchów | penetracja i zużycie pancerza już są; broń dostaje stan, naprawa u Zbrojmistrza i na stole roboczym |
| Napoczęte magazynki + sprawdzanie | Bez licznika; sprawdzenie magazynka trwa chwilę i daje przybliżoną liczbę („około połowy”) | zastępuje obecne natychmiastowe [T]; akcja z kółkiem, przerywalna |
| Plecak na ziemi | Zdjęty plecak leży w świecie, dopóki go nie założysz; wróg może go zabrać | spina się z nowym otwieraniem pojemników: pełne przeglądanie plecaka tylko po zdjęciu |
| Drzwi: otwieranie i wyważanie | Wytrych, łom, kopniak (hałas), barykadowanie | było w planie (krok 3) – realizujemy tu; słuch AI już liczy drogę dźwięku przez drzwi |
| Zdarzenia w strefie | Zawalenie stropu, pożar, patrol, zrzut słyszany z daleka | rosnące zagrożenie (kolejne grupy) już jest – zdarzenia je zastępują i urozmaicają, nie dublują |
| Głód i pragnienie (lekko) | Jedzenie i woda podtrzymują wytrzymałość i regenerację | konserwy i woda są już łupem – dostają funkcję |
| Przekupstwo i rozejm | Szabrownicy przepuszczają za opłatą; opuszczona broń = brak wrogich zamiarów | wymaga zmiany statycznych sojuszy na stan per oddział |
| Poddawanie się | Ranny wróg może się poddać (szok i morale już są) | korzysta z istniejącego szoku i ucieczki przy niskim morale |
| Wojna frakcji | Frakcje walczą ze sobą, hałasem można je napuścić | słuch po drogach dźwięku już jest; sojusze do przebudowy razem z przekupstwem |

## Odrzucone lub do ponownego przemyślenia

- Ryzyko i nagroda: propozycje kolidowały z planem – „zamykająca się strefa” dubluje wyjście czasowe i rosnące zagrożenie,
  „ciało poprzednika” kłóci się z ubezpieczeniem u Pośrednika, „zakład z Pośrednikiem” z planowanymi kontraktami handlarzy.
  Do nowej rundy pomysłów z osobnym sprawdzeniem kolizji.
- Strefa, świat i meta: bez wyboru – zostaje roadmapa (kontrakty, boss, rozbudowa bazy z GDD).

## Proponowana kolejność

1. Sprawdzanie i napoczęte magazynki, zacięcia (mały zakres, broń i UI już gotowe).
2. Drzwi (otwieranie, wyważanie, barykady) – zmienia generator i nawigację, więc wcześnie.
3. Przygniatanie ogniem i poddawanie się (AI).
4. Przekupstwo, rozejm i wojna frakcji (przebudowa sojuszy).
5. Podsłuch wroga, plecak na ziemi, głód i pragnienie.
6. Zdarzenia w strefie.

## Placówka i reputacja (v0.10.0)

| Mechanika | Opis | Styk z istniejącym |
| --- | --- | --- |
| Kryjówka z meblami | meble z funkcją (skrytka, warsztat, sen, kuchnia, światło) i ozdobne; tryb budowy [B] | zastępuje stałe szafki i stół roboczy dawnego schronu; stare zapisy dostają dawny układ |
| Sen po rajdzie | prycza leczy połowę ran raz po każdym powrocie | Medyk nadal leczy w pełni i od razu – prycza tylko tańsza i wolniejsza droga |
| Kuchenka | posiłek ze skrytki ×1,5 sytości, woda jako herbata | głód i pragnienie maleją też przy wyjściu do strefy, więc jedzenie w bazie ma sens |
| Reputacja frakcji | zabijanie −5, zlecenia +, progi oferty, ceny, rozejm w strefie | rozejm korzysta z istniejącego przekupstwa (flaga oddziału); zabójstwa dla zleceń jednej frakcji kosztują reputację u innej – wybór strony |
| Zestaw z przydziału | darmowy zestaw nie do sprzedania | zamyka pętlę „sprzedaj pistolet → weź nowy zestaw” |

## Boss, warsztat i reputacja w strefie (v0.11.0)

| Mechanika | Opis | Styk z istniejącym |
| --- | --- | --- |
| Sęp | boss z obstawą w głębi strefy; pewny przy przyjętym zleceniu | posterunkowa obrona jak u wojska; dezerterzy poza reputacją i rozejmem najemników |
| Elaboracja | proch + prasa przy stole roboczym → amunicja | uzupełnia sklep: opłaca się tylko z prochu z łupu (cena prochu 400) |
| Łaty pancerza | tkanina przywraca wytrzymałość, maks. −10% za łatę, wartość −15% | Medyk/handlarze nie naprawiają – jedyna droga przedłużenia życia pancerza |
| Ostrzeżenia i polowanie | przyjaźni ostrzegają, wrodzy przy −40 ruszają na gracza | korzysta z istniejącego alarmu oddziału; posterunki wojska nie opuszczają gniazd |
| Rozliczanie zabójstw | tylko ofiary gracza (kula, granat, wykrwawienie po trafieniu) | naprawia nabijanie zleceń i reputacji przez wojnę frakcji |

## Pułapki, ślady i wywiad (v0.13.0)

| Mechanika | Opis | Styk z istniejącym |
| --- | --- | --- |
| Pułapka z granatu | F1 + szklanka na klamce zamkniętych drzwi; otwarcie = wybuch po 2,3–2,8 s | czas zastawiania (5 s) odsłania gracza jak każda czynność z ekwipunku; rozbrojenie tylko od strony pułapki; zabójstwa zaliczane do zleceń |
| Spray gracza | własne strzałki i znaki na ścianach | znaki zostają w danym rajdzie; fałszywe strzałki szabrowników wymuszają weryfikację drogi mapą |
| Mapa ze szkicem | odwiedzone pomieszczenia i zauważone strzałki | wymaga przedmiotu „mapa” w slocie wyposażenia |
| Meldunki | stół z mapą w kryjówce pokazuje Sępa i zdarzenia następnego rajdu | ziarno rajdu losowane z wyprzedzeniem i zapisywane |
| Zaginięcie w akcji | wyjście z gry w trakcie rajdu = utrata sprzętu z rajdu | zamyka exploit „zamknij grę, zachowaj ekwipunek” |
| Bez „weź wszystko” | celowo pominięte: zarządzanie ekwipunkiem ma być ciężkie i odsłaniać gracza | — |

## Pułapki, ciała i ciężar ekwipunku (v0.14.0)

| Mechanika | Opis | Styk z istniejącym |
| --- | --- | --- |
| Potykacz | granat + drut w poprzek przejścia | ten sam zapalnik co pułapka na drzwiach; wrogowie mogą go zauważyć i zabrać granat – pułapka nie jest pewna |
| Zauważanie pułapek | szansa wg światła, czujności i frakcji | korzysta z oświetlenia (jak wykrywanie gracza) i stanu AI |
| Stłuczenie | zatrzymana kula boli kilka sekund | wpięte w ból ciała (drżenie celownika), przeciwbólowe znoszą |
| Zmęczenie rąk | długie celowanie przez przyrządy | zachęca do podparcia i kucania |
| Ciała i ranni | alarm przy ciele, wołanie o pomoc | korzysta z alarmu oddziału; ranny to przynęta dla obu stron |
| Mapa w rękach | plan tylko z kartką w dłoniach | jak inne czynności: odsłania gracza (broń schowana) |
| Brudna broń | kurz po rajdzie: zacięcia i cena | zestaw czyszczący ma sens także po krótkich rajdach |
| Niepewne meldunki | przekłamania wg reputacji u Wojska | daje reputacji Wojska wartość poza sklepem |

## Tempo i ciężar (v0.15.0)

| Mechanika | Opis | Styk z istniejącym |
| --- | --- | --- |
| Wolniejszy marsz | gracz i wrogowie wolniej, ciężkie rozpędzanie | mapy i okna czasowe bez zmian – rajd trwa dłużej, każde przejście korytarza kosztuje |
| Ciągnięcie zwłok | ukrywanie ciał przed alarmem | korzysta z oświetlenia (ciemny kąt) i drzwi (zasłaniają) |
| Opatrywanie kolegi | ranny jako przynęta | oddział i wołanie rannego z v0.14 |
| Impas posterunku | odpuszczenie gniazda | wojna frakcji nie zamraża się na posterunkach |
| Głośność zapięć | rzep vs zamek | wybór kamizelki = szybkość kontra cisza |
| Pewny meldunek | Pośrednik za bony | alternatywa dla reputacji u Wojska |
