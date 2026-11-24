class_name WorldGrid
extends RefCounted

## Layered tile world: land parcel ownership, O(1) structure occupancy index,
## and reserved water_pipes & power_poles layers for upcoming utility expansions.

var owned_parcels: Dictionary = {} # Vector2i -> true
var structures: Dictionary = {}    # Vector2i -> String ("plot:id", "lot:id", "deco:id")
var water_pipes: Dictionary = {}   # Reserved for Water Network phase
var power_poles: Dictionary = {}   # Reserved for Power Grid phase
var version: int = 0


func reset_ownership(parcels: Array) -> void:
	owned_parcels.clear()
	for p in parcels:
		owned_parcels[p] = true
	version += 1


func is_parcel_owned(px: int, pz: int) -> bool:
	return owned_parcels.has(Vector2i(px, pz))


func is_cell_owned(cell: Vector2i) -> bool:
	if not OutpostLayout.is_cell_in_map(cell.x, cell.y):
		return false
	var parcel := OutpostLayout.parcel_of(cell.x, cell.y)
	return owned_parcels.has(parcel)


func is_parcel_purchasable(p: Vector2i) -> bool:
	if not OutpostLayout.is_parcel_in_map(p.x, p.y):
		return false
	if owned_parcels.has(p):
		return false
	for n in OutpostLayout.neighbors4(p):
		if owned_parcels.has(n):
			return true
	return false


func purchasable_parcels() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for px in range(OutpostLayout.PARCEL_COUNT_X):
		for pz in range(OutpostLayout.PARCEL_COUNT_Z):
			var p := Vector2i(px, pz)
			if is_parcel_purchasable(p):
				result.append(p)
	return result


func next_parcel_price() -> float:
	var extra := maxi(0, owned_parcels.size() - OutpostLayout.STARTER_PARCELS.size())
	var raw := 120.0 * pow(1.4, float(extra))
	return round(raw / 5.0) * 5.0


func buy_parcel(p: Vector2i) -> bool:
	if not is_parcel_purchasable(p):
		return false
	owned_parcels[p] = true
	version += 1
	return true


func rebuild_occupancy(plots: Array, parking_lots: Array, decorations: Array) -> void:
	structures.clear()
	for p in plots:
		if not p["is_built"]:
			continue
		for c in _rect_cells(p["grid_x"], p["grid_z"], GameCatalog.BUSINESSES[p["type"]]["grid_w"], GameCatalog.BUSINESSES[p["type"]]["grid_d"], p["rot"]):
			structures[c] = "plot:%s" % p["id"]
	for l in parking_lots:
		var spec: Dictionary = GameCatalog.PARKING_LOTS[l["kind"]]
		for c in _rect_cells(l["grid_x"], l["grid_z"], spec["grid_w"], spec["grid_d"], l["rot"]):
			structures[c] = "lot:%s" % l["id"]
	for d in decorations:
		structures[Vector2i(d["grid_x"], d["grid_z"])] = "deco:%s" % d["id"]
	version += 1


static func _rect_cells(gx: int, gz: int, base_w: int, base_d: int, rot: int) -> Array[Vector2i]:
	var sz := OutpostLayout.rotated_size(base_w, base_d, rot)
	var out: Array[Vector2i] = []
	for dx in range(sz.x):
		for dz in range(sz.y):
			out.append(Vector2i(gx + dx, gz + dz))
	return out


func is_occupied(cell: Vector2i) -> bool:
	return structures.has(cell)


func is_occupied_except(cell: Vector2i, ignore_id: String) -> bool:
	if not structures.has(cell):
		return false
	return ignore_id.is_empty() or structures[cell] != ignore_id
