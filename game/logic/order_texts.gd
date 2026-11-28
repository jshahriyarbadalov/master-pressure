## Тексты заказа (клиенты, условия, бонус) из data/texts/clients_<lang>.json.
## Выбор детерминирован по client_id: один и тот же заказ — один и тот же клиент
## и одни и те же фразы на любом устройстве.
extends RefCounted

const JsonIo = preload("res://addons/master_core/level/json_io.gd")

var data := {}


func _init(lang: String = "ru") -> void:
	data = JsonIo.read("res://data/texts/clients_%s.json" % lang)


func client(order: Dictionary) -> Dictionary:
	var cl: Array = data["clients"]
	return cl[int(order.get("client_id", 0)) % cl.size()]


func _variant(list: Array, order: Dictionary, salt: int) -> String:
	return list[(int(order.get("client_id", 0)) / 7 + salt) % list.size()]


## Фраза жёсткого условия или "" если его нет.
func hard_text(order: Dictionary) -> String:
	if not order.has("hard"):
		return ""
	var h: Dictionary = order["hard"]
	var t := _variant(data["hard"][h["type"]], order, 0)
	return t.format({"n": h.get("n", "")})


func bonus_text(order: Dictionary) -> String:
	if not order.has("bonus"):
		return ""
	return _variant(data["bonus"], order, 1).format({"n": order["bonus"]["n"]})


## Короткий счётчик условия для плашки: «труб 7/6».
func measure_text(m: Dictionary) -> String:
	if m.is_empty():
		return ""
	return String(data["ui"]["measure"][m["type"]]).format({"v": m["value"], "n": m["n"]})


## Реплика при победе без выполненного условия — с конкретными числами.
func fail_text(m: Dictionary) -> String:
	var what := String(data["ui"]["fail_what"][m["type"]]).format({"v": m["value"], "n": m["n"]})
	return String(data["ui"]["hard_failed_detail"]).format({"what": what})


func ui(key: String, args: Dictionary = {}) -> String:
	return String(data["ui"][key]).format(args)
