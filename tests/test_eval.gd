extends "res://tests/test_case.gd"

const PressureLevel = preload("res://game/logic/pressure_level.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")


func _check_expect(lv, rots: PackedByteArray, exp: Dictionary, tag: String) -> void:
	var r := PressureEval.evaluate(lv, lv.masks_for(rots))
	check_eq(r["leaks"], int(exp["leaks"]), tag + " протечки")
	check_eq(r["heff"], int(exp["heff"]), tag + " H_эфф")
	check_eq(PressureEval.count_wet(r["wet"]), int(exp["wet"]), tag + " мокрых")
	check_eq(r["connected"], exp["connected"], tag + " подключено")
	check_eq(r["win"], exp["win"], tag + " победа")
	var got := []
	for p in r["taps"]:
		got.append(p)
	var want := []
	for p in exp["taps"]:
		want.append(null if p == null else int(p))
	check_eq(str(got), str(want), tag + " напор на кранах")


func test_examples() -> bool:
	var ex: Array = load_json("res://tests/fixtures/examples.json")
	for e in ex:
		var lv = PressureLevel.from_dict(e["level"])
		_check_expect(lv, lv.solution, e["solution_expect"], e["name"] + " решение:")
		var trap = PressureLevel.from_dict(e["level"])
		trap.set_rots_from_rows(e["trap"]["rots"])
		_check_expect(trap, trap.rots, e["trap"]["expect"], e["name"] + " ловушка:")
	return ok()


func test_examples_numbers_from_doc() -> bool:
	# Числа прямо из GAME_DESIGN.md, чтобы документ и код не разошлись.
	var ex: Array = load_json("res://tests/fixtures/examples.json")
	var want := {"ex1": [3], "ex2": [2, 2], "ex3": [4, 2]}
	for e in ex:
		var lv = PressureLevel.from_dict(e["level"])
		var r := PressureEval.evaluate(lv, lv.masks_for(lv.solution))
		check_eq(str(r["taps"]), str(want[e["name"]]), e["name"])
		check(r["win"], e["name"] + " решение должно выигрывать")
	return ok()


func test_golden_300() -> bool:
	var cases: Array = load_json("res://tests/fixtures/eval_golden.json")
	var before := failures.size()
	for idx in cases.size():
		var c: Dictionary = cases[idx]
		var lv = PressureLevel.from_dict(c["level"])
		_check_expect(lv, lv.rots, c["expect"], "случай %d:" % idx)
		if failures.size() - before > 10:
			failures.append("... слишком много расхождений, остановлено")
			break
	return ok()
