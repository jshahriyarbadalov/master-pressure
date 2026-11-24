extends "res://tests/test_case.gd"

const Pieces = preload("res://game/logic/pieces.gd")
const Dir = preload("res://addons/master_core/grid/dir.gd")
const PressureLevel = preload("res://game/logic/pressure_level.gd")


func test_rotation_cycles() -> bool:
	for k in [Pieces.STRAIGHT, Pieces.CORNER, Pieces.TEE, Pieces.CROSS]:
		var m := Pieces.mask(k, 0)
		check_eq(Dir.rot_mask(Dir.rot_mask(Dir.rot_mask(Dir.rot_mask(m, 1), 1), 1), 1), m, "4 поворота, тип %d" % k)
	check_eq(Pieces.distinct_rots(Pieces.STRAIGHT).size(), 2, "прямая")
	check_eq(Pieces.distinct_rots(Pieces.CORNER).size(), 4, "угол")
	check_eq(Pieces.distinct_rots(Pieces.TEE).size(), 4, "тройник")
	check_eq(Pieces.distinct_rots(Pieces.CROSS).size(), 1, "крест")
	check_eq(Pieces.mask(Pieces.CORNER, 1), 0b0110, "угол N-E -> E-S")
	return ok()


func test_examples_roundtrip() -> bool:
	var ex: Array = load_json("res://tests/fixtures/examples.json")
	check_eq(ex.size(), 3, "три примера")
	for e in ex:
		var d: Dictionary = e["level"]
		var lv = PressureLevel.from_dict(d)
		var d2: Dictionary = lv.to_dict()
		var lv2 = PressureLevel.from_dict(JSON.parse_string(JSON.stringify(d2)))
		check_eq(lv2.to_dict(), d2, "%s: загрузить -> сохранить -> загрузить" % e["name"])
		check_eq(d2["rows"], d["rows"], "%s: клетки" % e["name"])
		check_eq(d2["solution"], d["solution"], "%s: решение" % e["name"])
		check_eq(lv.taps.size(), d["taps"].size(), "%s: краны" % e["name"])
	return ok()


func test_golden_roundtrip() -> bool:
	var cases: Array = load_json("res://tests/fixtures/eval_golden.json")
	for c in cases:
		var lv = PressureLevel.from_dict(c["level"])
		var d2: Dictionary = lv.to_dict()
		check_eq(d2["rows"], c["level"]["rows"], "клетки")
		check_eq(d2["rots"], c["level"]["rots"], "повороты")
	return ok()
