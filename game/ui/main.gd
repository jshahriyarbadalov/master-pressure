## Экран игры (прототип). Раскладка под одну руку: сверху треть — только
## информация, поле — в нижних двух третях, кнопки — внизу.
extends Control

const PressureLevel = preload("res://game/logic/pressure_level.gd")
const BoardView = preload("res://game/ui/board_view.gd")
const JsonIo = preload("res://addons/master_core/level/json_io.gd")

const BAR_H := 120.0

var level = null
var board: BoardView
var info: Label


func _ready() -> void:
	if board != null:
		return  # уже инициализирован (тесты вызывают _ready вручную)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 36)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(info)
	board = BoardView.new()
	add_child(board)
	board.cell_tapped.connect(_on_cell_tapped)
	resized.connect(_layout)
	_layout()
	var ex: Array = JsonIo.read("res://tests/fixtures/examples.json")
	load_level(PressureLevel.from_dict(ex[0]["level"]))


func _layout() -> void:
	var top := floorf(size.y / 3.0)
	info.position = Vector2(24, 24)
	info.size = Vector2(size.x - 48, top - 48)
	board.position = Vector2(0, top)
	board.size = Vector2(size.x, size.y - top - BAR_H)
	board.refit()


func load_level(lv) -> void:
	level = lv
	board.set_level(lv)
	_update_info()


## Касание клетки: повернуть, если это поворачиваемый участок.
func tap_cell(i: int) -> bool:
	if level == null or not level.is_rotatable(i):
		return false
	level.rotate_cell(i)
	board.queue_redraw()
	_update_info()
	return true


func _on_cell_tapped(i: int) -> void:
	tap_cell(i)


func _update_info() -> void:
	info.text = "Давление — прототип\nПоле %d×%d" % [level.w, level.h]
