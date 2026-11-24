## Точный решатель «Давления»: перебор МОКРЫХ сетей с отсечениями.
##
## Идея (docs/GAME_DESIGN.md, раздел 6). Перебор всех поворотов — 4^N. Но сухие
## трубы на результат не влияют, поэтому растим сеть от источника:
##  - берём очередную мокрую клетку и пробуем её повороты;
##  - каждый конец, смотрящий в соседнюю трубу, — развилка решения:
##      «соединить» (сосед обязан иметь ответный конец и становится мокрым) или
##      «протечь» (сосед обязан НЕ иметь ответного конца; +1 протечка);
##  - конец в стену/край/пустоту — протечка без выбора.
## Ограничения соседей копятся в масках need[i] / forbid[i]; ветка отбрасывается,
## если у соседа не осталось подходящего поворота.
##
## Отсечение (режим с требованиями): напор на кране t не может превысить
## H − L·протечки − dmin(t), где dmin — нижняя граница стоимости пути
## (не меньше manhattan−1 клеток и +1 за поворот, если источник и кран не на одной линии).
## Протечки только растут, поэтому ветку, где граница уже < требования, можно бросить.
extends RefCounted

const Pieces = preload("res://game/logic/pieces.gd")
const Dir = preload("res://addons/master_core/grid/dir.gd")
const Grid = preload("res://addons/master_core/grid/grid.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")

# --- входные данные ---
var lv
var use_bound := true      ## отсекать по требованиям кранов
var node_limit := 2000000  ## предел узлов перебора
var max_winners := 1000000 ## остановиться после стольких решений
var max_connecting := 1000000000 ## остановиться после стольких соединяющих сетей
var store_winners := 4     ## сколько решений сохранить (повороты)

# --- результат ---
var nodes := 0
var aborted := false       ## упёрлись в предел узлов — результат неполный
var networks := 0          ## полных сетей рассмотрено
var connecting := 0        ## из них довели воду до всех кранов
var winners := 0
var winners_watertight := 0     ## решений без протечек
var connecting_watertight := 0  ## соединяющих сетей без протечек
var winner_rots: Array[PackedByteArray] = []
var winner_leaks := PackedInt32Array()  ## протечки в каждом сохранённом решении
var best_taps := []        ## лучший напор на каждом кране среди соединяющих сетей
var time_ms := 0

# --- состояние перебора ---
var _n := 0
var _mask := PackedInt32Array()    ## -1 — не назначено
var _need := PackedInt32Array()
var _forbid := PackedInt32Array()
var _wet := PackedByteArray()
var _order := PackedInt32Array()
var _leaks := 0
var _rots_of_kind := {}
var _dmin := PackedInt32Array()
var _stop := false


func _init(level = null) -> void:
	lv = level


func solve() -> Dictionary:
	var t0 := Time.get_ticks_msec()
	_n = lv.w * lv.h
	_mask.resize(_n)
	_mask.fill(-1)
	_need.resize(_n)
	_need.fill(0)
	_forbid.resize(_n)
	_forbid.fill(0)
	_wet.resize(_n)
	_wet.fill(0)
	_order.clear()
	_leaks = 0
	nodes = 0
	aborted = false
	_stop = false
	networks = 0
	connecting = 0
	winners = 0
	winners_watertight = 0
	connecting_watertight = 0
	winner_rots.clear()
	winner_leaks.clear()
	best_taps = []
	for t in lv.taps:
		best_taps.append(null)
	for k in [Pieces.STRAIGHT, Pieces.CORNER, Pieces.TEE, Pieces.CROSS]:
		var masks := PackedInt32Array()
		for r in Pieces.distinct_rots(k):
			masks.append(Pieces.mask(k, r))
		_rots_of_kind[k] = masks
	_dmin.resize(lv.taps.size())
	for j in lv.taps.size():
		var t: int = lv.taps[j]
		var dx := absi(t % lv.w - lv.src % lv.w)
		var dy := absi(t / lv.w - lv.src / lv.w)
		_dmin[j] = maxi(0, dx + dy - 1) + (1 if dx != 0 and dy != 0 else 0)

	# Выходы источника — тоже развилки «соединить / протечь».
	var arms := PackedInt32Array()
	for d in 4:
		if not (lv.outlets >> d & 1):
			continue
		var q := Grid.neighbor(lv.w, lv.h, lv.src, d)
		if q >= 0 and lv.kinds[q] >= Pieces.STRAIGHT:
			arms.append(q * 4 + Dir.opp(d))
		elif q < 0 or lv.kinds[q] != Pieces.TAP:
			_leaks += 1
	if _bound_ok():
		_expand(arms, 0, 0)
	time_ms = Time.get_ticks_msec() - t0
	return summary()


func summary() -> Dictionary:
	return {
		"winners": winners, "connecting": connecting, "networks": networks,
		"winners_watertight": winners_watertight, "connecting_watertight": connecting_watertight,
		"nodes": nodes, "aborted": aborted, "time_ms": time_ms, "best_taps": best_taps,
	}


func _bound_ok() -> bool:
	if not use_bound:
		return true
	var heff: int = lv.H - lv.L * _leaks
	for j in lv.taps.size():
		if heff - _dmin[j] < int(lv.req[lv.taps[j]]):
			return false
	return true


func _feasible(q: int) -> bool:
	var need := _need[q]
	var forbid := _forbid[q]
	for m in _rots_of_kind[lv.kinds[q]]:
		if (m & need) == need and (m & forbid) == 0:
			return true
	return false


## Перебор решений по списку развилок arms (клетка*4 + сторона соседа), затем дальше по очереди.
func _expand(arms: PackedInt32Array, k: int, pos: int) -> void:
	if _stop:
		return
	if k == arms.size():
		_process(pos)
		return
	var q := arms[k] >> 2
	var side := arms[k] & 3
	var bit := 1 << side
	# 1) соединить
	var old_need := _need[q]
	_need[q] = old_need | bit
	if _feasible(q):
		if _wet[q] == 0:
			_wet[q] = 1
			_order.append(q)
			_expand(arms, k + 1, pos)
			_order.remove_at(_order.size() - 1)
			_wet[q] = 0
		else:
			_expand(arms, k + 1, pos)
	_need[q] = old_need
	# 2) протечь
	var old_forbid := _forbid[q]
	_forbid[q] = old_forbid | bit
	_leaks += 1
	if _feasible(q) and _bound_ok():
		_expand(arms, k + 1, pos)
	_leaks -= 1
	_forbid[q] = old_forbid


func _process(pos: int) -> void:
	if _stop:
		return
	nodes += 1
	if nodes > node_limit:
		aborted = true
		_stop = true
		return
	if pos == _order.size():
		_complete()
		return
	var i := _order[pos]
	var need := _need[i]
	var forbid := _forbid[i]
	for m in _rots_of_kind[lv.kinds[i]]:
		if (m & need) != need or (m & forbid) != 0:
			continue
		_mask[i] = m
		var added_leaks := 0
		var arms := PackedInt32Array()
		var ok := true
		for d in 4:
			if not (m >> d & 1):
				continue
			var q := Grid.neighbor(lv.w, lv.h, i, d)
			var side := Dir.opp(d)
			if q < 0:
				added_leaks += 1
				continue
			var kq: int = lv.kinds[q]
			if kq == Pieces.TAP:
				continue
			if kq == Pieces.SOURCE:
				if not (lv.outlets >> side & 1):
					added_leaks += 1
				continue
			if kq < Pieces.STRAIGHT:
				added_leaks += 1
				continue
			if _mask[q] >= 0:
				# сосед уже назначен: ответный конец есть или нет — решено
				if not (_mask[q] >> side & 1):
					added_leaks += 1
				continue
			arms.append(q * 4 + side)
		_leaks += added_leaks
		if _bound_ok():
			_expand(arms, 0, pos + 1)
		_leaks -= added_leaks
		if _stop:
			break
	_mask[i] = -1


func _complete() -> void:
	networks += 1
	var masks := PackedByteArray()
	masks.resize(_n)
	var rots := PackedByteArray()
	rots.resize(_n)
	for i in _n:
		var k: int = lv.kinds[i]
		if k < Pieces.STRAIGHT:
			continue
		var m := _mask[i]
		if m < 0:
			# сухая клетка: любой поворот без запрещённых концов
			for mm in _rots_of_kind[k]:
				if (mm & _forbid[i]) == 0:
					m = mm
					break
		masks[i] = m
		rots[i] = Pieces.rot_for_mask(k, m)
	var r := PressureEval.evaluate(lv, masks)
	if not r["connected"]:
		return
	connecting += 1
	if r["leaks"] == 0:
		connecting_watertight += 1
	if connecting >= max_connecting:
		_stop = true
	for j in lv.taps.size():
		var p = r["taps"][j]
		if best_taps[j] == null or p > best_taps[j]:
			best_taps[j] = p
	if r["win"]:
		winners += 1
		if r["leaks"] == 0:
			winners_watertight += 1
		if winner_rots.size() < store_winners:
			winner_rots.append(rots)
			winner_leaks.append(r["leaks"])
		if winners >= max_winners:
			_stop = true


## Удобная обёртка: перебор с отсечением, вернуть сводку.
static func count_winners(level, limit: int = 2000000, stop_after: int = 1000000) -> Dictionary:
	var s = load("res://game/logic/pressure_solver.gd").new(level)
	s.node_limit = limit
	s.max_winners = stop_after
	var res: Dictionary = s.solve()
	res["winner_rots"] = s.winner_rots
	res["winner_leaks"] = s.winner_leaks
	return res


## Перебор без отсечения (для метрики «доля проходящих сетей»).
## stop_connecting — остановиться, найдя столько соединяющих сетей (полный счёт дорог:
## на 6×7 он съедал 95% времени генерации и всё равно упирался в лимит).
static func count_all(level, limit: int = 2000000, stop_connecting: int = 1000000000) -> Dictionary:
	var s = load("res://game/logic/pressure_solver.gd").new(level)
	s.use_bound = false
	s.node_limit = limit
	s.max_connecting = stop_connecting
	var res: Dictionary = s.solve()
	res["stopped_early"] = s.connecting >= stop_connecting
	return res
