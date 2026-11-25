class_name WorldGrid
extends RefCounted

## Layered tile world:
## - Land parcel ownership + deterministic parcel resource traits (Oil Seep, Aquifer, Wind, Scenic, Highway)
## - O(1) surface structure occupancy index
## - Multi-layer utility grids: overhead power poles, underground power conduits, water pipes, and scenic/appeal cache.

var owned_parcels: Dictionary = {}     # Vector2i -> true
var parcel_traits: Dictionary = {}     # Vector2i -> int (GameCatalog.ParcelTrait)
var structures: Dictionary = {}        # Vector2i -> String ("plot:id", "lot:id", "util:id", "deco:id")
var power_poles: Dictionary = {}       # Vector2i -> Dictionary (overhead poles/towers)
var power_underground: Dictionary = {} # Vector2i -> Dictionary (buried cables; allowed under roads/props)
var water_pipes: Dictionary = {}       # Vector2i -> Dictionary (buried water pipes; allowed under roads/props)
var appeal_map: Dictionary = {}        # Vector2i -> float (cached scenic/noise modifier)
var version: int = 0


func _init() -> void:
	_init_parcel_traits()


func _init_parcel_traits() -> void:
	parcel_traits.clear()
	var oil_parcels: Array[Vector2i] = [
		Vector2i(1, 5),
		Vector2i(6, 5),
		Vector2i(0, 3),
		Vector2i(7, 4),
	]
	var aquifer_parcels: Array[Vector2i] = [
		Vector2i(5, 6),
		Vector2i(2, 4),
		Vector2i(3, 3),
		Vector2i(6, 2),
	]
	var wind_extra: Array[Vector2i] = [
		Vector2i(1, 1),
		Vector2i(6, 1),
	]

	for px in range(OutpostLayout.PARCEL_COUNT_X):
		for pz in range(OutpostLayout.PARCEL_COUNT_Z):
			var p := Vector2i(px, pz)
			if OutpostLayout.STARTER_PARCELS.has(p):
				parcel_traits[p] = GameCatalog.ParcelTrait.NONE
			elif oil_parcels.has(p):
				parcel_traits[p] = GameCatalog.ParcelTrait.OIL_SEEP
			elif aquifer_parcels.has(p):
				parcel_traits[p] = GameCatalog.ParcelTrait.AQUIFER
			elif pz == OutpostLayout.PARCEL_COUNT_Z - 1 and px >= 1 and px <= OutpostLayout.PARCEL_COUNT_X - 2:
				parcel_traits[p] = GameCatalog.ParcelTrait.HIGHWAY_PRIME
			elif px == 0 or px == OutpostLayout.PARCEL_COUNT_X - 1 or wind_extra.has(p):
				parcel_traits[p] = GameCatalog.ParcelTrait.WIND_CORRIDOR
			elif pz <= 1:
				parcel_traits[p] = GameCatalog.ParcelTrait.SCENIC_MESA
			else:
				parcel_traits[p] = GameCatalog.ParcelTrait.NONE


func parcel_trait(p: Vector2i) -> int:
	return int(parcel_traits.get(p, GameCatalog.ParcelTrait.NONE))


func cell_trait(cell: Vector2i) -> int:
	if not OutpostLayout.is_cell_in_map(cell.x, cell.y):
		return GameCatalog.ParcelTrait.NONE
	return parcel_trait(OutpostLayout.parcel_of(cell.x, cell.y))


func parcels_with_trait(trait_id: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: Vector2i in parcel_traits.keys():
		if int(parcel_traits[p]) == trait_id:
			out.append(p)
	return out


func is_parcel_trait_revealed(p: Vector2i) -> bool:
	return owned_parcels.has(p) or is_parcel_purchasable(p)


func reset_ownership(parcels: Array) -> void:
	owned_parcels.clear()
	for p in parcels:
		owned_parcels[p] = true
	version += 1


func clear_utilities() -> void:
	power_poles.clear()
	power_underground.clear()
	water_pipes.clear()
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


func rebuild_occupancy(plots: Array, parking_lots: Array, decorations: Array, utilities: Array = []) -> void:
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
	for u in utilities:
		var uw := int(u.get("grid_w", 1))
		var ud := int(u.get("grid_d", 1))
		var urot := int(u.get("rot", 0))
		for c in _rect_cells(int(u["grid_x"]), int(u["grid_z"]), uw, ud, urot):
			structures[c] = "util:%s" % str(u["id"])
	for d in decorations:
		structures[Vector2i(d["grid_x"], d["grid_z"])] = "deco:%s" % d["id"]
	for cell: Vector2i in power_poles.keys():
		if not structures.has(cell):
			structures[cell] = "pole:%d,%d" % [cell.x, cell.y]
	_rebuild_appeal_cache(decorations, utilities)
	version += 1


func _rebuild_appeal_cache(decorations: Array, utilities: Array = []) -> void:
	appeal_map.clear()
	for d in decorations:
		var dc := Vector2i(int(d["grid_x"]), int(d["grid_z"]))
		var bonus := 0.08 if (int(d["kind"]) == GameCatalog.DecorationKind.PICNIC_SET or int(d["kind"]) == GameCatalog.DecorationKind.CAMPFIRE_RING) else 0.04
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var cell := Vector2i(dc.x + dx, dc.y + dz)
				if abs(dx) + abs(dz) <= 2:
					appeal_map[cell] = float(appeal_map.get(cell, 0.0)) + bonus
	for u in utilities:
		var ukind: int = int(u.get("kind", -1))
		var spec: Dictionary = GameCatalog.UTILITIES.get(ukind, {})
		var nrad: int = int(spec.get("noise_radius", 0))
		if nrad > 0:
			var uc := Vector2i(int(u["grid_x"]), int(u["grid_z"]))
			for dx in range(-nrad, nrad + 1):
				for dz in range(-nrad, nrad + 1):
					if abs(dx) + abs(dz) <= nrad:
						var cell := Vector2i(uc.x + dx, uc.y + dz)
						appeal_map[cell] = float(appeal_map.get(cell, 0.0)) - 0.10
	for pcell: Vector2i in power_poles.keys():
		var meta: Dictionary = power_poles[pcell]
		var pkind: int = int(meta.get("kind", GameCatalog.PowerLineKind.WOOD_POLE))
		var pen := float(GameCatalog.POWER_LINES.get(pkind, {}).get("scenic_penalty", 0.04))
		if pen > 0.0:
			for nb in OutpostLayout.neighbors4(pcell):
				appeal_map[nb] = float(appeal_map.get(nb, 0.0)) - pen


func tile_appeal(cell: Vector2i) -> float:
	var base := float(appeal_map.get(cell, 0.0))
	if cell_trait(cell) == GameCatalog.ParcelTrait.SCENIC_MESA:
		base += 0.20
	return base


# --- Multi-layer utility API (ready for Power & Water phases) ---

func can_place_underground_utility(cell: Vector2i) -> bool:
	return OutpostLayout.is_cell_in_map(cell.x, cell.y) and is_cell_owned(cell)


func set_power_pole(cell: Vector2i, meta: Dictionary = {}) -> void:
	power_poles[cell] = meta
	version += 1


func remove_power_pole(cell: Vector2i) -> void:
	if power_poles.erase(cell):
		version += 1


func has_power_pole(cell: Vector2i) -> bool:
	return power_poles.has(cell)


func set_underground_power(cell: Vector2i, meta: Dictionary = {}) -> void:
	power_underground[cell] = meta
	version += 1


func remove_underground_power(cell: Vector2i) -> void:
	if power_underground.erase(cell):
		version += 1


func has_underground_power(cell: Vector2i) -> bool:
	return power_underground.has(cell)


func set_water_pipe(cell: Vector2i, meta: Dictionary = {}) -> void:
	water_pipes[cell] = meta
	version += 1


func remove_water_pipe(cell: Vector2i) -> void:
	if water_pipes.erase(cell):
		version += 1


func has_water_pipe(cell: Vector2i) -> bool:
	return water_pipes.has(cell)


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
