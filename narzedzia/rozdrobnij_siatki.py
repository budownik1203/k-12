"""JUŻ WYKONANA – nie uruchamiać ponownie (podwoiłaby siatki pojemników).
Jednorazowa migracja danych do drobniejszej siatki ekwipunku (każda stara kratka = 2x2 nowe).
Pojemniki: siatki, układy przegródek i kieszenie x2. Przedmioty: nowe, dokładniejsze rozmiary
(małe rzeczy zajmują mniej niż dawne 2x2, długie – proporcjonalnie)."""
import json, re
from pathlib import Path

P = Path(__file__).resolve().parent.parent / "assets" / "dane" / "przedmioty.json"
s = P.read_text(encoding="utf-8")

ROZ = {
    "pw9": (3, 2), "pm63": (5, 3), "kb47": (8, 3), "obrzyn": (6, 2),
    "tlumik_9": (3, 1), "tlumik_762": (4, 1), "hamulec": (2, 1), "kolimator": (2, 2), "luneta": (4, 2), "chwyt": (1, 2),
    "latarka_taktyczna": (2, 1),
    "mag_pw9": (1, 2), "mag_pm63": (1, 4), "mag_kb47": (2, 4),
    "a_9x18": (2, 3), "a_762": (2, 3), "a_762bp": (2, 3), "a_12": (2, 3),
    "bandaz": (1, 1), "opatrunek": (2, 1), "szyna": (1, 4), "bolostop": (1, 1), "apteczka": (2, 2),
    "kamizelka_kl2": (6, 6), "kamizelka_kl4": (6, 6), "helm_wz67": (4, 3),
    "zegarek": (1, 1), "wodka": (1, 3), "papierosy": (2, 1), "konserwa": (2, 2), "woda": (1, 3), "suchary": (2, 1),
    "lampa_elektronowa": (1, 2), "akumulator": (3, 3), "kaseta": (2, 1), "teczka_akt": (2, 4), "lancuszek": (1, 1),
    "radio": (3, 2), "klucz_nastawny": (3, 1), "przewody": (3, 2), "kartka_mieso": (1, 1), "spirytus": (1, 2),
    "klucz_piwnica": (1, 1), "mapa": (2, 1), "kompas": (1, 1), "maszyna_do_pisania": (5, 4), "kanister": (4, 5),
    "telefon": (3, 3), "gasnica": (2, 5), "lornetka": (3, 2), "maska_gazowa": (3, 3), "granat_f1": (1, 2),
    "wytrych": (1, 2), "kombinerki": (1, 3), "tasma": (2, 2), "zestaw_czyszczacy": (3, 1), "ikona": (3, 3),
    "latarka": (3, 1),
}
STOS = {  # garść / pełne pudełko
    "a_9x18": "[[12, 1, 1, \"_garsc\"], [50, 2, 3, \"\"]]",
    "a_762": "[[10, 1, 1, \"_garsc\"], [60, 2, 3, \"\"]]",
    "a_762bp": "[[10, 1, 1, \"_garsc\"], [60, 2, 3, \"\"]]",
    "a_12": "[[6, 1, 2, \"_garsc\"], [20, 2, 3, \"\"]]",
}

linie = s.split("\n")
biez = None
for i, l in enumerate(linie):
    m = re.search(r'\{"id": "([^"]+)"', l)
    if m:
        biez = m.group(1)
        m2 = re.search(r'"w": (\d+), "h": (\d+)', l)
        if m2:
            if biez in ROZ:
                w, h = ROZ[biez]
            else:  # pojemniki jako przedmioty: x2
                w, h = int(m2.group(1)) * 2, int(m2.group(2)) * 2
            l = l[:m2.start()] + '"w": %d, "h": %d' % (w, h) + l[m2.end():]
        if biez in STOS:
            l = re.sub(r'"rozmiary_stosu": \[\[.*?\]\]', '"rozmiary_stosu": ' + STOS[biez], l)
    # pojemnik: siatka, układ, kieszenie
    l = re.sub(r'"sw": (\d+), "sh": (\d+)', lambda m: '"sw": %d, "sh": %d' % (int(m.group(1)) * 2, int(m.group(2)) * 2), l)

    def uklad(m):
        wiersze = json.loads("[" + m.group(1) + "]")
        nowe = []
        for r in wiersze:
            r2 = "".join(c * 2 for c in r)
            nowe += [r2, r2]
        return '"uklad": ' + json.dumps(nowe, ensure_ascii=False)
    l = re.sub(r'"uklad": \[([^\]]*)\]', uklad, l)

    def kiesz(m):
        arr = json.loads(m.group(1))
        for k in arr:
            for j in range(4):
                k[j] = int(k[j]) * 2
        return '"kieszenie": ' + json.dumps(arr, ensure_ascii=False)
    l = re.sub(r'"kieszenie": (\[\[.*?\]\])', kiesz, l)
    linie[i] = l
s = "\n".join(linie)
s = s.replace("w/h = rozmiar w siatce", "w/h = rozmiar w siatce (drobnej: dawna kratka = 2x2)")
P.write_text(s, encoding="utf-8")
json.loads(s)
print("ok")
