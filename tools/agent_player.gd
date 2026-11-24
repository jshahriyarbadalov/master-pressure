## Агент-игрок (T-09), headless:
##   godot --headless -s tools/agent_player.gd -- --in a.jsonl,b.jsonl --out results.jsonl [--runs 3] [--max-moves 1500] [--from 0 --to 100]
## Для каждого уровня:
##  1) независимая перепроверка: задуманное решение выигрывает, старт не решён,
##     решатель (заново, с нуля) находит ≥ 1 решения и не упирается в лимит;
##  2) признаки и оценка сложности (difficulty.gd);
##  3) «человекоподобный» бот играет runs раз: доля решённых, медиана касаний.
extends SceneTree

const PressureLevel = preload("res://game/logic/pressure_level.gd")
const PressureEval = preload("res://game/logic/pressure_eval.gd")
const PressureSolver = preload("res://game/logic/pressure_solver.gd")
const Difficulty = preload("res://game/logic/difficulty.gd")
const BotPlayer = preload("res://game/logic/bot_player.gd")
const JsonIo = preload("res://addons/master_core/level/json_io.gd")


func _init() -> void:
	var a := _args()
	var runs := int(a.get("runs", 3))
	var bot = BotPlayer.new()
	bot.max_moves = int(a.get("max-moves", 600))
	var levels := []
	for path in String(a["in"]).split(","):
		for d in JsonIo.read_lines(path):
			levels.append(d)
	var lo := int(a.get("from", 0))
	var hi := mini(int(a.get("to", levels.size())), levels.size())
	var out := []
	var t0 := Time.get_ticks_msec()
	var bad := 0
	for idx in range(lo, hi):
		var d: Dictionary = levels[idx]
		var lv = PressureLevel.from_dict(d)
		var sol_ok: bool = PressureEval.evaluate(lv, lv.masks_for(lv.solution))["win"]
		var start_ok: bool = not PressureEval.evaluate(lv, lv.masks())["win"]
		var cw := PressureSolver.count_winners(lv, 2000000)
		var solver_ok: bool = int(cw["winners"]) >= 1 and not cw["aborted"]
		# найденные решателем решения должны действительно выигрывать
		for rots in cw["winner_rots"]:
			if not PressureEval.evaluate(lv, lv.masks_for(rots))["win"]:
				solver_ok = false
		var verified := sol_ok and start_ok and solver_ok
		if not verified:
			bad += 1
		var f := Difficulty.annotate(lv)
		var moves := []
		var solved := 0
		for k in runs:
			var res: Dictionary = bot.play(lv, int(lv.meta.get("seed", idx)) * 31 + k)
			moves.append(int(res["moves"]))
			if res["solved"]:
				solved += 1
		moves.sort()
		out.append({
			"idx": idx, "size": "%dx%d" % [lv.w, lv.h], "seed": lv.meta.get("seed", -1),
			"verified": verified, "sol_ok": sol_ok, "start_ok": start_ok, "solver_ok": solver_ok,
			"winners": cw["winners"], "solver_nodes": cw["nodes"],
			"bot_solved": solved, "bot_runs": runs, "bot_moves_median": moves[moves.size() / 2],
			"features": f,
		})
	if a.has("out"):
		JsonIo.write_lines(String(a["out"]), out, a.has("append"))
	print("agent: levels=%d verified_fail=%d time=%.1fs" % [out.size(), bad, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if bad > 0 else 0)


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
