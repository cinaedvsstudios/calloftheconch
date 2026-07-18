class_name CotcGameplayPauseScope
extends Node

const WORLD_ROOT_NAMES: Array[StringName] = [
	&"SeaOfPillars",
	&"ItemEffectController",
	&"SeaEnvironment",
	&"PillarsCity",
]
const MANUAL_TIME_PARAMETER: StringName = &"mati_manual_time"
const USE_MANUAL_TIME_PARAMETER: StringName = &"mati_use_manual_time"

var _context: Node
var _pause_applied: bool = false
var _process_mode_snapshot: Dictionary = {}
var _shader_snapshot: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_context = get_parent()
	if _context == null:
		set_process(false)
		return
	if not _context.child_entered_tree.is_connected(_on_context_child_entered_tree):
		_context.child_entered_tree.connect(_on_context_child_entered_tree)
	_configure_existing_roots()
	set_process(true)
	call_deferred(&"_sync_pause_state")


func _process(_delta: float) -> void:
	_sync_pause_state()


func _exit_tree() -> void:
	_restore_world_process_modes()
	_restore_shader_time()


func _sync_pause_state() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if tree.paused and not _pause_applied:
		_apply_pause_scope()
	elif not tree.paused and _pause_applied:
		_release_pause_scope()


func _configure_existing_roots() -> void:
	if _context == null:
		return
	for root_name: StringName in WORLD_ROOT_NAMES:
		var world_root: Node = _context.get_node_or_null(NodePath(String(root_name)))
		if world_root != null:
			world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	var gameplay_ui: Node = _context.get_node_or_null("GameplayUI")
	if gameplay_ui != null:
		gameplay_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	var gameplay_music: Node = _context.get_node_or_null("GameplayMusic")
	if gameplay_music != null:
		gameplay_music.process_mode = Node.PROCESS_MODE_ALWAYS


func _on_context_child_entered_tree(child: Node) -> void:
	if child == null or not WORLD_ROOT_NAMES.has(child.name):
		return
	child.process_mode = Node.PROCESS_MODE_PAUSABLE
	if _pause_applied:
		_capture_branch_process_modes(child)


func _apply_pause_scope() -> void:
	_pause_applied = true
	_process_mode_snapshot.clear()
	for world_root: Node in _get_world_roots():
		_capture_branch_process_modes(world_root)
	_freeze_shader_time()


func _release_pause_scope() -> void:
	_restore_world_process_modes()
	_restore_shader_time()
	_pause_applied = false


func _capture_branch_process_modes(node: Node) -> void:
	if node == null:
		return
	var instance_id: int = node.get_instance_id()
	if not _process_mode_snapshot.has(instance_id):
		_process_mode_snapshot[instance_id] = {
			"node": node,
			"process_mode": node.process_mode,
		}
	if node.process_mode != Node.PROCESS_MODE_DISABLED:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	for child: Node in node.get_children():
		_capture_branch_process_modes(child)


func _restore_world_process_modes() -> void:
	for entry_value: Variant in _process_mode_snapshot.values():
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var node: Node = entry.get("node") as Node
		if is_instance_valid(node):
			node.process_mode = int(entry.get("process_mode", Node.PROCESS_MODE_INHERIT))
	_process_mode_snapshot.clear()


func _get_world_roots() -> Array[Node]:
	var roots: Array[Node] = []
	if _context == null:
		return roots
	for root_name: StringName in WORLD_ROOT_NAMES:
		var world_root: Node = _context.get_node_or_null(NodePath(String(root_name)))
		if world_root != null:
			roots.append(world_root)
	return roots


func _freeze_shader_time() -> void:
	_shader_snapshot.clear()
	var seen_materials: Dictionary = {}
	for canvas_item: CanvasItem in _get_time_driven_canvas_items():
		if canvas_item == null or not (canvas_item.material is ShaderMaterial):
			continue
		var material: ShaderMaterial = canvas_item.material as ShaderMaterial
		var material_id: int = material.get_instance_id()
		if seen_materials.has(material_id):
			continue
		seen_materials[material_id] = true
		var previous_use_manual: Variant = material.get_shader_parameter(USE_MANUAL_TIME_PARAMETER)
		var previous_manual_time: Variant = material.get_shader_parameter(MANUAL_TIME_PARAMETER)
		var frozen_time: float = float(Time.get_ticks_msec()) / 1000.0
		if bool(previous_use_manual):
			frozen_time = float(previous_manual_time)
		_shader_snapshot.append({
			"material": material,
			"use_manual_time": previous_use_manual,
			"manual_time": previous_manual_time,
		})
		material.set_shader_parameter(MANUAL_TIME_PARAMETER, frozen_time)
		material.set_shader_parameter(USE_MANUAL_TIME_PARAMETER, true)


func _restore_shader_time() -> void:
	for entry: Dictionary in _shader_snapshot:
		var material: ShaderMaterial = entry.get("material") as ShaderMaterial
		if not is_instance_valid(material):
			continue
		material.set_shader_parameter(
			MANUAL_TIME_PARAMETER,
			entry.get("manual_time", 0.0),
		)
		material.set_shader_parameter(
			USE_MANUAL_TIME_PARAMETER,
			entry.get("use_manual_time", false),
		)
	_shader_snapshot.clear()


func _get_time_driven_canvas_items() -> Array[CanvasItem]:
	var items: Array[CanvasItem] = []
	if _context == null:
		return items
	var water_mottle: CanvasItem = _context.get_node_or_null(
		"SeaEnvironment/AtmosphereEffects/WaterMottle"
	) as CanvasItem
	if water_mottle != null:
		items.append(water_mottle)
	var waterlines: CanvasItem = _context.get_node_or_null(
		"SeaOfPillars/ParallaxLayer/waterlines"
	) as CanvasItem
	if waterlines != null:
		items.append(waterlines)
	return items
