## Меню игры: главный экран, список заказов, настройки.
## Поверх игрового экрана (main.gd). Кнопки — в нижней части экрана
## (правило одной руки); список заказов, как и поле, — в нижних двух третях.
extends Control

signal play_requested(index: int)
signal settings_changed

const PixelArt = preload("res://game/ui/pixel_art.gd")
const Themes = preload("res://game/ui/themes.gd")

const TILE := 112.0
const COLS := 5

var game = null  ## main.gd — источник прогресса и настроек
var screen := "home"
var _confirm_reset := false
var _buttons: Array[Button] = []
var _tiles: Array[Button] = []
var _t0 := 0.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(p_screen: String = "home") -> void:
	screen = p_screen
	_confirm_reset = false
	visible = true
	_t0 = Time.get_ticks_msec() / 1000.0
	_rebuild()


func close() -> void:
	visible = false


func _process(_d: float) -> void:
	if visible and screen == "home":
		queue_redraw()  # вода в трубе заголовка течёт


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_rebuild()


func _clear() -> void:
	for b in _buttons:
		b.queue_free()
	for t in _tiles:
		t.queue_free()
	_buttons.clear()
	_tiles.clear()


func _button(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 34)
	var st := PixelArt.button_styles()
	if primary:
		st["normal"] = st["normal"].duplicate()
		st["normal"].bg_color = Color("3a5f3f")
		st["hover"] = st["normal"]
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_color_override("font_color", PixelArt.C["text"])
	b.add_theme_color_override("font_disabled_color", PixelArt.C["text_dim"])
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	add_child(b)
	_buttons.append(b)
	return b


## Кнопки столбиком снизу вверх: последняя в списке — у самого низа.
func _stack(buttons: Array) -> void:
	var h := 110.0
	var pad := 16.0
	var y := size.y - pad - h
	for k in range(buttons.size() - 1, -1, -1):
		var b: Button = buttons[k]
		b.position = Vector2(pad, y)
		b.size = Vector2(size.x - pad * 2, h)
		y -= h + pad


func _rebuild() -> void:
	_clear()
	if game == null or size.x < 100:
		return
	match screen:
		"home": _build_home()
		"orders": _build_orders()
		"settings": _build_settings()
		"howto": _build_howto()
	queue_redraw()


func _build_home() -> void:
	var next: int = game.next_unsolved()
	var cont := _button("Продолжить · заказ %d" % (next + 1), func(): play_requested.emit(next), true)
	var orders := _button("Заказы", func(): open("orders"))
	var sett := _button("Настройки", func(): open("settings"))
	_stack([cont, orders, sett])


func _build_orders() -> void:
	var n: int = game.levels.size()
	var unlocked: int = game.unlocked_count()
	var gap := 10.0
	var tile := minf(TILE, (size.x - gap * (COLS + 1)) / COLS)
	var rows := ceili(float(n) / COLS)
	var grid_w := COLS * tile + (COLS - 1) * gap
	var left := (size.x - grid_w) / 2.0
	var top := size.y / 3.0  # сетка — в нижних двух третях, над кнопкой «Назад»
	for i in n:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(left + (i % COLS) * (tile + gap), top + (i / COLS) * (tile + gap))
		b.size = Vector2(tile, tile)
		# кнопка только ловит касание; плитку рисует _draw_tiles
		for k in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
		b.disabled = i >= unlocked
		var idx := i
		b.pressed.connect(func(): play_requested.emit(idx))
		add_child(b)
		_tiles.append(b)
	var back := _button("Назад", func(): open("home"))
	_stack([back])


func _build_settings() -> void:
	var s: Dictionary = game.settings
	var snd := _button("Звук: " + ("вкл" if s["sound"] else "выкл"), func(): _toggle("sound"))
	var vib := _button("Вибрация: " + ("вкл" if s["vibration"] else "выкл"), func(): _toggle("vibration"))
	var hand := _button("Рука: " + ("левая" if s["left_hand"] else "правая"), func(): _toggle("left_hand"))
	var how := _button("Как играть", func(): open("howto"))
	var reset := _button("Сбросить прогресс" if not _confirm_reset else "Точно сбросить? Нажми ещё раз", _reset)
	var back := _button("Назад", func(): open("home"))
	_stack([snd, vib, hand, how, reset, back])


## «Как играть»: показывается при первом запуске и из настроек.
func _build_howto() -> void:
	var ok := _button("Понятно", _howto_done, true)
	_stack([ok])


func _howto_done() -> void:
	var first: bool = not game.settings.get("seen_howto", false)
	game.settings["seen_howto"] = true
	game.save_progress()
	if first:
		play_requested.emit(game.next_unsolved())
	else:
		open("settings")


func _toggle(key: String) -> void:
	game.settings[key] = not game.settings[key]
	game.apply_settings()
	game.save_progress()
	settings_changed.emit()
	_rebuild()


func _reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_rebuild()
		return
	game.reset_progress()
	open("home")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PixelArt.C["bg"])
	if game == null:
		return
	var font := get_theme_default_font()
	match screen:
		"home":
			_draw_title(font)
		"orders":
			_draw_header(font, "Заказы", "выполнено %d из %d" % [game.solved_count(), game.levels.size()])
			_draw_tiles(font)
		"settings":
			_draw_header(font, "Настройки", "")
		"howto":
			_draw_howto(font)


func _draw_header(font: Font, title: String, sub: String) -> void:
	draw_string(font, Vector2(32, 90), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, PixelArt.C["text"])
	if sub != "":
		draw_string(font, Vector2(32, 140), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, PixelArt.C["text_dim"])
	_draw_wallet(font)


func _draw_wallet(font: Font) -> void:
	var txt := "%d ₼" % int(game.money)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_texture_rect(Themes.small("coin"), Rect2(size.x - w - 76, 40, 32, 32), false)
	draw_string(font, Vector2(size.x - w - 32, 68), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, PixelArt.C["text"])


## Заголовок: «ДАВЛЕНИЕ» и труба, по которой бежит вода.
func _draw_title(font: Font) -> void:
	_draw_wallet(font)
	var title := "ДАВЛЕНИЕ"
	var fs := 92
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty := size.y * 0.22
	draw_string(font, Vector2((size.x - tw) / 2 + 5, ty + 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PixelArt.C["pipe_dark"])
	draw_string(font, Vector2((size.x - tw) / 2, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PixelArt.C["copper_ui"])
	var sub := "мастер по вызову"
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	draw_string(font, Vector2((size.x - sw) / 2, ty + 56), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, PixelArt.C["text_dim"])
	# труба через весь экран: бак → прямые → кран-манометр
	var cell := 80.0
	var y := size.y * 0.34
	var count := int(size.x / cell)
	var x0 := (size.x - count * cell) / 2
	var t := Time.get_ticks_msec() / 1000.0
	for k in count:
		var r := Rect2(x0 + k * cell, y, cell, cell)
		if k == 0:
			draw_texture_rect(PixelArt.pipe(0b0010), r, false)
			draw_texture_rect(PixelArt.channel(0b0010), r, false, PixelArt.water_color(1.0))
			draw_texture_rect(PixelArt.tank(), r, false)
		elif k == count - 1:
			draw_texture_rect(PixelArt.gauge("ok"), r, false)
		else:
			draw_texture_rect(PixelArt.pipe(0b1010), r, false)
			var wave := 0.82 + 0.18 * sin(t * 6.0 - k * 0.9)
			var c := PixelArt.water_color(1.0 - float(k) / count)
			draw_texture_rect(PixelArt.channel(0b1010), r, false, Color(c.r * wave, c.g * wave, c.b * wave))
	var done := "выполнено заказов: %d из %d" % [game.solved_count(), game.levels.size()]
	var dw := font.get_string_size(done, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_string(font, Vector2((size.x - dw) / 2, y + cell + 60), done, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, PixelArt.C["text_dim"])


## Плитки заказов: номер, иконка помещения, отметка ✓ / ★ / замок.
func _draw_tiles(font: Font) -> void:
	for i in _tiles.size():
		var b := _tiles[i]
		var r := Rect2(b.position, b.size)
		var room: String = game.room_of(i)
		var locked := b.disabled
		var status0: int = game.level_status(i)
		var border := Color("f2c14e") if status0 == 2 else (Color("57c785") if status0 == 1 else Color("3a4256"))
		draw_rect(r, border)
		draw_texture_rect(Themes.floor_tile(room, false), r.grow(-4), false, Color(1, 1, 1, 0.35) if locked else Color(0.85, 0.85, 0.85))
		var icon_col := Color(1, 1, 1, 0.35) if locked else Color.WHITE
		draw_texture_rect(Themes.icon(room), Rect2(r.position + Vector2(r.size.x * 0.25, r.size.y * 0.12), r.size * 0.5), false, icon_col)
		var num := str(i + 1)
		draw_string(font, r.position + Vector2(10, r.size.y - 12), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, PixelArt.C["text"] if not locked else PixelArt.C["text_dim"])
		var status: int = game.level_status(i)
		if status >= 1:
			draw_string(font, r.position + Vector2(r.size.x - 34, r.size.y - 12), "✓" if status == 1 else "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("57c785") if status == 1 else Color("f2c14e"))
		elif locked:
			draw_rect(Rect2(r.position + Vector2(r.size.x - 34, r.size.y - 36), Vector2(20, 16)), PixelArt.C["text_dim"])
			draw_arc(r.position + Vector2(r.size.x - 24, r.size.y - 38), 7, PI, TAU, 8, PixelArt.C["text_dim"], 3)


const HOWTO := [
	["tank_pipe_gauge", "Крути трубы касанием — доведи воду от бака до всех кранов."],
	["corner", "Каждая труба отнимает 1 напора, поворот воды — ещё 1, развилка — ещё 1."],
	["gauge", "На кране «есть / нужно». Зелёный — напора хватает, оранжевый — мало."],
	["drop", "Протечка снижает напор всей сети на 2. Закрывай лишние концы труб."],
	["star", "Выполни условие клиента и уложись в повороты — получишь премию."],
]


func _draw_howto(font: Font) -> void:
	draw_string(font, Vector2(32, 90), "Как играть", HORIZONTAL_ALIGNMENT_LEFT, -1, 56, PixelArt.C["text"])
	var y := 150.0
	var row := 150.0
	for item in HOWTO:
		var pic: String = item[0]
		var r := Rect2(32, y + 10, 96, 96)
		match pic:
			"tank_pipe_gauge":
				var s3 := 48.0
				var rr := Rect2(24, y + 34, s3, s3)
				draw_texture_rect(PixelArt.pipe(0b0010), rr, false)
				draw_texture_rect(PixelArt.channel(0b0010), rr, false, PixelArt.water_color(1.0))
				draw_texture_rect(PixelArt.tank(), rr, false)
				rr.position.x += s3
				draw_texture_rect(PixelArt.pipe(0b1010), rr, false)
				draw_texture_rect(PixelArt.channel(0b1010), rr, false, PixelArt.water_color(0.7))
				rr.position.x += s3
				draw_texture_rect(PixelArt.gauge("ok"), rr, false)
			"corner":
				draw_texture_rect(PixelArt.pipe(0b0110), r, false)
				draw_texture_rect(PixelArt.channel(0b0110), r, false, PixelArt.water_color(0.5))
			"gauge":
				draw_texture_rect(PixelArt.gauge("ok"), r, false)
				var t := "3/2"
				var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
				draw_string(font, r.get_center() + Vector2(-tw / 2, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("2a1f1d"))
			"drop":
				draw_texture_rect(PixelArt.pipe(0b0101), r, false)
				draw_texture_rect(PixelArt.drop(), Rect2(r.get_center() + Vector2(-12, -64), Vector2(24, 30)), false)
			"star":
				draw_texture_rect(Themes.small("star"), Rect2(r.position + Vector2(16, 16), Vector2(64, 64)), false)
		var tx := 176.0 if pic != "tank_pipe_gauge" else 176.0
		draw_multiline_string(font, Vector2(tx, y + 50), item[1], HORIZONTAL_ALIGNMENT_LEFT, size.x - tx - 32, 28, 3, PixelArt.C["text"])
		y += row
