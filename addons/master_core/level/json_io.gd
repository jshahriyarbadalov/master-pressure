## Чтение/запись JSON и JSON Lines (по уровню на строку).
extends RefCounted


static func read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("не открыть %s" % path)
		return null
	return JSON.parse_string(f.get_as_text())


static func write(path: String, data: Variant, indent: String = "  ") -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("не записать %s" % path)
		return false
	f.store_string(JSON.stringify(data, indent, false))
	return true


static func read_lines(path: String) -> Array:
	var out := []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("не открыть %s" % path)
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "":
			out.append(JSON.parse_string(line))
	return out


static func write_lines(path: String, items: Array, append: bool = false) -> bool:
	var f: FileAccess
	if append and FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("не записать %s" % path)
		return false
	for it in items:
		f.store_line(JSON.stringify(it, "", false))
	return true
