## Скриншот экрана игры (нужен дисплей, например xvfb-run):
##   xvfb-run -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 --resolution 720x1280 -s tools/screenshot.gd -- --out shot.png [--level N] [--solve K]
## --solve K — докрутить первые K поворачиваемых клеток до решения (показать воду).
extends SceneTree

var main: Control
var frames := 0
var out := "shot.png"
var series := 0       ## --frames N: снять N кадров (out_000.png …) для GIF
var every := 3        ## --every K: каждый K-й кадр
var taps := []        ## --taps "i,j,k": касания по ходу съёмки (для анимации поворота)


func _initialize() -> void:
	var a := {}
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size() - 1, 2):
		a[args[i].trim_prefix("--")] = args[i + 1]
	out = a.get("out", out)
	series = int(a.get("frames", 0))
	every = int(a.get("every", 3))
	if a.has("taps"):
		for t in String(a["taps"]).split(","):
			taps.append(int(t))
	main = load("res://game/ui/main.tscn").instantiate()
	root.add_child(main)
	if main.board == null:
		main._ready()
	if a.has("level"):
		main.index = int(a["level"])
		main._load_current()
	if a.has("almost"):
		# решить заказ, кроме последнего касания — его сделаем в кадре (видно пружинку и победу)
		var Order2 = load("res://game/logic/order.gd")
		var sols2: Array = Order2.analyze(main.level)
		var plan2: PackedByteArray = sols2[0]["plan"]
		var lv2 = main.level
		var need := []
		for i in lv2.w * lv2.h:
			if lv2.is_rotatable(i):
				for k in (plan2[i] - lv2.rots[i]) & 3:
					need.append(i)
		for k in need.size() - 1:
			main.tap_cell(need[k])
		taps = [need[need.size() - 1]]
	if a.has("win"):
		# докрутить до ближайшего решения заказа (минимум касаний)
		var Order = load("res://game/logic/order.gd")
		var sols: Array = Order.analyze(main.level)
		if not sols.is_empty():
			var plan: PackedByteArray = sols[0]["plan"]
			var lvw = main.level
			for i in lvw.w * lvw.h:
				var guard := 0
				while lvw.is_rotatable(i) and lvw.rots[i] != plan[i] and guard < 4 and not main.won:
					main.tap_cell(i)
					guard += 1
	if a.has("solve"):
		var k := int(a["solve"])
		var lv = main.level
		for i in lv.w * lv.h:
			if k <= 0:
				break
			if lv.is_rotatable(i) and lv.rots[i] != lv.solution[i]:
				var guard := 0
				while lv.rots[i] != lv.solution[i] and guard < 4:
					main.tap_cell(i)
					guard += 1
				k -= 1


func _process(_delta: float) -> bool:
	frames += 1
	if series > 0:
		var k := frames - 5
		if k >= 0 and k % every == 0:
			var n := k / every
			if n < taps.size() * 0 + 1000 and taps.size() > 0 and n % 6 == 0 and n / 6 < taps.size():
				main.tap_cell(taps[n / 6])
			root.get_texture().get_image().save_png(out.get_basename() + "_%03d.png" % n)
			if n + 1 >= series:
				print("saved %d frames" % series)
				return true
		return false
	if frames == 5:
		var img := root.get_texture().get_image()
		img.save_png(out)
		print("saved ", out, " ", img.get_size())
		return true
	return false
