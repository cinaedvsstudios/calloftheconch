class_name SoundEffectSetting
extends Resource
## Inspector-editable definition used by AudioService.

@export var key: StringName = &""
@export var stream: AudioStream
@export var bus_name: StringName = &"SFX"
@export_range(-80.0, 24.0, 0.1) var volume_db: float = 0.0
@export_range(0.01, 4.0, 0.01) var pitch_random_min: float = 1.0
@export_range(0.01, 4.0, 0.01) var pitch_random_max: float = 1.0
@export_range(1, 32, 1) var max_simultaneous: int = 4


func is_valid() -> bool:
	return not key.is_empty() and stream != null
