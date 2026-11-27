## Скриншот экрана игры (нужен дисплей, например xvfb-run):
##   xvfb-run -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 --resolution 720x1280 -s tools/screenshot.gd -- --out shot.png [--level N] [--solve K]
## --solve K — докрутить первые K поворачиваемых клеток до решения (показать воду).
extends SceneTree

var main: Control
var frames := 0
var out := "shot.png"


func _initialize() -> void:
	var a := {}
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size() - 1, 2):
		a[args[i].trim_prefix("--")] = args[i + 1]
	out = a.get("out", out)
	main = load("res://game/ui/main.tscn").instantiate()
	root.add_child(main)
	if main.board == null:
		main._ready()
	if a.has("level"):
		main.index = int(a["level"])
		main._load_current()
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
	if frames == 5:
		var img := root.get_texture().get_image()
		img.save_png(out)
		print("saved ", out, " ", img.get_size())
		return true
	return false
