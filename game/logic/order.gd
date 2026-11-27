## Заказ клиента («Давление» в мире Мастера).
##
## Уровень = вызов мастера. У заказа:
##  - client_id — номер клиента (тексты и имена — данные, T-16);
##  - hard — необязательное жёсткое условие, без него заказ не выполнен:
##      {"type": "no_leaks"}            — ни одной протечки («хозяйка придирчивая»);
##      {"type": "max_tees", "n": k}    — не больше k развилок (тройник/крест в мокрой сети);
##  - bonus — «уложись в N поворотов» ({"type": "max_moves", "n": N}): оплата ×1.5;
##  - pay — базовая оплата.
## Условие выбирается так, чтобы оно было выполнимо (проверено решателем) и
## ОТСЕКАЛО часть решений — иначе это просто текст, а не задача.
##
## Минимум поворотов считается точно: решатель перечисляет все побеждающие мокрые
## сети; для каждой — сумма минимальных поворотов мокрых клеток до нужной маски
## плюс поворот сухих соседей, которые иначе подключились бы к сети.
extends RefCounted

const Pieces = preload("res://game/logic/pieces.gd")
const Dir = preload("res://addons/master_core/grid/dir.gd")
const Grid = preload("res://addons/master_core/grid/grid.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")
const PressureSolver = preload("res://game/logic/pressure_solver.gd")

const MAX_WINNERS := 64
const BONUS_MULT := 1.5


## Все решения уровня с характеристиками: [{rots, wet, leaks, tees, moves}], отсортированы по moves.
static func analyze(lv) -> Array:
	var s = PressureSolver.new(lv)
	s.store_winners = MAX_WINNERS
	s.max_winners = MAX_WINNERS
	s.solve()
	var out := []
	for rots in s.winner_rots:
		var m: PackedByteArray = lv.masks_for(rots)
		var r := PressureEval.evaluate(lv, m)
		var tees := 0
		for i in lv.w * lv.h:
			if r["wet"][i] == 1 and (lv.kinds[i] == Pieces.TEE or lv.kinds[i] == Pieces.CROSS):
				tees += 1
		out.append({
			"rots": rots, "wet": r["wet"], "leaks": int(r["leaks"]), "tees": tees,
			"moves": min_moves(lv, lv.rots, m, r["wet"]),
		})
	out.sort_custom(func(a, b): return int(a["moves"]) < int(b["moves"]))
	return out


## Минимум касаний (по 90° по часовой) от поворотов start до сети с масками target на мокрых клетках.
## Сухая клетка не должна подключаться к мокрой сети или к выходу источника.
## (Конец сухой трубы в кран — можно: кран воду дальше не передаёт, труба остаётся сухой.)
static func min_moves(lv, start: PackedByteArray, target: PackedByteArray, wet: PackedByteArray) -> int:
	var total := 0
	for i in lv.w * lv.h:
		var k: int = lv.kinds[i]
		if not Pieces.is_pipe(k) or k == Pieces.CROSS:
			continue
		var best := 99
		for step in 4:
			var m := Pieces.mask(k, (start[i] + step) & 3)
			var ok: bool
			if wet[i] == 1:
				ok = m == target[i]
			else:
				ok = not _would_connect(lv, target, wet, i, m)
			if ok:
				best = step
				break
		if best == 99:
			return 1 << 30  # недостижимо (не должно случаться для решений решателя)
		total += best
	return total


static func _would_connect(lv, target: PackedByteArray, wet: PackedByteArray, i: int, m: int) -> bool:
	for d in 4:
		if not (m >> d & 1):
			continue
		var q := Grid.neighbor(lv.w, lv.h, i, d)
		if q < 0:
			continue
		var kq: int = lv.kinds[q]
		var back := Dir.opp(d)
		if kq == Pieces.SOURCE and (lv.outlets >> back & 1):
			return true
		if Pieces.is_pipe(kq) and wet[q] == 1 and (target[q] >> back & 1):
			return true
	return false


## Составить заказ для уровня. rng — SeededRng. Возвращает словарь заказа.
static func make(lv, rng) -> Dictionary:
	var sols := analyze(lv)
	var order := {"client_id": rng.rand_int(0, 9999)}
	if sols.is_empty():
		return order
	# жёсткое условие — только если оно отсекает часть решений
	var options := []
	var watertight := 0
	var min_tees := 1 << 30
	var max_tees := 0
	for s in sols:
		if int(s["leaks"]) == 0:
			watertight += 1
		min_tees = mini(min_tees, int(s["tees"]))
		max_tees = maxi(max_tees, int(s["tees"]))
	if watertight > 0 and watertight < sols.size():
		options.append({"type": "no_leaks"})
	if min_tees < max_tees:
		options.append({"type": "max_tees", "n": min_tees})
	if not options.is_empty():
		order["hard"] = rng.pick(options)
	# бонус: минимум поворотов среди решений, выполняющих жёсткое условие, + небольшой запас
	var best := 1 << 30
	for s in sols:
		if _hard_ok_solution(order, s):
			best = mini(best, int(s["moves"]))
	order["min_moves"] = best
	order["bonus"] = {"type": "max_moves", "n": best + rng.rand_int(0, 2)}
	var score := float(lv.meta.get("difficulty", {}).get("score", 10.0))
	order["pay"] = 10 * maxi(1, roundi(score / 2.0))
	return order


static func _hard_ok_solution(order: Dictionary, s: Dictionary) -> bool:
	if not order.has("hard"):
		return true
	var h: Dictionary = order["hard"]
	match String(h["type"]):
		"no_leaks":
			return int(s["leaks"]) == 0
		"max_tees":
			return int(s["tees"]) <= int(h["n"])
	return true


## Проверка в игре: r — PressureEval.evaluate текущих поворотов, moves — сделано поворотов.
## Возвращает {done, hard_ok, bonus_ok, pay}.
static func check(lv, order: Dictionary, r: Dictionary, moves: int) -> Dictionary:
	var hard_ok := true
	if order.has("hard"):
		var h: Dictionary = order["hard"]
		match String(h["type"]):
			"no_leaks":
				hard_ok = int(r["leaks"]) == 0
			"max_tees":
				var tees := 0
				for i in lv.w * lv.h:
					if r["wet"][i] == 1 and (lv.kinds[i] == Pieces.TEE or lv.kinds[i] == Pieces.CROSS):
						tees += 1
				hard_ok = tees <= int(h["n"])
	var done: bool = r["win"] and hard_ok
	var bonus_ok := done and order.has("bonus") and moves <= int(order["bonus"]["n"])
	var pay := 0
	if done:
		pay = int(order.get("pay", 0))
		if bonus_ok:
			pay = roundi(pay * BONUS_MULT)
	return {"done": done, "hard_ok": hard_ok, "bonus_ok": bonus_ok, "pay": pay}
