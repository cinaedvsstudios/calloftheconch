extends AudioStreamPlayer2D

## Keeps shark-specific audio separate from patrol and freeze behaviour.
## Fin-loss audio remains owned by Hylas so landing and damage stay distinct.


func _ready() -> void:
	var shark: Node = get_parent()
	if shark == null:
		return
	var frozen_callback: Callable = Callable(self, "_on_frozen_started")
	if shark.has_signal(&"frozen_started") and not shark.is_connected(&"frozen_started", frozen_callback):
		shark.connect(&"frozen_started", frozen_callback)
	var contact_callback: Callable = Callable(self, "_on_hylas_contacted")
	if shark.has_signal(&"hylas_contacted") and not shark.is_connected(&"hylas_contacted", contact_callback):
		shark.connect(&"hylas_contacted", contact_callback)


func _on_frozen_started() -> void:
	if stream == null:
		return
	stop()
	play()


func _on_hylas_contacted(hylas: Node2D) -> void:
	if hylas != null and hylas.has_method(&"play_fin_loss_sound"):
		hylas.call(&"play_fin_loss_sound")
