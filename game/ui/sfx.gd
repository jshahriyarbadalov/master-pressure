## Звуки, синтезированные кодом при запуске (без аудиофайлов).
## 16 бит, моно, 22 050 Гц. Каждый звук — короткая формула: тон + огибающая.
extends RefCounted

const RATE := 22050
const SeededRng = preload("res://addons/master_core/rng/seeded_rng.gd")

static var _cache := {}


static func get_stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var s: PackedFloat32Array
	match name:
		"rotate": s = _rotate()
		"plink": s = _plink()
		"win": s = _win()
		"coin": s = _coin()
		"undo": s = _undo()
		"fail": s = _fail()
		_: s = PackedFloat32Array([0.0])
	var st := _to_wav(s)
	_cache[name] = st
	return st


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampi(int(samples[i] * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st


static func _n(sec: float) -> int:
	return int(sec * RATE)


## Металлический щелчок вентиля: короткий шум + звон 1,1 кГц.
static func _rotate() -> PackedFloat32Array:
	var rng := SeededRng.new(7)
	var out := PackedFloat32Array()
	var n := _n(0.07)
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var noise := (rng.rand_float() * 2.0 - 1.0) * exp(-t * 120.0)
		var ring := sin(TAU * 1100.0 * t) * exp(-t * 55.0)
		out[i] = 0.35 * noise + 0.35 * ring
	return out


## «Плинк» — вода дошла до крана с нужным напором: тон скользит вверх.
static func _plink() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := _n(0.2)
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 880.0 + 440.0 * (t / 0.2)
		ph += TAU * f / RATE
		out[i] = (sin(ph) + 0.3 * sin(2.0 * ph)) * 0.32 * exp(-t * 14.0)
	return out


## Победа: арпеджио до–ми–соль–до мягким треугольным звуком.
static func _win() -> PackedFloat32Array:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var step := 0.09
	var out := PackedFloat32Array()
	var n := _n(step * notes.size() + 0.35)
	out.resize(n)
	for k in notes.size():
		var start := _n(step * k)
		var f: float = notes[k]
		for i in range(start, n):
			var t := float(i - start) / RATE
			var tri := 2.0 * absf(2.0 * fposmod(f * t, 1.0) - 1.0) - 1.0
			out[i] += tri * 0.22 * exp(-t * (6.0 if k == notes.size() - 1 else 12.0))
	return out


## Монеты: два коротких звонких тона.
static func _coin() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := _n(0.22)
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 1318.5 if t < 0.06 else 1760.0
		var t0 := t if t < 0.06 else t - 0.06
		out[i] = sin(TAU * f * t) * 0.25 * exp(-t0 * 18.0)
	return out


## Отмена: короткий тон вниз.
static func _undo() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := _n(0.09)
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (620.0 - 2200.0 * t) / RATE
		out[i] = sin(ph) * 0.25 * exp(-t * 25.0)
	return out


## Условие клиента нарушено: низкий глухой гудок.
static func _fail() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := _n(0.25)
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var sq := 1.0 if fposmod(150.0 * t, 1.0) < 0.5 else -1.0
		out[i] = sq * 0.12 * exp(-t * 9.0)
	return out
