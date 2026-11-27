## Отчёт по прогону агента (T-09), headless:
##   godot --headless -s tools/report.gd -- --in results.jsonl --md docs/reports/levels_1000.md --csv docs/reports/levels_1000.csv [--max-moves 600]
## Считает: перепроверку, сводку по размерам, распределение сложности (1..10 по
## децилям оценки), согласие оценки с ботом (Спирмен) и подбирает веса
## наименьшими квадратами по log(1 + касания бота).
extends SceneTree

const JsonIo = preload("res://addons/master_core/level/json_io.gd")
const Difficulty = preload("res://game/logic/difficulty.gd")

const FEATURES := ["wet_bits", "all_bits", "taps", "tight_taps", "solver_log", "solution_leaks", "loop", "pass_ratio"]


func _init() -> void:
	var a := _args()
	var rows: Array = []
	for path in String(a["in"]).split(","):
		rows.append_array(JsonIo.read_lines(path))
	var max_moves := int(a.get("max-moves", 600))
	var n := rows.size()

	# --- оценка → уровень 1..10 по децилям ---
	var scores := []
	for r in rows:
		scores.append(float(r["features"]["score"]))
	var sorted_scores := scores.duplicate()
	sorted_scores.sort()
	var cuts := []
	for k in range(1, 10):
		cuts.append(sorted_scores[int(k * n / 10.0)])
	for r in rows:
		var s := float(r["features"]["score"])
		var tier := 1
		for c in cuts:
			if s >= float(c):
				tier += 1
		r["tier"] = tier
		r["effort"] = float(r["bot_moves_median"]) if int(r["bot_solved"]) * 2 > int(r["bot_runs"]) else float(max_moves)

	# --- сводка по размерам ---
	var sizes := []
	var by := {}
	for r in rows:
		var s: String = r["size"]
		if not by.has(s):
			by[s] = []
			sizes.append(s)
		by[s].append(r)
	var md := PackedStringArray()
	md.append("# Отчёт: %d сгенерированных уровней «Давления»" % n)
	md.append("")
	md.append("Сгенерировано: %s. Правила v0 (L=2). Воспроизвести — команды внизу." % Time.get_date_string_from_system())
	md.append("")
	var verified := 0
	for r in rows:
		if r["verified"]:
			verified += 1
	md.append("**Решаемость:** %d из %d уровней перепроверены независимо (решение выигрывает, старт не решён, решатель заново нашёл решение и уложился в лимит). Провалов: %d." % [verified, n, n - verified])
	md.append("")
	md.append("## По размерам")
	md.append("")
	md.append("| Размер | Уровней | Оценка (медиана) | Бот решил | Касаний бота (медиана) | Узлов решателя (медиана) | С протечкой в решении | С кольцом | Решений (медиана) |")
	md.append("|---|---|---|---|---|---|---|---|---|")
	for s in sizes:
		var g: Array = by[s]
		var solved := 0
		var runs := 0
		var leaks := 0
		var loops := 0
		for r in g:
			solved += int(r["bot_solved"])
			runs += int(r["bot_runs"])
			if int(r["features"]["solution_leaks"]) > 0:
				leaks += 1
			if int(r["features"]["loop"]) > 0:
				loops += 1
		md.append("| %s | %d | %.1f | %d%% | %d | %d | %d%% | %d%% | %d |" % [s, g.size(), _median(g, func(r): return float(r["features"]["score"])),
			roundi(100.0 * solved / maxf(1, runs)), int(_median(g, func(r): return float(r["bot_moves_median"]))),
			int(_median(g, func(r): return float(r["solver_nodes"]))), roundi(100.0 * leaks / g.size()), roundi(100.0 * loops / g.size()),
			int(_median(g, func(r): return float(r["winners"])))])
	md.append("")

	# --- распределение уровней сложности ---
	md.append("## Распределение сложности (1..10 — децили оценки по всему набору)")
	md.append("")
	md.append("```")
	for t in range(1, 11):
		var line := "%2d " % t
		var total := 0
		for s in sizes:
			var c := 0
			for r in by[s]:
				if int(r["tier"]) == t:
					c += 1
			total += c
		line += "#".repeat(int(round(total / 2.0))) + " %d" % total
		var parts := []
		for s in sizes:
			var c := 0
			for r in by[s]:
				if int(r["tier"]) == t:
					c += 1
			parts.append("%s:%d" % [s, c])
		line += "   (" + ", ".join(parts) + ")"
		md.append(line)
	md.append("```")
	md.append("")

	# --- согласие с ботом ---
	var effort := []
	for r in rows:
		effort.append(float(r["effort"]))
	var rho := _spearman(scores, effort)
	md.append("## Калибровка по боту")
	md.append("")
	md.append("Усилие бота = медиана касаний из %d попыток; если бот не решил больше половины попыток — %d (лимит)." % [int(rows[0]["bot_runs"]), max_moves])
	md.append("")
	md.append("- Спирмен(оценка v0, усилие бота) = **%.2f**" % rho)
	var fit := _fit(rows)
	var fitted := []
	for r in rows:
		var v: float = fit["b0"]
		for k in FEATURES:
			v += float(fit["w"][k]) * float(r["features"][k])
		fitted.append(v)
	md.append("- Спирмен(подобранная оценка, усилие бота) = **%.2f** на том же наборе (оптимистично)" % _spearman(fitted, effort))
	# честная проверка: подбор на чётных уровнях, проверка на нечётных, и наоборот
	var cv := []
	for part in 2:
		var train := []
		var test := []
		for i in rows.size():
			(train if i % 2 == part else test).append(rows[i])
		var fp := _fit(train)
		var pred := []
		var eff := []
		for r in test:
			var v: float = fp["b0"]
			for k in FEATURES:
				v += float(fp["w"][k]) * float(r["features"][k])
			pred.append(v)
			eff.append(float(r["effort"]))
		cv.append(_spearman(pred, eff))
	md.append("- Спирмен(подобранная оценка, усилие бота) = **%.2f** на отложенной половине (честная проверка: подбор на одной половине уровней, проверка на другой)" % ((cv[0] + cv[1]) / 2.0))
	md.append("")
	md.append("| Признак | Вес v0 | Подобранный вес (на log(1+касания)) |")
	md.append("|---|---|---|")
	for k in FEATURES:
		md.append("| %s | %s | %.3f |" % [k, str(Difficulty.WEIGHTS.get(k, 0)), float(fit["w"][k])])
	md.append("")
	md.append("Подобранные веса — предложение, в код не внесены: решение за владельцем.")
	md.append("")

	if a.has("md"):
		DirAccess.make_dir_recursive_absolute(String(a["md"]).get_base_dir())
		var f := FileAccess.open(String(a["md"]), FileAccess.WRITE)
		f.store_string("\n".join(md) + "\n" + String(a.get("footer", "")))
	if a.has("csv"):
		var c := FileAccess.open(String(a["csv"]), FileAccess.WRITE)
		var head := ["idx", "size", "seed", "verified", "winners", "solver_nodes", "bot_solved", "bot_runs", "bot_moves_median", "score", "tier"]
		head.append_array(FEATURES)
		c.store_line(",".join(head))
		for r in rows:
			var vals := [r["idx"], r["size"], r["seed"], r["verified"], r["winners"], r["solver_nodes"], r["bot_solved"], r["bot_runs"], r["bot_moves_median"], r["features"]["score"], r["tier"]]
			for k in FEATURES:
				vals.append(r["features"][k])
			var sv := PackedStringArray()
			for v in vals:
				sv.append(str(v))
			c.store_line(",".join(sv))
	print("report: n=%d verified=%d spearman=%.2f" % [n, verified, rho])
	quit(0)


func _median(arr: Array, getter: Callable) -> float:
	var vals := []
	for r in arr:
		vals.append(getter.call(r))
	vals.sort()
	return float(vals[vals.size() / 2]) if not vals.is_empty() else 0.0


func _ranks(x: Array) -> Array:
	var idx := range(x.size())
	idx.sort_custom(func(i, j): return x[i] < x[j])
	var ranks := []
	ranks.resize(x.size())
	var i := 0
	while i < idx.size():
		var j := i
		while j + 1 < idx.size() and x[idx[j + 1]] == x[idx[i]]:
			j += 1
		var avg := (i + j) / 2.0
		for k in range(i, j + 1):
			ranks[idx[k]] = avg
		i = j + 1
	return ranks


func _spearman(x: Array, y: Array) -> float:
	var rx := _ranks(x)
	var ry := _ranks(y)
	var n := rx.size()
	var mx := 0.0
	var my := 0.0
	for i in n:
		mx += rx[i]
		my += ry[i]
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in n:
		sxy += (rx[i] - mx) * (ry[i] - my)
		sxx += (rx[i] - mx) * (rx[i] - mx)
		syy += (ry[i] - my) * (ry[i] - my)
	return sxy / sqrt(maxf(sxx * syy, 1e-12))


## Наименьшие квадраты (с маленькой гребневой добавкой): log(1+усилие) ~ b0 + Σ w_k·признак_k.
func _fit(rows: Array) -> Dictionary:
	var k := FEATURES.size() + 1
	var A := []
	for i in k:
		var row := []
		row.resize(k + 1)
		row.fill(0.0)
		A.append(row)
	for r in rows:
		var x := [1.0]
		for f in FEATURES:
			x.append(float(r["features"][f]))
		var y := log(1.0 + float(r["effort"]))
		for i in k:
			for j in k:
				A[i][j] += x[i] * x[j]
			A[i][k] += x[i] * y
	for i in range(1, k):
		A[i][i] += 1e-3
	# Гаусс
	for c in k:
		var p := c
		for r2 in range(c + 1, k):
			if absf(A[r2][c]) > absf(A[p][c]):
				p = r2
		var tmp = A[c]
		A[c] = A[p]
		A[p] = tmp
		var piv: float = A[c][c]
		if absf(piv) < 1e-12:
			continue
		for j in range(c, k + 1):
			A[c][j] /= piv
		for r2 in k:
			if r2 != c:
				var fct: float = A[r2][c]
				for j in range(c, k + 1):
					A[r2][j] -= fct * A[c][j]
	var w := {}
	for i in FEATURES.size():
		w[FEATURES[i]] = A[i + 1][k]
	return {"b0": A[0][k], "w": w}


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
