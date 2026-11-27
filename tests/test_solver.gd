extends "res://tests/test_case.gd"

const Pieces = preload("res://game/logic/pieces.gd")
const PressureLevel = preload("res://game/logic/pressure_level.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")
const PressureSolver = preload("res://game/logic/pressure_solver.gd")
const SeededRng = preload("res://addons/master_core/rng/seeded_rng.gd")


func test_examples_counts() -> bool:
	var ex: Array = load_json("res://tests/fixtures/examples.json")
	for e in ex:
		var lv = PressureLevel.from_dict(e["level"])
		var all := PressureSolver.count_all(lv)
		check_eq(all["connecting"], int(e["connecting"]), e["name"] + " соединяющих")
		check_eq(all["winners"], int(e["winning"]), e["name"] + " побеждающих (без отсечения)")
		var w := PressureSolver.count_winners(lv)
		check_eq(w["winners"], int(e["winning"]), e["name"] + " побеждающих (с отсечением)")
		check(not w["aborted"], e["name"] + " не досчитан")
		for rots in w["winner_rots"]:
			var r := PressureEval.evaluate(lv, lv.masks_for(rots))
			check(r["win"], e["name"] + " сохранённое решение должно выигрывать")
	return ok()


## Полный перебор поворотов: число РАЗНЫХ мокрых сетей (соединяющих, побеждающих).
func _brute(lv) -> Array:
	var pipes: Array[int] = []
	var opts := []
	for i in lv.w * lv.h:
		if Pieces.is_pipe(lv.kinds[i]):
			pipes.append(i)
			opts.append(Pieces.distinct_rots(lv.kinds[i]))
	var conn := {}
	var wins := {}
	var idx := []
	idx.resize(pipes.size())
	idx.fill(0)
	var rots: PackedByteArray = lv.rots.duplicate()
	while true:
		for p in pipes.size():
			rots[pipes[p]] = opts[p][idx[p]]
		var m: PackedByteArray = lv.masks_for(rots)
		var r := PressureEval.evaluate(lv, m)
		if r["connected"]:
			var key := ""
			for i in pipes:
				if r["wet"][i]:
					key += "%d:%d," % [i, m[i]]
			conn[key] = true
			if r["win"]:
				wins[key] = true
		var p2 := 0
		while p2 < pipes.size():
			idx[p2] += 1
			if idx[p2] < opts[p2].size():
				break
			idx[p2] = 0
			p2 += 1
		if p2 == pipes.size():
			break
	return [conn.size(), wins.size()]


func test_matches_brute_force_100() -> bool:
	var rng := SeededRng.new(777)
	var done := 0
	var tries := 0
	while done < 100 and tries < 2000:
		tries += 1
		var w := rng.rand_int(3, 4)
		var h := rng.rand_int(2, 4)
		var rows := []
		for y in h:
			var s := ""
			for x in w:
				s += rng.pick(["I", "I", "L", "L", "L", "Y", "Y", "X", ".", "#"])
			rows.append(s)
		var cells := []
		for i in w * h:
			cells.append(i)
		rng.shuffle(cells)
		var srow: String = rows[cells[0] / w]
		rows[cells[0] / w] = srow.substr(0, cells[0] % w) + "S" + srow.substr(cells[0] % w + 1)
		var reqs := {}
		for k in rng.rand_int(1, 2):
			var c: int = cells[1 + k]
			var trow: String = rows[c / w]
			rows[c / w] = trow.substr(0, c % w) + "T" + trow.substr(c % w + 1)
			reqs[Vector2i(c % w, c / w)] = rng.rand_int(0, 6)
		var lv = PressureLevel.from_rows(rows, rng.rand_int(5, 14), [rng.rand_int(0, 3)], reqs, rng.rand_int(1, 3))
		var space := 1
		for i in w * h:
			if Pieces.is_pipe(lv.kinds[i]):
				space *= Pieces.distinct_rots(lv.kinds[i]).size()
		if space > 3000:
			continue
		var bf := _brute(lv)
		var all := PressureSolver.count_all(lv)
		var cw := PressureSolver.count_winners(lv)
		check_eq([all["connecting"], all["winners"]], bf, "уровень %s: [соединяющих, побеждающих] перебор=%s" % [str(rows), str(bf)])
		check_eq(cw["winners"], bf[1], "с отсечением, уровень %s" % str(rows))
		done += 1
	check_eq(done, 100, "сгенерировано уровней")
	return ok()
