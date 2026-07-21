extends "res://scenes/objects/PufferFish/puffer_fish.gd"

## Keeps permanent visual scale authored on AnimatedSprite while restoring the
## two intended gameplay reactions: Tail Flip impact and Conch pulse inflation.

var _reaction_hylas: CotcHylas


func _ready() -> void:
	super._ready()
	call_deferred(&"_connect_reaction_hylas")
	set_process(true)


func _exit_tree() -> void:
	_disconnect_reaction_hylas()


func _process(_delta: float) -> void:
	if not is_instance_valid(_reaction_hylas):
		_connect_reaction_hylas()


func _apply_display_scale() -> void:
	pass


func _connect_reaction_hylas() -> void:
	var candidate: CotcHylas = get_tree().get_first_node_in_group(&"hylas") as CotcHylas
	if candidate == _reaction_hylas:
		return
	_disconnect_reaction_hylas()
	_reaction_hylas = candidate
	if not is_instance_valid(_reaction_hylas):
		return
	if not _reaction_hylas.tail_flip_impact.is_connected(_on_hylas_tail_flip_impact):
		_reaction_hylas.tail_flip_impact.connect(_on_hylas_tail_flip_impact)


func _disconnect_reaction_hylas() -> void:
	if (
			is_instance_valid(_reaction_hylas)
			and _reaction_hylas.tail_flip_impact.is_connected(_on_hylas_tail_flip_impact)
		):
		_reaction_hylas.tail_flip_impact.disconnect(_on_hylas_tail_flip_impact)
	_reaction_hylas = null


func _on_hylas_tail_flip_impact(
		contact_position: Vector2,
		normal: Vector2,
		target: Node,
	) -> void:
	if target != self:
		return
	receive_tail_flip_bash(contact_position, normal, _reaction_hylas)


func receive_tail_flip_bash(
		contact_position: Vector2,
		normal: Vector2,
		source: Node,
	) -> void:
	# The first hit only startles and inflates the fish. Once fully puffed, later
	# Tail Flips use the original kick impulse and refresh the puff timer.
	if is_puffed():
		super.receive_tail_flip_bash(contact_position, normal, source)
		return
	_begin_inflating()


func receive_conch_hit(
		_origin: Vector2,
		_direction: Vector2,
		_distance: float,
		_strength: float,
	) -> void:
	# Conch energy inflates the fish without physically kicking it away.
	if is_puffed():
		_begin_puffed_hold()
		return
	_begin_inflating()
