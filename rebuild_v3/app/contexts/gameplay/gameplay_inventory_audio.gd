extends "res://rebuild_v3/app/contexts/gameplay/gameplay_double_tap_inventory.gd"

const ITEM_CLICK_STREAM: AudioStream = preload("res://assets/audio/pickup6.mp3")
const ITEM_EQUIP_STREAM: AudioStream = preload("res://assets/audio/pickup1.mp3")
const INVENTORY_OPEN_STREAM: AudioStream = preload("res://assets/audio/pickup4.mp3")

var _item_click_audio: AudioStreamPlayer
var _item_equip_audio: AudioStreamPlayer
var _inventory_open_audio: AudioStreamPlayer


func _ready() -> void:
	super._ready()
	_item_click_audio = _create_ui_audio_player(&"InventoryItemClickAudio", ITEM_CLICK_STREAM, -5.0)
	_item_equip_audio = _create_ui_audio_player(&"InventoryItemEquipAudio", ITEM_EQUIP_STREAM, -4.0)
	_inventory_open_audio = _create_ui_audio_player(&"InventoryOpenAudio", INVENTORY_OPEN_STREAM, -5.0)

	if not _inventory_overlay.inventory_opened.is_connected(_on_inventory_opened_audio):
		_inventory_overlay.inventory_opened.connect(_on_inventory_opened_audio)
	if not _inventory_overlay.item_equipped.is_connected(_on_inventory_item_equipped_audio):
		_inventory_overlay.item_equipped.connect(_on_inventory_item_equipped_audio)


func _create_ui_audio_player(
		player_name: StringName,
		stream: AudioStream,
		volume_db: float,
	) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = String(player_name)
	player.stream = stream
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _on_inventory_opened_audio() -> void:
	_play_ui_audio(_inventory_open_audio)
	call_deferred(&"_connect_inventory_item_click_sounds")


func _connect_inventory_item_click_sounds() -> void:
	var item_grid: Node = _inventory_overlay.get_node_or_null("%ItemGrid")
	if item_grid == null:
		return
	_connect_item_button_tree(item_grid)


func _connect_item_button_tree(parent: Node) -> void:
	for child: Node in parent.get_children():
		var button := child as Button
		if button != null:
			var callback := Callable(self, "_on_inventory_item_gui_input")
			if not button.gui_input.is_connected(callback):
				button.gui_input.connect(callback)
		_connect_item_button_tree(child)


func _on_inventory_item_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_play_ui_audio(_item_click_audio)


func _on_inventory_item_equipped_audio(
		_slot_id: StringName,
		_item_id: StringName,
	) -> void:
	_play_ui_audio(_item_equip_audio)


func _play_ui_audio(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()
