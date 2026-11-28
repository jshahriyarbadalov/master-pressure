extends "res://tests/test_case.gd"

const PressureLevel = preload("res://game/logic/pressure_level.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")
const PressureSolver = preload("res://game/logic/pressure_solver.gd")
const PressureGenerator = preload("res://game/logic/pressure_generator.gd")


func test_same_seed_same_level() -> bool:
	for s in [11, 12, 13]:
		var a = PressureGenerator.new({"w": 5, "h": 5, "taps": 2}).generate(s)
		var b = PressureGenerator.new({"w": 5, "h": 5, "taps": 2}).generate(s)
		check(a != null and b != null, "seed %d: уровень не сгенерирован" % s)
		if a != null and b != null:
			check_eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()), "seed %d: тот же уровень (побайтно)" % s)
	var c = PressureGenerator.new({"w": 5, "h": 5, "taps": 2}).generate(14)
	var d = PressureGenerator.new({"w": 5, "h": 5, "taps": 2}).generate(15)
	check(JSON.stringify(c.to_dict()["rows"]) != JSON.stringify(d.to_dict()["rows"]), "разные seed — разные уровни")
	return ok()


func test_levels_valid() -> bool:
	for s in range(20, 26):
		var lv = PressureGenerator.new({"w": 5, "h": 6, "taps": 2}).generate(s)
		check(lv != null, "seed %d: не сгенерирован" % s)
		if lv == null:
			continue
		var sol := PressureEval.evaluate(lv, lv.masks_for(lv.solution))
		check(sol["win"], "seed %d: задуманное решение выигрывает" % s)
		var start := PressureEval.evaluate(lv, lv.masks())
		check(not start["win"], "seed %d: старт не решён" % s)
		var cw := PressureSolver.count_winners(lv)
		check(int(cw["winners"]) >= 1 and not cw["aborted"], "seed %d: решатель подтверждает решаемость" % s)
		check(int(cw["winners"]) <= 4, "seed %d: решений не больше 4" % s)
		# JSON-цикл сохраняет уровень
		var back = PressureLevel.from_dict(JSON.parse_string(JSON.stringify(lv.to_dict())))
		check(PressureEval.evaluate(back, back.masks_for(back.solution))["win"], "seed %d: решение после JSON" % s)
	return ok()


func test_order_mode() -> bool:
	var Order = load("res://game/logic/order.gd")
	var with_hard := 0
	for s in range(200, 210):
		var g = PressureGenerator.new({"w": 5, "h": 5, "taps": 2, "order": true})
		var lv = g.generate(s)
		check(lv != null, "seed %d: уровень с заказом сгенерирован" % s)
		if lv == null:
			continue
		check(not lv.order.is_empty(), "seed %d: заказ есть" % s)
		var sols: Array = Order.analyze(lv)
		check(int(lv.order["min_moves"]) >= Order.moves_floor(lv, sols), "seed %d: не слишком легко (%d ≥ %d)" % [s, int(lv.order["min_moves"]), Order.moves_floor(lv, sols)])
		var ok := 0
		for sl in sols:
			if Order.check(lv, lv.order, PressureEval.evaluate(lv, sl["mask"]), int(sl["moves"]))["done"]:
				ok += 1
		check(ok >= 1 and ok <= 4, "seed %d: под заказом 1..4 решения (%d)" % [s, ok])
		if lv.order.has("hard"):
			with_hard += 1
			check(ok < sols.size(), "seed %d: условие отсекает решения" % s)
	check(with_hard >= 3, "условие клиента хотя бы у 3 из 10 (%d)" % with_hard)
	return ok()
