## Уровень «Давления»: клетки, повороты, источник, краны, параметры напора.
## Формат JSON (version 1):
## {"version":1, "w":5, "h":2, "rows":["SYIYT","#LIL#"], "rots":["00000","00000"],
##  "outlets":[1], "taps":[{"x":4,"y":0,"req":3}], "H":8, "L":2,
##  "solution":["01010","00000"] (необязательно), "meta":{...}}
## Направления выходов источника: 0=N 1=E 2=S 3=W.
extends RefCounted

const Pieces = preload("res://game/logic/pieces.gd")

var w := 0
var h := 0
var kinds := PackedByteArray()
var rots := PackedByteArray()
var src := -1
var outlets := 0           ## маска выходов источника
var taps := PackedInt32Array()  ## индексы кранов по порядку
var req := {}              ## индекс крана -> требуемый напор
var H := 10
var L := 2
var solution := PackedByteArray()  ## повороты задуманного решения (может быть пустым)
var meta := {}


func size() -> int:
	return w * h


func is_rotatable(i: int) -> bool:
	return Pieces.is_pipe(kinds[i]) and kinds[i] != Pieces.CROSS


## Маски концов всех клеток для текущих поворотов (0 у не-труб).
func masks() -> PackedByteArray:
	return masks_for(rots)


func masks_for(r: PackedByteArray) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(w * h)
	for i in w * h:
		if Pieces.is_pipe(kinds[i]):
			m[i] = Pieces.mask(kinds[i], r[i])
	return m


func rotate_cell(i: int) -> void:
	rots[i] = (rots[i] + 1) & 3


func clone():
	var c = get_script().new()
	c.w = w
	c.h = h
	c.kinds = kinds.duplicate()
	c.rots = rots.duplicate()
	c.src = src
	c.outlets = outlets
	c.taps = taps.duplicate()
	c.req = req.duplicate()
	c.H = H
	c.L = L
	c.solution = solution.duplicate()
	c.meta = meta.duplicate(true)
	return c


## Построить из текстовых строк. reqs: Vector2i(x, y) -> требование.
static func from_rows(rows: Array, p_H: int, outlet_dirs: Array, reqs: Dictionary, p_L: int = 2):
	var lv = load("res://game/logic/pressure_level.gd").new()
	lv.h = rows.size()
	lv.w = (rows[0] as String).length()
	lv.kinds.resize(lv.w * lv.h)
	lv.rots.resize(lv.w * lv.h)
	for y in lv.h:
		var row: String = rows[y]
		assert(row.length() == lv.w, "строки разной длины")
		for x in lv.w:
			var k := Pieces.from_char(row[x])
			lv.kinds[y * lv.w + x] = k
			if k == Pieces.SOURCE:
				lv.src = y * lv.w + x
	lv.outlets = 0
	for d in outlet_dirs:
		lv.outlets |= 1 << int(d)
	for y in lv.h:
		for x in lv.w:
			var i: int = y * lv.w + x
			if lv.kinds[i] == Pieces.TAP:
				lv.taps.append(i)
				lv.req[i] = int(reqs.get(Vector2i(x, y), 0))
	lv.H = p_H
	lv.L = p_L
	return lv


func set_rots_from_rows(rows: Array) -> void:
	for y in h:
		for x in w:
			rots[y * w + x] = int((rows[y] as String)[x])


func rows_of(arr: PackedByteArray, as_kinds: bool) -> Array:
	var out := []
	for y in h:
		var s := ""
		for x in w:
			var v: int = arr[y * w + x]
			s += Pieces.to_char(v) if as_kinds else str(v)
		out.append(s)
	return out


func to_dict() -> Dictionary:
	var od := []
	for d in 4:
		if outlets >> d & 1:
			od.append(d)
	var td := []
	for t in taps:
		td.append({"x": t % w, "y": t / w, "req": req[t]})
	var d := {
		"version": 1, "w": w, "h": h,
		"rows": rows_of(kinds, true), "rots": rows_of(rots, false),
		"outlets": od, "taps": td, "H": H, "L": L, "meta": meta,
	}
	if solution.size() == w * h:
		d["solution"] = rows_of(solution, false)
	return d


static func from_dict(d: Dictionary):
	var reqs := {}
	for t in d["taps"]:
		reqs[Vector2i(int(t["x"]), int(t["y"]))] = int(t["req"])
	var lv = from_rows(d["rows"], int(d["H"]), d["outlets"], reqs, int(d.get("L", 2)))
	lv.set_rots_from_rows(d["rots"])
	if d.has("solution"):
		lv.solution.resize(lv.w * lv.h)
		for y in lv.h:
			for x in lv.w:
				lv.solution[y * lv.w + x] = int((d["solution"][y] as String)[x])
	lv.meta = d.get("meta", {})
	return lv


## Текстовая картинка сети: ┌─┐, «·» — сухая труба (если передан wet).
const GLYPH := {0b0101: "│", 0b1010: "─", 0b0011: "└", 0b0110: "┌", 0b1100: "┐", 0b1001: "┘",
	0b0111: "├", 0b1110: "┬", 0b1101: "┤", 0b1011: "┴", 0b1111: "┼"}


func draw(r: PackedByteArray = PackedByteArray(), wet: PackedByteArray = PackedByteArray()) -> String:
	if r.is_empty():
		r = rots
	var lines := []
	for y in h:
		var s := ""
		for x in w:
			var i := y * w + x
			var k := kinds[i]
			if Pieces.is_pipe(k):
				if not wet.is_empty() and wet[i] == 0:
					s += "·"
				else:
					s += GLYPH[Pieces.mask(k, r[i])]
			else:
				s += {Pieces.EMPTY: " ", Pieces.WALL: "█", Pieces.SOURCE: "S", Pieces.TAP: "T"}[k]
		lines.append(s)
	return "\n".join(lines)
