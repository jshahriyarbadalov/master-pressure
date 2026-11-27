## Карточка заказа — бумажный «наряд»: лист с зубчатым краем, штамп вызова,
## иконка места, имя, жалоба в облачке, плашки условия и бонуса, полоска
## поворотов, оплата и кошелёк. При выполнении — штамп «ВЫПОЛНЕНО».
## Фигуры рисуются кодом в _draw, текст — Label (перенос строк).
extends Control

const Themes = preload("res://game/ui/themes.gd")

const PAPER := Color("efe3c8")
const PAPER_EDGE := Color("cbb994")
const INK := Color("2a1f1d")
const INK_DIM := Color("7a6a55")
const BUBBLE := Color("fffaf0")
const RED := Color("e4573d")
const GOLD := Color("f2c14e")
const GREEN := Color("3f9a5a")

var data := {}  ## см. show_order
var name_l: Label
var place_l: Label
var said_l: Label
var hard_l: Label
var bonus_l: Label
var moves_l: Label
var pay_l: Label
var wallet_l: Label
var status_l: Label


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l = _label(30, INK)
	place_l = _label(20, INK_DIM)
	said_l = _label(23, INK, true)
	hard_l = _label(20, Color.WHITE, true)
	bonus_l = _label(20, INK, true)
	moves_l = _label(20, INK)
	pay_l = _label(26, INK)
	wallet_l = _label(18, INK_DIM)
	status_l = _label(18, INK_DIM)


func _label(fs: int, col: Color, wrap := false) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## d: {theme, name, place, said, said_is_error, hard, bonus_n, moves, pay, money,
##     call_no, done, bonus_ok, status}
func show_order(d: Dictionary) -> void:
	data = d
	name_l.text = d.get("name", "")
	place_l.text = d.get("place", "")
	said_l.text = "«%s»" % d.get("said", "")
	said_l.add_theme_color_override("font_color", RED if d.get("said_is_error", false) else INK)
	hard_l.text = d.get("hard", "")
	hard_l.visible = hard_l.text != ""
	bonus_l.text = "≤ %d поворотов ×1,5" % int(d.get("bonus_n", 0))
	moves_l.text = "поворотов %d/%d" % [int(d.get("moves", 0)), int(d.get("bonus_n", 0))]
	pay_l.text = "%d ₼" % int(d.get("pay", 0))
	wallet_l.text = "кошелёк %d ₼" % int(d.get("money", 0))
	status_l.text = d.get("status", "")
	_layout()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func relayout() -> void:
	_layout()
	queue_redraw()


## Ширину задаём через custom_minimum_size: Label с переносом при смене текста
## пересчитывает размер и иначе схлопывается до узкой колонки.
func _place(l: Label, pos: Vector2, w: float) -> void:
	l.position = pos
	l.custom_minimum_size = Vector2(maxf(w, 10.0), 0)
	l.size = Vector2(maxf(w, 10.0), 0)


func _layout() -> void:
	var w := size.x
	if w < 100:
		return
	var x0 := 92.0
	_place(name_l, Vector2(x0, 24), w - x0 - 190)
	_place(place_l, Vector2(x0, 60), w - x0 - 40)
	_place(said_l, Vector2(40, 106), w - 80)
	var y := 192.0
	_place(hard_l, Vector2(58, y), w - 100)
	if hard_l.visible:
		y += 44 + 26 * maxi(0, hard_l.get_line_count() - 1)
	_place(bonus_l, Vector2(58, y), 270)
	_place(moves_l, Vector2(w - 250, y), 220)
	y += 46
	_place(pay_l, Vector2(62, y - 4), 200)
	_place(wallet_l, Vector2(w - 250, y + 2), 220)
	_place(status_l, Vector2(28, size.y - 30), w - 56)


func _draw() -> void:
	if data.is_empty():
		return
	var w := size.x
	var h := size.y - 34
	# лист бумаги с зубчатым нижним краем
	draw_rect(Rect2(16, 10, w - 32, h - 10), PAPER_EDGE)
	draw_rect(Rect2(18, 12, w - 36, h - 16), PAPER)
	var zx := 18.0
	while zx < w - 18:
		draw_colored_polygon(PackedVector2Array([Vector2(zx, h - 4), Vector2(zx + 8, h + 4), Vector2(zx + 16, h - 4)]), PAPER)
		zx += 16
	# иконка места
	draw_rect(Rect2(30, 22, 52, 52), Color("e2d3b0"))
	draw_texture_rect(Themes.icon(data.get("theme", "")), Rect2(32, 24, 48, 48), false)
	# штамп вызова (наклонный)
	_stamp(Vector2(w - 92, 46), "ВЫЗОВ №%d" % int(data.get("call_no", 0)), RED, 18, -0.12)
	# облачко реплики с хвостиком к иконке
	var b := Rect2(30, 100, w - 60, 80)
	draw_rect(b.grow(2), PAPER_EDGE)
	draw_rect(b, BUBBLE)
	draw_colored_polygon(PackedVector2Array([Vector2(52, 101), Vector2(60, 86), Vector2(72, 101)]), BUBBLE)
	# плашки: условие (красная), бонус (золотая)
	if hard_l.visible:
		var hr := Rect2(30, hard_l.position.y - 4, w - 60, 34 + 26 * maxi(0, hard_l.get_line_count() - 1))
		draw_rect(hr, RED)
		draw_texture_rect(Themes.small("warn"), Rect2(36, hr.position.y + 8, 16, 16), false)
	var br := Rect2(30, bonus_l.position.y - 4, 300, 36)
	draw_rect(br, GOLD)
	draw_texture_rect(Themes.small("star"), Rect2(36, br.position.y + 10, 16, 16), false)
	# полоска поворотов: зелёная, краснеет при превышении лимита
	var lim := maxi(1, int(data.get("bonus_n", 1)))
	var mv := int(data.get("moves", 0))
	var bar := Rect2(w - 250, bonus_l.position.y + 30, 220, 8)
	draw_rect(bar, PAPER_EDGE)
	var frac := clampf(float(mv) / lim, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), RED if mv > lim else GREEN)
	# монеты
	draw_texture_rect(Themes.small("coin"), Rect2(30, pay_l.position.y + 6, 24, 24), false)
	draw_texture_rect(Themes.small("coin"), Rect2(w - 276, wallet_l.position.y + 4, 20, 20), false)
	# штамп «ВЫПОЛНЕНО»
	if data.get("done", false):
		_stamp(Vector2(w * 0.62, h * 0.62), "ВЫПОЛНЕНО" + ("  ★" if data.get("bonus_ok", false) else ""), Color(GREEN, 0.8), 34, -0.18)


func _stamp(center: Vector2, text: String, col: Color, fs: int, angle: float) -> void:
	var font := get_theme_default_font()
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_set_transform(center, angle)
	var r := Rect2(-sz.x / 2 - 10, -sz.y / 2 - 4, sz.x + 20, sz.y + 8)
	draw_rect(r, col, false, 3.0)
	draw_string(font, Vector2(-sz.x / 2, sz.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform(Vector2.ZERO, 0.0)
