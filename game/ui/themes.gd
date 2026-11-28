## Помещения клиентов: пол под трубами (тайл 16×16), фон экрана, иконка места.
## 10 тем, всё нарисовано кодом. Полы приглушённые, чтобы медные трубы читались.
extends RefCounted

const T := 16
const NAMES := ["kitchen", "bathroom", "parquet", "garden", "cafe", "school", "garage", "marble", "carpet", "courtyard"]

## Фон экрана вокруг поля и цвет сетки клеток для каждой темы.
const BG := {
	"kitchen": Color("2a2320"), "bathroom": Color("1c2a33"), "parquet": Color("261c16"),
	"garden": Color("1b2417"), "cafe": Color("211c22"), "school": Color("1c2621"),
	"garage": Color("1e2023"), "marble": Color("23252b"), "carpet": Color("2a1619"),
	"courtyard": Color("22201c"),
}

static var _cache := {}


static func _img() -> Image:
	var im := Image.create(T, T, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	return im


static func _r(im: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, T - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, T - 1) + 1):
			im.set_pixel(x, y, c)


static func _px(im: Image, pts: Array, c: Color) -> void:
	for p in pts:
		im.set_pixel(p[0], p[1], c)


## Тема по индексу уровня, если у клиента её нет.
static func by_index(i: int) -> String:
	return NAMES[posmod(i, NAMES.size())]


## Пол помещения. grid=true — с тонкой границей клетки (клетки с участками).
static func floor_tile(theme: String, grid: bool) -> ImageTexture:
	var key := "%s_%s" % [theme, grid]
	if _cache.has(key):
		return _cache[key]
	var im := _img()
	match theme:
		"kitchen":  # мелкая плитка 4×4 с затиркой
			_r(im, 0, 0, 15, 15, Color("6b5a4c"))
			for ty in 4:
				for tx in 4:
					var c := Color("8a7563") if (tx + ty) % 2 == 0 else Color("7c6858")
					_r(im, tx * 4, ty * 4, tx * 4 + 2, ty * 4 + 2, c)
		"bathroom":  # кафель 8×8, голубоватый
			_r(im, 0, 0, 15, 15, Color("4c6a78"))
			for ty in 2:
				for tx in 2:
					_r(im, tx * 8, ty * 8, tx * 8 + 6, ty * 8 + 6, Color("6f93a3"))
					_r(im, tx * 8, ty * 8, tx * 8 + 6, ty * 8, Color("8db1c0"))
		"parquet":  # «ёлочка» из дощечек
			_r(im, 0, 0, 15, 15, Color("4e3523"))
			for row in 4:
				var y0 := row * 4
				var off := 0 if row % 2 == 0 else 4
				for k in range(-1, 3):
					var x0 := k * 8 + off
					_r(im, x0, y0, x0 + 6, y0 + 2, Color("6a4a31") if (row + k) % 2 == 0 else Color("5d412b"))
		"garden":  # земля и травинки
			_r(im, 0, 0, 15, 15, Color("3f2f22"))
			_px(im, [[2, 3], [9, 1], [13, 6], [5, 10], [11, 13], [1, 14], [7, 6]], Color("4c3a2a"))
			_px(im, [[3, 2], [3, 1], [10, 9], [10, 8], [14, 12], [6, 13], [6, 12]], Color("4f7a3a"))
		"cafe":  # шахматный пол, приглушённый
			for ty in 2:
				for tx in 2:
					_r(im, tx * 8, ty * 8, tx * 8 + 7, ty * 8 + 7, Color("4a4148") if (tx + ty) % 2 == 0 else Color("2f2a31"))
		"school":  # линолеум с крапинками
			_r(im, 0, 0, 15, 15, Color("3d5246"))
			_px(im, [[2, 2], [7, 4], [12, 3], [4, 9], [10, 11], [14, 14], [1, 13], [8, 15]], Color("4a6254"))
			_px(im, [[5, 6], [13, 9], [3, 15]], Color("33453b"))
		"garage":  # бетон, трещина, пятно масла
			_r(im, 0, 0, 15, 15, Color("4a4d52"))
			_px(im, [[3, 3], [4, 4], [5, 4], [6, 5], [11, 10], [12, 11]], Color("3a3c40"))
			_r(im, 9, 2, 12, 4, Color("35363b"))
			_px(im, [[1, 12], [8, 8], [14, 14]], Color("55595f"))
		"marble":  # мрамор с прожилками
			_r(im, 0, 0, 15, 15, Color("8a8d96"))
			_px(im, [[0, 3], [1, 4], [2, 4], [3, 5], [4, 6], [5, 6], [6, 7], [9, 10], [10, 11], [11, 11], [12, 12], [14, 1], [13, 2]], Color("a6a9b2"))
			_px(im, [[7, 7], [8, 8], [8, 9]], Color("767982"))
		"carpet":  # ковёр с узором
			_r(im, 0, 0, 15, 15, Color("5e2a2f"))
			_px(im, [[7, 3], [6, 4], [8, 4], [5, 5], [9, 5], [6, 6], [8, 6], [7, 7]], Color("8c4a3e"))
			_px(im, [[0, 0], [15, 15], [0, 15], [15, 0]], Color("8c4a3e"))
		"courtyard":  # брусчатка
			_r(im, 0, 0, 15, 15, Color("2e2b26"))
			for st in [[1, 1, 6, 5], [9, 0, 14, 5], [0, 8, 4, 13], [6, 7, 11, 12], [13, 8, 15, 13]]:
				_r(im, st[0], st[1], st[2], st[3], Color("5b554b"))
				_r(im, st[0], st[1], st[2], st[1], Color("6b6458"))
		_:
			_r(im, 0, 0, 15, 15, Color("222a38"))
	if grid:
		var g := Color(0, 0, 0, 0.28)
		for i in T:
			im.set_pixel(i, T - 1, im.get_pixel(i, T - 1).blend(g))
			im.set_pixel(T - 1, i, im.get_pixel(T - 1, i).blend(g))
	var t := ImageTexture.create_from_image(im)
	_cache[key] = t
	return t


## Иконка места клиента 16×16 (для карточки заказа).
static func icon(theme: String) -> ImageTexture:
	var key := "icon_" + theme
	if _cache.has(key):
		return _cache[key]
	var im := _img()
	var dark := Color("3b2a1e")
	match theme:
		"kitchen":  # кастрюля
			_r(im, 3, 7, 12, 13, Color("c9cfd8"))
			_r(im, 2, 6, 13, 6, dark)
			_r(im, 0, 8, 2, 8, dark)
			_r(im, 13, 8, 15, 8, dark)
			_r(im, 6, 4, 9, 5, dark)
		"bathroom":  # капля
			_px(im, [[7, 2], [8, 2], [6, 4], [9, 4], [7, 3], [8, 3]], Color("3a86ff"))
			_r(im, 5, 5, 10, 11, Color("3a86ff"))
			_r(im, 6, 12, 9, 13, Color("3a86ff"))
			_px(im, [[6, 7], [6, 8]], Color("bfe0ff"))
		"parquet":  # дом
			for y in 6:
				_r(im, 7 - y, 2 + y, 8 + y, 2 + y, Color("b0743f"))
			_r(im, 3, 8, 12, 14, Color("e9dfc7"))
			_r(im, 7, 10, 8, 14, dark)
		"garden":  # цветок
			_r(im, 7, 8, 8, 15, Color("4f7a3a"))
			_r(im, 5, 3, 10, 7, Color("f3a35c"))
			_r(im, 7, 5, 8, 5, Color("ffe08a"))
			_r(im, 9, 10, 11, 11, Color("4f7a3a"))
		"cafe":  # чашка
			_r(im, 3, 6, 10, 13, Color("e9dfc7"))
			_r(im, 11, 8, 13, 11, Color("e9dfc7"))
			_r(im, 12, 9, 12, 10, Color(0, 0, 0, 0))
			_r(im, 4, 6, 9, 7, Color("7a4c2a"))
			_px(im, [[5, 2], [6, 3], [5, 4], [8, 2], [9, 3], [8, 4]], Color("aeb7c4"))
		"school":  # книга
			_r(im, 2, 3, 13, 13, Color("3a72c0"))
			_r(im, 7, 3, 8, 13, dark)
			_r(im, 3, 5, 6, 5, Color("e9dfc7"))
			_r(im, 9, 5, 12, 5, Color("e9dfc7"))
		"garage":  # гаечный ключ
			_r(im, 7, 5, 8, 14, Color("aeb7c4"))
			_r(im, 5, 1, 10, 5, Color("aeb7c4"))
			_r(im, 7, 1, 8, 3, Color(0, 0, 0, 0))
		"marble":  # ключ от номера
			_r(im, 3, 3, 8, 8, Color("e6a96a"))
			_r(im, 5, 5, 6, 6, Color(0, 0, 0, 0))
			_r(im, 8, 7, 14, 8, Color("e6a96a"))
			_r(im, 12, 9, 13, 10, Color("e6a96a"))
		"carpet":  # нота
			_r(im, 9, 2, 10, 11, Color("e9dfc7"))
			_r(im, 10, 2, 13, 3, Color("e9dfc7"))
			_r(im, 5, 10, 9, 13, Color("e9dfc7"))
		"courtyard":  # дерево
			_r(im, 7, 10, 8, 15, Color("7a4c2a"))
			_r(im, 3, 2, 12, 10, Color("4f7a3a"))
			_px(im, [[5, 4], [9, 6], [6, 8]], Color("6fa352"))
	var t := ImageTexture.create_from_image(im)
	_cache[key] = t
	return t


## Монета ₼ 8×8 и звезда бонуса 8×8, значок «внимание» 8×8.
static func small(name: String) -> ImageTexture:
	var key := "small_" + name
	if _cache.has(key):
		return _cache[key]
	var im := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	match name:
		"coin":
			for y in 8:
				for x in 8:
					var d := Vector2(x - 3.5, y - 3.5).length()
					if d <= 3.7:
						im.set_pixel(x, y, Color("b8862b"))
					if d <= 2.8:
						im.set_pixel(x, y, Color("f2c14e"))
			im.set_pixel(3, 3, Color("fff1b8"))
		"star":
			for p in [[3, 0], [4, 0], [3, 1], [4, 1], [0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [7, 2], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [2, 4], [3, 4], [4, 4], [5, 4], [1, 5], [2, 5], [5, 5], [6, 5], [1, 6], [6, 6]]:
				im.set_pixel(p[0], p[1], Color("f2c14e"))
		"warn":
			for y in 7:
				var half := y / 2
				for x in range(3 - half, 5 + half):
					im.set_pixel(x, y, Color("e4573d"))
			im.set_pixel(3, 2, Color.WHITE)
			im.set_pixel(4, 2, Color.WHITE)
			im.set_pixel(3, 3, Color.WHITE)
			im.set_pixel(4, 3, Color.WHITE)
			im.set_pixel(3, 5, Color.WHITE)
			im.set_pixel(4, 5, Color.WHITE)
	var t := ImageTexture.create_from_image(im)
	_cache[key] = t
	return t
