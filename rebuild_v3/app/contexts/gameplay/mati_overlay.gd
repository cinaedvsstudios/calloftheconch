class_name CotcMatiOverlay
extends Control
const MATI_TEXTURE: Texture2D = preload("res://assets/objects/ui_mati.png")
var elapsed := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
func set_elapsed(value: float) -> void:
	elapsed = clampf(value, 0.0, 30.0)
	show(); queue_redraw()
func clear() -> void:
	hide(); queue_redraw()
func _draw() -> void:
	if not visible or MATI_TEXTURE == null: return
	var ts := MATI_TEXTURE.get_size()
	var horizontal := ts.x >= ts.y
	var cell := Vector2(ts.y, ts.y) if horizontal else Vector2(ts.x, ts.x)
	var count := maxi(1, roundi((ts.x if horizontal else ts.y) / (cell.x if horizontal else cell.y)))
	var fps := 3.0 if elapsed < 5.0 or elapsed >= 25.0 else 1.0
	var ff := elapsed * fps
	var a := int(floor(ff)) % count
	var b := (a + 1) % count
	var blend := smoothstep(0.0, 1.0, ff - floor(ff))
	var target := Rect2(Vector2(size.x - 178.0, 24.0), Vector2(150.0,150.0))
	var sa := Rect2(Vector2(a*cell.x,0) if horizontal else Vector2(0,a*cell.y),cell)
	var sb := Rect2(Vector2(b*cell.x,0) if horizontal else Vector2(0,b*cell.y),cell)
	draw_texture_rect_region(MATI_TEXTURE,target,sa,Color(1,1,1,1.0-blend))
	draw_texture_rect_region(MATI_TEXTURE,target,sb,Color(1,1,1,blend))
