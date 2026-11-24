## Сборка пака уровней для прототипа (T-12), headless:
##   godot --headless -s tools/make_pack.gd -- --levels a.jsonl,b.jsonl --results agent.jsonl --out levels/packs/proto.json [--per-size 6]
## Берёт уровни, перепроверенные агентом, по размерам от меньшего к большему;
## внутри размера — по возрастанию оценки сложности (квантили 10%..95%).
## Ранние уровни — только те, что бот решил во всех партиях.
## Добавляет 2–3 «сюрприза»: ВСЕ решения с протечкой, хотя сеть без протечек,
## соединяющая все краны, существует (но по напору не проходит), и бот
## тратит на уровень хотя бы 20 касаний.
extends SceneTree

const JsonIo = preload("res://addons/master_core/level/json_io.gd")
const PressureLevel = preload("res://game/logic/pressure_level.gd")
const PressureSolver = preload("res://game/logic/pressure_solver.gd")

const SIZE_ORDER := ["5x5", "6x6", "6x7", "7x8", "7x9"]
const QUANTILES := [0.10, 0.30, 0.50, 0.70, 0.85, 0.95]


func _init() -> void:
	var a := _args()
	var by_key := {}
	for path in String(a["levels"]).split(","):
		for d in JsonIo.read_lines(path):
			by_key["%dx%d:%d" % [int(d["w"]), int(d["h"]), int(d["meta"]["seed"])]] = d
	var results := []
	for path in String(a["results"]).split(","):
		results.append_array(JsonIo.read_lines(path))
	var per_size := int(a.get("per-size", 6))
	var pack := []
	var surprises := 0
	for s in SIZE_ORDER:
		var group := []
		for r in results:
			if r["size"] == s and r["verified"] and by_key.has("%s:%d" % [s, int(r["seed"])]):
				group.append(r)
		if group.is_empty():
			continue
		group.sort_custom(func(x, y): return float(x["features"]["score"]) < float(y["features"]["score"]))
		var picked := {}
		for qi in per_size:
			var q: float = QUANTILES[qi % QUANTILES.size()]
			var k := clampi(int(q * group.size()), 0, group.size() - 1)
			# ищем ближайший подходящий: на 5×5 — решённый ботом во всех партиях
			for off in group.size():
				var cand_i := k + (off / 2 if off % 2 == 0 else -(off + 1) / 2)
				if cand_i < 0 or cand_i >= group.size() or picked.has(cand_i):
					continue
				var c: Dictionary = group[cand_i]
				if s == "5x5" and int(c["bot_solved"]) < int(c["bot_runs"]):
					continue
				picked[cand_i] = true
				break
		# сюрприз: на средних и больших размерах заменить один уровень на «с протечкой в решении»
		if s in ["6x7", "7x8", "7x9"] and surprises < 3:
			var keys := picked.keys()
			keys.sort()
			var replace_at: int = keys[keys.size() / 2]
			var found := -1
			var order := range(group.size())
			order.sort_custom(func(x, y): return absi(x - replace_at) < absi(y - replace_at))
			var checked := 0
			for gi in order:
				if picked.has(gi) or int(group[gi]["features"]["solution_leaks"]) == 0 or int(group[gi]["bot_moves_median"]) < 20:
					continue
				checked += 1
				if checked > 25:
					break
				if _is_surprise(by_key["%s:%d" % [s, int(group[gi]["seed"])]]):
					found = gi
					break
			if found >= 0:
				picked.erase(replace_at)
				picked[found] = true
				group[found]["surprise"] = true
				surprises += 1
		var idxs := picked.keys()
		idxs.sort()
		for gi in idxs:
			var r: Dictionary = group[gi]
			var d: Dictionary = by_key["%s:%d" % [s, int(r["seed"])]].duplicate(true)
			d["meta"]["difficulty"] = r["features"]
			d["meta"]["bot_moves_median"] = r["bot_moves_median"]
			d["meta"]["bot_solved"] = "%d/%d" % [int(r["bot_solved"]), int(r["bot_runs"])]
			if r.get("surprise", false):
				d["meta"]["surprise"] = true
			pack.append(d)
	var out := {"name": "proto", "version": 1, "levels": _ints(pack)}
	DirAccess.make_dir_recursive_absolute(String(a["out"]).get_base_dir())
	JsonIo.write(String(a["out"]), out, " ")
	print("pack: %d уровней, сюрпризов %d" % [pack.size(), surprises])
	quit(0)


## JSON-парсер Godot возвращает все числа как float; целые возвращаем в int,
## чтобы в паке было «5», а не «5.0».
func _ints(x: Variant) -> Variant:
	if x is float and x == floorf(x) and absf(x) < 1e15:
		return int(x)
	if x is Array:
		var out := []
		for v in x:
			out.append(_ints(v))
		return out
	if x is Dictionary:
		var out := {}
		for k in x:
			out[k] = _ints(x[k])
		return out
	return x


## Сюрприз: решения есть только с протечкой, а сеть без протечек соединяет,
## но не проходит по напору.
func _is_surprise(d: Dictionary) -> bool:
	var lv = PressureLevel.from_dict(d)
	var w := PressureSolver.new(lv)
	w.node_limit = 300000
	w.solve()
	if w.aborted or w.winners == 0 or w.winners_watertight > 0:
		return false
	var all := PressureSolver.new(lv)
	all.use_bound = false
	all.node_limit = 30000
	all.solve()
	return all.connecting_watertight > 0


func _args() -> Dictionary:
	var d := {}
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size() - 1, 2):
		d[args[i].trim_prefix("--")] = args[i + 1]
	return d
