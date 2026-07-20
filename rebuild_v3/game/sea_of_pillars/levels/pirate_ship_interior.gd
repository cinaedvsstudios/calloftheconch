class_name CotcPirateShipInterior
extends Node2D

## Standalone single-screen pirate-ship room loaded by the exterior entry sequence.

@export var interior_size: Vector2 = Vector2(1280.0, 720.0)
@export var interior_waterline_y: float = -10000.0

@onready var _hylas: CotcHylas = %Hylas
@onready var _hylas_start: Marker2D = %HylasStart
@onready var _bubble_overlay: VideoStreamPlayer = %BubbleOverlay
@onready var _underwater_ambience: AudioStreamPlayer = %UnderwaterAmbience


func _ready() -> void:
	_configure_hylas()
	_start_room_ambience()


func _exit_tree() -> void:
	if is_instance_valid(_bubble_overlay):
		_bubble_overlay.stop()
	if is_instance_valid(_underwater_ambience):
		_underwater_ambience.stop()


func _configure_hylas() -> void:
	if not is_instance_valid(_hylas) or not is_instance_valid(_hylas_start):
		push_error("Pirate ship interior requires Hylas and HylasStart nodes.")
		return

	# The wreck is a still, enclosed room. Disable the broad open-sea current while
	# preserving Hylas's normal swimming, idle sink and action presentation.
	_hylas.current_base_velocity = Vector2.ZERO
	_hylas.current_sway_horizontal = 0.0
	_hylas.current_sway_vertical = 0.0
	_hylas.configure_world(
		Rect2(Vector2.ZERO, interior_size),
		interior_waterline_y,
		_hylas_start.global_position,
	)
	_hylas.set_play_enabled(true)


func _start_room_ambience() -> void:
	if is_instance_valid(_bubble_overlay) and _bubble_overlay.stream != null:
		_bubble_overlay.show()
		_bubble_overlay.play()
	if is_instance_valid(_underwater_ambience) and _underwater_ambience.stream != null:
		_underwater_ambience.play()
