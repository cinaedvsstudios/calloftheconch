class_name CotcEncodedTextureLoader
extends RefCounted

const FORMAT_WEBP: StringName = &"webp"
const FORMAT_JPG: StringName = &"jpg"
const FORMAT_PNG: StringName = &"png"


static func load_texture(
		primary_resource_path: String,
		encoded_fallback_path: String,
		encoded_format: StringName,
	) -> Texture2D:
	if ResourceLoader.exists(primary_resource_path, "Texture2D"):
		return ResourceLoader.load(primary_resource_path, "Texture2D") as Texture2D
	if encoded_fallback_path.is_empty() or not FileAccess.file_exists(encoded_fallback_path):
		return null
	var encoded_text: String = FileAccess.get_file_as_string(encoded_fallback_path).strip_edges()
	if encoded_text.is_empty():
		return null
	var raw_data: PackedByteArray = Marshalls.base64_to_raw(encoded_text)
	if raw_data.is_empty():
		return null
	var image: Image = Image.new()
	var load_error: Error = ERR_FILE_UNRECOGNIZED
	match encoded_format:
		FORMAT_WEBP:
			load_error = image.load_webp_from_buffer(raw_data)
		FORMAT_JPG:
			load_error = image.load_jpg_from_buffer(raw_data)
		FORMAT_PNG:
			load_error = image.load_png_from_buffer(raw_data)
		_:
			push_warning("Unknown encoded texture format '%s'." % String(encoded_format))
			return null
	if load_error != OK:
		push_warning(
			"Could not decode fallback texture %s. Error %d."
			% [encoded_fallback_path, load_error]
		)
		return null
	return ImageTexture.create_from_image(image)
