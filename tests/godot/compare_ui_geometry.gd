extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("Expected baseline capture directory and updated capture directory.")
		quit(2)
		return
	var before_dir := args[0]
	var after_dir := args[1]
	var failures: Array[String] = []
	var controls := 0
	var screens := 0
	var maximum_delta := 0.0
	for file_name in DirAccess.get_files_at(before_dir):
		if not file_name.ends_with(".json"):
			continue
		var before := normalized_geometry(JSON.parse_string(FileAccess.get_file_as_string(before_dir.path_join(file_name))))
		if not FileAccess.file_exists(after_dir.path_join(file_name)):
			failures.append("Missing capture: " + file_name)
			continue
		var after := normalized_geometry(JSON.parse_string(FileAccess.get_file_as_string(after_dir.path_join(file_name))))
		screens += 1
		if before.keys() != after.keys():
			failures.append("Changed controls/text: " + file_name)
		for key in before:
			if not after.has(key):
				continue
			controls += 1
			for axis in range(4):
				var delta := absf(float(before[key][axis]) - float(after[key][axis]))
				maximum_delta = maxf(maximum_delta, delta)
				if delta > 1.0:
					failures.append("%s %s: %s -> %s" % [file_name, key, before[key], after[key]])
					break
	if screens == 0:
		failures.append("No capture geometry found")
	print("UI geometry: %d screens, %d controls, maximum delta %.3fpx, %d failures" % [screens, controls, maximum_delta, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)

func normalized_geometry(geometry: Dictionary) -> Dictionary:
	# The wall-clock duration varies between runs; its rectangle is still compared.
	var duration := RegEx.create_from_string("^(Label:Act [0-9]+ · .+ · )[0-9]+:[0-9]+(:[0-9]+)$")
	var result := {}
	for key in geometry:
		result[duration.sub(String(key), "$1TIME$2")] = geometry[key]
	return result
