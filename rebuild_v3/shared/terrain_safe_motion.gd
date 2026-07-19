class_name CotcTerrainSafeMotion
extends RefCounted

## Collision-aware movement for decorative Area2D and Node2D objects that cannot
## use CharacterBody2D.move_and_slide(). The mover is swept as a circle against
## terrain bodies, then the remaining motion is slid along the contact normal.

const DEFAULT_TERRAIN_MASK: int = 1
const MIN_MOTION_SQUARED: float = 0.000001
const SAFE_FRACTION_BACKOFF: float = 0.001


static func move_circle(
		mover: Node2D,
		motion: Vector2,
		radius: float,
		collision_mask: int = DEFAULT_TERRAIN_MASK,
		margin: float = 1.5,
		max_slides: int = 2,
	) -> Dictionary:
	var result: Dictionary = {
		&"motion": Vector2.ZERO,
		&"blocked": false,
		&"normal": Vector2.ZERO,
		&"started_overlapping": false,
	}
	if mover == null or motion.length_squared() <= MIN_MOTION_SQUARED:
		return result

	var world: World2D = mover.get_world_2d()
	if world == null:
		mover.global_position += motion
		result[&"motion"] = motion
		return result

	var shape := CircleShape2D.new()
	var global_scale: Vector2 = mover.global_transform.get_scale()
	var scale_factor: float = maxf(absf(global_scale.x), absf(global_scale.y))
	shape.radius = maxf(1.0, radius * maxf(0.001, scale_factor))

	var space_state: PhysicsDirectSpaceState2D = world.direct_space_state
	var remaining_motion: Vector2 = motion
	var total_motion: Vector2 = Vector2.ZERO
	var excluded_rids: Array[RID] = []
	var collision_object: CollisionObject2D = mover as CollisionObject2D
	if collision_object != null:
		excluded_rids.append(collision_object.get_rid())

	for _slide_index: int in range(maxi(1, max_slides)):
		if remaining_motion.length_squared() <= MIN_MOTION_SQUARED:
			break

		var start_position: Vector2 = mover.global_position
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(mover.global_rotation, start_position)
		query.motion = remaining_motion
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.margin = maxf(0.0, margin)
		query.exclude = excluded_rids

		var fractions: PackedFloat32Array = space_state.cast_motion(query)
		var safe_fraction: float = 1.0
		var unsafe_fraction: float = 1.0
		if fractions.size() >= 2:
			safe_fraction = clampf(fractions[0], 0.0, 1.0)
			unsafe_fraction = clampf(fractions[1], safe_fraction, 1.0)

		if safe_fraction >= 0.9999:
			mover.global_position += remaining_motion
			total_motion += remaining_motion
			remaining_motion = Vector2.ZERO
			break

		result[&"blocked"] = true
		if safe_fraction <= 0.0001 and unsafe_fraction <= 0.0001:
			result[&"started_overlapping"] = true

		var travelled_fraction: float = maxf(0.0, safe_fraction - SAFE_FRACTION_BACKOFF)
		var travelled_motion: Vector2 = remaining_motion * travelled_fraction
		mover.global_position += travelled_motion
		total_motion += travelled_motion

		var contact_position: Vector2 = start_position + remaining_motion * unsafe_fraction
		var contact_query := PhysicsShapeQueryParameters2D.new()
		contact_query.shape = shape
		contact_query.transform = Transform2D(mover.global_rotation, contact_position)
		contact_query.collision_mask = collision_mask
		contact_query.collide_with_bodies = true
		contact_query.collide_with_areas = false
		contact_query.margin = maxf(0.0, margin)
		contact_query.exclude = excluded_rids

		var rest_info: Dictionary = space_state.get_rest_info(contact_query)
		var contact_normal: Vector2 = rest_info.get("normal", Vector2.ZERO)
		if contact_normal.length_squared() <= MIN_MOTION_SQUARED:
			contact_normal = -remaining_motion.normalized()
		else:
			contact_normal = contact_normal.normalized()
		result[&"normal"] = contact_normal

		var untravelled_motion: Vector2 = remaining_motion * (1.0 - safe_fraction)
		remaining_motion = untravelled_motion.slide(contact_normal)

	result[&"motion"] = total_motion
	return result
