## Детерминированный ГСЧ xoshiro128** (32 бита), одинаковый на всех платформах
## и версиях движка. Встроенный RandomNumberGenerator не используем: его
## последовательность между версиями Godot не гарантирована (не подтверждено).
## Все операции на 32-битных словах с маской — 64-битные int GDScript не переполняются.
extends RefCounted

const M := 0xFFFFFFFF

var s0 := 0
var s1 := 0
var s2 := 0
var s3 := 0


func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)


static func from_string(text: String):
	return load("res://addons/master_core/rng/seeded_rng.gd").new(fnv1a32(text))


## FNV-1a 32 по UTF-8 байтам.
static func fnv1a32(text: String) -> int:
	var hsh := 0x811C9DC5
	for b in text.to_utf8_buffer():
		hsh = mul32(hsh ^ b, 0x01000193)
	return hsh


## (a * b) mod 2^32 без переполнения 64-битного int.
static func mul32(a: int, b: int) -> int:
	a &= M
	b &= M
	var lo := (a * (b & 0xFFFF)) & M
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & M


static func rotl(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & M


func set_seed(seed_value: int) -> void:
	var z := (seed_value ^ (seed_value >> 32)) & M
	var st: Array[int] = []
	for k in 4:
		z = (z + 0x9E3779B9) & M
		var t := z
		t = mul32(t ^ (t >> 16), 0x85EBCA6B)
		t = mul32(t ^ (t >> 13), 0xC2B2AE35)
		t ^= t >> 16
		st.append(t & M)
	s0 = st[0]
	s1 = st[1]
	s2 = st[2]
	s3 = st[3]
	if s0 == 0 and s1 == 0 and s2 == 0 and s3 == 0:
		s0 = 1


func next_u32() -> int:
	var result := mul32(rotl(mul32(s1, 5), 7), 9)
	var t := (s1 << 9) & M
	s2 ^= s0
	s3 ^= s1
	s1 ^= s2
	s0 ^= s3
	s2 ^= t
	s3 = rotl(s3, 11)
	return result


## Целое в [lo, hi] без смещения (отбрасывание хвоста).
## Имена rand_int/rand_float, а не randi_range/randf: иначе вызов без self.
## внутри класса уходит во ВСТРОЕННЫЙ глобальный ГСЧ Godot (была такая ошибка).
func rand_int(lo: int, hi: int) -> int:
	var n := hi - lo + 1
	assert(n > 0, "пустой диапазон")
	var limit := 0x100000000 - (0x100000000 % n)
	while true:
		var x := next_u32()
		if x < limit:
			return lo + x % n
	return lo


func rand_float() -> float:
	return next_u32() / 4294967296.0


func chance(p: float) -> bool:
	return rand_float() < p


func pick(arr: Array) -> Variant:
	return arr[rand_int(0, arr.size() - 1)]


func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rand_int(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Независимый поток для подзадачи (например, "fill" или "scramble").
func fork(tag: String):
	return load("res://addons/master_core/rng/seeded_rng.gd").new(next_u32() ^ fnv1a32(tag))
