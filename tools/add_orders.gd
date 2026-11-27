## Добавить заказы к уровням пака (T-17), headless:
##   godot --headless -s tools/add_orders.gd -- --pack levels/packs/proto.json
## Заказ детерминирован: seed уровня → SeededRng → Order.make.
extends SceneTree

const JsonIo = preload("res://addons/master_core/level/json_io.gd")
const PressureLevel = preload("res://game/logic/pressure_level.gd")
const SeededRng = preload("res://addons/master_core/rng/seeded_rng.gd")
const Order = preload("res://game/logic/order.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := String(args[1]) if args.size() > 1 else "res://levels/packs/proto.json"
	var pack: Dictionary = JsonIo.ints(JsonIo.read(path))
	var out := []
	var hard := 0
	for d in pack["levels"]:
		var lv = PressureLevel.from_dict(d)
		lv.order = Order.make(lv, SeededRng.new(int(lv.meta.get("seed", 1)) ^ 0x4F52))
		if lv.order.has("hard"):
			hard += 1
		out.append(lv.to_dict())
	pack["levels"] = out
	JsonIo.write(path, JsonIo.ints(pack), " ")
	print("orders: %d уровней, с жёстким условием %d" % [out.size(), hard])
	quit(0)
