class_name DeveloperAdminPanel
extends CanvasLayer
## Small permanent diagnostics panel for this prototype. It remains local to RootContext.

const MAX_ACTIONS: int = 100

@onready var _report_text: TextEdit = %ReportText
@onready var _copy_button: Button = %CopyReportButton

var _root_context: RootContext
var _pause_service: PauseService
var _launch_msec: int = 0
var _actions: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_launch_msec = Time.get_ticks_msec()
	%CloseButton.pressed.connect(_on_close_pressed)
	_copy_button.pressed.connect(_on_copy_report_pressed)
	hide()


func bind_dependencies(root_context: RootContext, pause_service: PauseService) -> void:
	_root_context = root_context
	_pause_service = pause_service


func record_action(category: String, detail: String = "") -> void:
	var timestamp: String = _format_uptime(Time.get_ticks_msec() - _launch_msec)
	var line: String = "[%s] %s" % [timestamp, category]
	if not detail.is_empty():
		line += ": %s" % detail
	_actions.append(line)
	if _actions.size() > MAX_ACTIONS:
		_actions.pop_front()
	if visible:
		_refresh_report()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"toggle_developer_admin"):
		return
	visible = not visible
	if visible:
		_refresh_report()
		_copy_button.grab_focus()
	get_viewport().set_input_as_handled()


func _refresh_report() -> void:
	_report_text.text = _build_report()


func _build_report() -> String:
	var engine_info: Dictionary = Engine.get_version_info()
	var engine_version: String = str(engine_info.get("string", "Unknown"))
	var active_context: String = "Unknown"
	if _root_context != null:
		active_context = _root_context.get_active_context_id_text()

	var paused: bool = false
	if _pause_service != null:
		paused = _pause_service.is_paused

	var prototype_summary: String = "Prototype scene not active."
	if _root_context != null:
		prototype_summary = _root_context.get_diagnostic_summary()

	var action_text: String = "(none)"
	if not _actions.is_empty():
		action_text = "\n".join(_actions)

	return """GODOT_DIAGNOSTIC_REPORT v1
Project: Call of the Conch Prototype
Build: 0.1-dev | Godot: %s | Debug: true
Platform: Windows | Renderer: Compatibility
Uptime: %s

CONTEXT
Active context: %s
Active scene: %s
Paused: %s

STATE SUMMARY
%s

PERFORMANCE
FPS: %.1f

LAST ACTIONS
%s

WARNINGS / ERRORS
Use Godot's debugger panel for engine warnings/errors in this first prototype.

NOTES
What I expected:
What actually happened:
How often it happens:
""" % [
		engine_version,
		_format_uptime(Time.get_ticks_msec() - _launch_msec),
		active_context,
		get_tree().current_scene.scene_file_path,
		str(paused),
		prototype_summary,
		Engine.get_frames_per_second(),
		action_text,
	]


func _format_uptime(total_msec: int) -> String:
	var total_seconds: int = maxi(0, total_msec / 1000)
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _on_close_pressed() -> void:
	hide()


func _on_copy_report_pressed() -> void:
	_refresh_report()
	DisplayServer.clipboard_set(_report_text.text)
	_copy_button.text = "Copied"
	var restore_timer: SceneTreeTimer = get_tree().create_timer(0.8, true)
	await restore_timer.timeout
	if is_instance_valid(_copy_button):
		_copy_button.text = "Copy Report"
