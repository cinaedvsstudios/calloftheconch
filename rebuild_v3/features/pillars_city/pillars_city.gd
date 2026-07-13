class_name CotcPillarsCity
extends CanvasLayer

signal exit_requested
signal menu_requested
signal location_changed(location_name: String)

const CITY_BACKGROUND_PATH: String = "res://assets/backgrounds/bg_pillars_city.jpg"
const AGORA_SIGN_PATH: String = "res://assets/ui/ui_location_agora_of_myra.webp"
const CITY_NAME: String = "Neresithoppos"

@onready var _background: TextureRect = %CityBackground
@onready var _bubble_overlay: VideoStreamPlayer = %BubbleOverlay
@onready var _exit_gate_button: Button = %ExitGateButton
@onready var _menu_building_button: Button = %MenuBuildingButton
@onready var _agora_button: Button = %AgoraButton
@onready var _oracle_button: Button = %OracleButton
@onready var _location_overlay: Control = %LocationOverlay
@onready var _location_sign: TextureRect = %LocationSign
@onready var _location_title: Label = %LocationTitle
@onready var _location_subtitle: Label = %LocationSubtitle
@onready var _return_button: Button = %ReturnButton

var _active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_optional_artwork()
	_exit_gate_button.pressed.connect(_on_exit_gate_pressed)
	_menu_building_button.pressed.connect(_on_menu_building_pressed)
	_agora_button.pressed.connect(_on_agora_pressed)
	_oracle_button.pressed.connect(_on_oracle_pressed)
	_return_button.pressed.connect(_close_location)
	_location_overlay.hide()
	deactivate()


func activate() -> void:
	_active = true
	show()
	_location_overlay.hide()
	location_changed.emit(CITY_NAME)
	if _bubble_overlay.stream != null:
		_bubble_overlay.show()
		_bubble_overlay.play()
	_menu_building_button.grab_focus()


func deactivate() -> void:
	_active = false
	_location_overlay.hide()
	_bubble_overlay.stop()
	_bubble_overlay.hide()
	hide()


func is_active() -> bool:
	return _active


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed(&"ui_cancel") and _location_overlay.visible:
		_close_location()
		get_viewport().set_input_as_handled()


func _load_optional_artwork() -> void:
	if ResourceLoader.exists(CITY_BACKGROUND_PATH, "Texture2D"):
		_background.texture = ResourceLoader.load(CITY_BACKGROUND_PATH, "Texture2D") as Texture2D
	else:
		push_warning("Pillars city background is missing: %s" % CITY_BACKGROUND_PATH)
	if ResourceLoader.exists(AGORA_SIGN_PATH, "Texture2D"):
		_location_sign.texture = ResourceLoader.load(AGORA_SIGN_PATH, "Texture2D") as Texture2D


func _on_exit_gate_pressed() -> void:
	if not _active:
		return
	exit_requested.emit()


func _on_menu_building_pressed() -> void:
	if not _active:
		return
	menu_requested.emit()


func _on_agora_pressed() -> void:
	_open_location(
		"The Agora of Myra",
		"Trade, supplies and the city’s working marketplace.",
		true,
	)


func _on_oracle_pressed() -> void:
	_open_location(
		"The Hieron of the Oracle",
		"The sacred chamber of the city oracle.",
		false,
	)


func _open_location(title: String, subtitle: String, show_agora_sign: bool) -> void:
	_location_title.text = title.to_upper()
	_location_subtitle.text = subtitle
	_location_sign.visible = show_agora_sign and _location_sign.texture != null
	_location_overlay.show()
	location_changed.emit(title)
	_return_button.grab_focus()


func _close_location() -> void:
	_location_overlay.hide()
	location_changed.emit(CITY_NAME)
	_menu_building_button.grab_focus()


func get_debug_lines() -> Array[String]:
	return [
		"[PillarsCity]",
		"active=%s" % str(_active),
		"background_loaded=%s" % str(_background.texture != null),
		"bubble_overlay_playing=%s" % str(_bubble_overlay.is_playing()),
		"location_overlay_visible=%s" % str(_location_overlay.visible),
	]
