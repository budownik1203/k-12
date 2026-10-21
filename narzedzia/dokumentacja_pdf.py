#!/usr/bin/env python3
"""Buduje PDF-y dokumentacji z plików docs/dokumentacja/*.md (Markdown -> HTML -> Chromium -> PDF).

Użycie: python3 narzedzia/dokumentacja_pdf.py [katalog_wyjściowy]
Każdy plik .md zaczyna się blokiem metadanych:
    tytul: ...
    podtytul: ...
    ---
"""
import glob
import os
import re
import sys

import markdown
from playwright.sync_api import sync_playwright

KORZEN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZRODLA = os.path.join(KORZEN, "docs", "dokumentacja")
WYJSCIE = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(KORZEN, "build", "dokumentacja")
WERSJA = "v0.16.6"
DATA = "październik 2026"

CSS = """
@page { size: A4; margin: 20mm 18mm 20mm 18mm; }
* { box-sizing: border-box; }
body { font-family: 'DejaVu Sans', sans-serif; font-size: 10pt; line-height: 1.5; color: #23251f; }
.okladka { height: 250mm; display: flex; flex-direction: column; justify-content: space-between;
  border: 2px solid #3d4232; padding: 18mm 16mm; page-break-after: always; background: #f3f1e8; }
.okladka .gora { font-family: 'DejaVu Sans Mono', monospace; font-size: 9pt; letter-spacing: 2px; color: #5d6150; }
.okladka h1 { font-size: 30pt; margin: 0 0 6mm 0; color: #2c3024; border: none; letter-spacing: 1px; }
.okladka .pod { font-size: 13pt; color: #4a4e3e; max-width: 140mm; }
.okladka .stempel { display: inline-block; border: 2.5px solid #9a2a1c; color: #9a2a1c; padding: 2mm 5mm;
  font-family: 'DejaVu Sans Mono', monospace; font-weight: bold; transform: rotate(-4deg); font-size: 11pt; }
.okladka .dol { font-family: 'DejaVu Sans Mono', monospace; font-size: 9pt; color: #5d6150; }
h1 { font-size: 17pt; color: #2c3024; border-bottom: 2px solid #3d4232; padding-bottom: 2mm; margin-top: 11mm; page-break-after: avoid; }
h2 { font-size: 13.5pt; color: #3d4232; margin-top: 7mm; border-bottom: 1px solid #c9c6b6; padding-bottom: 1mm; }
h3 { font-size: 11pt; color: #4f5440; margin-top: 5mm; }
h4 { font-size: 10pt; color: #4f5440; margin-top: 4mm; }
h2, h3, h4 { page-break-after: avoid; }
p { margin: 1.6mm 0; text-align: justify; }
ul, ol { margin: 1.5mm 0 1.5mm 5mm; padding-left: 4mm; }
li { margin: 0.6mm 0; }
code { font-family: 'DejaVu Sans Mono', monospace; font-size: 8.6pt; background: #ecebe2; padding: 0 1mm; border-radius: 1mm; }
pre { background: #ecebe2; padding: 3mm; border-left: 3px solid #7a7f68; font-size: 8.3pt; white-space: pre-wrap;
  page-break-inside: avoid; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 2.5mm 0; font-size: 8.6pt; page-break-inside: auto; }
tr { page-break-inside: avoid; }
th { background: #3d4232; color: #f1efe4; text-align: left; padding: 1.4mm 2mm; font-weight: bold; }
td { border-bottom: 1px solid #d6d3c4; padding: 1.2mm 2mm; vertical-align: top; }
tr:nth-child(even) td { background: #f6f5ee; }
blockquote { margin: 3mm 0; padding: 2.5mm 4mm; background: #f1eedf; border-left: 4px solid #9a2a1c; color: #3b3a30; }
blockquote p { margin: 0.8mm 0; }
.spis { page-break-after: always; }
.spis h2 { border: none; }
.spis ul { list-style: none; margin-left: 0; padding-left: 0; }
.spis li.l2 { margin-left: 6mm; font-size: 9pt; color: #4a4e3e; }
.spis a { color: #23251f; text-decoration: none; }
img { max-width: 100%; border: 1px solid #b9b6a6; margin: 2mm 0; }
figure { margin: 3mm 0; page-break-inside: avoid; }
figcaption { font-size: 8.5pt; color: #5d6150; font-style: italic; }
strong { color: #1f211b; }
hr { border: none; border-top: 1px solid #c9c6b6; margin: 5mm 0; }
"""


def wczytaj(sciezka):
    tekst = open(sciezka, encoding="utf-8").read()
    meta = {}
    if "\n---\n" in tekst:
        glowa, tekst = tekst.split("\n---\n", 1)
        for linia in glowa.splitlines():
            if ":" in linia:
                k, v = linia.split(":", 1)
                meta[k.strip()] = v.strip()
    return meta, tekst


def spis_tresci(html):
    pozycje = []
    def zamien(m):
        poziom, tresc = m.group(1), m.group(2)
        kotwica = "s%d" % len(pozycje)
        pozycje.append((poziom, re.sub(r"<[^>]+>", "", tresc), kotwica))
        return '<h%s id="%s">%s</h%s>' % (poziom, kotwica, tresc, poziom)
    html = re.sub(r"<h([12])>(.*?)</h\1>", zamien, html)
    lista = "".join('<li class="l%s"><a href="#%s">%s</a></li>' % (p, k, t) for p, t, k in pozycje)
    return html, '<div class="spis"><h2>Spis treści</h2><ul>%s</ul></div>' % lista


def zbuduj(md_sciezka, przegladarka):
    meta, tekst = wczytaj(md_sciezka)
    katalog = os.path.dirname(md_sciezka)
    # tabela tuż po akapicie (bez pustej linii) – Markdown by jej nie rozpoznał
    linie = tekst.split("\n")
    out = []
    for i, l in enumerate(linie):
        if l.startswith("|") and out and out[-1].strip() and not out[-1].startswith("|"):
            out.append("")
        out.append(l)
    tekst = "\n".join(out)
    html = markdown.markdown(tekst, extensions=["tables", "fenced_code", "sane_lists"])
    # obrazki z docs/zrzuty – ścieżki bezwzględne (file://)
    html = re.sub(r'src="([^":]+)"', lambda m: 'src="file://%s"' % os.path.abspath(os.path.join(katalog, m.group(1))), html)
    html, spis = spis_tresci(html)
    okladka = """<div class="okladka"><div><div class="gora">STREFA K-12 · DOKUMENTACJA PROJEKTOWA · %s</div></div>
<div><h1>%s</h1><div class="pod">%s</div></div>
<div><span class="stempel">%s</span></div>
<div class="dol">Stan gry: %s (%s)<br>Godot 4.6.1 · renderer Compatibility · GDScript<br>Repozytorium: github.com/budownik1203/k-12</div></div>""" % (
        meta.get("nr", ""), meta.get("tytul", ""), meta.get("podtytul", ""), meta.get("stempel", "DO UŻYTKU WEWNĘTRZNEGO"), WERSJA, DATA)
    strona = "<!doctype html><html lang='pl'><head><meta charset='utf-8'><style>%s</style></head><body>%s%s%s</body></html>" % (
        CSS, okladka, spis, html)
    nazwa = os.path.splitext(os.path.basename(md_sciezka))[0]
    html_plik = os.path.join(WYJSCIE, nazwa + ".html")
    open(html_plik, "w", encoding="utf-8").write(strona)
    pdf_plik = os.path.join(WYJSCIE, nazwa + ".pdf")
    s = przegladarka.new_page()
    s.goto("file://" + html_plik)
    s.wait_for_load_state("networkidle")
    stopka = ('<div style="font-size:7pt;font-family:DejaVu Sans Mono,monospace;color:#6b6f5c;width:100%%;'
              'padding:0 18mm;display:flex;justify-content:space-between;"><span>Strefa K-12 · %s</span>'
              '<span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>') % meta.get("tytul", "")
    s.pdf(path=pdf_plik, format="A4", print_background=True, display_header_footer=True,
          header_template="<div></div>", footer_template=stopka,
          margin={"top": "18mm", "bottom": "18mm", "left": "18mm", "right": "18mm"})
    s.close()
    os.remove(html_plik)
    return pdf_plik


def main():
    os.makedirs(WYJSCIE, exist_ok=True)
    pliki = sorted(glob.glob(os.path.join(ZRODLA, "*.md")))
    if len(sys.argv) > 2:
        pliki = [p for p in pliki if any(f in p for f in sys.argv[2:])]
    with sync_playwright() as pw:
        b = pw.chromium.launch(executable_path=os.environ.get("CHROMIUM", "/opt/pw-browsers/chromium") if os.path.exists("/opt/pw-browsers/chromium") else None)
        for p in pliki:
            print(zbuduj(p, b))
        b.close()


if __name__ == "__main__":
    main()
