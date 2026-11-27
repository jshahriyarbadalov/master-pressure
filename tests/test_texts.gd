extends "res://tests/test_case.gd"

const OrderTexts = preload("res://game/logic/order_texts.gd")

const MAX_LINE := 60  ## длинная реплика не влезет в верхнюю треть экрана


func test_texts_complete() -> bool:
	var t = OrderTexts.new("ru")
	var ids := {}
	for c in t.data["clients"]:
		for k in ["id", "name", "place", "complaint", "thanks"]:
			check(c.has(k) and String(c[k]).strip_edges() != "", "клиент %s: поле %s" % [str(c.get("id")), k])
		check(not ids.has(c["id"]), "повтор id %s" % c["id"])
		ids[c["id"]] = true
		check(String(c["complaint"]).length() <= MAX_LINE, "жалоба длинная: %s" % c["id"])
		check(String(c["thanks"]).length() <= MAX_LINE, "благодарность длинная: %s" % c["id"])
	check(ids.size() >= 30, "клиентов не меньше 30")
	for s in t.data["hard"]["max_tees"]:
		check(String(s).contains("{n}"), "в условии про развилки есть {n}: " + s)
	for s in t.data["bonus"]:
		check(String(s).contains("{n}"), "в бонусе есть {n}: " + s)
	return ok()


func test_texts_for_order() -> bool:
	var t = OrderTexts.new("ru")
	var order := {"client_id": 1234, "hard": {"type": "max_tees", "n": 2}, "bonus": {"type": "max_moves", "n": 11}, "pay": 50}
	check(t.hard_text(order).contains("2"), "условие подставило n")
	check(t.bonus_text(order).contains("11"), "бонус подставил n")
	check_eq(t.client(order)["id"], t.client(order.duplicate())["id"], "клиент детерминирован")
	check_eq(t.hard_text({"client_id": 1}), "", "без условия — пусто")
	check(t.ui("pay", {"pay": 50}).contains("50"), "строка интерфейса")
	return ok()
