#!/usr/bin/env python3
"""Generuje docs/dokumentacja/06_Przedmioty.md z danych gry (przedmioty.json, meble.json, oferty handlarzy).
Uruchamiać po każdej zmianie danych przedmiotów: python3 narzedzia/dokumentacja_przedmioty.py"""
import json
import os
import re

K = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = json.load(open(os.path.join(K, "assets/dane/przedmioty.json"), encoding="utf-8"))
M = json.load(open(os.path.join(K, "assets/dane/meble.json"), encoding="utf-8"))
P = {p["id"]: p for p in D["przedmioty"]}


def kod(sciezka):
    return open(os.path.join(K, sciezka), encoding="utf-8").read()


# oferty handlarzy i frakcji wyciągnięte z kodu (["id", ile(, próg)])
def oferty():
    out = {}
    h = kod("scripts/ui/handel_ui.gd")
    for nazwa in ["zbrojmistrz", "medyk", "posrednik"]:
        blok = h.split('"%s": {' % nazwa, 1)[1].split('"skupuje"', 1)[0]
        for pid in re.findall(r'\["([a-z0-9_]+)", \d+\]', blok):
            out.setdefault(pid, []).append(nazwa.capitalize())
    f = kod("scripts/core/frakcje_bazy.gd")
    for fr, nz in [("szabrownik", "Szabrownicy"), ("najemnik", "Najemnicy"), ("wojskowy", "Wojsko")]:
        blok = f.split('"%s": {' % fr, 1)[1].split('"zlecenia"', 1)[0]
        for pid, prog in re.findall(r'\["([a-z0-9_]+)", \d+, (\d+)\]', blok):
            out.setdefault(pid, []).append("%s%s" % (nz, " (rep. %s)" % prog if prog != "0" else ""))
    return out


def gdzie_lup():
    out = {}
    for tab, wpisy in D["tabele_lootu"].items():
        suma = sum(w for _, w in wpisy)
        for pid, w in wpisy:
            if pid != "nic":
                out.setdefault(pid, []).append("%s %d%%" % (tab.replace("_", " "), round(100 * w / suma)))
    for fr, dane in D["frakcje"].items():
        for pid, w in dane.get("lup", []):
            if pid != "nic":
                out.setdefault(pid, []).append("przy %s" % dane["nazwa"].lower())
        for z in dane.get("zestawy", []):
            for k in ["bron", "pancerz", "helm", "amunicja"]:
                if z.get(k):
                    out.setdefault(z[k], [])
                    t = "wyposażenie: %s" % dane["nazwa"].lower()
                    if t not in out[z[k]]:
                        out[z[k]].append(t)
    return out


OF = oferty()
LUP = gdzie_lup()

GRUPY = [
    ("Broń", ["bron"], "Cztery bronie palne. Statystyki strzeleckie – patrz Mechaniki (Broń i walka)."),
    ("Dodatki do broni", ["dodatek"], "Montaż polowy (w terenie, z animacją) albo warsztatowy (tylko na stole roboczym w kryjówce)."),
    ("Magazynki", ["magazynek"], "Osobne przedmioty; napełnia się je nabój po naboju, znalezione są nieprzeliczone."),
    ("Amunicja", ["amunicja"], "Luzem w stosach (garść albo paczka – rozmiar w siatce rośnie z ilością)."),
    ("Leki", ["med"], "Każdy lek działa z animacją i trwa; przeterminowane działają wolniej i czasem wcale."),
    ("Pancerze i hełmy", ["pancerz"], "Klasa ochrony, wytrzymałość i strefy ciała. Zużywają się; można je łatać na stole roboczym."),
    ("Oporządzenie: kamizelki i plecaki", ["pojemnik"], "Własne modele 3D i własne zapięcia (rzep, zamek, klapa, ściągacz, zatrzask, guzik)."),
    ("Granaty", ["granat"], ""),
    ("Narzędzia i wyposażenie", ["latarka", "mapa", "kompas", "klucz"], "Sloty wyposażenia: pas + 0–2 z kamizelki (latarka, mapa, kompas)."),
    ("Łup, jedzenie i narzędzia codzienne", ["lup"], "Wartość w bonach (skup 40–60%), część ma funkcję (jedzenie, narzędzia, pułapki, warsztat)."),
]


def szczegoly(p):
    t = []
    if "bron" in p:
        b = p["bron"]
        t.append("kaliber %s, %s, %d strz./min, rozrzut %.1f°/%.2f°, odrzut %.2f, przeładowanie %.1f s" % (
            b["kaliber"], "/".join(b["tryby"]), b["rpm"], b["rozrzut_biodro"], b["rozrzut_ads"], b["odrzut"], b["przeladowanie"]))
        if b.get("dodatki"):
            t.append("dodatki: " + "; ".join("%s: %s" % (k, ", ".join(P[x]["nazwa"] for x in v)) for k, v in b["dodatki"].items()))
    if "dodatek" in p:
        d = p["dodatek"]
        ef = []
        for k, n in [("halas", "hałas"), ("odrzut", "odrzut"), ("rozrzut_ads", "rozrzut ADS"), ("rozrzut_biodro", "rozrzut z biodra"), ("obrazenia", "obrażenia")]:
            if k in d:
                ef.append("%s ×%.2f" % (n, d[k]))
        if "zoom" in d:
            ef.append("powiększenie")
        if d.get("plomien") is False:
            ef.append("bez płomienia")
        t.append("slot %s, montaż %s%s; %s" % (d["slot"], d["montaz"], (" (%.0f s)" % d["czas"]) if d.get("czas") else "", ", ".join(ef) or "—"))
    if "magazynek" in p:
        t.append("kaliber %s, pojemność %d" % (p["magazynek"]["kaliber"], p["magazynek"]["pojemnosc"]))
    if "amunicja" in p:
        a = p["amunicja"]
        t.append("obrażenia %d, penetracja %d%s, stos %d" % (a["obrazenia"], a["penetracja"], (", %d śrucin" % a["srut"]) if a.get("srut") else "", p.get("stos", 1)))
    if "med" in p:
        m = p["med"]
        t.append("efekt: %s, czas %.1f s, użycia %d%s" % (m["efekt"].replace("_", " "), m["czas"], m["uzycia"], (", działa %d s" % m["trwanie"]) if m.get("trwanie") else ""))
    if "pancerz" in p:
        a = p["pancerz"]
        t.append("klasa %d, wytrzymałość %d, chroni: %s" % (a["klasa"], a["wytrzymalosc"], ", ".join(a["strefy"])))
    if "pojemnik" in p:
        c = p["pojemnik"]
        komorek = sum(r.count("#") for r in c["uklad"]) if c.get("uklad") else c["sw"] * c["sh"]
        kiesz = ", ".join("%s (%s)" % (k[4], k[5]) for k in c.get("kieszenie", []))
        t.append("slot %s, siatka %dx%d (%d pól), redukcja wagi %d%%%s%s" % (
            c["slot"], c["sw"], c["sh"], komorek, round(100 * c.get("redukcja", 0)), (", sloty wyposażenia +%d" % c["utility"]) if c.get("utility") else "",
            ("; kieszenie: " + kiesz) if kiesz else ""))
    if "granat" in p:
        g = p["granat"]
        t.append("obrażenia %d, promień %.1f m, zapalnik %.1f s" % (g["obrazenia"], g["promien"], g["zapalnik"]))
    if "jedzenie" in p:
        j = p["jedzenie"]
        t.append("głód %+d, pragnienie %+d, %.1f s%s" % (j["glod"], j["pragnienie"], j["czas"], ", alkohol" if j.get("alkohol") else ""))
    if "klucz" in p:
        t.append("otwiera: %s, użycia %d" % (p["klucz"]["otwiera"].replace("_", " "), p["klucz"]["uzycia"]))
    if "uzycia" in p:
        t.append("użycia %d" % p["uzycia"])
    return "; ".join(t)


FUNKCJE = {
    "wodka": "gasi ból, potem ręce drżą", "zegarek": "z zegarkiem w ekwipunku [H] pokazuje dokładny czas rajdu i okna wyjść",
    "wytrych": "otwiera drzwi i kłódki (zręcznościówka, 3 haczyki)", "kombinerki": "wyłamanie kłódki narzędziem", "klucz_nastawny": "wyłamanie kłódki narzędziem",
    "tasma": "owinięty metal nie brzęczy", "zestaw_czyszczacy": "czyszczenie broni (6 s), mniej zacięć", "proch": "elaboracja amunicji na stole roboczym",
    "prasa_elaboracyjna": "stół roboczy: 9x18 ×20 / 12/70 ×10 (1 proch), 7,62 ×15 (2 proch)", "tkanina_balistyczna": "łata pancerza na stole roboczym",
    "farba_spray": "własne strzałki i znaki na ścianach", "drut": "potykacz z granatem", "klin": "blokuje drzwi od swojej strony", "szklanka": "pułapka z granatem na klamce",
    "niesmiertelnik": "dowód zlecenia Najemników", "teczka_akt": "zlecenie Wojska (dostawa)", "radio": "zlecenie Wojska (dostawa)", "kanister": "zlecenie Najemników",
    "akumulator": "zlecenie Najemników", "lancuszek": "zlecenie Szabrowników", "mapa": "[O] mapa w rękach: plan, wyjścia, strzałki", "kompas": "pasek kierunków; z mapą – namiar na wyjścia",
    "latarka": "lewa ręka, sama albo pod pistoletem (chwyt Harriesa)", "granat_f1": "rzut [G], pułapki", "klucz_piwnica": "wyjście przez piwnicę nr 7",
}

L = []
L.append("""nr: 06
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
""")

for tytul, typy, opis in GRUPY:
    L.append("# %s\n" % tytul)
    if opis:
        L.append(opis + "\n")
    L.append("| Przedmiot | Rozmiar · waga · cena | Parametry | Opis (w grze) | Skąd |")
    L.append("| --- | --- | --- | --- | --- |")
    for p in D["przedmioty"]:
        if p["typ"] not in typy:
            continue
        par = szczegoly(p)
        if p["id"] in FUNKCJE:
            par = (par + "; " if par else "") + "**" + FUNKCJE[p["id"]] + "**"
        skad = "; ".join(OF.get(p["id"], []) + LUP.get(p["id"], [])) or "—"
        L.append("| **%s** `%s` | %dx%d · %.2f kg · %d | %s | %s | %s |" % (
            p["nazwa"], p["id"], p["w"], p["h"], p["waga"], p["cena"], par or "—", p.get("opis", ""), skad))
    L.append("")

L.append("# Tabele łupu w meblach\n")
L.append("Każdy mebel-pojemnik losuje zwykle 1 raz (czasem 2–3, bywa pusto: rozkład 0,1,1,1,2,2,3 → średnio ok. 1,4). Wpis „nic” to pusty los.\n")
for tab, wpisy in D["tabele_lootu"].items():
    suma = sum(w for _, w in wpisy)
    L.append("**%s:** %s\n" % (tab.replace("_", " ").capitalize(), ", ".join("%s %d%%" % ((P[i]["nazwa"] if i in P else "nic"), round(100 * w / suma)) for i, w in wpisy)))

L.append("# Meble w strefie\n")
L.append("Meble stawiane przez generator w zestawach wg typu pomieszczenia. Pojemnik = tabela łupu; osłona = punkt osłony dla AI (niska/wysoka).\n")
L.append("| Mebel | Wymiary (m) | Pojemnik (tabela) | Osłona |")
L.append("| --- | --- | --- | --- |")
for k, v in M.items():
    r = v.get("rozmiar", [0, 0, 0])
    L.append("| %s `%s` | %.2f × %.2f × %.2f | %s | %s |" % (v.get("nazwa", k), k, r[0], r[1], r[2], v.get("pojemnik") or "—", v.get("oslona") or "—"))
L.append("")

mk = kod("scripts/core/meble_kryjowki.gd")
L.append("# Meble kryjówki (Kwatermistrz)\n")
L.append("Skrytka: 20 kolumn, 10 rzędów bazowo, maksymalnie 64. Nowa gra: prycza, szafka metalowa, żarówka (16 rzędów). Druga izba 5 × 7 m: 25 000 bonów.\n")
L.append("| Mebel | Cena | Funkcja | Opis |")
L.append("| --- | --- | --- | --- |")
for mid, cena, fun, opis in re.findall(r'"([a-z_]+)": \{"cena": (\d+), "funkcja": "([a-z]*)"[^}]*"opis": "([^"]+)"\}', mk):
    L.append("| %s | %s | %s | %s |" % (M.get(mid, {}).get("nazwa", mid), cena, fun or "wystrój", opis))
L.append("")

L.append("""# Możliwości rozwoju

- Druga broń długa (strzelba pompowa lub karabin wyborowy), magazynki bębnowe, kolby (nowy slot), amunicja smugowa i śrut breneka.
- Archiwum dokumentów: teczki akt i kasety jako zbieralne fragmenty lore (odsłuch/odczyt w kryjówce).
- Naprawa broni (stan) u Zbrojmistrza lub na stole roboczym.
- Przedmioty biomowe (klucze do konkretnych pomieszczeń, karty dostępu w kompleksie).
- Plecaki z ramą (lepsza redukcja wagi, głośniejsze), torby na udo (szybki dostęp, mała pojemność).

""")

open(os.path.join(K, "docs/dokumentacja/06_Przedmioty.md"), "w", encoding="utf-8").write("\n".join(L))
print("ok", len(L))
