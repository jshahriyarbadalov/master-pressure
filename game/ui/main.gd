## Экран игры (прототип). Раскладка под одну руку: сверху треть — только
## информация, поле — в нижних двух третях, кнопки — внизу.
extends Control

const PressureLevel = preload("res://game/logic/pressure_level.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")
const BoardView = preload("res://game/ui/board_view.gd")
const JsonIo = preload("res://addons/master_core/level/json_io.gd")
const Order = preload("res://game/logic/order.gd")
const OrderTexts = preload("res://game/logic/order_texts.gd")

const BAR_H := 140.0
const PACK_PATH := "res://levels/packs/proto.json"
const SAVE_PATH := "user://progress.json"
const PAD := 16.0

var save_path := SAVE_PATH  ## тесты подменяют, чтобы не трогать настоящий прогресс
var levels: Array = []      ## словари уровней (JSON)
var index := 0
var level = null
var start_rots := PackedByteArray()
var undo_stack := PackedInt32Array()
var result := {}
var won := false
var moves := 0        ## поворотов: касание +1, «Отменить» −1, «Заново» — 0
var money := 0        ## кошелёк мастера, сохраняется
var paid := false     ## оплата за текущий заказ уже начислена
var order_state := {} ## Order.check для текущего положения
var texts = null

var board: BoardView
var info: Label
var debug: Label
var btn_undo: Button
var btn_reset: Button
var btn_next: Button


func _ready() -> void:
	if board != null:
		return  # уже инициализирован (тесты вызывают _ready вручную)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texts = OrderTexts.new("ru")
	var bg := ColorRect.new()
	bg.color = Color("161a23")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 26)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.clip_text = true
	add_child(info)
	debug = Label.new()
	debug.add_theme_font_size_override("font_size", 18)
	debug.add_theme_color_override("font_color", Color("6b7385"))
	add_child(debug)
	board = BoardView.new()
	add_child(board)
	board.cell_tapped.connect(_on_cell_tapped)
	btn_undo = _button("Отменить", undo)
	btn_reset = _button("Заново", reset)
	btn_next = _button("Дальше", next_level)
	resized.connect(_layout)
	_layout()
	var pack := _load_pack_levels()
	load_pack(pack, _load_progress(pack.size()))


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 34)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	add_child(b)
	return b


## Пак прототипа (levels/packs/proto.json); если его нет — три примера из GAME_DESIGN.
func _load_pack_levels() -> Array:
	if FileAccess.file_exists(PACK_PATH):
		var p = JsonIo.read(PACK_PATH)
		if p is Dictionary and p.has("levels") and not p["levels"].is_empty():
			return p["levels"]
	var out := []
	for e in JsonIo.read("res://tests/fixtures/examples.json"):
		out.append(e["level"])
	return out


func load_progress(n: int) -> int:
	return _load_progress(n)


func _load_progress(n: int) -> int:
	if not FileAccess.file_exists(save_path):
		return 0
	var d = JsonIo.read(save_path)
	if d is Dictionary:
		money = int(d.get("money", 0))
		return clampi(int(d.get("index", 0)), 0, maxi(0, n - 1))
	return 0


func save_progress() -> void:
	JsonIo.write(save_path, {"index": index, "total": levels.size(), "money": money})


func _layout() -> void:
	var top := floorf(size.y / 3.0)
	info.position = Vector2(24, 20)
	info.size = Vector2(size.x - 48, top - 52)
	debug.position = Vector2(24, top - 30)
	debug.size = Vector2(size.x - 48, 24)
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
	paid = false
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
	moves -= 1  # отмена возвращает поворот
	_refresh()


func reset() -> void:
	level.rots = start_rots.duplicate()
	undo_stack.clear()
	moves = 0
	won = false
	_refresh()


func next_level() -> void:
	if not won:
		return
	index = (index + 1) % levels.size()
	save_progress()
	_load_current()


func _on_cell_tapped(i: int) -> void:
	tap_cell(i)


func _refresh() -> void:
	result = PressureEval.evaluate(level, level.masks())
	if level.order.is_empty():
		order_state = {}
		won = result["win"]
	else:
		order_state = Order.check(level, level.order, result, moves)
		won = order_state["done"]
		if won and not paid:
			paid = true
			money += int(order_state["pay"])
			save_progress()
	board.set_result(result)
	btn_next.disabled = not won
	btn_undo.disabled = won or undo_stack.is_empty()
	_update_info()


func _update_info() -> void:
	var lines := PackedStringArray()
	if not level.order.is_empty():
		var o: Dictionary = level.order
		var c: Dictionary = texts.client(o)
		lines.append("%s · %s" % [c["name"], c["place"]])
		lines.append("«%s»" % c["complaint"])
		var hard: String = texts.hard_text(o)
		if hard != "":
			lines.append("⚠ " + hard)
		lines.append("★ " + texts.bonus_text(o))
		lines.append("Поворотов %d из %d · %s · %s" % [moves, int(o["bonus"]["n"]), texts.ui("pay", {"pay": o.get("pay", 0)}), texts.ui("wallet", {"money": money})])
		if won:
			var key := "done_bonus" if order_state["bonus_ok"] else "done"
			lines.append("«%s» %s" % [c["thanks"], texts.ui(key, {"pay": order_state["pay"]})])
		elif result["win"]:
			lines.append(texts.ui("hard_failed"))
		else:
			lines.append(_taps_line())
	else:
		lines.append("Уровень %d/%d · поле %d×%d · ходов %d" % [index + 1, levels.size(), level.w, level.h, moves])
		lines.append("Напор источника %d − протечки %d×%d = %d" % [level.H, result["leaks"], level.L, result["heff"]])
		lines.append(_taps_line())
		lines.append("Решено! Жми «Дальше»." if won else "Участок −1, поворот −1, развилка −1 за лишний конец.")
	info.text = "\n".join(lines)
	debug.text = _debug_line()


func _taps_line() -> String:
	var ok := 0
	for j in level.taps.size():
		var p = result["taps"][j]
		if p != null and int(p) >= int(level.req[level.taps[j]]):
			ok += 1
	return "Напор %d − протечки %d×%d = %d · краны %d/%d" % [level.H, result["leaks"], level.L, result["heff"], ok, level.taps.size()]


## Отладочная строка для прототипа: по seed уровень можно воспроизвести.
func _debug_line() -> String:
	var m: Dictionary = level.meta
	var d: Dictionary = m.get("difficulty", {})
	if not m.has("seed"):
		return "пример из документа"
	return "%d/%d · seed %d · оценка %.1f · минимум %d" % [index + 1, levels.size(), int(m["seed"]), float(d.get("score", 0)), int(level.order.get("min_moves", -1))]
