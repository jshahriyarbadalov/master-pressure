extends "res://tests/test_case.gd"

const SeededRng = preload("res://addons/master_core/rng/seeded_rng.gd")


func test_sequences_match_reference() -> bool:
	var g: Dictionary = load_json("res://tests/fixtures/rng_golden.json")
	for seed_value in [1, 20261125, 0x7FFFFFFFFFFF]:
		var r := SeededRng.new(seed_value)
		var want: Array = g[str(seed_value)]
		var bad := 0
		for k in 1000:
			if r.next_u32() != int(want[k]):
				bad += 1
		check_eq(bad, 0, "seed %d: расхождений" % seed_value)
	var rs = SeededRng.from_string("заказ 2026-11-25")
	var bad2 := 0
	for k in 1000:
		if rs.next_u32() != int(g["str"][k]):
			bad2 += 1
	check_eq(bad2, 0, "seed из строки")
	var r42 := SeededRng.new(42)
	var bad3 := 0
	for k in 1000:
		if r42.rand_int(0, 6) != int(g["range_0_6"][k]):
			bad3 += 1
	check_eq(bad3, 0, "randi_range(0,6)")
	for key in g["fnv"]:
		check_eq(SeededRng.fnv1a32(key), int(g["fnv"][key]), "fnv1a32('%s')" % key)
	return ok()


func test_range_and_uniformity() -> bool:
	var r := SeededRng.new(7)
	var counts := [0, 0, 0, 0, 0, 0]
	for k in 60000:
		var v := r.rand_int(0, 5)
		check(v >= 0 and v <= 5, "вне диапазона")
		counts[v] += 1
	for c in counts:
		check(absi(c - 10000) < 500, "неравномерно: %s" % str(counts))
	return ok()


## Ловит ошибку «вызов без self. уходит во встроенный ГСЧ»: pick/shuffle/chance
## должны давать одно и то же при одном seed.
func test_helpers_deterministic() -> bool:
	var outs := []
	for run in 2:
		var r := SeededRng.new(99)
		var arr := range(20)
		r.shuffle(arr)
		var picks := []
		var chances := []
		for k in 20:
			picks.append(r.pick([1, 2, 3, 4, 5, 6, 7]))
			chances.append(r.chance(0.5))
		outs.append(str(arr) + str(picks) + str(chances))
	check_eq(outs[0], outs[1], "shuffle/pick/chance при одном seed")
	return ok()
