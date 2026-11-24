class_name RoadNetwork
extends RefCounted

## Player-built desert road grid, contiguous highway junction counter,
## auto-detected parking entry sides, BFS route scoring & A* visitor pathfinding.

var tiles: Dictionary = {} # Vector2i -> int (GameCatalog.RoadTier)
var _dist_from_hw: Dictionary = {} # Vector2i -> int
var _parent: Dictionary = {}       # Vector2i -> Variant (Vector2i or null)
var _path_min_tier: Dictionary = {} # Vector2i -> int
var version: int = 0


func clear() -> void:
	tiles.clear()
	_dist_from_hw.clear()
	_parent.clear()
	_path_min_tier.clear()
	version += 1


func has_road(cell: Vector2i) -> bool:
	return tiles.has(cell)


func tile_tier(cell: Vector2i) -> int:
	return tiles.get(cell, -1)


func road_count() -> int:
	return tiles.size()


func paved_road_count() -> int:
	var n := 0
	for t in tiles.values():
		if t == GameCatalog.RoadTier.PAVED:
			n += 1
	return n


func gravel_or_better_count() -> int:
	var n := 0
	for t in tiles.values():
		if t >= GameCatalog.RoadTier.GRAVEL:
			n += 1
	return n


func set_tile(cell: Vector2i, tier: int) -> void:
	tiles[cell] = tier
	version += 1


func remove_tile(cell: Vector2i) -> int:
	if not tiles.has(cell):
		return -1
	var old_tier: int = tiles[cell]
	tiles.erase(cell)
	version += 1
	return old_tier


func is_connected_to_highway(cell: Vector2i) -> bool:
	return _dist_from_hw.has(cell)


func highway_turn_off_count() -> int:
	var xs: Array[int] = []
	for c: Vector2i in tiles.keys():
		if c.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z:
			xs.append(c.x)
	return _count_contiguous_runs(xs)


func highway_turn_off_count_with(extra: Array[Vector2i]) -> int:
	var xset: Dictionary = {}
	for c: Vector2i in tiles.keys():
		if c.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z:
			xset[c.x] = true
	for c in extra:
		if c.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z:
			xset[c.x] = true
	var xs: Array[int] = []
	for k in xset.keys():
		xs.append(int(k))
	return _count_contiguous_runs(xs)


static func _count_contiguous_runs(xs: Array[int]) -> int:
	xs.sort()
	var runs := 0
	var prev := -999999
	for x in xs:
		if prev == -999999 or x != prev + 1:
			runs += 1
		prev = x
	return runs


static func line_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var dx := b.x - a.x
	var dz := b.y - a.y
	var sx := signi(dx)
	var sz := signi(dz)
	if absi(dx) >= absi(dz):
		for i in range(absi(dx) + 1):
			cells.append(Vector2i(a.x + i * sx, a.y))
		for j in range(1, absi(dz) + 1):
			cells.append(Vector2i(b.x, a.y + j * sz))
	else:
		for j in range(absi(dz) + 1):
			cells.append(Vector2i(a.x, a.y + j * sz))
		for i in range(1, absi(dx) + 1):
			cells.append(Vector2i(a.x + i * sx, b.y))
	return cells


static func offset_path_right(pts: Array[Vector3], offset: float) -> Array[Vector3]:
	if pts.size() < 2:
		return pts.duplicate()
	var out: Array[Vector3] = []
	for i in range(pts.size()):
		var prev := pts[i - 1] if i > 0 else pts[i]
		var nxt := pts[i + 1] if i < pts.size() - 1 else pts[i]
		var dx := nxt.x - prev.x
		var dz := nxt.z - prev.z
		var length := sqrt(dx * dx + dz * dz)
		if length < 1e-6:
			out.append(pts[i])
			continue
		dx /= length
		dz /= length
		out.append(Vector3(pts[i].x - dz * offset, pts[i].y, pts[i].z + dx * offset))
	return out


func recompute(plots: Array, parking_lots: Array, decorations: Array) -> void:
	_dist_from_hw.clear()
	_parent.clear()
	_path_min_tier.clear()

	# 1. Multi-source BFS from Route 163 entry row
	var queue: Array[Vector2i] = []
	var head := 0
	for c: Vector2i in tiles.keys():
		if c.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z:
			_dist_from_hw[c] = 0
			_parent[c] = null
			_path_min_tier[c] = tiles[c]
			queue.append(c)

	while head < queue.size():
		var cur := queue[head]
		head += 1
		var cur_dist: int = _dist_from_hw[cur]
		var cur_tier: int = _path_min_tier[cur]
		for nxt in OutpostLayout.neighbors4(cur):
			if not tiles.has(nxt):
				continue
			var nxt_tier := mini(cur_tier, int(tiles[nxt]))
			var nxt_dist := cur_dist + 1
			var better := not _dist_from_hw.has(nxt) or nxt_dist < int(_dist_from_hw[nxt]) or (nxt_dist == int(_dist_from_hw[nxt]) and nxt_tier > int(_path_min_tier[nxt]))
			if better:
				_dist_from_hw[nxt] = nxt_dist
				_parent[nxt] = cur
				_path_min_tier[nxt] = nxt_tier
				queue.append(nxt)

	# 2. Evaluate connectivity & road-facing bay side for every parking lot
	for lot in parking_lots:
		var spec: Dictionary = GameCatalog.PARKING_LOTS[lot["kind"]]
		var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], lot["rot"])
		var gx: int = lot["grid_x"]
		var gz: int = lot["grid_z"]
		var directly_hw := false
		for dz in range(sz.y):
			if gz + dz == OutpostLayout.HIGHWAY_ENTRY_ROW_Z:
				directly_hw = true
				break

		var side_checks := [
			[GameCatalog.LotEntrySide.SOUTH, _side_cells_x(gx, sz.x, gz + sz.y)],
			[GameCatalog.LotEntrySide.NORTH, _side_cells_x(gx, sz.x, gz - 1)],
			[GameCatalog.LotEntrySide.EAST, _side_cells_z(gx + sz.x, gz, sz.y)],
			[GameCatalog.LotEntrySide.WEST, _side_cells_z(gx - 1, gz, sz.y)],
		]
		var best_side := -1
		var best_adj := Vector2i(9999, 9999)
		var best_contacts := 0
		var best_dist := 999
		var best_tier := 0

		for sc in side_checks:
			var side: int = sc[0]
			var border: Array = sc[1]
			var contacts := 0
			var side_best := Vector2i(9999, 9999)
			var side_dist := 999
			var side_tier := 0
			for rc: Vector2i in border:
				if not _dist_from_hw.has(rc):
					continue
				contacts += 1
				var d: int = _dist_from_hw[rc]
				var t: int = _path_min_tier.get(rc, 0)
				if d < side_dist or (d == side_dist and t > side_tier):
					side_dist = d
					side_best = rc
					side_tier = t
			if contacts == 0:
				continue
			if contacts > best_contacts or (contacts == best_contacts and side_dist < best_dist) or (contacts == best_contacts and side_dist == best_dist and side_tier > best_tier):
				best_contacts = contacts
				best_side = side
				best_adj = side_best
				best_dist = side_dist
				best_tier = side_tier

		if best_side != -1:
			lot["is_connected"] = true
			lot["connected_side"] = best_side
			lot["drive_in_path"] = _reconstruct_world_path(best_adj)
		elif directly_hw:
			lot["is_connected"] = true
			lot["connected_side"] = GameCatalog.LotEntrySide.SOUTH
			var pos := OutpostLayout.footprint_center(gx, gz, sz.x, sz.y)
			lot["drive_in_path"] = [Vector3(pos.x, 0.0, OutpostLayout.PARKING_AISLE_Z)]
		else:
			lot["is_connected"] = false
			lot["connected_side"] = -1
			lot["drive_in_path"] = []

	# 3. Evaluate RoadAccessReport for every built store
	var sign_bonus := _compute_sign_bonus(decorations)
	for p in plots:
		if not p["is_built"]:
			p["access"] = disconnected_report()
		else:
			p["access"] = evaluate_building_access(p["type"], p["grid_x"], p["grid_z"], p["rot"], parking_lots, sign_bonus)


static func _side_cells_x(gx: int, w: int, z: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(w):
		out.append(Vector2i(gx + dx, z))
	return out


static func _side_cells_z(x: int, gz: int, d: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dz in range(d):
		out.append(Vector2i(x, gz + dz))
	return out


static func disconnected_report() -> Dictionary:
	return {
		"score": 0.0,
		"has_highway": false,
		"has_direct_road": false,
		"frontage_aligned": false,
		"has_parking": false,
		"road_tier": -1,
		"road_steps": 999,
		"walk_steps": 999,
		"scenic_bonus": false,
		"highway_bonus": false,
		"status_label": "NO ROAD",
		"hint": "Connect road & parking from Route 163",
		"route_preview": [],
	}


func evaluate_building_access(btype: int, gx: int, gz: int, rot: int, parking_lots: Array, sign_bonus: float = 0.0) -> Dictionary:
	var data: Dictionary = GameCatalog.BUSINESSES[btype]
	var sz := OutpostLayout.rotated_size(data["grid_w"], data["grid_d"], rot)
	var w := sz.x
	var d := sz.y
	var footprint: Dictionary = {}
	for dx in range(w):
		for dz in range(d):
			footprint[Vector2i(gx + dx, gz + dz)] = true

	var entrance: Vector2i
	match rot & 3:
		0: entrance = Vector2i(gx + int(w / 2), gz + d)
		1: entrance = Vector2i(gx - 1, gz + int(d / 2))
		2: entrance = Vector2i(gx + int(w / 2), gz - 1)
		_: entrance = Vector2i(gx + w, gz + int(d / 2))

	var perimeter: Dictionary = {}
	for c: Vector2i in footprint.keys():
		for n in OutpostLayout.neighbors4(c):
			if not footprint.has(n):
				perimeter[n] = true

	var has_best_road := false
	var best_road_cell := Vector2i.ZERO
	var frontage_aligned := false
	var best_road_dist := 999
	var best_road_tier := -1

	if _dist_from_hw.has(entrance):
		has_best_road = true
		best_road_cell = entrance
		frontage_aligned = true
		best_road_dist = _dist_from_hw[entrance]
		best_road_tier = _path_min_tier.get(entrance, 0)
	else:
		for p: Vector2i in perimeter.keys():
			if not _dist_from_hw.has(p):
				continue
			var dist: int = _dist_from_hw[p]
			var t: int = _path_min_tier.get(p, 0)
			var is_front := false
			match rot & 3:
				0: is_front = p.y == gz + d
				1: is_front = p.x == gx - 1
				2: is_front = p.y == gz - 1
				_: is_front = p.x == gx + w
			if not has_best_road or (is_front and not frontage_aligned) or (is_front == frontage_aligned and dist < best_road_dist):
				has_best_road = true
				best_road_cell = p
				frontage_aligned = is_front
				best_road_dist = dist
				best_road_tier = t

	var active_lots: Array = []
	for l in parking_lots:
		if l["is_connected"]:
			active_lots.append(l)

	if active_lots.is_empty():
		return {
			"score": 0.0,
			"has_highway": has_best_road,
			"has_direct_road": has_best_road,
			"frontage_aligned": frontage_aligned,
			"has_parking": false,
			"road_tier": best_road_tier,
			"road_steps": best_road_dist,
			"walk_steps": 999,
			"scenic_bonus": false,
			"highway_bonus": false,
			"status_label": "NEED LOT" if has_best_road else "NO ROAD",
			"hint": "Place a Parking Lot along your road" if has_best_road else "Connect road & parking lot from Route 163",
			"route_preview": _reconstruct_world_path(best_road_cell) if has_best_road else [],
		}

	var nearest_lot = null
	var best_walk := 999
	for l in active_lots:
		var spec: Dictionary = GameCatalog.PARKING_LOTS[l["kind"]]
		var lsz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], l["rot"])
		var min_d := 999
		for dx in range(lsz.x):
			for dz in range(lsz.y):
				var md := OutpostLayout.manhattan(Vector2i(l["grid_x"] + dx, l["grid_z"] + dz), entrance)
				if md < min_d:
					min_d = md
		if min_d < best_walk:
			best_walk = min_d
			nearest_lot = l

	var close_sand := nearest_lot != null and best_walk <= 3
	if not has_best_road and not close_sand:
		return {
			"score": 0.0,
			"has_highway": false,
			"has_direct_road": false,
			"frontage_aligned": false,
			"has_parking": false,
			"road_tier": -1,
			"road_steps": 999,
			"walk_steps": best_walk,
			"scenic_bonus": false,
			"highway_bonus": false,
			"status_label": "NO ROAD",
			"hint": "Paint a road from Route 163 to this store",
			"route_preview": [],
		}

	var frontage_factor := (1.0 if frontage_aligned else 0.80) if has_best_road else 0.48
	var eff_tier := best_road_tier
	if eff_tier < 0:
		match nearest_lot["kind"]:
			GameCatalog.ParkingLotKind.PAVED_LOT: eff_tier = GameCatalog.RoadTier.PAVED
			GameCatalog.ParkingLotKind.GRAVEL_LOT: eff_tier = GameCatalog.RoadTier.GRAVEL
			_: eff_tier = GameCatalog.RoadTier.DIRT

	var surface_factor: float = GameCatalog.ROAD_TIERS[eff_tier]["access_factor"] if has_best_road else 0.72
	var road_steps := best_road_dist if has_best_road else 1
	var decay := 0.006 if eff_tier == GameCatalog.RoadTier.PAVED else (0.012 if eff_tier == GameCatalog.RoadTier.GRAVEL else 0.02)
	var dist_factor := 1.0 if road_steps <= 24 else clampf(1.0 - float(road_steps - 24) * decay, 0.6, 1.0)
	var park_factor := 1.0 if best_walk <= 4 else (0.82 if best_walk <= 7 else 0.62)

	var scenic_bonus: bool = data["prefers_scenic"] and gz <= OutpostLayout.SCENIC_ROW_MAX
	var highway_bonus: bool = data["prefers_highway"] and (gz + d - 1) >= OutpostLayout.HIGHWAY_BONUS_ROW_MIN
	var loop_bonus := 0.08 if highway_turn_off_count() >= 2 else 0.0

	var raw_score := frontage_factor * surface_factor * dist_factor * park_factor + (0.15 if scenic_bonus else 0.0) + (0.10 if highway_bonus else 0.0) + loop_bonus + sign_bonus
	var final_score := clampf(raw_score, 0.15, 1.35)
	var pct := roundi(final_score * 100.0)

	var label := ""
	var hint := ""
	if not has_best_road:
		label = "SAND PATH %d%%" % pct
		hint = "Paint a road to the entrance for more customers"
	elif not frontage_aligned:
		label = "SIDE ACCESS %d%%" % pct
		hint = "Rotate entrance toward road for +20% flow"
	elif best_walk > 5:
		label = "FAR LOT %d%%" % pct
		hint = "Add a closer parking lot to boost traffic"
	elif final_score < 0.75:
		label = "DIRT ROAD %d%%" % pct
		hint = "Upgrade road to Gravel/Paved for faster traffic"
	elif final_score >= 0.98:
		label = "GREAT %d%%" % pct
		hint = "Scenic Mesa Bonus +15%!" if scenic_bonus else ("Highway Edge Bonus +10%!" if highway_bonus else "Peak highway access!")
	else:
		label = "GOOD %d%%" % pct
		hint = "Strong road & parking access"

	var store_center := OutpostLayout.footprint_center(gx, gz, w, d)
	var route_preview: Array[Vector3] = []
	if has_best_road:
		route_preview.append_array(_reconstruct_world_path(best_road_cell))
		route_preview.append(store_center)
	elif nearest_lot != null:
		for pt in nearest_lot["drive_in_path"]:
			route_preview.append(pt)
		route_preview.append(store_center)

	return {
		"score": final_score,
		"has_highway": true,
		"has_direct_road": has_best_road,
		"frontage_aligned": frontage_aligned,
		"has_parking": true,
		"road_tier": eff_tier if has_best_road else -1,
		"road_steps": road_steps,
		"walk_steps": best_walk,
		"scenic_bonus": scenic_bonus,
		"highway_bonus": highway_bonus,
		"status_label": label,
		"hint": hint,
		"route_preview": route_preview,
	}


func build_visitor_walk_path(start_world: Vector3, dest_world: Vector3, blocked: Dictionary) -> Array[Vector3]:
	var s := OutpostLayout.world_to_cell(start_world)
	var g := OutpostLayout.world_to_cell(dest_world)
	s = Vector2i(clampi(s.x, OutpostLayout.MIN_GRID_X, OutpostLayout.MAX_GRID_X), clampi(s.y, OutpostLayout.MIN_GRID_Z, OutpostLayout.MAX_GRID_Z))
	g = Vector2i(clampi(g.x, OutpostLayout.MIN_GRID_X, OutpostLayout.MAX_GRID_X), clampi(g.y, OutpostLayout.MIN_GRID_Z, OutpostLayout.MAX_GRID_Z))
	if s == g:
		return [dest_world]

	const MARGIN := 8
	var min_x := maxi(OutpostLayout.MIN_GRID_X, mini(s.x, g.x) - MARGIN)
	var max_x := mini(OutpostLayout.MAX_GRID_X, maxi(s.x, g.x) + MARGIN)
	var min_z := maxi(OutpostLayout.MIN_GRID_Z, mini(s.y, g.y) - MARGIN)
	var max_z := mini(OutpostLayout.MAX_GRID_Z, maxi(s.y, g.y) + MARGIN)

	var g_score: Dictionary = {s: 0}
	var parent: Dictionary = {s: null}
	var open: Array = [[OutpostLayout.manhattan(s, g), s]]

	while not open.is_empty():
		var best_idx := 0
		for i in range(1, open.size()):
			if open[i][0] < open[best_idx][0]:
				best_idx = i
		var cur: Vector2i = open[best_idx][1]
		open.remove_at(best_idx)
		if cur == g:
			break
		var cur_cost: int = g_score[cur]
		for nxt in OutpostLayout.neighbors4(cur):
			if nxt.x < min_x or nxt.x > max_x or nxt.y < min_z or nxt.y > max_z:
				continue
			if nxt != g and blocked.has(nxt):
				continue
			var step_cost := 1 if tiles.has(nxt) else 3
			var nc := cur_cost + step_cost
			if nc < int(g_score.get(nxt, 1 << 29)):
				g_score[nxt] = nc
				parent[nxt] = cur
				open.append([nc + OutpostLayout.manhattan(nxt, g), nxt])

	if not parent.has(g):
		return [dest_world]

	var rev: Array[Vector2i] = []
	var cur_p = g
	while cur_p != null:
		rev.append(cur_p)
		cur_p = parent[cur_p]
	rev.reverse()
	var wps: Array[Vector3] = []
	for i in range(1, rev.size() - 1):
		wps.append(OutpostLayout.cell_center_v(rev[i]))
	wps.append(dest_world)
	return wps


func vehicle_speed_at(world_pos: Vector3) -> float:
	var c := OutpostLayout.world_to_cell(world_pos)
	if not tiles.has(c):
		return 3.8
	return float(GameCatalog.ROAD_TIERS[tiles[c]]["vehicle_speed"])


func _reconstruct_world_path(end_cell: Vector2i) -> Array[Vector3]:
	var rev: Array[Vector2i] = []
	var cur = end_cell
	var guard := 0
	while cur != null and guard < 256:
		guard += 1
		rev.append(cur)
		cur = _parent.get(cur, null)
	rev.reverse()
	if rev.is_empty():
		return []
	var pts: Array[Vector3] = [Vector3(OutpostLayout.cell_center_v(rev[0]).x, 0.0, OutpostLayout.HIGHWAY_NORTH_EDGE_Z)]
	for c in rev:
		pts.append(OutpostLayout.cell_center_v(c))
	return pts


func _compute_sign_bonus(decorations: Array) -> float:
	var signs := 0
	for d in decorations:
		if d["kind"] == GameCatalog.DecorationKind.WOODEN_SIGNPOST:
			signs += 1
	return minf(0.16, float(signs) * 0.08)
