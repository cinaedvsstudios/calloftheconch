class_name PrototypeAssets
extends RefCounted
## Resolves the deliberately small Prototype 0.1 asset set.
## Missing media remains non-fatal so the prototype can still open for code checks.

const WATER_BACKGROUND_CANDIDATES: PackedStringArray = [
	"res://assets/backgrounds/waterbg.jpg",
	"res://assets/backgrounds/water_bg.jpg",
]
const WATER_SKY_BACKGROUND_CANDIDATES: PackedStringArray = [
	"res://assets/backgrounds/waterskybg.jpg",
]
const WATER_PARALLAX_OVERLAY_CANDIDATES: PackedStringArray = [
	"res://assets/backgrounds/waterbgparalax.webp",
]
const SAND_OVERLAY_CANDIDATES: PackedStringArray = [
	"res://assets/backgrounds/sandoverlay.webp",
]
const MOUNTAIN_OVERLAY_01_CANDIDATES: PackedStringArray = [
	"res://assets/backgrounds/mountainoverlay01.webp",
]
const MOUNTAIN_OVERLAY_03_CANDIDATES: PackedStringArray = [
	"res://assets/backgrounds/mountainoverlay03.webp",
]
const CITY_BACKGROUND_CANDIDATES: PackedStringArray = [
	"res://assets/backgrounds/bg_pillars_city.jpg",
	"res://assets/backgrounds/pillars_city.jpg",
]
const TITLE_TEXTURE_CANDIDATES: PackedStringArray = [
	"res://assets/ui/title.png",
]
const BUBBLE_VIDEO_CANDIDATES: PackedStringArray = [
	"res://assets/effects/bubble_riser_field.ogv",
]
const TAIL_BURST_VIDEO_CANDIDATES: PackedStringArray = [
	"res://assets/effects/bubble-explosion.ogv",
	"res://assets/effects/bubble_explosion.ogv",
]
const AUDIO_DIRECTORY: String = "res://assets/audio"
const CHARACTER_DIRECTORY: String = "res://assets/characters"
const EFFECTS_DIRECTORY: String = "res://assets/effects"
const SUPPORTED_FRAME_EXTENSIONS: PackedStringArray = ["png", "webp"]


static func load_texture(candidates: PackedStringArray) -> Texture2D:
	for path: String in candidates:
		if not ResourceLoader.exists(path):
			continue
		var resource: Resource = load(path)
		if resource is Texture2D:
			return resource as Texture2D
	return null


static func load_video(candidates: PackedStringArray) -> VideoStream:
	for path: String in candidates:
		if not ResourceLoader.exists(path):
			continue
		var resource: Resource = load(path)
		if resource is VideoStream:
			return resource as VideoStream
	return null


static func load_audio_with_words(required_words: PackedStringArray) -> AudioStream:
	var directory: DirAccess = DirAccess.open(AUDIO_DIRECTORY)
	if directory == null:
		return null

	for file_name: String in directory.get_files():
		var normalised_name: String = file_name.to_lower()
		if not _is_audio_file(normalised_name) or not _contains_all_words(normalised_name, required_words):
			continue
		var path: String = "%s/%s" % [AUDIO_DIRECTORY, file_name]
		var resource: Resource = load(path)
		if resource is AudioStream:
			return resource as AudioStream
	return null


static func load_hylas_frames(prefix: String) -> Array[Texture2D]:
	return _load_numbered_texture_frames(CHARACTER_DIRECTORY, prefix)


static func load_effect_frames(prefix: String) -> Array[Texture2D]:
	return _load_numbered_texture_frames(EFFECTS_DIRECTORY, prefix)


static func _load_numbered_texture_frames(directory_path: String, prefix: String) -> Array[Texture2D]:
	var frame_paths: Array[String] = []
	var file_names: PackedStringArray = DirAccess.get_files_at(directory_path)
	for file_name: String in file_names:
		if not _matches_numbered_frame(file_name, prefix):
			continue
		frame_paths.append("%s/%s" % [directory_path, file_name])

	frame_paths.sort_custom(func(left_path: String, right_path: String) -> bool:
		return _frame_index_from_path(left_path) < _frame_index_from_path(right_path)
	)

	var frames: Array[Texture2D] = []
	for frame_path: String in frame_paths:
		var resource: Resource = load(frame_path)
		if resource is Texture2D:
			frames.append(resource as Texture2D)
	return frames


static func _matches_numbered_frame(file_name: String, prefix: String) -> bool:
	var extension: String = file_name.get_extension().to_lower()
	if not SUPPORTED_FRAME_EXTENSIONS.has(extension):
		return false

	var base_name: String = file_name.get_basename()
	var required_prefix: String = "%s_" % prefix
	if not base_name.begins_with(required_prefix):
		return false

	var numeric_suffix: String = base_name.trim_prefix(required_prefix)
	return numeric_suffix.is_valid_int()


static func _frame_index_from_path(frame_path: String) -> int:
	var base_name: String = frame_path.get_file().get_basename()
	var separator_index: int = base_name.rfind("_")
	if separator_index < 0:
		return 0
	return base_name.substr(separator_index + 1).to_int()


static func _contains_all_words(file_name: String, required_words: PackedStringArray) -> bool:
	for required_word: String in required_words:
		if not file_name.contains(required_word.to_lower()):
			return false
	return true


static func _is_audio_file(file_name: String) -> bool:
	return file_name.ends_with(".mp3") or file_name.ends_with(".ogg") or file_name.ends_with(".wav")
