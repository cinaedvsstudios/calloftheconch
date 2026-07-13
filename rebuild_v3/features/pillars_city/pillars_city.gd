class_name CotcPillarsCity
extends CanvasLayer

signal exit_requested
signal menu_requested
signal location_changed(location_name: String)

const TARGET_EXIT: StringName = &"exit"
const TARGET_MENU: StringName = &"menu"
const TARGET_AGORA: StringName = &"agora"
const TARGET_ORACLE: StringName = &"oracle"

@export_category("City Artwork")
@export var city_background_texture: Texture2D = preload(
	"res://assets/backgrounds/bg_pillars_city.jpg"
)
@export var agora_sign_texture: Texture2D = preload(
	"res://assets/ui/ui_location_agora_of_myra.webp"
)

@export_category("City Hylas")
@export var city_hylas_scene: PackedScene = preload(
	"res://rebuild_v3/features/hylas/hylas.tscn"
)
@export_range(60.0, 220.0, 1.0) var hylas_display_height: float = 118.0
@export_range(40.0, 220.0, 1.0) var doorway_interaction_radius: float = 105.0
@export var hylas_spawn_ratio: Vector2 = Vector2(0.50, 0.78)
@export_range(-20, 20, 1) var hylas_z_index: int = 0
@export_range(0.0, 240.0, 1.0) var hylas_edge_padding: float = 48.0

@export_category("City Hylas Movement")
@export_range(1.0, 2000.0, 1.0) var hylas_swim_speed: float = 320.0
@export_range(1.0, 5000.0, 1.0) var hylas_swim_acceleration: float = 1600.0
@export_range(1.0, 5000.0, 1.0) var hylas_idle_momentum_deceleration: float = 300.0
@export_range(1.0, 8000.0, 1.0) var hylas_brake_deceleration: float = 2800.0
@export_range(0.0, 100.0, 0.5) var hylas_idle_sink_speed: float = 4.0
@export var hylas_current_base_velocity: Vector2 = Vector2.ZERO
@export_range(0.0, 100.0, 0.5) var hylas_current_sway_horizontal: float = 2.0
@export_range(0.0, 100.0, 0.5) var hylas_current_sway_vertical: float = 1.0
@export_range(0.0, 5.0, 0.01) var hylas_current_sway_frequency: float = 0.24

@export_category("City Interaction Text")
@export var city_name: String = "Neresithoppos"
@export var exit_prompt_text: String = "Press Space to leave the city"
@export var doorway_prompt_template: String = "Press Space to enter %s"
@export var agora_title: String = "The Agora of Myra"
@export_multiline var agora_subtitle: String = "Trade, supplies and the city’s working marketplace."
@export var oracle_title: String = "The Hieron of the Oracle"
@export_multiline var oracle_subtitle: String = "The sacred chamber of the city oracle."

@onready var _background: TextureRect = %CityBackground
@onready var _bubble_overlay: VideoStreamPlayer = %BubbleOverlay
@onready var _exit_gate_button: Button = %ExitGateButton
@onready var _menu_building_button: Button = %MenuBuildingButton
@onready var _agora_button: Button = %AgoraButton
@onready var _oracle_button: Button = %OracleButton
@onready var _interaction_hint: Label = $InteractionHint
@onready var _location_overlay: Control = %LocationOverlay
@onready var _location_sign: TextureRect = %LocationSign
@onready var _location_title: Label = %LocationTitle
@onready var _location_subtitle: Label = %LocationSubtitle
@onready var _return_button: Button = %ReturnButton

var _active: bool = false
var _city_hylas: CotcHylas
var _active_hotspot_id: StringName = &""
var _hotspot_buttons: Array[Button] = []
var _hotspot_ids: Array[StringName] = []
var _hotspot_labels: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_artwork()
	_prepare_hotspots()
	_create_city_hylas()
	_return_button.pressed.connect(_close_location)
	_location_overlay.hide()
	_interaction_hint.hide()
	set_process(false)
	deactivate()


func activate() -> void:
	_active = true
	show()
	_location_overlay.hide()
	location_changed.emit(city_name)
	if is_instance_valid(_city_hylas):
		_configure_city_hylas_for_viewport(true)
		_set_city_hylas_play_enabled(true)
		_city_hylas.show()
	set_process(true)
	_update_doorway_interaction()
	if _bubble_overlay.stream != null:
		_bubble_overlay.show()
		_bubble_overlay.play()


func deactivate() -> void:
	_active = false
	_active_hotspot_id = &""
	set_process(false)
	_location_overlay.hide()
	_interaction_hint.hide()
	_set_city_hylas_interaction_available(false)
	_set_city_hylas_play_enabled(false)
	if is_instance_valid(_city_hylas):
		_city_hylas.hide()
	_bubble_overlay.stop()
	_bubble_overlay.hide()
	hide()


func is_active() -> bool:
	return _active


func _process(_delta: float) -> void:
	if not _active or get_tree().paused or _location_overlay.visible:
		return
	_update_doorway_interaction()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed(&"ui_cancel") and _location_overlay.visible:
		_close_location()
		get_viewport().set_input_as_handled()


func _apply_artwork() -> void:
	_background.texture = city_background_texture
	_location_sign.texture = agora_sign_texture
	if _background.texture == null:
		push_warning("Pillars city background texture is not assigned in the Inspector.")


func _prepare_hotspots() -> void:
	_hotspot_buttons = [
		_exit_gate_button,
		_menu_building_button,
		_agora_button,
		_oracle_button,
	]
	_hotspot_ids = [
		TARGET_EXIT,
		TARGET_MENU,
		TARGET_AGORA,
		TARGET_ORACLE,
	]
	_hotspot_labels = [
		"EXIT THE CITY",
		"MENU",
		agora_title.to_upper(),
		oracle_title.to_upper(),
	]
	for button: Button in _hotspot_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = ""


func _create_city_hylas() -> void:
	if city_hylas_scene == null:
		push_error("City Hylas scene is not assigned in the Pillars City Inspector.")
		return
	_city_hylas = city_hylas_scene.instantiate() as CotcHylas
	if _city_hylas == null:
		push_error("Could not create Hylas for the Pillars city.")
		return
	_city_hylas.name = "CityHylas"
	_city_hylas.process_mode = Node.PROCESS_MODE_PAUSABLE
	_city_hylas.z_index = hylas_z_index
	_city_hylas.display_height = hylas_display_height
	_city_hylas.player_edge_padding = hylas_edge_padding
	_city_hylas.swim_speed = hylas_swim_speed
	_city_hylas.swim_acceleration = hylas_swim_acceleration
	_city_hylas.idle_momentum_deceleration = hylas_idle_momentum_deceleration
	_city_hylas.brake_deceleration = hylas_brake_deceleration
	_city_hylas.current_base_velocity = hylas_current_base_velocity
	_city_hylas.current_sway_horizontal = hylas_current_sway_horizontal
	_city_hylas.current_sway_vertical = hylas_current_sway_vertical
	_city_hylas.current_sway_frequency = hylas_current_sway_frequency
	_city_hylas.idle_sink_speed = hylas_idle_sink_speed
	add_child(_city_hylas)
	move_child(_city_hylas, _bubble_overlay.get_index() + 1)
	var city_camera: Camera2D = _city_hylas.get_node_or_null("Camera2D") as Camera2D
	if city_camera != null:
		city_camera.enabled = false
	if _city_hylas.has_signal(&"interaction_requested"):
		_city_hylas.connect(
			&"interaction_requested",
			Callable(self, "_on_city_hylas_interaction_requested"),
		)
	_city_hylas.hide()
	_set_city_hylas_play_enabled(false)


func _configure_city_hylas_for_viewport(reset_position: bool) -> void:
	if not is_instance_valid(_city_hylas):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var world_bounds: Rect2 = Rect2(Vector2.ZERO, viewport_size)
	var spawn_position: Vector2 = Vector2(
		viewport_size.x * clampf(hylas_spawn_ratio.x, 0.0, 1.0),
		viewport_size.y * clampf(hylas_spawn_ratio.y, 0.0, 1.0),
	)
	_city_hylas.configure_world(world_bounds, -10000.0, spawn_position)
	if reset_position:
		_city_hylas.reset_to_start(spawn_position)


func _update_doorway_interaction() -> void:
	if not is_instance_valid(_city_hylas):
		return
	var nearest_target_id: StringName = &""
	var nearest_target_label: String = ""
	var nearest_distance: float = INF
	for index: int in range(_hotspot_buttons.size()):
		var hotspot_center: Vector2 = _hotspot_buttons[index].get_global_rect().get_center()
		var distance: float = _city_hylas.global_position.distance_to(hotspot_center)
		if distance > doorway_interaction_radius or distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_target_id = _hotspot_ids[index]
		nearest_target_label = _hotspot_labels[index]

	_active_hotspot_id = nearest_target_id
	var interaction_available: bool = _active_hotspot_id != &""
	_set_city_hylas_interaction_available(interaction_available)
	if not interaction_available:
		_interaction_hint.hide()
		return
	if _active_hotspot_id == TARGET_EXIT:
		_interaction_hint.text = exit_prompt_text
	else:
		_interaction_hint.text = doorway_prompt_template % nearest_target_label
	_interaction_hint.show()


func _set_city_hylas_play_enabled(is_enabled: bool) -> void:
	if not is_instance_valid(_city_hylas):
		return
	_city_hylas.set_play_enabled(is_enabled)


func _set_city_hylas_interaction_available(is_available: bool) -> void:
	if not is_instance_valid(_city_hylas):
		return
	if _city_hylas.has_method(&"set_interaction_available"):
		_city_hylas.call(&"set_interaction_available", is_available)


func _on_city_hylas_interaction_requested() -> void:
	if not _active or _location_overlay.visible:
		return
	match _active_hotspot_id:
		TARGET_EXIT:
			exit_requested.emit()
		TARGET_MENU:
			menu_requested.emit()
		TARGET_AGORA:
			_open_location(agora_title, agora_subtitle, true)
		TARGET_ORACLE:
			_open_location(oracle_title, oracle_subtitle, false)


func _open_location(title: String, subtitle: String, show_agora_sign: bool) -> void:
	_location_title.text = title.to_upper()
	_location_subtitle.text = subtitle
	_location_sign.visible = show_agora_sign and _location_sign.texture != null
	_location_overlay.show()
	_interaction_hint.hide()
	_set_city_hylas_interaction_available(false)
	_set_city_hylas_play_enabled(false)
	if is_instance_valid(_city_hylas):
		_city_hylas.hide()
	location_changed.emit(title)
	_return_button.grab_focus()


func _close_location() -> void:
	_location_overlay.hide()
	location_changed.emit(city_name)
	if is_instance_valid(_city_hylas):
		_city_hylas.show()
	_set_city_hylas_play_enabled(true)
	_update_doorway_interaction()


func get_debug_lines() -> Array[String]:
	return [
		"[PillarsCity]",
		"active=%s" % str(_active),
		"background_loaded=%s" % str(_background.texture != null),
		"bubble_overlay_playing=%s" % str(_bubble_overlay.is_playing()),
		"location_overlay_visible=%s" % str(_location_overlay.visible),
		"city_hylas_loaded=%s" % str(is_instance_valid(_city_hylas)),
		"hylas_display_height=%.1f" % hylas_display_height,
		"doorway_radius=%.1f" % doorway_interaction_radius,
		"active_hotspot=%s" % String(_active_hotspot_id),
	]
