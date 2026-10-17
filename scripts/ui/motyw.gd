class_name Motyw
extends RefCounted
## Wspólny wygląd interfejsu: urzędowe formularze, papier na ciemnym tle, czerwień pieczątek.

const TLO := Color(0.07, 0.072, 0.065, 0.96)
const TLO_JASNE := Color(0.12, 0.12, 0.105, 0.97)
const RAMKA := Color(0.42, 0.40, 0.31)
const TEKST := Color(0.82, 0.79, 0.69)
const TEKST_CIEMNY := Color(0.55, 0.53, 0.46)
const CZERWIEN := Color(0.70, 0.26, 0.18)
const ZIELEN := Color(0.42, 0.62, 0.38)
const ZOLC := Color(0.80, 0.66, 0.30)
const KOMORKA := Color(0.13, 0.135, 0.12, 0.92)
const KOMORKA_LINIA := Color(0.24, 0.24, 0.2)

static var _motyw: Theme
static var _mono: Font
static var _mono_b: Font
static var _cond: Font


static func mono() -> Font:
	if _mono == null:
		_mono = load("res://assets/fonty/DejaVuSansMono.ttf")
	return _mono


static func mono_b() -> Font:
	if _mono_b == null:
		_mono_b = load("res://assets/fonty/DejaVuSansMono-Bold.ttf")
	return _mono_b


static func cond() -> Font:
	if _cond == null:
		_cond = load("res://assets/fonty/DejaVuSansCondensed.ttf")
	return _cond


static func panel(kolor := TLO, ramka := RAMKA, grubosc := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = kolor
	s.border_color = ramka
	s.set_border_width_all(grubosc)
	s.set_content_margin_all(8)
	return s


static func motyw() -> Theme:
	if _motyw != null:
		return _motyw
	var t := Theme.new()
	t.default_font = cond()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEKST)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	var b := panel(Color(0.13, 0.13, 0.11), RAMKA)
	b.set_content_margin_all(6)
	b.content_margin_left = 14
	b.content_margin_right = 14
	var bh := panel(Color(0.22, 0.2, 0.15), ZOLC)
	bh.content_margin_left = 14
	bh.content_margin_right = 14
	var bp := panel(Color(0.3, 0.12, 0.08), CZERWIEN)
	bp.content_margin_left = 14
	bp.content_margin_right = 14
	var bd := panel(Color(0.09, 0.09, 0.08), Color(0.25, 0.24, 0.2))
	bd.content_margin_left = 14
	bd.content_margin_right = 14
	t.set_stylebox("normal", "Button", b)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEKST)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_disabled_color", "Button", TEKST_CIEMNY)
	t.set_font("font", "Button", mono_b())
	t.set_font_size("font_size", "Button", 15)
	t.set_stylebox("panel", "PopupMenu", panel(TLO_JASNE))
	t.set_color("font_color", "PopupMenu", TEKST)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 0.95, 0.8))
	var hov := panel(Color(0.3, 0.12, 0.08), CZERWIEN)
	t.set_stylebox("hover", "PopupMenu", hov)
	t.set_font("font", "PopupMenu", cond())
	t.set_font_size("font_size", "PopupMenu", 15)
	t.set_stylebox("panel", "TooltipPanel", panel(TLO_JASNE))
	t.set_color("font_color", "TooltipLabel", TEKST)
	t.set_stylebox("background", "ProgressBar", panel(Color(0.05, 0.05, 0.05), RAMKA))
	var fill := StyleBoxFlat.new()
	fill.bg_color = ZOLC
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("slider", "HSlider", panel(Color(0.05, 0.05, 0.05), RAMKA, 1))
	_motyw = t
	return t


static func etykieta(tekst: String, rozmiar := 15, kolor := TEKST, font: Font = null) -> Label:
	var l := Label.new()
	l.text = tekst
	l.add_theme_font_size_override("font_size", rozmiar)
	l.add_theme_color_override("font_color", kolor)
	if font:
		l.add_theme_font_override("font", font)
	return l


static func naglowek(tekst: String, rozmiar := 13) -> Label:
	var l := etykieta(tekst.to_upper(), rozmiar, TEKST_CIEMNY, mono_b())
	return l
