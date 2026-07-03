class_name BubbleOverlay
extends VideoStreamPlayer
## Full-strength black-background bubbles, rendered additively over the scene.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stream = PrototypeAssets.load_video(PrototypeAssets.BUBBLE_VIDEO_CANDIDATES)
	if stream == null:
		hide()
		return

	var additive_material: CanvasItemMaterial = CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive_material
	loop = true
	expand = true
	show()
	play()
