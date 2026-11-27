## Экран игры (прототип). Раскладка под одну руку: сверху треть — только
## информация, поле — в нижних двух третях, кнопки — внизу.
extends Control

const PressureLevel = preload("res://game/logic/pressure_level.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")
const BoardView = preload("res://game/ui/board_view.gd")
const JsonIo = preload("res://addons/master_core/level/json_io.gd")

const BAR_H := 140.0
const PAD := 16.0

var levels: Array = []      ## словари уровней (JSON)
var index := 0
var level = null
var start_rots := PackedByteArray()
var undo_stack := PackedInt32Array()
var result := {}
var won := false
var moves := 0

var board: BoardView
var info: Label
var btn_undo: Button
var btn_reset: Button
var btn_next: Button


func _ready() -> void:
	if board != null:
		return  # уже инициализирован (тесты вызывают _ready вручную)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("161a23")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 32)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(info)
	board = BoardView.new()
	add_child(board)
	board.cell_tapped.connect(_on_cell_tapped)
	btn_undo = _button("Отменить", undo)
	btn_reset = _button("Заново", reset)
	btn_next = _button("Дальше", next_level)
	resized.connect(_layout)
	_layout()
	load_pack(_default_levels())


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 34)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	add_child(b)
	return b


## Уровни по умолчанию: три примера из GAME_DESIGN (T-12 заменит их паком).
func _default_levels() -> Array:
	var out := []
	for e in JsonIo.read("res://tests/fixtures/examples.json"):
		out.append(e["level"])
	return out


func _layout() -> void:
	var top := floorf(size.y / 3.0)
	info.position = Vector2(24, 24)
	info.size = Vector2(size.x - 48, top - 48)
	board.position = Vector2(0, top)
	board.size = Vector2(size.x, size.y - top - BAR_H)
	board.refit()
	var bw := (size.x - PAD * 4) / 3.0
	var y := size.y - BAR_H + PAD
	var bh := BAR_H - PAD * 2
	for k in 3:
		var b: Button = [btn_undo, btn_reset, btn_next][k]
		b.position = Vector2(PAD + k * (bw + PAD), y)
		b.size = Vector2(bw, bh)


func load_pack(dicts: Array, start_index: int = 0) -> void:
	levels = dicts
	index = clampi(start_index, 0, maxi(0, levels.size() - 1))
	_load_current()


func _load_current() -> void:
	level = PressureLevel.from_dict(levels[index])
	start_rots = level.rots.duplicate()
	undo_stack.clear()
	moves = 0
	won = false
	board.set_level(level)
	_refresh()


## Касание клетки: повернуть, если это поворачиваемый участок и уровень не решён.
func tap_cell(i: int) -> bool:
	if level == null or won or not level.is_rotatable(i):
		return false
	level.rotate_cell(i)
	undo_stack.append(i)
	moves += 1
	_refresh()
	return true


func undo() -> void:
	if won or undo_stack.is_empty():
		return
	var i: int = undo_stack[undo_stack.size() - 1]
	undo_stack.remove_at(undo_stack.size() - 1)
	level.rots[i] = (level.rots[i] + 3) & 3
	moves += 1
	_refresh()


func reset() -> void:
	level.rots = start_rots.duplicate()
	undo_stack.clear()
	won = false
	_refresh()


func next_level() -> void:
	if not won:
		return
	index = (index + 1) % levels.size()
	_load_current()


func _on_cell_tapped(i: int) -> void:
	tap_cell(i)


func _refresh() -> void:
	result = PressureEval.evaluate(level, level.masks())
	won = result["win"]
	board.set_result(result)
	btn_next.disabled = not won
	btn_undo.disabled = won or undo_stack.is_empty()
	_update_info()


func _update_info() -> void:
	var ok := 0
	for j in level.taps.size():
		var p = result["taps"][j]
		if p != null and int(p) >= int(level.req[level.taps[j]]):
			ok += 1
	var lines := PackedStringArray()
	lines.append("Уровень %d/%d · поле %d×%d · ходов %d" % [index + 1, levels.size(), level.w, level.h, moves])
	lines.append("Напор источника %d − протечки %d×%d = %d" % [level.H, result["leaks"], level.L, result["heff"]])
	lines.append("Краны с нужным напором: %d из %d" % [ok, level.taps.size()])
	if won:
		lines.append("Решено! Жми «Дальше».")
	else:
		lines.append("Участок −1, поворот −1, развилка −1 за лишний конец.")
	info.text = "\n".join(lines)
