## Пиксельная графика «Давления», нарисованная кодом (тайлы 16×16).
## Всё своё: палитра, формы — ничего не взято из чужих игр.
## Текстуры строятся один раз и кэшируются; рисуются без сглаживания (NEAREST).
extends RefCounted

const T := 16  ## размер тайла в пикселях

## Палитра (своя): медь, хром, вода, ночной фон.
const C := {
	"bg": Color("141821"),
	"cell": Color("222a38"),
	"cell_hi": Color("2e3849"),
	"cell_lo": Color("1a202b"),
	"empty": Color("181d27"),
	"empty_dot": Color("1f2532"),
	"brick": Color("5a3b33"),
	"brick_hi": Color("6e4a3f"),
	"mortar": Color("2a1f1d"),
	"pipe_dark": Color("5a3a22"),
	"pipe": Color("b0743f"),
	"pipe_hi": Color("e6a96a"),
	"channel": Color("7a4c2a"),
	"water_lo": Color("1d4a86"),
	"water_hi": Color("8fe3ff"),
	"leak": Color("ff5a6e"),
	"leak_hi": Color("ffc2ca"),
	"chrome_dark": Color("5c6573"),
	"chrome": Color("aeb7c4"),
	"chrome_hi": Color("eef2f6"),
	"gauge_dry": Color("e9dfc7"),
	"gauge_ok": Color("7fd99a"),
	"gauge_low": Color("f3a35c"),
	"tank_dark": Color("1f3b66"),
	"tank": Color("3a72c0"),
	"tank_hi": Color("8cc2ff"),
	"rivet": Color("cfe3ff"),
	"text": Color("f2e6d0"),
	"text_dim": Color("8b93a4"),
	"copper_ui": Color("c4844a"),
}

static var _cache := {}


static func _img() -> Image:
	var im := Image.create(T, T, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	return im


static func _rect(im: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, T - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, T - 1) + 1):
			im.set_pixel(x, y, col)


static func _tex(key: String, im: Image) -> ImageTexture:
	var t := ImageTexture.create_from_image(im)
	_cache[key] = t
	return t


## Фон клетки: поворачиваемая — со скосом (выпуклая плитка), пустая — тёмная.
static func cell_tile(kind: String) -> ImageTexture:
	var key := "cell_" + kind
	if _cache.has(key):
		return _cache[key]
	var im := _img()
	match kind:
		"floor":
			_rect(im, 0, 0, T - 1, T - 1, C["cell"])
			_rect(im, 0, 0, T - 1, 0, C["cell_hi"])
			_rect(im, 0, 0, 0, T - 1, C["cell_hi"])
			_rect(im, 0, T - 1, T - 1, T - 1, C["cell_lo"])
			_rect(im, T - 1, 0, T - 1, T - 1, C["cell_lo"])
		"empty":
			_rect(im, 0, 0, T - 1, T - 1, C["empty"])
			im.set_pixel(7, 7, C["empty_dot"])
			im.set_pixel(8, 8, C["empty_dot"])
		"wall":
			_rect(im, 0, 0, T - 1, T - 1, C["mortar"])
			for row in 4:
				var y0 := row * 4
				var off := 0 if row % 2 == 0 else 4
				for bx in range(-1, 3):
					var x0 := bx * 8 + off
					_rect(im, x0, y0, x0 + 6, y0 + 2, C["brick"])
					_rect(im, x0, y0, x0 + 6, y0, C["brick_hi"])
	return _tex(key, im)


## Труба с концами mask (бит d: 0=N 1=E 2=S 3=W). Канал внутри — тёмный (сухо).
static func pipe(mask: int) -> ImageTexture:
	var key := "pipe_%d" % mask
	if _cache.has(key):
		return _cache[key]
	var im := _img()
	# слои: тёмный контур → тело → блик → канал
	for pass_i in 4:
		for d in 4:
			if not (mask >> d & 1):
				continue
			_arm(im, d, pass_i)
		_hub(im, pass_i)
	return _tex(key, im)


## Маска канала: белые пиксели там, где течёт вода (окрашивается при отрисовке).
static func channel(mask: int) -> ImageTexture:
	var key := "chan_%d" % mask
	if _cache.has(key):
		return _cache[key]
	var im := _img()
	for d in 4:
		if mask >> d & 1:
			_arm_rect(im, d, 7, 8, Color.WHITE)
	_rect(im, 7, 7, 8, 8, Color.WHITE)
	return _tex(key, im)


## Прямоугольник вдоль конца d с поперечным диапазоном [a, b].
static func _arm_rect(im: Image, d: int, a: int, b: int, col: Color) -> void:
	match d:
		0: _rect(im, a, 0, b, 8, col)
		1: _rect(im, 7, a, T - 1, b, col)
		2: _rect(im, a, 7, b, T - 1, col)
		3: _rect(im, 0, a, 8, b, col)


static func _arm(im: Image, d: int, pass_i: int) -> void:
	match pass_i:
		0:
			_arm_rect(im, d, 5, 10, C["pipe_dark"])
			# фланец у края клетки
			match d:
				0: _rect(im, 4, 0, 11, 1, C["pipe_dark"])
				1: _rect(im, T - 2, 4, T - 1, 11, C["pipe_dark"])
				2: _rect(im, 4, T - 2, 11, T - 1, C["pipe_dark"])
				3: _rect(im, 0, 4, 1, 11, C["pipe_dark"])
		1:
			_arm_rect(im, d, 6, 9, C["pipe"])
			match d:
				0: _rect(im, 5, 0, 10, 0, C["pipe"])
				1: _rect(im, T - 1, 5, T - 1, 10, C["pipe"])
				2: _rect(im, 5, T - 1, 10, T - 1, C["pipe"])
				3: _rect(im, 0, 5, 0, 10, C["pipe"])
		2:
			_arm_rect(im, d, 6, 6, C["pipe_hi"])
		3:
			_arm_rect(im, d, 7, 8, C["channel"])


static func _hub(im: Image, pass_i: int) -> void:
	match pass_i:
		0: _rect(im, 4, 4, 11, 11, C["pipe_dark"])
		1: _rect(im, 5, 5, 10, 10, C["pipe"])
		2:
			_rect(im, 5, 5, 10, 5, C["pipe_hi"])
			_rect(im, 5, 5, 5, 10, C["pipe_hi"])
		3: _rect(im, 7, 7, 8, 8, C["channel"])


## Бак-источник (выходы рисуются трубами поверх).
static func tank() -> ImageTexture:
	if _cache.has("tank"):
		return _cache["tank"]
	var im := _img()
	_rect(im, 3, 2, 12, 13, C["tank_dark"])
	_rect(im, 4, 3, 11, 12, C["tank"])
	_rect(im, 4, 3, 11, 3, C["tank_hi"])
	_rect(im, 4, 3, 4, 12, C["tank_hi"])
	_rect(im, 4, 7, 11, 7, C["tank_dark"])
	for p in [Vector2i(5, 5), Vector2i(10, 5), Vector2i(5, 10), Vector2i(10, 10)]:
		im.set_pixel(p.x, p.y, C["rivet"])
	return _tex("tank", im)


## Кран-манометр: хромированное кольцо и стекло (цвет = состояние).
static func gauge(state: String) -> ImageTexture:
	var key := "gauge_" + state
	if _cache.has(key):
		return _cache[key]
	var im := _img()
	var face: Color = C["gauge_dry"]
	if state == "ok":
		face = C["gauge_ok"]
	elif state == "low":
		face = C["gauge_low"]
	for y in T:
		for x in T:
			var dx := x - 7.5
			var dy := y - 7.5
			var r := sqrt(dx * dx + dy * dy)
			if r <= 7.2:
				im.set_pixel(x, y, C["chrome_dark"])
			if r <= 6.3:
				im.set_pixel(x, y, C["chrome"] if dx + dy > 0 else C["chrome_hi"])
			if r <= 5.0:
				im.set_pixel(x, y, face)
	return _tex(key, im)


## Капля протечки 4×5.
static func drop() -> ImageTexture:
	if _cache.has("drop"):
		return _cache["drop"]
	var im := Image.create(4, 5, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	for p in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(1, 4), Vector2i(2, 4)]:
		im.set_pixel(p.x, p.y, C["leak"])
	im.set_pixel(1, 2, C["leak_hi"])
	var t := ImageTexture.create_from_image(im)
	_cache["drop"] = t
	return t


## Цвет воды по напору: t = 0 (еле течёт) … 1 (полный напор).
static func water_color(t: float) -> Color:
	return (C["water_lo"] as Color).lerp(C["water_hi"], clampf(t, 0.0, 1.0))


## Стиль кнопок и панели: плоский, без скруглений, медная рамка.
static func button_styles() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = C["cell_hi"]
	normal.border_color = C["copper_ui"]
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(0)
	var pressed := normal.duplicate()
	pressed.bg_color = C["cell_lo"]
	var disabled := normal.duplicate()
	disabled.border_color = C["cell_hi"]
	disabled.bg_color = C["cell_lo"]
	return {"normal": normal, "hover": normal, "pressed": pressed, "disabled": disabled, "focus": StyleBoxEmpty.new()}
