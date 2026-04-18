extends Node

# BotatoLogger — diagnostic file logger for debugging AI movement in-game.
#
# When enabled (via the ENABLE_DEBUG_LOG option in mod settings), writes detailed
# per-frame diagnostic info to $HOME/botato_debug.log (Linux/Mac) or
# %USERPROFILE%\botato_debug.log (Windows).
#
# Throttling: first 5 get_movement() calls logged in full detail, thereafter
# 1 summary line every 60 frames (once per second at 60fps).
#
# Owned by AutobattlerOptions node.

const LOG_FILENAME = "botato_debug.log"
const DETAILED_FRAMES = 5        # fully detailed logging for first N frames
const SUMMARY_INTERVAL = 60      # summary line every N frames after that

var _enabled: bool = false
var _file = null                 # Godot 3.5 File instance (Reference type)
var _path: String = ""
var _frame_counter: int = 0


func init_logger(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		return
	_path = _resolve_home_path() + "/" + LOG_FILENAME
	_file = File.new()
	var err = _file.open(_path, File.WRITE)  # truncate on open
	if err != OK:
		push_error("BotatoLogger: failed to open " + _path + " err=" + str(err))
		_enabled = false
		_file = null
		return
	_frame_counter = 0
	log_line("========== botato debug log started ==========")
	log_line("timestamp:  " + _timestamp())
	log_line("log path:   " + _path)
	log_line("platform:   " + OS.get_name())
	log_line("=================================================")


func set_enabled(enabled: bool) -> void:
	if enabled == _enabled:
		return
	if enabled:
		init_logger(true)
	else:
		log_line("========== botato debug log stopped ==========")
		if _file and _file.is_open():
			_file.close()
		_file = null
		_enabled = false


func is_enabled() -> bool:
	return _enabled


func log_line(msg: String) -> void:
	if not _enabled:
		return
	if _file == null or not _file.is_open():
		return
	_file.store_line("[" + _timestamp() + "] " + msg)
	_file.flush()


func log_section(title: String) -> void:
	if not _enabled:
		return
	log_line("")
	log_line("--- " + title + " ---")


func log_vec(name: String, v: Vector2) -> void:
	if not _enabled:
		return
	log_line("  " + name + " = " + str(v) + " (length=" + str(v.length()) + ")")


func log_kv(name, value) -> void:
	if not _enabled:
		return
	log_line("  " + str(name) + " = " + str(value))


func log_dict(name: String, d: Dictionary) -> void:
	if not _enabled:
		return
	log_line(name + ":")
	for k in d.keys():
		log_line("  " + str(k) + " = " + str(d[k]))


# ---- Frame counter helpers ----

func next_frame() -> int:
	_frame_counter += 1
	return _frame_counter


func frame_num() -> int:
	return _frame_counter


func should_log_detailed() -> bool:
	# Full detail for first N frames after detailed logging starts
	return _enabled and _frame_counter <= DETAILED_FRAMES


func should_log_summary() -> bool:
	# Summary every SUMMARY_INTERVAL frames after detailed period
	return _enabled and _frame_counter > DETAILED_FRAMES and (_frame_counter % SUMMARY_INTERVAL) == 0


# ---- Private helpers ----

func _timestamp() -> String:
	var t = OS.get_datetime()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]


func _resolve_home_path() -> String:
	# Linux/macOS: $HOME
	var home = OS.get_environment("HOME")
	if home != "":
		return home
	# Windows: %USERPROFILE%
	home = OS.get_environment("USERPROFILE")
	if home != "":
		return home
	# Last fallback: Godot's user data dir
	return OS.get_user_data_dir()
