extends "res://tests/test_case.gd"

## Smoke-тест интерфейса headless: сцена создаётся, касание по клетке
## поворачивает участок, касание мимо/по неповорачиваемой ничего не делает.

const Pieces = preload("res://game/logic/pieces.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")


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


func test_pack_and_progress() -> bool:
	var m := _make()
	m.save_path = "user://test_progress.json"
	check_eq(m.levels.size(), 30, "загружен пак прототипа")
	var sizes := []
	for d in m.levels:
		sizes.append(int(d["w"]) * int(d["h"]))
	var sorted_sizes := sizes.duplicate()
	sorted_sizes.sort()
	check_eq(sizes, sorted_sizes, "размеры не убывают (5×5 → 7×9)")
	m.load_pack(m.levels, 0)
	var lv = m.level
	# решаем решением, которое выполняет заказ (задуманное генератором может нарушать условие клиента)
	var Order = load("res://game/logic/order.gd")
	var plan: PackedByteArray = PackedByteArray()
	for sl in Order.analyze(lv):
		var rr = PressureEval.evaluate(lv, sl["mask"])
		if Order.check(lv, lv.order, rr, 0)["done"]:
			plan = sl["plan"]
			break
	check(not plan.is_empty(), "у первого заказа есть решение под условием")
	for i in lv.w * lv.h:
		if lv.is_rotatable(i) and not plan.is_empty():
			var guard := 0
			while lv.rots[i] != plan[i] and guard < 4 and not m.won:
				m.tap_cell(i)
				guard += 1
	check(m.won, "первый уровень пака решается")
	m.next_level()
	check_eq(m.index, 1, "перешли на второй уровень")
	check_eq(m.load_progress(30), 1, "прогресс сохранён и читается")
	m.queue_free()
	return ok()


## Докрутить клетки касаниями до заданных поворотов.
func _tap_to(m, rots: PackedByteArray) -> void:
	var lv = m.level
	for i in lv.w * lv.h:
		if lv.is_rotatable(i):
			var guard := 0
			while lv.rots[i] != rots[i] and guard < 4 and not m.won:
				m.tap_cell(i)
				guard += 1


func test_order_screen_pay_and_bonus() -> bool:
	var Order = load("res://game/logic/order.gd")
	var m := _make()
	m.save_path = "user://test_progress_orders.json"
	m.money = 0
	m.load_pack(m.levels, 0)
	var lv = m.level
	check(not lv.order.is_empty(), "у уровня пака есть заказ")
	check(m.card.visible and m.card.said_l.text.contains("«"), "на карточке реплика клиента")
	var sols: Array = Order.analyze(lv)
	_tap_to(m, sols[0]["plan"])
	check(m.won, "заказ выполнен самым коротким решением")
	check(m.order_state["bonus_ok"], "бонус за минимум поворотов: %d ≤ %d" % [m.moves, int(lv.order["bonus"]["n"])])
	check_eq(m.money, roundi(int(lv.order["pay"]) * 1.5), "оплата с премией в кошельке")
	m.next_level()
	check_eq(m.money, roundi(int(lv.order["pay"]) * 1.5), "оплата не начислена повторно")
	# «Отменить» возвращает поворот
	var lv2 = m.level
	var cell := -1
	for i in lv2.w * lv2.h:
		if lv2.is_rotatable(i):
			cell = i
			break
	m.tap_cell(cell)
	m.tap_cell(cell)
	m.undo()
	check_eq(m.moves, 1, "отмена вернула поворот")
	m.queue_free()
	return ok()


func test_order_hard_condition_blocks_win() -> bool:
	var Order = load("res://game/logic/order.gd")
	var m := _make()
	m.save_path = "user://test_progress_orders.json"
	var idx := -1
	for k in m.levels.size():
		var o: Dictionary = m.levels[k].get("order", {})
		if o.has("hard") and o["hard"]["type"] == "no_leaks":
			idx = k
			break
	check(idx >= 0, "в паке есть заказ «без протечек»")
	if idx < 0:
		return ok()
	m.load_pack(m.levels, idx)
	var sols: Array = Order.analyze(m.level)
	var leaky := -1
	var clean := -1
	for k in sols.size():
		if int(sols[k]["leaks"]) > 0 and leaky < 0:
			leaky = k
		if int(sols[k]["leaks"]) == 0 and clean < 0:
			clean = k
	check(leaky >= 0 and clean >= 0, "есть решение с протечкой и без")
	_tap_to(m, sols[leaky]["plan"])
	check(m.result["win"], "напор в норме")
	check(not m.won, "но условие «без протечек» не выполнено — заказ не засчитан")
	check(m.card.said_l.text.contains("условие клиента"), "игроку сказано, что не так")
	m.reset()
	_tap_to(m, sols[clean]["plan"])
	check(m.won, "без протечек — заказ выполнен")
	m.queue_free()
	return ok()


func test_rooms_change_every_level() -> bool:
	var m := _make()
	var prev := ""
	var clients := {}
	for k in m.levels.size():
		m.load_pack(m.levels, k)
		check(m.board.room != prev, "уровень %d: помещение сменилось (%s)" % [k + 1, m.board.room])
		prev = m.board.room
		clients[int(m.level.order["client_id"]) % 30] = true
	check_eq(clients.size(), 30, "все 30 клиентов разные")
	m.queue_free()
	return ok()


func test_sounds_synthesized() -> bool:
	var Sfx = load("res://game/ui/sfx.gd")
	for n in ["rotate", "plink", "win", "coin", "undo", "fail"]:
		var st: AudioStreamWAV = Sfx.get_stream(n)
		check(st.data.size() > 1000, "звук %s не пустой" % n)
		check(st.get_length() < 1.0, "звук %s короткий: %.2f с" % [n, st.get_length()])
		var peak := 0
		for i in range(0, st.data.size(), 2):
			peak = maxi(peak, absi(st.data.decode_s16(i)))
		check(peak < 32767 and peak > 2000, "звук %s без перегруза и слышен (пик %d)" % [n, peak])
	return ok()


func test_rotation_animation_ends() -> bool:
	var m := _make()
	var lv = m.level
	var cell := -1
	for i in lv.w * lv.h:
		if lv.is_rotatable(i):
			cell = i
			break
	m.tap_cell(cell)
	check(m.board._rot_start.has(cell), "поворот анимируется")
	var BoardView = load("res://game/ui/board_view.gd")
	check(absf(BoardView.back_out(1.0) - 1.0) < 0.001, "пружинка заканчивается ровно в положении")
	var over := 0.0
	for k in 20:
		over = maxf(over, BoardView.back_out(k / 20.0))
	check(over > 1.0, "есть перелёт (пружинка)")
	m.queue_free()
	return ok()
