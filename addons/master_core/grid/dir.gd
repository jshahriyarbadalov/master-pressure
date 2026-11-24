## Направления сетки и 4-битные маски концов (бит d = конец в сторону d).
## Общий код серии: ничего не знает о трубах.
extends RefCounted

const N := 0
const E := 1
const S := 2
const W := 3
const DX: Array[int] = [0, 1, 0, -1]
const DY: Array[int] = [-1, 0, 1, 0]
const NAMES: Array[String] = ["N", "E", "S", "W"]


static func opp(d: int) -> int:
	return (d + 2) & 3


## Поворот маски на r шагов по часовой (N→E→S→W).
static func rot_mask(mask: int, r: int) -> int:
	r &= 3
	return ((mask << r) | (mask >> (4 - r))) & 15


static func popcount4(mask: int) -> int:
	return (mask & 1) + (mask >> 1 & 1) + (mask >> 2 & 1) + (mask >> 3 & 1)
