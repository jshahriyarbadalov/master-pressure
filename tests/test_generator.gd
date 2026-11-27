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
