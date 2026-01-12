class_name BlockRaycast extends RefCounted

# from https://github.com/murumart/gd-blockgame/blob/main/world/blocks/collision/block_raycast.gd

## Class that represents a raycast through the block world and provides static methods
## for instancing itself.

## The axis of the last traversal.
var xyz_axis: Vector3.Axis
## Whether the last traversal increased or decreased the last [member xyz_axis] axis coordinate.
var axis_direction: int = 0
## True if the raycast didn't find a block.
var failure := false
## Array of all traversed block world coordinates.
var steps_traversed: PackedVector3Array = []
## The block the raycast ended on. -1 if [member failure] is true.
var found_block: int = -1


## Returns the last traversed block, or what the raycast collided with.
func get_collision_point() -> Vector3:
	if steps_traversed.is_empty():
		return Vector3.ONE * -1
	return steps_traversed[steps_traversed.size() - 1]


static func fraction(x: float) -> float:
	return x - floorf(x)


## Casts a fast ray through the world and returns a [BlockRaycast] instance of the
## results.
## Based on the algoritm found [url=https://github.com/StanislavPetrovV/Minecraft/blob/main/voxel_handler.py]here[/url].
static func cast_ray_fast_vh(
		start_position: Vector3,
		direction: Vector3,
		max_distance: int,
		tex_data: PackedByteArray,
		tex_size: int,
) -> BlockRaycast:

	const BIGNUM = 999999999.0

	var rc := BlockRaycast.new()
	rc.failure = true

	if tex_data.is_empty():
		return rc

	var v1 := start_position
	var v2 := start_position + direction * max_distance

	var current_bpos := v1.floor()
	var step_dir := Vector3.AXIS_X
	var step_sign := 0

	var vd := Vector3(
		signf(v2.x - v1.x),
		signf(v2.y - v1.y),
		signf(v2.z - v1.z),
	)
	var vdelta := Vector3(
		minf(vd.x / (v2.x - v1.x), BIGNUM) if vd.x != 0 else BIGNUM,
		minf(vd.y / (v2.y - v1.y), BIGNUM) if vd.y != 0 else BIGNUM,
		minf(vd.z / (v2.z - v1.z), BIGNUM) if vd.z != 0 else BIGNUM,
	)
	var vmax := Vector3(
		vdelta.x * (1.0 - fraction(v1.x)) if vd.x > 0 else vdelta.x * fraction(v1.x),
		vdelta.y * (1.0 - fraction(v1.y)) if vd.y > 0 else vdelta.y * fraction(v1.y),
		vdelta.z * (1.0 - fraction(v1.z)) if vd.z > 0 else vdelta.z * fraction(v1.z),
	)

	while not (vmax.x > 1 and vmax.y > 1 and vmax.z > 1):
		if (current_bpos.x < 0 or current_bpos.x >= tex_size
			or current_bpos.y < 0 or current_bpos.y >= tex_size
			or current_bpos.z < 0 or current_bpos.z >= tex_size
		):
			# allow touching the floor of the area
			rc.steps_traversed.append(current_bpos)
			if (current_bpos.y == -1 and step_dir == Vector3.AXIS_Y and step_sign == -1
				and current_bpos.x >= 0 and current_bpos.x < tex_size
				and current_bpos.z >= 0 and current_bpos.z < tex_size
			):
				rc.found_block = 0
				rc.xyz_axis = step_dir
				rc.axis_direction = step_sign
				rc.failure = false
				return rc
		else:
			rc.steps_traversed.append(current_bpos)
			var resbid := tex_data[current_bpos.x + current_bpos.y * tex_size + current_bpos.z * tex_size * tex_size]
			if resbid != 0:
				rc.found_block = resbid
				rc.xyz_axis = step_dir
				rc.axis_direction = step_sign
				rc.failure = false
				return rc

		if vmax.x < vmax.y:
			if vmax.x < vmax.z:
				current_bpos.x += vd.x
				vmax.x += vdelta.x
				step_dir = Vector3.AXIS_X
				step_sign = sign(vd.x)
			else:
				current_bpos.z += vd.z
				vmax.z += vdelta.z
				step_dir = Vector3.AXIS_Z
				step_sign = sign(vd.z)
		else:
			if vmax.y < vmax.z:
				current_bpos.y += vd.y
				vmax.y += vdelta.y
				step_dir = Vector3.AXIS_Y
				step_sign = sign(vd.y)
			else:
				current_bpos.z += vd.z
				vmax.z += vdelta.z
				step_dir = Vector3.AXIS_Z
				step_sign = sign(vd.z)

	return rc


func _to_string() -> String:
	return ("BlockRaycast[ "
		+ "failure: " + str(failure)
		+ ", xyz_axis: " + str(xyz_axis)
		+ ", axis_direction: " + str(axis_direction)
		#+ ", position: " + str(position)
		+ ", found_block: " + str(found_block)
		+ ", steps_traversed: " + str(steps_traversed)
		+ " ]")
