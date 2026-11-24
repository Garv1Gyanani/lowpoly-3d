class_name OutpostLayout
extends RefCounted

## Shared spatial layout for the open-desert outpost world:
## 64 x 64 tile buildable map (2 world units per tile) north of Route 163,
## divided into 8 x 8 land parcels that the player buys to expand.

const HIGHWAY_CENTER_Z := 13.4
const HIGHWAY_WESTBOUND_Z := 12.5
const HIGHWAY_EASTBOUND_Z := 14.3
const HIGHWAY_NORTH_EDGE_Z := 11.1
const PARKING_AISLE_Z := 10.95

const GRID_CELL_SIZE := 2.0
const MIN_GRID_X := -32
const MAX_GRID_X := 31
const MIN_GRID_Z := -58
const MAX_GRID_Z := 5
const HIGHWAY_ENTRY_ROW_Z := 5

const PARCEL_SIZE := 8
const PARCEL_COUNT_X := 8
const PARCEL_COUNT_Z := 8
const STARTER_PARCELS: Array[Vector2i] = [Vector2i(3, 5), Vector2i(4, 5)]

const SCENIC_ROW_MAX := -35
const HIGHWAY_BONUS_ROW_MIN := -1

const WORLD_MIN_X := (MIN_GRID_X - 0.5) * GRID_CELL_SIZE
const WORLD_MAX_X := (MAX_GRID_X + 0.5) * GRID_CELL_SIZE
const WORLD_MIN_Z := (MIN_GRID_Z - 0.5) * GRID_CELL_SIZE
const WORLD_MAX_Z := (MAX_GRID_Z + 0.5) * GRID_CELL_SIZE


static func cell_center(gx: int, gz: int) -> Vector3:
	return Vector3(gx * GRID_CELL_SIZE, 0.0, gz * GRID_CELL_SIZE)


static func cell_center_v(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * GRID_CELL_SIZE, 0.0, cell.y * GRID_CELL_SIZE)


static func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(world_pos.x / GRID_CELL_SIZE), roundi(world_pos.z / GRID_CELL_SIZE))


static func is_cell_in_map(gx: int, gz: int) -> bool:
	return gx >= MIN_GRID_X and gx <= MAX_GRID_X and gz >= MIN_GRID_Z and gz <= MAX_GRID_Z


static func parcel_of(gx: int, gz: int) -> Vector2i:
	return Vector2i(
		floori(float(gx - MIN_GRID_X) / float(PARCEL_SIZE)),
		floori(float(gz - MIN_GRID_Z) / float(PARCEL_SIZE))
	)


static func is_parcel_in_map(px: int, pz: int) -> bool:
	return px >= 0 and px < PARCEL_COUNT_X and pz >= 0 and pz < PARCEL_COUNT_Z


static func parcel_cell_bounds(px: int, pz: int) -> Rect2i:
	var min_gx := MIN_GRID_X + px * PARCEL_SIZE
	var min_gz := MIN_GRID_Z + pz * PARCEL_SIZE
	return Rect2i(min_gx, min_gz, PARCEL_SIZE, PARCEL_SIZE)


static func parcel_center(px: int, pz: int) -> Vector3:
	var min_gx := MIN_GRID_X + px * PARCEL_SIZE
	var min_gz := MIN_GRID_Z + pz * PARCEL_SIZE
	var max_gx := min_gx + PARCEL_SIZE - 1
	var max_gz := min_gz + PARCEL_SIZE - 1
	return Vector3(
		(min_gx + max_gx) * 0.5 * GRID_CELL_SIZE,
		0.0,
		(min_gz + max_gz) * 0.5 * GRID_CELL_SIZE
	)


static func footprint_center(gx: int, gz: int, w_cells: int, d_cells: int) -> Vector3:
	var cx := (gx + (w_cells - 1) * 0.5) * GRID_CELL_SIZE
	var cz := (gz + (d_cells - 1) * 0.5) * GRID_CELL_SIZE
	return Vector3(cx, 0.0, cz)


static func rotated_size(base_w: int, base_d: int, rotation_quarter: int) -> Vector2i:
	var r := rotation_quarter & 3
	if r == 1 or r == 3:
		return Vector2i(base_d, base_w)
	return Vector2i(base_w, base_d)


static func yaw_for_quarter_turn(rotation_quarter: int) -> float:
	return float(rotation_quarter & 3) * (PI * 0.5)


static func forward_step_for_quarter_turn(rotation_quarter: int) -> Vector2i:
	match rotation_quarter & 3:
		0:
			return Vector2i(0, 1)
		1:
			return Vector2i(-1, 0)
		2:
			return Vector2i(0, -1)
		_:
			return Vector2i(1, 0)


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func neighbors4(c: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(c.x + 1, c.y),
		Vector2i(c.x - 1, c.y),
		Vector2i(c.x, c.y + 1),
		Vector2i(c.x, c.y - 1),
	]
