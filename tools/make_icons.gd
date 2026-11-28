## Иконки и заставка, нарисованные кодом (T-25):
##   godot --headless -s tools/make_icons.gd
## Кладёт PNG в res://assets/icons/. Рисуем на сетке 24×24 и увеличиваем
## без сглаживания в целое число раз — пиксели остаются чёткими.
extends SceneTree

const PixelArt = preload("res://game/ui/pixel_art.gd")
const Themes = preload("res://game/ui/themes.gd")

const N := 24


func _init() -> void:
	var fg := _foreground()
	var bg := _background()
	var full := bg.duplicate()
	full.blend_rect(fg, Rect2i(0, 0, N, N), Vector2i.ZERO)
	_save(_scale(fg, 18), "adaptive_foreground_432.png")
	_save(_scale(bg, 18), "adaptive_background_432.png")
	_save(_scale(full, 8), "icon_192.png")
	var store := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	store.fill(PixelArt.C["bg"])
	store.blit_rect(_scale(full, 21), Rect2i(0, 0, 504, 504), Vector2i(4, 4))
	_save(store, "icon_512.png")
	# заставка: манометр с трубами покрупнее на прозрачном фоне (фон задаёт проект)
	_save(_scale(fg, 12), "splash.png")
	print("icons: ok")
	quit(0)


func _scale(im: Image, k: int) -> Image:
	var c := im.duplicate()
	c.resize(im.get_width() * k, im.get_height() * k, Image.INTERPOLATE_NEAREST)
	return c


func _save(im: Image, name: String) -> void:
	im.save_png("res://assets/icons/" + name)


func _tex_img(t: Texture2D) -> Image:
	return t.get_image()


## Передний план: медная труба слева и справа, в центре манометр со стрелкой.
## Манометр 16×16 занимает центральные 2/3 — безопасная зона адаптивной иконки.
func _foreground() -> Image:
	var im := Image.create(N, N, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var pipe := _tex_img(PixelArt.pipe(0b1010))
	var chan := _tex_img(PixelArt.channel(0b1010))
	var water: Color = PixelArt.water_color(0.9)
	# вода в канале
	for y in 16:
		for x in 16:
			if chan.get_pixel(x, y).a > 0.5:
				pipe.set_pixel(x, y, water)
	im.blend_rect(pipe, Rect2i(0, 0, 8, 16), Vector2i(0, 4))
	im.blend_rect(pipe, Rect2i(8, 0, 8, 16), Vector2i(16, 4))
	var gauge := _tex_img(PixelArt.gauge("ok"))
	im.blend_rect(gauge, Rect2i(0, 0, 16, 16), Vector2i(4, 4))
	# стрелка давления: из центра вверх-вправо
	var needle := Color("e4573d")
	for p in [Vector2i(11, 12), Vector2i(12, 11), Vector2i(13, 10), Vector2i(14, 9), Vector2i(12, 12)]:
		im.set_pixel(p.x, p.y, needle)
	im.set_pixel(11, 11, Color("2a1f1d"))
	return im


## Фон: ночной кафель ванной, приглушённый.
func _background() -> Image:
	var im := Image.create(N, N, false, Image.FORMAT_RGBA8)
	im.fill(PixelArt.C["bg"])
	var tile := _tex_img(Themes.floor_tile("bathroom", false))
	for ty in 2:
		for tx in 2:
			for y in 16:
				for x in 16:
					var px := tx * 16 + x - 4
					var py := ty * 16 + y - 4
					if px >= 0 and py >= 0 and px < N and py < N:
						var c := tile.get_pixel(x, y)
						im.set_pixel(px, py, c.darkened(0.55))
	return im
