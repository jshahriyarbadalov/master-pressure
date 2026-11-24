## Базовый класс тестов. Тест — метод `test_*() -> bool`, в конце `return ok()`.
## Если метод упал с ошибкой выполнения, он вернёт null — раннер засчитает падение.
extends RefCounted

var failures: Array[String] = []
var tree: SceneTree  ## дерево сцен раннера (для тестов интерфейса)
var _current := ""


func ok() -> bool:
	return true


func check(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("%s: %s" % [_current, msg])


func check_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_num(actual) and _is_num(expected)):
		failures.append("%s: %s — тип %s != %s (%s vs %s)" % [_current, msg, type_string(typeof(actual)), type_string(typeof(expected)), str(actual), str(expected)])
	elif actual != expected:
		failures.append("%s: %s — получено %s, ожидалось %s" % [_current, msg, str(actual), str(expected)])


func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		failures.append("%s: не открыть %s" % [_current, path])
		return null
	return JSON.parse_string(f.get_as_text())
