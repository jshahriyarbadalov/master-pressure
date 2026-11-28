## Добавить заказы к уровням пака (T-17), headless:
##   godot --headless -s tools/add_orders.gd -- --pack levels/packs/proto.json
## Заказ детерминирован: seed уровня → SeededRng → Order.make.
extends SceneTree

const JsonIo = preload("res://addons/master_core/level/json_io.gd")
const PressureLevel = preload("res://game/logic/pressure_level.gd")
const SeededRng = preload("res://addons/master_core/rng/seeded_rng.gd")
const Order = preload("res://game/logic/order.gd")
const OrderTexts = preload("res://game/logic/order_texts.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := String(args[1]) if args.size() > 1 else "res://levels/packs/proto.json"
	var pack: Dictionary = JsonIo.ints(JsonIo.read(path))
	var out := []
	var hard := 0
	var clients: Array = OrderTexts.new("ru").data["clients"]
	var order_of := _client_order(clients, SeededRng.new(0x434C))
	var k := 0
	for d in pack["levels"]:
		var lv = PressureLevel.from_dict(d)
		if lv.order.is_empty():
			lv.order = Order.make(lv, SeededRng.new(int(lv.meta.get("seed", 1)) ^ 0x4F52))
		else:
			lv.order["pay"] = Order.pay_for(lv)  # заказ из генератора; оплата — по сложности
		# клиент: каждый по разу, соседние уровни — в разных помещениях
		var cid: int = int(lv.order["client_id"])
		lv.order["client_id"] = cid - cid % clients.size() + int(order_of[k % order_of.size()])
		k += 1
		if lv.order.has("hard"):
			hard += 1
		out.append(lv.to_dict())
	pack["levels"] = out
	var rooms := []
	for d in out:
		rooms.append(clients[int(d["order"]["client_id"]) % clients.size()]["theme"])
	print("помещения по уровням: ", ", ".join(rooms))
	JsonIo.write(path, JsonIo.ints(pack), " ")
	print("orders: %d уровней, с жёстким условием %d" % [out.size(), hard])
	quit(0)


## Порядок клиентов: перестановка всех клиентов, где у соседей разные помещения.
func _client_order(clients: Array, rng) -> Array:
	for attempt in 200:
		var idx := range(clients.size())
		rng.shuffle(idx)
		var ok := true
		for i in range(1, idx.size()):
			if clients[idx[i]]["theme"] == clients[idx[i - 1]]["theme"]:
				ok = false
				break
		if ok:
			return idx
	return range(clients.size())
