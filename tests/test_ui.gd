extends "res://tests/test_case.gd"

## Smoke-тест интерфейса headless: сцена создаётся, касание по клетке
## поворачивает участок, касание мимо/по неповорачиваемой ничего не делает.

const Pieces = preload("res://game/logic/pieces.gd")


func _make() -> Control:
	var scene: Control = load("res://game/ui/main.tscn").instantiate()
	tree.root.add_child(scene)
	if scene.board == null:
		scene._ready()
	scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scene.size = Vector2(720, 1280)
	scene._layout()
	return scene


func test_tap_rotates() -> bool:
	var m := _make()
	var lv = m.level
	check(lv != null, "уровень загружен")
	var rotatable := -1
	var fixed := -1
	for i in lv.w * lv.h:
		if lv.is_rotatable(i) and rotatable < 0:
			rotatable = i
		if not lv.is_rotatable(i) and fixed < 0:
			fixed = i
	var before: int = lv.rots[rotatable]
	check(m.tap_cell(rotatable), "поворачиваемая клетка повернулась")
	check_eq(lv.rots[rotatable], (before + 1) & 3, "поворот на 90°")
	check(not m.tap_cell(fixed), "неповорачиваемая клетка не крутится")
	# касание через доску: центр клетки -> индекс клетки
	var b = m.board
	var r: Rect2 = b.cell_rect(rotatable)
	check_eq(b.cell_at(r.get_center()), rotatable, "попадание касанием в клетку")
	check_eq(b.cell_at(Vector2(-5, -5)), -1, "касание мимо поля")
	check(b.cell >= b.MIN_CELL or lv.w * b.MIN_CELL > b.size.x, "клетка не меньше 48 dp, если влезает")
	m.queue_free()
	return ok()


func test_layout_one_hand() -> bool:
	var m := _make()
	check(m.board.position.y >= 1280 / 3.0 - 1, "поле не выше нижних двух третей")
	check(m.board.position.y + m.board.size.y <= 1280, "поле на экране")
	m.queue_free()
	return ok()


func test_play_example_to_win() -> bool:
	var m := _make()
	var ex: Array = load_json("res://tests/fixtures/examples.json")
	var want := [[3], [2, 2], [4, 2]]
	for k in 3:
		m.load_pack([ex[k]["level"]], 0)
		var lv = m.level
		check(not m.won, "пример %d: старт не решён" % (k + 1))
		check(m.btn_next.disabled, "пример %d: «Дальше» выключена до победы" % (k + 1))
		# докрутить каждую клетку касаниями до решения
		for i in lv.w * lv.h:
			if not lv.is_rotatable(i):
				continue
			var guard := 0
			while lv.rots[i] != lv.solution[i] and guard < 4 and not m.won:
				m.tap_cell(i)
				guard += 1
		check(m.won, "пример %d: решён касаниями" % (k + 1))
		check_eq(str(m.result["taps"]), str(want[k]), "пример %d: напор на кранах как в документе" % (k + 1))
		check(not m.btn_next.disabled, "пример %d: «Дальше» включилась" % (k + 1))
		check(not m.tap_cell(0) or not lv.is_rotatable(0), "после победы поле не крутится")
	m.queue_free()
	return ok()


func test_undo_and_reset() -> bool:
	var m := _make()
	var lv = m.level
	var start: PackedByteArray = lv.rots.duplicate()
	var cells := []
	for i in lv.w * lv.h:
		if lv.is_rotatable(i):
			cells.append(i)
	m.tap_cell(cells[0])
	m.tap_cell(cells[1])
	m.undo()
	m.undo()
	check_eq(lv.rots, start, "два «Отменить» вернули старт")
	m.tap_cell(cells[0])
	m.reset()
	check_eq(lv.rots, start, "«Заново» вернуло старт")
	m.queue_free()
	return ok()
