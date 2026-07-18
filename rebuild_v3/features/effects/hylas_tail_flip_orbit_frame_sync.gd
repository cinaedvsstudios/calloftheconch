class_name CotcHylasTailFlipOrbitFrameSync
extends Node

const TAIL_FLIP_ANIMATION: StringName = &"tail_flip"
const ORBIT_REVOLUTIONS: float = 2.0
# One canonical animation phase is used for both directions. The completed orbit
# geometry is mirrored separately for left-facing Hylas, so the moving highlight
# cannot be phase-corrected back into the same onscreen path.
const CANONICAL_START_PROGRESS: float = 13.0 / 60.0

@onready var _refinement: Node = get_parent()
@onready var _player: CharacterBody2D = get_parent().get_parent().get_parent() as CharacterBody2D
@onready var _sprite: AnimatedSprite2D = _player.get_node_or_null("AnimatedSprite") as AnimatedSprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = 110
	set_process(true)


func _process(_delta: float) -> void:
	if _player == null or _sprite == null or _refinement == null:
		return
	if _sprite.animation != TAIL_FLIP_ANIMATION:
		return
	if float(_player.get("_tail_flip_remaining")) <= 0.0:
		return
	if not _refinement.has_method(&"_update_orbit_geometry"):
		return

	var frame_count: int = _sprite.sprite_frames.get_frame_count(TAIL_FLIP_ANIMATION)
	if frame_count <= 1:
		_refinement.call(&"_update_orbit_geometry", CANONICAL_START_PROGRESS)
		return

	var final_frame_index: float = float(frame_count - 1)
	var frame_progress: float = clampf(_sprite.frame_progress, 0.0, 1.0)
	var animation_progress: float = clampf(
		(float(_sprite.frame) + frame_progress) / final_frame_index,
		0.0,
		1.0,
	)

	# Always build the same canonical right-facing animation. The refinement
	# mirrors the finished Line2D points when Hylas faces left. Using one phase
	# here is what makes the left-facing result a literal horizontal mirror.
	var orbit_progress: float = fposmod(
		CANONICAL_START_PROGRESS - animation_progress * ORBIT_REVOLUTIONS,
		1.0,
	)
	_refinement.call(&"_update_orbit_geometry", orbit_progress)
