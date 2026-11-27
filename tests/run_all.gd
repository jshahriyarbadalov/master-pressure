## Тест-раннер без плагинов: godot --headless -s tests/run_all.gd [-- фильтр]
## Находит tests/test_*.gd, вызывает методы test_*. Код выхода 1 при любой ошибке.
extends SceneTree


func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()
	var total := 0
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("FAIL ", f, ": скрипт не загружается (ошибка разбора)")
			continue
		var inst = script.new()
		inst.tree = self
		for m in inst.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			if filter != "" and not (f + "::" + name).contains(filter):
				continue
			total += 1
			inst._current = f + "::" + name
			var before: int = inst.failures.size()
			var ts := Time.get_ticks_msec()
			var res = inst.call(name)
			var dt := Time.get_ticks_msec() - ts
			if res != true:
				inst.failures.append("%s: упал с ошибкой (не дошёл до return ok())" % inst._current)
			if inst.failures.size() > before:
				failed += 1
				print("FAIL ", inst._current, " (", dt, " мс)")
				for i in range(before, inst.failures.size()):
					print("     ", inst.failures[i])
			else:
				print("ok   ", inst._current, " (", dt, " мс)")
	print("\nИтого: %d тестов, упало %d, %.1f с" % [total, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failed > 0 or total == 0 else 0)
