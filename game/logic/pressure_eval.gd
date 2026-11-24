## Оценщик напора по правилам v0 (docs/GAME_DESIGN.md, раздел 3).
##
## 1. Мокрая сеть — трубы, связанные с источником (только топология).
## 2. Протечка — конец мокрой трубы или выход источника, который смотрит в
##    стену/край/пустоту/трубу без ответного конца. H_эфф = H − L × протечки.
## 3. Проход через трубу: −1; поворот внутри клетки: ещё −1;
##    в клетке n > 2 соединённых концов: ещё −(n − 2).
## 4. Напор на кране = лучший путь (Дейкстра по состояниям «клетка + сторона входа»).
## Победа: каждый кран подключён и его напор ≥ требования.
extends RefCounted

const Pieces = preload("res://game/logic/pieces.gd")
const Dir = preload("res://addons/master_core/grid/dir.gd")
const Grid = preload("res://addons/master_core/grid/grid.gd")

const UNREACHED := -1000000


## Принимает ли клетка q конец, пришедший к её стороне side.
static func accepts(lv, m: PackedByteArray, q: int, side: int) -> bool:
	if q < 0:
		return false
	var k: int = lv.kinds[q]
	if k >= Pieces.STRAIGHT:
		return (m[q] >> side & 1) == 1
	if k == Pieces.TAP:
		return true
	if k == Pieces.SOURCE:
		return (lv.outlets >> side & 1) == 1
	return false


## Число соединённых концов клетки i.
static func connected_arms(lv, m: PackedByteArray, i: int) -> int:
	var c := 0
	for d in 4:
		if (m[i] >> d & 1) and accepts(lv, m, Grid.neighbor(lv.w, lv.h, i, d), Dir.opp(d)):
			c += 1
	return c


## Мокрая сеть и протечки. Возвращает [wet: PackedByteArray, leaks: int, leak_list: PackedInt32Array]
## leak_list — пары (клетка*4 + направление), клетка = -1 для выхода источника... кодируем src.
static func wet_and_leaks(lv, m: PackedByteArray) -> Array:
	var w: int = lv.w
	var h: int = lv.h
	var wet := PackedByteArray()
	wet.resize(w * h)
	var leak_list := PackedInt32Array()
	var stack := PackedInt32Array()
	var src: int = lv.src
	for d in 4:
		if not (lv.outlets >> d & 1):
			continue
		var q := Grid.neighbor(w, h, src, d)
		if accepts(lv, m, q, Dir.opp(d)):
			if q >= 0 and lv.kinds[q] >= Pieces.STRAIGHT and wet[q] == 0:
				wet[q] = 1
				stack.append(q)
		else:
			leak_list.append(src * 4 + d)
	while stack.size() > 0:
		var i: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var mi: int = m[i]
		for d in 4:
			if not (mi >> d & 1):
				continue
			var q := Grid.neighbor(w, h, i, d)
			if accepts(lv, m, q, Dir.opp(d)):
				if lv.kinds[q] >= Pieces.STRAIGHT and wet[q] == 0:
					wet[q] = 1
					stack.append(q)
			else:
				leak_list.append(i * 4 + d)
	return [wet, leak_list.size(), leak_list]


## Полная оценка. m — маски концов (lv.masks() или lv.masks_for(rots)).
## Результат: wet, leaks, leak_list, heff, taps (Array: напор или null по порядку lv.taps),
## connected, win, cell_p (PackedInt32Array: лучший напор на входе в клетку или UNREACHED).
static func evaluate(lv, m: PackedByteArray) -> Dictionary:
	var w: int = lv.w
	var h: int = lv.h
	var n := w * h
	var wl := wet_and_leaks(lv, m)
	var leaks: int = wl[1]
	var heff: int = lv.H - lv.L * leaks

	var best := PackedInt32Array()
	best.resize(n * 4)
	best.fill(-1)
	var junc := PackedInt32Array()
	junc.resize(n)
	junc.fill(-1)
	var tap_cost := {}
	var buckets: Array[PackedInt32Array] = []

	var src: int = lv.src
	for d in 4:
		if not (lv.outlets >> d & 1):
			continue
		var q := Grid.neighbor(w, h, src, d)
		if q < 0:
			continue
		if lv.kinds[q] == Pieces.TAP:
			tap_cost[q] = 0
		elif lv.kinds[q] >= Pieces.STRAIGHT and accepts(lv, m, q, Dir.opp(d)):
			_push(buckets, 0, q * 4 + Dir.opp(d))

	var dist := 0
	while dist < buckets.size():
		var bucket: PackedInt32Array = buckets[dist]
		var k := 0
		while k < bucket.size():
			var s: int = bucket[k]
			k += 1
			if best[s] != -1:
				continue
			best[s] = dist
			var i := s >> 2
			var ent := s & 3
			if junc[i] < 0:
				junc[i] = maxi(0, connected_arms(lv, m, i) - 2)
			var mi: int = m[i]
			for e in 4:
				if e == ent or not (mi >> e & 1):
					continue
				var q := Grid.neighbor(w, h, i, e)
				if not accepts(lv, m, q, Dir.opp(e)):
					continue
				var cost := 1 + junc[i] + (0 if e == Dir.opp(ent) else 1)
				var nd := dist + cost
				var kq: int = lv.kinds[q]
				if kq == Pieces.TAP:
					if not tap_cost.has(q) or nd < tap_cost[q]:
						tap_cost[q] = nd
				elif kq >= Pieces.STRAIGHT:
					var ns := q * 4 + Dir.opp(e)
					if best[ns] == -1:
						_push(buckets, nd, ns)
			bucket = buckets[dist]  # массив мог вырасти (стоимости ≥ 1, поэтому не этот)
		dist += 1

	var taps := []
	var connected := true
	var win := true
	for t in lv.taps:
		if tap_cost.has(t):
			var p: int = heff - tap_cost[t]
			taps.append(p)
			if p < int(lv.req[t]):
				win = false
		else:
			taps.append(null)
			connected = false
			win = false
	var cell_p := PackedInt32Array()
	cell_p.resize(n)
	cell_p.fill(UNREACHED)
	for s in n * 4:
		if best[s] >= 0:
			cell_p[s >> 2] = maxi(cell_p[s >> 2], heff - best[s])
	return {
		"wet": wl[0], "leaks": leaks, "leak_list": wl[2], "heff": heff,
		"taps": taps, "connected": connected, "win": win, "cell_p": cell_p,
	}


static func _push(buckets: Array[PackedInt32Array], d: int, s: int) -> void:
	while buckets.size() <= d:
		buckets.append(PackedInt32Array())
	buckets[d].append(s)


static func count_wet(wet: PackedByteArray) -> int:
	var c := 0
	for v in wet:
		c += v
	return c
