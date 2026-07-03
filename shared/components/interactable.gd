class_name Interactable
extends Node
## Generic local interaction hook. The owning feature handles wider consequences.

signal interaction_started(interactor: Node)
signal interaction_finished(interactor: Node)

@export var interaction_label: String = "Interact"
@export var enabled: bool = true
@export_multiline var description: String = ""


func can_interact(_interactor: Node) -> bool:
	return enabled


func interact(interactor: Node) -> void:
	if not can_interact(interactor):
		return

	interaction_started.emit(interactor)
	interaction_finished.emit(interactor)
