extends "res://tests/test_case.gd"

const Pieces = preload("res://game/logic/pieces.gd")
const PressureLevel = preload("res://game/logic/pressure_level.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")
const PressureGenerator = preload("res://game/logic/pressure_generator.gd")
const SeededRng = preload("res://addons/master_core/rng/seeded_rng.gd")
const Order = preload("res://game/logic/order.gd")


## Полный перебор: минимум касаний от старта до любого побеждающего положения.
func _brute_min_moves(lv) -> int:
	var cells: Array[int] = []
	for i in lv.w * lv.h:
		if lv.is_rotatable(i):
			cells.append(i)
	var best := 1 << 30
	var n := cells.size()
	var total := 1 << (2 * n)
	var rots: PackedByteArray = lv.rots.duplicate()
	for code in total:
		var cost := 0
		for k in n:
			var step := (code >> (2 * k)) & 3
			rots[cells[k]] = (lv.rots[cells[k]] + step) & 3
			cost += step
		if cost >= best:
			continue
		if PressureEval.evaluate(lv, lv.masks_for(rots))["win"]:
			best = cost
	return best


func test_min_moves_matches_brute_force() -> bool:
	var rng := SeededRng.new(4242)
	var done := 0
	var tries := 0
	while done < 40 and tries < 3000:
		tries += 1
		var w := rng.rand_int(3, 4)
		var h := rng.rand_int(2, 3)
		var rows := []
		for y in h:
			var s := ""
			for x in w:
				s += rng.pick(["I", "L", "L", "Y", "Y", "X", "."])
			rows.append(s)
		var cells := range(w * h)
		rng.shuffle(cells)
		var put := func(c: int, ch: String):
			var row: String = rows[c / w]
			rows[c / w] = row.substr(0, c % w) + ch + row.substr(c % w + 1)
		put.call(cells[0], "S")
		var reqs := {}
		for k in rng.rand_int(1, 2):
			put.call(cells[1 + k], "T")
			reqs[Vector2i(cells[1 + k] % w, cells[1 + k] / w)] = rng.rand_int(0, 4)
		var lv = PressureLevel.from_rows(rows, rng.rand_int(6, 12), [rng.rand_int(0, 3)], reqs, 2)
		var rotatable := 0
		for i in w * h:
			if lv.is_rotatable(i):
				rotatable += 1
				lv.rots[i] = rng.rand_int(0, 3)
		if rotatable > 6 or PressureEval.evaluate(lv, lv.masks())["win"]:
			continue
		var sols := Order.analyze(lv)
		var bf := _brute_min_moves(lv)
		if sols.is_empty():
			check_eq(bf, 1 << 30, "нет решений у решателя — нет и у перебора: %s" % str(rows))
			continue
		check_eq(int(sols[0]["moves"]), bf, "минимум касаний, уровень %s" % str(rows))
		done += 1
	check(done >= 30, "проверено уровней с решением: %d" % done)
	return ok()


func test_orders_on_generated_levels() -> bool:
	var with_hard := 0
	for s in range(70, 80):
		var lv = PressureGenerator.new({"w": 5, "h": 6, "taps": 2}).generate(s)
		var order := Order.make(lv, SeededRng.new(s))
		lv.order = order
		check(order.has("bonus") and order.has("pay"), "seed %d: у заказа есть бонус и оплата" % s)
		var sols := Order.analyze(lv)
		var hard_ok_count := 0
		for sol in sols:
			var r := PressureEval.evaluate(lv, lv.masks_for(sol["rots"]))
			var c := Order.check(lv, order, r, int(sol["moves"]))
			if c["done"]:
				hard_ok_count += 1
				if int(sol["moves"]) == int(order["min_moves"]):
					check(c["bonus_ok"], "seed %d: самое короткое решение получает бонус" % s)
		check(hard_ok_count >= 1, "seed %d: заказ выполним" % s)
		if order.has("hard"):
			with_hard += 1
			check(hard_ok_count < sols.size(), "seed %d: жёсткое условие отсекает часть решений" % s)
		# формат уровня сохраняет заказ
		var back = PressureLevel.from_dict(JSON.parse_string(JSON.stringify(lv.to_dict())))
		check_eq(JSON.stringify(back.order), JSON.stringify(order), "seed %d: заказ в JSON" % s)
		# старт заказ не выполняет
		check(not Order.check(lv, order, PressureEval.evaluate(lv, lv.masks()), 0)["done"], "seed %d: старт не выполняет заказ" % s)
	print("    заказов с жёстким условием: %d из 10" % with_hard)
	return ok()
