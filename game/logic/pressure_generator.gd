## Генератор уровней «Давления»: построить → проверить → оценить → перемешать.
##
## 1. Источник с одним выходом и краны на расстоянии друг от друга.
## 2. Задуманная сеть: к каждому крану прокладывается путь от уже построенной
##    части (Дейкстра со случайными весами клеток — пути получаются извилистыми,
##    а не по линейке). Иногда добавляется кольцо и «тройник-приманка» с протечкой.
## 3. Остальные клетки — отвлекающие участки и пустоты.
## 4. Требования кранов = напор задуманной сети − запас. Значит, решение
##    существует по построению; решатель это перепроверяет и считает, сколько
##    всего решений (их может быть больше задуманного).
## 5. Фильтры: решатель уложился в лимит, решений не больше max_winners,
##    доля проходящих сетей среди соединяющих не больше max_pass_ratio.
## 6. Повороты перемешиваются так, чтобы старт не был решён и не решался одним касанием.
## Всё детерминировано от seed.
extends RefCounted

const Pieces = preload("res://game/logic/pieces.gd")
const Dir = preload("res://addons/master_core/grid/dir.gd")
const Grid = preload("res://addons/master_core/grid/grid.gd")
const SeededRng = preload("res://addons/master_core/rng/seeded_rng.gd")
const PressureLevel = preload("res://game/logic/pressure_level.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")
const PressureSolver = preload("res://game/logic/pressure_solver.gd")

## Параметры по умолчанию; перекрываются словарём params.
const DEFAULTS := {
	"w": 5, "h": 5, "taps": 2,
	"slack": 0,              ## запас: требование = напор задуманной сети − slack (0..slack)
	"L": 2,
	"loop_prob": 0.35,       ## шанс добавить кольцо
	"decoy_prob": 0.5,       ## шанс тройника-приманки (в задуманной сети это протечка)
	"empty_ratio": 0.12,     ## доля пустых клеток среди заполнения
	"fill_weights": [3, 4, 2, 1],  ## прямая, угол, тройник, крест
	"head": [1, 3],          ## минимальный напор на кране в задуманной сети: от..до
	"max_winners": 4,
	"max_pass_ratio": 0.25,
	"solver_nodes": 300000,
	"all_nodes": 20000,      ## лимит узлов для подсчёта соединяющих сетей
	"all_stop": 2000,        ## хватит стольких соединяющих сетей
	"min_cut": 2,            ## напор должен отсечь хотя бы столько соединяющих сетей
	"attempts": 60,
}

var params := {}
var stats := {"attempts": 0, "rejected": {}}


func _init(p: Dictionary = {}) -> void:
	params = DEFAULTS.duplicate(true)
	for k in p:
		params[k] = p[k]


## Сгенерировать уровень по seed. Возвращает PressureLevel или null.
func generate(seed_value: int):
	var rng := SeededRng.new(seed_value)
	stats = {"attempts": 0, "rejected": {}}
	for attempt in int(params["attempts"]):
		stats["attempts"] = attempt + 1
		var lv = _try(rng.fork("attempt"))
		if lv != null:
			lv.meta["seed"] = seed_value
			lv.meta["attempts"] = attempt + 1
			return lv
	return null


func _reject(reason: String) -> void:
	stats["rejected"][reason] = int(stats["rejected"].get(reason, 0)) + 1


func _try(rng):
	var w: int = params["w"]
	var h: int = params["h"]
	var n := w * h
	var kinds := PackedByteArray()
	kinds.resize(n)
	kinds.fill(Pieces.EMPTY)

	# --- 1. источник и краны ---
	var src: int = rng.rand_int(0, n - 1)
	var outs: Array[int] = []
	for d in 4:
		if Grid.neighbor(w, h, src, d) >= 0:
			outs.append(d)
	var out_dir: int = rng.pick(outs)
	var q0 := Grid.neighbor(w, h, src, out_dir)
	kinds[src] = Pieces.SOURCE
	var min_dist := maxi(3, (w + h) / 3)
	var cells := []
	for i in n:
		cells.append(i)
	rng.shuffle(cells)
	var taps: Array[int] = []
	for c in cells:
		if taps.size() >= int(params["taps"]):
			break
		if c == src or c == q0 or Grid.manhattan(w, c, src) < min_dist:
			continue
		var far := true
		for t in taps:
			if Grid.manhattan(w, c, t) < 2:
				far = false
		if far:
			taps.append(c)
	if taps.size() < int(params["taps"]):
		_reject("нет места для кранов")
		return null
	for t in taps:
		kinds[t] = Pieces.TAP

	# --- 2. задуманная сеть: arms[i] — маска концов клетки ---
	var arms := PackedInt32Array()
	arms.resize(n)
	var net := PackedByteArray()
	net.resize(n)
	net[q0] = 1
	arms[q0] |= 1 << Dir.opp(out_dir)
	var weight := PackedFloat32Array()
	weight.resize(n)
	for i in n:
		weight[i] = 1.0 + rng.rand_float() * 3.0
	for t in taps:
		var path := _route(w, h, kinds, net, t, weight)
		if path.is_empty():
			_reject("нет пути к крану")
			return null
		_lay(w, h, path, net, arms)
		# последний участок пути подключаем к крану
		var last: int = path[path.size() - 1]
		var dt := _dir_between(w, last, t)
		arms[last] |= 1 << dt
	if rng.chance(float(params["loop_prob"])):
		_add_loop(rng, w, h, kinds, net, arms, weight)
	if rng.chance(float(params["decoy_prob"])):
		_add_decoy(rng, w, h, kinds, net, arms)

	# клетки сети -> типы и повороты
	var lv = PressureLevel.new()
	lv.w = w
	lv.h = h
	lv.src = src
	lv.outlets = 1 << out_dir
	lv.L = int(params["L"])
	lv.rots.resize(n)
	lv.solution.resize(n)
	for i in n:
		if net[i] == 1:
			var m := arms[i]
			var c := Dir.popcount4(m)
			var k := Pieces.CROSS
			if c == 2:
				k = Pieces.STRAIGHT if (m == 0b0101 or m == 0b1010) else Pieces.CORNER
			elif c == 3:
				k = Pieces.TEE
			elif c < 2:
				_reject("тупик в сети")
				return null
			kinds[i] = k
			lv.solution[i] = Pieces.rot_for_mask(k, m)

	# --- 3. заполнение ---
	var fw: Array = params["fill_weights"]
	var fill_kinds := [Pieces.STRAIGHT, Pieces.CORNER, Pieces.TEE, Pieces.CROSS]
	var total_w := 0
	for x in fw:
		total_w += int(x)
	for i in n:
		if kinds[i] != Pieces.EMPTY or net[i] == 1:
			continue
		if rng.chance(float(params["empty_ratio"])):
			continue
		var roll: int = rng.rand_int(1, total_w)
		var acc := 0
		for j in 4:
			acc += int(fw[j])
			if roll <= acc:
				kinds[i] = fill_kinds[j]
				break
		lv.solution[i] = rng.rand_int(0, 3)
	lv.kinds = kinds
	# сухие отвлекающие участки в решении не должны случайно подключаться к сети
	_dry_fill(lv, net)

	# --- 4. напор и требования ---
	for t in taps:
		lv.taps.append(t)
		lv.req[t] = 0
	lv.H = 0
	var r0 := PressureEval.evaluate(lv, lv.masks_for(lv.solution))
	if not r0["connected"]:
		_reject("задуманная сеть не соединена")
		return null
	var minp := 1000000
	for p in r0["taps"]:
		minp = mini(minp, int(p))
	var head: Array = params["head"]
	lv.H = -minp + rng.rand_int(int(head[0]), int(head[1]))
	var r1 := PressureEval.evaluate(lv, lv.masks_for(lv.solution))
	for j in taps.size():
		var p: int = r1["taps"][j]
		lv.req[taps[j]] = maxi(1, p - rng.rand_int(0, int(params["slack"])))
	var r2 := PressureEval.evaluate(lv, lv.masks_for(lv.solution))
	if not r2["win"]:
		_reject("задуманная сеть не выигрывает")
		return null

	# --- 5. проверка решателем и фильтры ---
	var sol := PressureSolver.count_winners(lv, int(params["solver_nodes"]), int(params["max_winners"]) + 1)
	if sol["aborted"]:
		_reject("решатель не уложился")
		return null
	if int(sol["winners"]) < 1:
		_reject("решатель не нашёл решения (ошибка!)")
		return null
	if int(sol["winners"]) > int(params["max_winners"]):
		_reject("слишком много решений")
		return null
	var all := PressureSolver.count_all(lv, int(params["all_nodes"]), int(params["all_stop"]))
	var connecting: int = all["connecting"]
	var complete: bool = not all["aborted"] and not all["stopped_early"]
	var ratio := float(sol["winners"]) / maxf(1.0, float(connecting))
	# Полный счёт: доля проходящих ≤ max_pass_ratio. Неполный (лимит/остановка):
	# соединяющих сетей много, проверяем только, что напор отсекает хотя бы min_cut.
	if connecting - int(sol["winners"]) < int(params["min_cut"]):
		if complete:
			_reject("напор почти не важен")
			return null
	elif complete and ratio > float(params["max_pass_ratio"]):
		_reject("напор почти не важен")
		return null

	# --- 6. перемешивание ---
	if not _scramble(rng.fork("scramble"), lv):
		_reject("не удалось перемешать")
		return null

	lv.meta = {
		"w": w, "h": h, "taps": taps.size(), "slack": params["slack"],
		"winners": sol["winners"], "solver_nodes": sol["nodes"],
		"connecting": connecting, "connecting_complete": complete,
		"all_nodes": all["nodes"], "solution_leaks": r2["leaks"],
		"loop": _has_loop(lv, r2["wet"]),
	}
	return lv


## Путь от сети к соседу крана t через свободные клетки (Дейкстра со случайными весами).
func _route(w: int, h: int, kinds: PackedByteArray, net: PackedByteArray, t: int, weight: PackedFloat32Array) -> PackedInt32Array:
	var n := w * h
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(1e9)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var done := PackedByteArray()
	done.resize(n)
	for i in n:
		if net[i] == 1:
			dist[i] = 0.0
	# цели: свободные или сетевые клетки рядом с краном
	var goal := PackedByteArray()
	goal.resize(n)
	for d in 4:
		var q := Grid.neighbor(w, h, t, d)
		if q >= 0 and kinds[q] == Pieces.EMPTY:
			goal[q] = 1
	while true:
		var best := -1
		var bd := 1e9
		for i in n:
			if done[i] == 0 and dist[i] < bd:
				bd = dist[i]
				best = i
		if best < 0:
			return PackedInt32Array()
		done[best] = 1
		if goal[best] == 1:
			var path := PackedInt32Array()
			var c := best
			while c >= 0:
				path.append(c)
				c = prev[c]
			path.reverse()
			return path
		for d in 4:
			var q := Grid.neighbor(w, h, best, d)
			if q < 0 or done[q] == 1 or kinds[q] != Pieces.EMPTY:
				continue
			# не проходим вплотную через сеть — иначе сеть слипается в кашу
			var nd := bd + weight[q] + (2.0 if _touches_net(w, h, net, q, best) else 0.0)
			if nd < dist[q]:
				dist[q] = nd
				prev[q] = best
	return PackedInt32Array()


func _touches_net(w: int, h: int, net: PackedByteArray, q: int, from: int) -> bool:
	if net[q] == 1:
		return false
	for d in 4:
		var r := Grid.neighbor(w, h, q, d)
		if r >= 0 and r != from and net[r] == 1:
			return true
	return false


func _lay(w: int, h: int, path: PackedInt32Array, net: PackedByteArray, arms: PackedInt32Array) -> void:
	for k in path.size():
		net[path[k]] = 1
		if k > 0:
			var d := _dir_between(w, path[k - 1], path[k])
			arms[path[k - 1]] |= 1 << d
			arms[path[k]] |= 1 << Dir.opp(d)


func _dir_between(w: int, a: int, b: int) -> int:
	if b == a - w:
		return Dir.N
	if b == a + 1:
		return Dir.E
	if b == a + w:
		return Dir.S
	return Dir.W


## Кольцо: короткий путь между двумя клетками сети через свободные клетки.
func _add_loop(rng, w: int, h: int, kinds: PackedByteArray, net: PackedByteArray, arms: PackedInt32Array, weight: PackedFloat32Array) -> void:
	var candidates := []
	for i in w * h:
		if net[i] == 1 and Dir.popcount4(arms[i]) == 2:
			for d in 4:
				var q := Grid.neighbor(w, h, i, d)
				if q >= 0 and kinds[q] == Pieces.EMPTY and net[q] == 0:
					candidates.append([i, d])
	if candidates.is_empty():
		return
	rng.shuffle(candidates)
	for c in candidates.slice(0, 6):
		var a: int = c[0]
		var start := Grid.neighbor(w, h, a, c[1])
		# BFS по свободным клеткам до другой клетки сети с 2 концами (не a и не сосед a)
		var prev := {start: -1}
		var queue := [start]
		var found := -1
		var via := -1
		while not queue.is_empty() and found < 0:
			var cur: int = queue.pop_front()
			if prev.size() > 12:
				break
			for d in 4:
				var q := Grid.neighbor(w, h, cur, d)
				if q < 0 or prev.has(q):
					continue
				if net[q] == 1 and q != a and Dir.popcount4(arms[q]) == 2 and cur != start:
					found = q
					via = cur
					break
				if kinds[q] == Pieces.EMPTY and net[q] == 0:
					prev[q] = cur
					queue.append(q)
		if found < 0:
			continue
		var path := PackedInt32Array([a])
		var back := PackedInt32Array()
		var x := via
		while x >= 0:
			back.append(x)
			x = prev[x]
		back.reverse()
		path.append_array(back)
		path.append(found)
		_lay(w, h, path, net, arms)
		return


## Тройник-приманка: клетке сети с 2 концами добавляем конец наружу (в задуманной
## сети это протечка). Решатель потом выяснит, выгоднее ли её закрыть.
func _add_decoy(rng, w: int, h: int, kinds: PackedByteArray, net: PackedByteArray, arms: PackedInt32Array) -> void:
	var cand := []
	for i in w * h:
		if net[i] == 1 and Dir.popcount4(arms[i]) == 2:
			for d in 4:
				if not (arms[i] >> d & 1):
					var q := Grid.neighbor(w, h, i, d)
					if q < 0 or (net[q] == 0 and kinds[q] != Pieces.SOURCE and kinds[q] != Pieces.TAP):
						cand.append([i, d])
	if cand.is_empty():
		return
	var c = rng.pick(cand)
	arms[c[0]] |= 1 << int(c[1])


## Повороты сухих клеток в решении: не смотреть в мокрую сеть (иначе «решение»
## случайно подключило бы лишнее). Если не получается — оставляем как есть.
func _dry_fill(lv, net: PackedByteArray) -> void:
	for i in lv.w * lv.h:
		if net[i] == 1 or not Pieces.is_pipe(lv.kinds[i]):
			continue
		for r in Pieces.distinct_rots(lv.kinds[i]):
			var m := Pieces.mask(lv.kinds[i], r)
			var touches := false
			for d in 4:
				if m >> d & 1:
					var q := Grid.neighbor(lv.w, lv.h, i, d)
					if q >= 0 and (net[q] == 1 or lv.kinds[q] == Pieces.SOURCE or lv.kinds[q] == Pieces.TAP):
						touches = true
			if not touches:
				lv.solution[i] = r
				break


func _scramble(rng, lv) -> bool:
	for attempt in 20:
		for i in lv.w * lv.h:
			lv.rots[i] = rng.rand_int(0, 3) if lv.is_rotatable(i) else 0
		if PressureEval.evaluate(lv, lv.masks())["win"]:
			continue
		if _one_tap_win(lv):
			continue
		return true
	return false


func _one_tap_win(lv) -> bool:
	for i in lv.w * lv.h:
		if not lv.is_rotatable(i):
			continue
		var old: int = lv.rots[i]
		for k in 3:
			lv.rots[i] = (old + k + 1) & 3
			if PressureEval.evaluate(lv, lv.masks())["win"]:
				lv.rots[i] = old
				return true
		lv.rots[i] = old
	return false


func _has_loop(lv, wet: PackedByteArray) -> bool:
	# в связной сети без колец рёбер = вершин − 1; считаем рёбра между мокрыми клетками
	var verts := 1  # источник
	var edges := 0
	var m: PackedByteArray = lv.masks_for(lv.solution)
	for i in lv.w * lv.h:
		if wet[i] == 0:
			continue
		verts += 1
		for d in [Dir.E, Dir.S]:
			var q := Grid.neighbor(lv.w, lv.h, i, d)
			if q >= 0 and wet[q] == 1 and (m[i] >> d & 1) and (m[q] >> Dir.opp(d) & 1):
				edges += 1
	for d in 4:
		var q := Grid.neighbor(lv.w, lv.h, lv.src, d)
		if (lv.outlets >> d & 1) and q >= 0 and wet[q] == 1:
			edges += 1
	return edges > verts - 1
