class_name CotcDeveloperAdminPanel
extends Control

@onready var _report_text: TextEdit = %ReportText
@onready var _refresh_button: Button = %RefreshButton
@onready var _copy_button: Button = %CopyButton
@onready var _close_button: Button = %CloseButton

var _root_context: CotcRootContext
var _menu_context: CotcMenuContext
var _gameplay_context: CotcGameplayContext

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_button.pressed.connect(refresh_report)
	_copy_button.pressed.connect(_copy_report)
	_close_button.pressed.connect(hide)
	hide()

func bind_contexts(root_context: CotcRootContext, menu_context: CotcMenuContext, gameplay_context: CotcGameplayContext) -> void:
	_root_context = root_context
	_menu_context = menu_context
	_gameplay_context = gameplay_context

func toggle_panel() -> void:
	visible = not visible
	if visible:
		refresh_report()
		grab_focus()

func refresh_report() -> void:
	if _root_context == null:
		_report_text.text = "Developer/Admin panel is not bound yet."
		return
	_report_text.text = _root_context.build_debug_report()

func _copy_report() -> void:
	DisplayServer.clipboard_set(_report_text.text)
