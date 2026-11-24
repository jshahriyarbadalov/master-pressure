## Индексация прямоугольной сетки: клетка i = y * w + x.
extends RefCounted

const Dir = preload("res://addons/master_core/grid/dir.gd")


## Сосед клетки i в направлении d или -1, если за краем.
static func neighbor(w: int, h: int, i: int, d: int) -> int:
	var x := i % w + Dir.DX[d]
	var y := i / w + Dir.DY[d]
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return y * w + x


static func manhattan(w: int, a: int, b: int) -> int:
	return absi(a % w - b % w) + absi(a / w - b / w)
