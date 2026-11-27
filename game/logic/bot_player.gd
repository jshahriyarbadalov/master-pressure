## «Человекоподобный» бот: не знает решения, ищет его локально, как человек.
##
## Оценка положения (больше — лучше):
##   подключённый кран: min(напор − требование, 0)   (недостача напора)
##   неподключённый кран: −(H + 10) − расстояние от ближайшей мокрой клетки
## Шаг: «окинуть взглядом» клетки у воды (мокрые и соседние с ними), примерить
## каждый их поворот и сделать лучший. Чтобы не крутить одно и то же туда-обратно,
## последние tabu_size клеток трогать нельзя (табу-поиск). Если ничего не улучшает —
## всё равно делаем лучший из разрешённых ходов (так человек «пробует другое»).
## Касания: поворот на k·90° = k касаний (k = 1..3).
## Результат: решил ли за max_moves касаний и сколько касаний потратил.
extends RefCounted

const Grid = preload("res://addons/master_core/grid/grid.gd")
const SeededRng = preload("res://addons/master_core/rng/seeded_rng.gd")
const Pieces = preload("res://game/logic/pieces.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")

var max_moves := 600
var tabu_size := 5
var random_move_prob := 0.1  ## иногда — случайный поворот (человек ошибается)


func play(level, seed_value: int) -> Dictionary:
	var lv = level.clone()
	var rng := SeededRng.new(seed_value)
	var rot_cells := PackedInt32Array()
	for i in lv.w * lv.h:
		if lv.is_rotatable(i):
			rot_cells.append(i)
	if rot_cells.is_empty():
		return {"solved": false, "moves": 0, "steps": 0}
	var r := PressureEval.evaluate(lv, lv.masks())
	if r["win"]:
		return {"solved": true, "moves": 0, "steps": 0}
	var moves := 0
	var steps := 0
	var tabu: Array[int] = []
	while moves < max_moves:
		steps += 1
		var cand := _candidates(lv, r, rot_cells)
		var best_i := -1
		var best_k := 0
		var best_v := -1e18
		var best_r := {}
		if rng.chance(random_move_prob):
			best_i = cand[rng.rand_int(0, cand.size() - 1)]
			best_k = 1
		else:
			for i in cand:
				if tabu.has(i):
					continue
				var old: int = lv.rots[i]
				for k in range(1, 4):
					lv.rots[i] = (old + k) & 3
					if Pieces.mask(lv.kinds[i], lv.rots[i]) == Pieces.mask(lv.kinds[i], old):
						continue  # прямая: поворот на 180° ничего не меняет
					var r2 := PressureEval.evaluate(lv, lv.masks())
					var v: float = 1e9 if r2["win"] else _value(lv, r2) - 0.01 * k + rng.rand_float() * 0.001
					if v > best_v:
						best_v = v
						best_i = i
						best_k = k
						best_r = r2
				lv.rots[i] = old
		if best_i < 0:
			tabu.clear()
			continue
		lv.rots[best_i] = (lv.rots[best_i] + best_k) & 3
		moves += best_k
		r = best_r if not best_r.is_empty() else PressureEval.evaluate(lv, lv.masks())
		if r["win"]:
			return {"solved": true, "moves": moves, "steps": steps}
		tabu.append(best_i)
		if tabu.size() > tabu_size:
			tabu.pop_front()
	return {"solved": false, "moves": moves, "steps": steps}


## Клетки у воды: мокрые, соседние с мокрыми и с источником. Если таких нет — все.
func _candidates(lv, r: Dictionary, rot_cells: PackedInt32Array) -> PackedInt32Array:
	var near := PackedInt32Array()
	var wet: PackedByteArray = r["wet"]
	for i in rot_cells:
		if wet[i] == 1:
			near.append(i)
			continue
		for d in 4:
			var q := Grid.neighbor(lv.w, lv.h, i, d)
			if q >= 0 and (wet[q] == 1 or q == lv.src):
				near.append(i)
				break
	return near if not near.is_empty() else rot_cells


func _value(lv, r: Dictionary) -> float:
	var v := 0.0
	var wet: PackedByteArray = r["wet"]
	for j in lv.taps.size():
		var t: int = lv.taps[j]
		var p = r["taps"][j]
		if p != null:
			v += mini(int(p) - int(lv.req[t]), 0)
		else:
			var best := Grid.manhattan(lv.w, t, lv.src)
			for i in lv.w * lv.h:
				if wet[i] == 1:
					best = mini(best, Grid.manhattan(lv.w, t, i))
			v -= lv.H + 10 + best
	return v
