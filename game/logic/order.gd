## Заказ клиента («Давление» в мире Мастера).
##
## Уровень = вызов мастера. У заказа:
##  - client_id — номер клиента (тексты и имена — данные, T-16);
##  - hard — необязательное жёсткое условие, без него заказ не выполнен:
##      {"type": "no_leaks"}            — ни одной протечки («хозяйка придирчивая»);
##      {"type": "max_tees", "n": k}    — не больше k развилок (тройник/крест в мокрой сети);
##      {"type": "tap_min", "tap": i, "n": p} — на отмеченном кране напор ≥ p («на кухне сильный»);
##      {"type": "max_pipes", "n": k}   — не больше k участков в сети («материал дорогой»);
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
const MAX_OK := 4  ## под условием клиента должно остаться не больше стольких решений


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
		out.append({"rots": rots, "mask": m, "wet": r["wet"], "leaks": int(r["leaks"]), "tees": tees,
			"taps": r["taps"], "tap_list": Array(lv.taps), "pipes": PressureEval.count_wet(r["wet"])})
	recompute_moves(lv, out)
	return out


## Пересчитать касания от текущих поворотов lv.rots (сети от старта не зависят —
## решатель второй раз не нужен). Сортирует по числу касаний.
static func recompute_moves(lv, sols: Array) -> void:
	for s in sols:
		s["plan"] = min_plan(lv, lv.rots, s["mask"], s["wet"])
		s["moves"] = min_moves(lv, lv.rots, s["mask"], s["wet"])
	sols.sort_custom(func(a, b): return int(a["moves"]) < int(b["moves"]))


## Нижняя граница «не слишком легко»: минимум касаний ≥ max(4, половина
## поворачиваемых клеток в самой короткой сети-решении).
static func moves_floor(lv, sols: Array) -> int:
	if sols.is_empty():
		return 4
	var wet: PackedByteArray = sols[0]["wet"]
	var n := 0
	for i in lv.w * lv.h:
		if wet[i] == 1 and lv.is_rotatable(i):
			n += 1
	return maxi(4, ceili(n / 2.0))


static func pay_for(lv) -> int:
	var score := float(lv.meta.get("difficulty", {}).get("score", 10.0))
	return 10 * maxi(1, roundi(score / 2.0))


## Минимум касаний (по 90° по часовой) от поворотов start до сети с масками target на мокрых клетках.
static func min_moves(lv, start: PackedByteArray, target: PackedByteArray, wet: PackedByteArray) -> int:
	var plan := min_plan(lv, start, target, wet)
	if plan.is_empty():
		return 1 << 30  # недостижимо (не должно случаться для решений решателя)
	var total := 0
	for i in lv.w * lv.h:
		total += (plan[i] - start[i]) & 3
	return total


## Повороты, к которым ведёт минимум касаний (пусто, если недостижимо).
## Мокрая клетка — ближайший поворот с нужной маской (у прямой 0 и 2 одинаковы).
## Сухая — ближайший поворот, который не подключает её к мокрой сети или выходу
## источника. (Конец сухой трубы в кран — можно: кран воду дальше не передаёт.)
## Пригодится и для подсказки: «повернуть клетку к ближайшему решению».
static func min_plan(lv, start: PackedByteArray, target: PackedByteArray, wet: PackedByteArray) -> PackedByteArray:
	var plan := start.duplicate()
	for i in lv.w * lv.h:
		var k: int = lv.kinds[i]
		if not Pieces.is_pipe(k) or k == Pieces.CROSS:
			continue
		var found := false
		for step in 4:
			var r := (start[i] + step) & 3
			var m := Pieces.mask(k, r)
			var ok: bool
			if wet[i] == 1:
				ok = m == target[i]
			else:
				ok = not _would_connect(lv, target, wet, i, m)
			if ok:
				plan[i] = r
				found = true
				break
		if not found:
			return PackedByteArray()
	return plan


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
## sols — готовый Order.analyze (с касаниями от текущего старта), чтобы не гонять решатель снова.
static func make(lv, rng, sols: Array = []) -> Dictionary:
	if sols.is_empty():
		sols = analyze(lv)
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
	var min_pipes := 1 << 30
	var max_pipes := 0
	for s in sols:
		min_pipes = mini(min_pipes, int(s["pipes"]))
		max_pipes = maxi(max_pipes, int(s["pipes"]))
	if min_pipes < max_pipes:
		options.append({"type": "max_pipes", "n": min_pipes})
	# «сильный напор на отмеченном кране»: максимум по решениям, если не у всех он одинаков
	var tap_opts := []
	for j in lv.taps.size():
		var vmax := -1000000000
		var vmin := 1000000000
		for s in sols:
			vmax = maxi(vmax, int(s["taps"][j]))
			vmin = mini(vmin, int(s["taps"][j]))
		if vmin < vmax:
			tap_opts.append({"type": "tap_min", "tap": lv.taps[j], "n": vmax})
	if not tap_opts.is_empty():
		options.append(rng.pick(tap_opts))
	# условие должно оставлять головоломку точной: под ним ≤ MAX_OK решений
	options = options.filter(func(o): return _count_ok(o, sols) <= MAX_OK)
	if not options.is_empty():
		order["hard"] = rng.pick(options)
	# бонус: минимум поворотов среди решений, выполняющих жёсткое условие, + небольшой запас
	var best := 1 << 30
	for s in sols:
		if _hard_ok_solution(order, s):
			best = mini(best, int(s["moves"]))
	order["min_moves"] = best
	order["bonus"] = {"type": "max_moves", "n": best + rng.rand_int(0, 2)}
	order["pay"] = pay_for(lv)
	return order


static func _count_ok(hard: Dictionary, sols: Array) -> int:
	var c := 0
	for s in sols:
		if _hard_ok_solution({"hard": hard}, s):
			c += 1
	return c


static func _hard_ok_solution(order: Dictionary, s: Dictionary) -> bool:
	if not order.has("hard"):
		return true
	var h: Dictionary = order["hard"]
	match String(h["type"]):
		"no_leaks":
			return int(s["leaks"]) == 0
		"max_tees":
			return int(s["tees"]) <= int(h["n"])
		"max_pipes":
			return int(s["pipes"]) <= int(h["n"])
		"tap_min":
			var j: int = Array(s["tap_list"]).find(int(h["tap"]))
			return j >= 0 and s["taps"][j] != null and int(s["taps"][j]) >= int(h["n"])
	return true


## Проверка в игре: r — PressureEval.evaluate текущих поворотов, moves — сделано поворотов.
## Возвращает {done, hard_ok, bonus_ok, pay}.
## Текущее значение жёсткого условия для живого счётчика на карточке:
## {type, value, n, ok}. Пусто, если условия нет.
static func measure(lv, order: Dictionary, r: Dictionary) -> Dictionary:
	if not order.has("hard"):
		return {}
	var h: Dictionary = order["hard"]
	var t := String(h["type"])
	var n := int(h.get("n", 0))
	var v := 0
	var ok := true
	match t:
		"no_leaks":
			v = int(r["leaks"])
			ok = v == 0
		"max_tees":
			for i in lv.w * lv.h:
				if r["wet"][i] == 1 and (lv.kinds[i] == Pieces.TEE or lv.kinds[i] == Pieces.CROSS):
					v += 1
			ok = v <= n
		"max_pipes":
			v = PressureEval.count_wet(r["wet"])
			ok = v <= n
		"tap_min":
			var j: int = Array(lv.taps).find(int(h["tap"]))
			var p = r["taps"][j] if j >= 0 else null
			v = maxi(0, int(p)) if p != null else 0
			ok = p != null and int(p) >= n
	return {"type": t, "value": v, "n": n, "ok": ok}


static func check(lv, order: Dictionary, r: Dictionary, moves: int) -> Dictionary:
	var hard_ok: bool = measure(lv, order, r).get("ok", true)
	var done: bool = r["win"] and hard_ok
	var bonus_ok := done and order.has("bonus") and moves <= int(order["bonus"]["n"])
	var pay := 0
	if done:
		pay = int(order.get("pay", 0))
		if bonus_ok:
			pay = roundi(pay * BONUS_MULT)
	return {"done": done, "hard_ok": hard_ok, "bonus_ok": bonus_ok, "pay": pay}
