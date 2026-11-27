## Отрисовка поля и касания. Логики игры здесь нет: только рисуем уровень и
## сообщаем, по какой клетке ткнули (сигнал cell_tapped).
extends Control

signal cell_tapped(index: int)

const Pieces = preload("res://game/logic/pieces.gd")
const Dir = preload("res://addons/master_core/grid/dir.gd")

## Минимальный размер клетки в пикселях дизайна (ширина 720): ≈48 dp на телефоне 360 dp.
const MIN_CELL := 96.0
const COL_BG := Color("1d2330")
const COL_CELL := Color("2a3142")
const COL_PIPE := Color("8a93a6")
const COL_WALL := Color("12151c")
const COL_SOURCE := Color("3a86ff")
const COL_TAP := Color("e9c46a")

var level = null
var cell := MIN_CELL
var origin := Vector2.ZERO


func set_level(lv) -> void:
	level = lv
	_fit()
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
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	if level == null or cell < 8.0:
		return
	for i in level.w * level.h:
		_draw_cell(i)


func _draw_cell(i: int) -> void:
	var r := cell_rect(i)
	var k: int = level.kinds[i]
	var c := r.get_center()
	if k == Pieces.WALL:
		draw_rect(r.grow(-2), COL_WALL)
		return
	draw_rect(r.grow(-2), COL_CELL)
	if Pieces.is_pipe(k):
		_draw_arms(c, Pieces.mask(k, level.rots[i]), pipe_color(i), cell * 0.22)
	elif k == Pieces.SOURCE:
		_draw_arms(c, level.outlets, COL_SOURCE, cell * 0.22)
		draw_rect(Rect2(c - Vector2.ONE * cell * 0.28, Vector2.ONE * cell * 0.56), COL_SOURCE)
	elif k == Pieces.TAP:
		draw_circle(c, cell * 0.32, COL_TAP)
		_draw_tap_label(i, c)


func _draw_arms(c: Vector2, mask: int, col: Color, width: float) -> void:
	for d in 4:
		if mask >> d & 1:
			var tip := c + Vector2(Dir.DX[d], Dir.DY[d]) * cell * 0.5
			draw_line(c, tip, col, width)
	draw_circle(c, width * 0.5, col)


## Цвет трубы; в T-11 зависит от напора.
func pipe_color(_i: int) -> Color:
	return COL_PIPE


func _draw_tap_label(i: int, c: Vector2) -> void:
	var font := get_theme_default_font()
	var txt := str(level.req[i])
	var fs := int(cell * 0.3)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, c + Vector2(-w / 2.0, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
