class_name CotcTutorialHintTrigger
extends Area2D

## Invisible level marker that requests one central-library hint when Hylas enters it.

signal hint_requested(trigger: CotcTutorialHintTrigger)

enum EntrySide {
	AUTO,
	LEFT,
	RIGHT,
}

@export var hint_id: StringName = &""
@export_enum("Auto", "Left", "Right") var entry_side: int = EntrySide.AUTO
@export var repeatable: bool = false

var _claimed: bool = false


func _ready() -> void:
	add_to_group(&"tutorial_hint_trigger")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func set_claimed(claimed: bool) -> void:
	_claimed = claimed
	set_deferred(&"monitoring", not claimed)


func mark_consumed() -> void:
	_claimed = true
	set_deferred(&"monitoring", false)


func rearm() -> void:
	_claimed = false
	set_deferred(&"monitoring", true)


func is_claimed() -> bool:
	return _claimed


func _on_body_entered(body: Node2D) -> void:
	if _claimed or body == null or not body.is_in_group(&"hylas"):
		return
	hint_requested.emit(self)
