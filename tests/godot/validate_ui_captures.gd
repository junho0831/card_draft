extends SceneTree

const CAPTURE_NAMES := [
	"01_main_menu",
	"02_run_map",
	"03_battle",
	"04_card_reward",
	"05_shop",
	"06_event",
	"07_rest",
	"08_run_result",
]
const RESPONSIVE_VIEWPORTS := [
	"desktop_1920x1080",
	"landscape_1280x720",
	"landscape_1024x768",
	"portrait_800x1280",
]
const MIN_PNG_BYTES := 10 * 1024

func _init() -> void:
	call_deferred("_validate_all")

func _validate_all() -> void:
	var failures: Array[String] = []
	for viewport_name in RESPONSIVE_VIEWPORTS:
		for capture_name in CAPTURE_NAMES:
			_validate_capture(
				"user://ui_captures_responsive/%s_%s.png" % [viewport_name, capture_name],
				failures
			)
	if failures.is_empty():
		print("PASS responsive UI captures validated")
		quit(0)
		return
	printerr("FAIL responsive UI captures")
	for failure in failures:
		printerr("- %s" % failure)
	quit(1)

func _validate_capture(path: String, failures: Array[String]) -> void:
	if not FileAccess.file_exists(path):
		failures.append("missing %s" % path)
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < MIN_PNG_BYTES:
		failures.append("too small %s (%d bytes)" % [path, bytes.size()])
		return
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		failures.append("cannot load %s: %s" % [path, error_string(err)])
		return
	if not _image_has_content(image):
		failures.append("no visible UI content %s" % path)

func _image_has_content(image: Image) -> bool:
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return false
	var min_luma := 1.0
	var max_luma := 0.0
	for x_index in range(12):
		for y_index in range(8):
			var x := int(float(width - 1) * (float(x_index) + 0.5) / 12.0)
			var y := int(float(height - 1) * (float(y_index) + 0.5) / 8.0)
			var color := image.get_pixel(x, y)
			var luma := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			min_luma = minf(min_luma, luma)
			max_luma = maxf(max_luma, luma)
	return max_luma - min_luma > 0.02
