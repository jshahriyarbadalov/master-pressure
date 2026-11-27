extends "res://tests/test_case.gd"

const PressureLevel = preload("res://game/logic/pressure_level.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")
const BotPlayer = preload("res://game/logic/bot_player.gd")
const PressureGenerator = preload("res://game/logic/pressure_generator.gd")


func test_bot_solves_examples() -> bool:
	var ex: Array = load_json("res://tests/fixtures/examples.json")
	var bot = BotPlayer.new()
	for e in ex:
		var lv = PressureLevel.from_dict(e["level"])
		check(not PressureEval.evaluate(lv, lv.masks())["win"], e["name"] + ": старт не решён")
		var solved := 0
		for s in 3:
			if bot.play(lv, s)["solved"]:
				solved += 1
		check(solved >= 2, "%s: бот решил %d из 3" % [e["name"], solved])
	return ok()


func test_bot_deterministic_and_pure() -> bool:
	var lv = PressureGenerator.new({"w": 5, "h": 5, "taps": 2}).generate(31)
	var before: Dictionary = lv.to_dict()
	var bot = BotPlayer.new()
	var a: Dictionary = bot.play(lv, 7)
	var b: Dictionary = bot.play(lv, 7)
	check_eq(str(a), str(b), "один seed — одна партия")
	check_eq(JSON.stringify(lv.to_dict()), JSON.stringify(before), "бот не меняет исходный уровень")
	return ok()
