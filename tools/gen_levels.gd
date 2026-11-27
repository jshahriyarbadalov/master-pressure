## Генерация пачки уровней (headless):
##   godot --headless -s tools/gen_levels.gd -- --size 5x5 --taps 2 --count 100 --seed 1 --out levels/gen/5x5.jsonl [--slack 0] [--append]
## Пишет JSON Lines (уровень на строку) и печатает сводку.
extends SceneTree

const PressureGenerator = preload("res://game/logic/pressure_generator.gd")
const JsonIo = preload("res://addons/master_core/level/json_io.gd")


func _init() -> void:
	var a := _args()
	var wh: PackedStringArray = String(a.get("size", "5x5")).split("x")
	var params := {"w": int(wh[0]), "h": int(wh[1]), "taps": int(a.get("taps", 2)), "slack": int(a.get("slack", 0))}
	for k in ["max_winners", "solver_nodes", "all_nodes", "L"]:
		if a.has(k):
			params[k] = int(a[k])
	for k in ["loop_prob", "decoy_prob"]:
		if a.has(k):
			params[k] = float(a[k])
	var count := int(a.get("count", 10))
	var seed0 := int(a.get("seed", 1))
	var out := String(a.get("out", ""))
	var gen = PressureGenerator.new(params)
	var levels := []
	var failed := 0
	var rejected := {}
	var attempts := 0
	var t0 := Time.get_ticks_msec()
	var max_ms := 0
	for k in count:
		var ts := Time.get_ticks_msec()
		var lv = gen.generate(seed0 + k)
		var dt := Time.get_ticks_msec() - ts
		max_ms = maxi(max_ms, dt)
		attempts += int(gen.stats["attempts"])
		for r in gen.stats["rejected"]:
			rejected[r] = int(rejected.get(r, 0)) + int(gen.stats["rejected"][r])
		if lv == null:
			failed += 1
			continue
		levels.append(lv.to_dict())
	var total := Time.get_ticks_msec() - t0
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		JsonIo.write_lines(out, levels, a.has("append"))
	print("size=%s taps=%d: ok=%d failed=%d attempts=%d total=%.1fs avg=%dms max=%dms" % [a.get("size", "5x5"), params["taps"], levels.size(), failed, attempts, total / 1000.0, total / maxi(1, count), max_ms])
	print("rejected: ", rejected)
	quit(0)


func _args() -> Dictionary:
	var d := {}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var key: String = args[i].trim_prefix("--")
		if i + 1 < args.size() and not args[i + 1].begins_with("--"):
			d[key] = args[i + 1]
			i += 2
		else:
			d[key] = true
			i += 1
	return d
