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
