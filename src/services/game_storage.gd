extends RefCounted
class_name GameStorage

# Explicit command-line injection survives launchers that rewrite XDG_DATA_HOME.
static func test_directory() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-data-dir="):
			return argument.trim_prefix("--test-data-dir=")
	return OS.get_environment("CARD_DRAFT_TEST_DATA_DIR")

static func path_for(file_name: String) -> String:
	var directory := test_directory()
	return "user://" + file_name if directory.is_empty() else directory.path_join(file_name)

static func profile_path() -> String:
	return path_for("meta_profile.json")

static func run_path() -> String:
	return path_for("run_state.json")

static func prepare_test_directory() -> bool:
	var directory := test_directory()
	if directory.is_empty() or not directory.is_absolute_path() or directory.begins_with("user://"):
		push_error("Tests require -- --test-data-dir=/absolute/temporary/directory")
		return false
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	print("TEST STORAGE: ", run_path(), " | ", profile_path())
	return true
