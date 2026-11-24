## Типы клеток «Давления» и маски концов участков.
extends RefCounted

const Dir = preload("res://addons/master_core/grid/dir.gd")

const EMPTY := 0
const WALL := 1
const SOURCE := 2
const TAP := 3
const STRAIGHT := 4
const CORNER := 5
const TEE := 6
const CROSS := 7

## Символы в текстовом виде уровня (индекс = тип).
const CHARS := ".#STILYX"
## Маска в повороте 0: прямая N–S, угол N–E, тройник N–E–S, крест все.
const BASE: Array[int] = [0, 0, 0, 0, 0b0101, 0b0011, 0b0111, 0b1111]


static func is_pipe(kind: int) -> bool:
	return kind >= STRAIGHT


static func from_char(c: String) -> int:
	var k := CHARS.find(c)
	assert(k >= 0, "неизвестный символ клетки '%s'" % c)
	return k


static func to_char(kind: int) -> String:
	return CHARS[kind]


static func mask(kind: int, rot: int) -> int:
	return Dir.rot_mask(BASE[kind], rot)


## Повороты 0..3, дающие различные маски (прямая 2, крест 1, угол/тройник 4).
static func distinct_rots(kind: int) -> Array[int]:
	var seen := {}
	var out: Array[int] = []
	for r in 4:
		var m := mask(kind, r)
		if not seen.has(m):
			seen[m] = true
			out.append(r)
	return out


## Поворот, дающий маску m, или -1.
static func rot_for_mask(kind: int, m: int) -> int:
	for r in 4:
		if mask(kind, r) == m:
			return r
	return -1
