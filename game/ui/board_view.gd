## Отрисовка поля и касания. Логики игры здесь нет: только рисуем уровень и
## сообщаем, по какой клетке ткнули (сигнал cell_tapped).
extends Control

signal cell_tapped(index: int)

const Pieces = preload("res://game/logic/pieces.gd")
const Dir = preload("res://addons/master_core/grid/dir.gd")
const PixelArt = preload("res://game/ui/pixel_art.gd")
const Themes = preload("res://game/ui/themes.gd")

## Минимальный размер клетки в пикселях дизайна (ширина 720): ≈48 dp на телефоне 360 dp.
const MIN_CELL := 96.0
const COL_BG := Color("1d2330")
const COL_CELL := Color("2a3142")
const COL_PIPE := Color("8a93a6")
const COL_WALL := Color("12151c")
const COL_SOURCE := Color("3a86ff")
const COL_TAP := Color("e9c46a")
const COL_TAP_OK := Color("52b788")
const COL_TAP_LOW := Color("f4845f")
const COL_WATER_LO := Color("1b4b8a")
const COL_WATER_HI := Color("6fd3ff")
const COL_LEAK := Color("ff4d6d")
const UNREACHED := -1000000

var level = null
var target_tap := -1  ## кран из условия «сильный напор здесь» — золотое кольцо
var room := "kitchen"  ## помещение клиента: пол под трубами (не «theme» — так называется свойство Control)
var result := {}  ## результат PressureEval.evaluate для текущих поворотов
var cell := MIN_CELL
var origin := Vector2.ZERO

## Анимации (только отрисовка, на логику не влияют).
const ROT_TIME := 0.18      ## поворот с пружинкой, секунды
const WIN_TIME := 0.9       ## кольца от кранов при победе
var _rot_start := {}        ## клетка -> время начала поворота
var _win_start := -100.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # пиксели без сглаживания


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Клетка только что повернулась: показать докрутку из прежнего положения.
func animate_rotate(i: int) -> void:
	_rot_start[i] = now()


func animate_win() -> void:
	_win_start = now()


## «Перелёт» в конце: 0 → чуть больше 1 → 1 (пружинка).
static func back_out(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)


func _process(_delta: float) -> void:
	# вода течёт и капли летят всегда, когда есть мокрая сеть
	if level != null and (not result.is_empty() or not _rot_start.is_empty()):
		queue_redraw()


func set_level(lv) -> void:
	level = lv
	result = {}
	_fit()
	queue_redraw()


func set_result(r: Dictionary) -> void:
	result = r
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()
		queue_redraw()


func refit() -> void:
	_fit()
	queue_redraw()


func _fit() -> void:
	if level == null:
		return
	cell = floorf(minf(size.x / level.w, size.y / level.h))
	origin = ((size - Vector2(level.w, level.h) * cell) / 2.0).floor()


func cell_at(pos: Vector2) -> int:
	if level == null:
		return -1
	var p := (pos - origin) / cell
	if p.x < 0 or p.y < 0 or p.x >= level.w or p.y >= level.h:
		return -1
	return int(p.y) * level.w + int(p.x)


func cell_rect(i: int) -> Rect2:
	return Rect2(origin + Vector2(i % level.w, i / level.w) * cell, Vector2(cell, cell))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := cell_at(event.position)
		if i >= 0:
			cell_tapped.emit(i)
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Themes.BG.get(room, PixelArt.C["bg"]))
	if level == null or cell < 8.0:
		return
	for i in level.w * level.h:
		_draw_cell(i)
	_draw_leaks()
	_draw_win_rings()


## Победа: от каждого крана расходятся кольца воды.
func _draw_win_rings() -> void:
	var t := (now() - _win_start) / WIN_TIME
	if t < 0.0 or t > 1.0:
		return
	for tap in level.taps:
		var c := cell_rect(tap).get_center()
		for k in 2:
			var tk := clampf(t * 1.3 - k * 0.3, 0.0, 1.0)
			if tk <= 0.0 or tk >= 1.0:
				continue
			draw_arc(c, cell * (0.45 + 0.9 * tk), 0.0, TAU, 32, Color(PixelArt.C["water_hi"], 1.0 - tk), cell * 0.06)


func _draw_cell(i: int) -> void:
	var r := cell_rect(i)
	var k: int = level.kinds[i]
	if k == Pieces.WALL:
		draw_texture_rect(PixelArt.cell_tile("wall"), r, false)
		return
	if k == Pieces.EMPTY:
		draw_texture_rect(Themes.floor_tile(room, false), r, false, Color(0.78, 0.78, 0.78))
		return
	draw_texture_rect(Themes.floor_tile(room, true), r, false)
	if Pieces.is_pipe(k):
		var m := Pieces.mask(k, level.rots[i])
		var angle := 0.0
		if _rot_start.has(i):
			var t := (now() - float(_rot_start[i])) / ROT_TIME
			if t >= 1.0:
				_rot_start.erase(i)
			else:
				angle = -PI / 2.0 * (1.0 - back_out(clampf(t, 0.0, 1.0)))
		var c := r.get_center()
		draw_set_transform(c, angle)
		var local := Rect2(-r.size / 2.0, r.size)
		draw_texture_rect(PixelArt.pipe(m), local, false)
		if not result.is_empty() and result["wet"][i] == 1:
			draw_texture_rect(PixelArt.channel(m), local, false, flow_color(i))
		draw_set_transform(Vector2.ZERO, 0.0)
	elif k == Pieces.SOURCE:
		draw_texture_rect(PixelArt.pipe(level.outlets), r, false)
		draw_texture_rect(PixelArt.channel(level.outlets), r, false, PixelArt.water_color(1.0))
		draw_texture_rect(PixelArt.tank(), r, false)
	elif k == Pieces.TAP:
		var p = tap_pressure(i)
		var state := "dry"
		if p != null:
			state = "ok" if int(p) >= int(level.req[i]) else "low"
		if i == target_tap:
			draw_arc(r.get_center(), cell * 0.47, 0.0, TAU, 32, Color("f2c14e"), cell * 0.07)
			var star: Texture2D = Themes.small("star")
			draw_texture_rect(star, Rect2(r.position + Vector2(cell * 0.70, cell * 0.02), Vector2.ONE * cell * 0.28), false)
		draw_texture_rect(PixelArt.gauge(state), r, false)
		_draw_tap_label(i, r.get_center())


## Цвет трубы: сухая — серая; мокрая — синяя, тем ярче, чем выше напор.
func pipe_color(i: int) -> Color:
	if result.is_empty() or result["wet"][i] == 0:
		return COL_PIPE
	var p: int = result["cell_p"][i]
	if p == UNREACHED:
		return PixelArt.water_color(0.0)
	return PixelArt.water_color(float(p) / maxf(1.0, float(level.H)))


## Вода «бежит»: яркость пульсирует волнами от высокого напора к низкому
## (от источника к кранам); чем выше напор, тем быстрее волны.
func flow_color(i: int) -> Color:
	var base := pipe_color(i)
	var p := float(result["cell_p"][i])
	var speed := 3.0 + 5.0 * clampf(p / maxf(1.0, float(level.H)), 0.0, 1.0)
	var k := 0.82 + 0.18 * sin(now() * speed + p * 0.9)
	return Color(base.r * k, base.g * k, base.b * k, 1.0).lerp(Color.WHITE, 0.08 * (1.0 + sin(now() * speed + p * 0.9)))


func tap_pressure(i: int) -> Variant:
	if result.is_empty():
		return null
	var j: int = level.taps.find(i)
	return result["taps"][j] if j >= 0 else null


func _draw_leaks() -> void:
	if result.is_empty():
		return
	for code in result["leak_list"]:
		var i: int = code >> 2
		var d: int = code & 3
		var c := cell_rect(i).get_center()
		var px := cell / PixelArt.T
		var dir := Vector2(Dir.DX[d], Dir.DY[d])
		var tip := c + dir * cell * 0.5
		var sz := Vector2(4, 5) * px
		draw_texture_rect(PixelArt.drop(), Rect2(tip - sz / 2.0, sz), false)
		# брызги: две капли вылетают из конца и падают вниз
		for j in 2:
			var ph := fposmod(now() * 1.6 + float(code) * 0.37 + j * 0.5, 1.0)
			var pos := tip + dir * cell * 0.28 * ph + Vector2(0, cell * 0.35 * ph * ph)
			var dsz := sz * (0.7 - 0.4 * ph)
			draw_texture_rect(PixelArt.drop(), Rect2(pos - dsz / 2.0, dsz), false, Color(1, 1, 1, 1.0 - ph))


## Подпись крана: «есть/нужно» («–» — вода не дошла).
func _draw_tap_label(i: int, c: Vector2) -> void:
	var font := get_theme_default_font()
	var p = tap_pressure(i)
	var txt := "%s/%d" % ["–" if p == null else str(maxi(int(p), 0)), int(level.req[i])]
	var fs := int(cell * 0.21)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, c + Vector2(-w / 2.0, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("2a1f1d"))
