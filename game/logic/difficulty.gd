## Оценка сложности уровня v0 (docs/GAME_DESIGN.md, раздел 5).
##
## Признаки считаются по уровню и решателю. Итог — взвешенная сумма (raw);
## по набору уровней raw переводится в 1..10 по перцентилям (tools/report.gd).
## Веса — стартовые; калибруются ботом-игроком (T-09): см. docs/reports/.
extends RefCounted

const Pieces = preload("res://game/logic/pieces.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")
const PressureSolver = preload("res://game/logic/pressure_solver.gd")

## Стартовые веса. Ключ — признак, значение — вклад на единицу признака.
const WEIGHTS := {
	"wet_bits": 0.35,        ## log2 вариантов поворота клеток решения
	"all_bits": 0.08,        ## log2 вариантов поворота всего поля
	"taps": 0.8,
	"tight_taps": 0.6,       ## краны, где решение даёт ровно требование (запас 0)
	"solver_log": 1.2,       ## log10 узлов решателя с отсечением
	"solution_leaks": 1.0,   ## протечка в решении — контринтуитивно
	"loop": 0.7,
	"pass_ratio": -4.0,      ## чем больше доля проходящих сетей, тем проще
}


static func features(lv) -> Dictionary:
	var meta: Dictionary = lv.meta
	var sol_rots: PackedByteArray = lv.solution
	var r := PressureEval.evaluate(lv, lv.masks_for(sol_rots))
	var wet_bits := 0.0
	var all_bits := 0.0
	var rotatable := 0
	for i in lv.w * lv.h:
		if lv.is_rotatable(i):
			rotatable += 1
			var b := log(float(Pieces.distinct_rots(lv.kinds[i]).size())) / log(2.0)
			all_bits += b
			if r["wet"][i] == 1:
				wet_bits += b
	var tight := 0
	for j in lv.taps.size():
		if r["taps"][j] != null and int(r["taps"][j]) == int(lv.req[lv.taps[j]]):
			tight += 1
	var nodes: int = meta.get("solver_nodes", -1)
	var winners: int = meta.get("winners", -1)
	var connecting: int = meta.get("connecting", -1)
	if nodes < 0 or winners < 0 or connecting < 0:
		var cw := PressureSolver.count_winners(lv)
		nodes = cw["nodes"]
		winners = cw["winners"]
		var ca := PressureSolver.count_all(lv, 20000, 2000)
		connecting = ca["connecting"]
	return {
		"rotatable": rotatable,
		"wet_cells": PressureEval.count_wet(r["wet"]),
		"wet_bits": wet_bits,
		"all_bits": all_bits,
		"taps": lv.taps.size(),
		"tight_taps": tight,
		"solver_log": log(float(nodes) + 1.0) / log(10.0),
		"solution_leaks": r["leaks"],
		"loop": 1 if meta.get("loop", false) else 0,
		"winners": winners,
		"connecting": connecting,
		"pass_ratio": float(winners) / maxf(1.0, float(connecting)),
	}


static func score(f: Dictionary, weights: Dictionary = WEIGHTS) -> float:
	var s := 0.0
	for k in weights:
		s += float(weights[k]) * float(f.get(k, 0.0))
	return s


## Посчитать признаки и оценку и записать в lv.meta["difficulty"].
static func annotate(lv) -> Dictionary:
	var f := features(lv)
	f["score"] = snappedf(score(f), 0.01)
	for k in ["wet_bits", "all_bits", "solver_log", "pass_ratio"]:
		f[k] = snappedf(float(f[k]), 0.001)
	lv.meta["difficulty"] = f
	return f
