extends "res://tests/test_case.gd"

const PressureLevel = preload("res://game/logic/pressure_level.gd")
const Difficulty = preload("res://game/logic/difficulty.gd")


func test_examples_order() -> bool:
	var ex: Array = load_json("res://tests/fixtures/examples.json")
	var s := {}
	for e in ex:
		var lv = PressureLevel.from_dict(e["level"])
		var f := Difficulty.annotate(lv)
		s[e["name"]] = float(f["score"])
		check(lv.meta.has("difficulty"), e["name"] + ": оценка записана в meta")
		check_eq(int(f["winners"]), int(e["winning"]), e["name"] + ": решений")
	check(s["ex1"] < s["ex2"], "ex1 < ex2: %s" % str(s))
	check(s["ex2"] <= s["ex3"], "ex2 <= ex3: %s" % str(s))
	return ok()
