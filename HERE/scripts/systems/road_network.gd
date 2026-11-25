class_name RoadNetwork
extends RefCounted

## Player-built desert road grid, contiguous highway junction counter,
## auto-detected parking entry sides, BFS route scoring & A* visitor pathfinding.

const TWO_LANE_OFFSET := 0.86
const ONE_LANE_OFFSET := 0.42

var tiles: Dictionary = {} # Vector2i -> int (GameCatalog.RoadTier)
var _dist_from_hw: Dictionary = {} # Vector2i -> int
var _parent: Dictionary = {}       # Vector2i -> Variant (Vector2i or null)
var _path_min_tier: Dictionary = {} # Vector2i -> int
var _junction_clusters: Array[Dictionary] = [] # [{"cells": Array[Vector2i], "center_x": float, "min_x": int, "max_x": int}]
var version: int = 0


func clear() -> void:
	tiles.clear()
	_dist_from_hw.clear()
	_parent.clear()
	_path_min_tier.clear()
	_junction_clusters.clear()
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


## Expands a start->end road line into a clean 2-cell-wide (4.0m) two-lane road corridor.
## Automatically picks the open side when hugging map boundaries or existing structures.
static func corridor_path(a: Vector2i, b: Vector2i, grid: WorldGrid = null, two_lane: bool = true) -> Array[Vector2i]:
	var spine := line_path(a, b)
	if not two_lane:
		return spine

	var seen: Dictionary = {}
	var out: Array[Vector2i] = []

	if spine.size() == 1:
		var c := spine[0]
		var ox := 1 if (c.x + 1 <= OutpostLayout.MAX_GRID_X and (grid == null or not grid.is_occupied(Vector2i(c.x + 1, c.y)))) else -1
		var oz := 1 if (c.y + 1 <= OutpostLayout.MAX_GRID_Z and (grid == null or not grid.is_occupied(Vector2i(c.x, c.y + 1)))) else -1
		for pt in [c, Vector2i(c.x + ox, c.y), Vector2i(c.x, c.y + oz), Vector2i(c.x + ox, c.y + oz)]:
			if not seen.has(pt):
				seen[pt] = true
				out.append(pt)
		return out

	# Partition spine into horizontal and vertical legs so each leg chooses a consistent side offset
	var horiz: Array[Vector2i] = []
	var vert: Array[Vector2i] = []
	for i in range(spine.size()):
		var cur := spine[i]
		var has_h := (i > 0 and spine[i - 1].y == cur.y) or (i + 1 < spine.size() and spine[i + 1].y == cur.y)
		var has_v := (i > 0 and spine[i - 1].x == cur.x) or (i + 1 < spine.size() and spine[i + 1].x == cur.x)
		if has_h:
			horiz.append(cur)
		if has_v:
			vert.append(cur)

	var h_off := 1
	if not horiz.is_empty():
		var plus_bad := 0
		var minus_bad := 0
		for c in horiz:
			var cp := Vector2i(c.x, c.y + 1)
			var cm := Vector2i(c.x, c.y - 1)
			if not OutpostLayout.is_cell_in_map(cp.x, cp.y) or (grid != null and grid.is_occupied(cp)):
				plus_bad += 1
			if not OutpostLayout.is_cell_in_map(cm.x, cm.y) or (grid != null and grid.is_occupied(cm)):
				minus_bad += 1
		h_off = -1 if plus_bad > minus_bad else 1

	var v_off := 1
	if not vert.is_empty():
		var plus_bad := 0
		var minus_bad := 0
		for c in vert:
			var cp := Vector2i(c.x + 1, c.y)
			var cm := Vector2i(c.x - 1, c.y)
			if not OutpostLayout.is_cell_in_map(cp.x, cp.y) or (grid != null and grid.is_occupied(cp)):
				plus_bad += 1
			if not OutpostLayout.is_cell_in_map(cm.x, cm.y) or (grid != null and grid.is_occupied(cm)):
				minus_bad += 1
		v_off = -1 if plus_bad > minus_bad else 1

	for c in horiz:
		for pt in [c, Vector2i(c.x, c.y + h_off)]:
			if not seen.has(pt):
				seen[pt] = true
				out.append(pt)
	for c in vert:
		for pt in [c, Vector2i(c.x + v_off, c.y)]:
			if not seen.has(pt):
				seen[pt] = true
				out.append(pt)

	# Fill the 2x2 outer corner tile where a horizontal leg meets a vertical leg
	if not horiz.is_empty() and not vert.is_empty():
		for c in spine:
			var in_h := horiz.has(c)
			var in_v := vert.has(c)
			if in_h and in_v:
				var corner := Vector2i(c.x + v_off, c.y + h_off)
				if not seen.has(corner):
					seen[corner] = true
					out.append(corner)
	return out


## Exact mitered right-hand lane offset (preserves true lane width around 90-degree corners).
static func offset_path_right(pts: Array[Vector3], offset: float) -> Array[Vector3]:
	var clean := _simplify_collinear(pts)
	if clean.size() < 2:
		return clean
	var out: Array[Vector3] = []
	for i in range(clean.size()):
		if i == 0:
			var d := _dir2(clean[0], clean[1])
			out.append(clean[0] + Vector3(-d.z, 0.0, d.x) * offset)
		elif i == clean.size() - 1:
			var d := _dir2(clean[i - 1], clean[i])
			out.append(clean[i] + Vector3(-d.z, 0.0, d.x) * offset)
		else:
			var d0 := _dir2(clean[i - 1], clean[i])
			var d1 := _dir2(clean[i], clean[i + 1])
			var n0 := Vector3(-d0.z, 0.0, d0.x)
			var n1 := Vector3(-d1.z, 0.0, d1.x)
			var denom := 1.0 + n0.dot(n1)
			if denom < 0.22:
				out.append(clean[i] + n0 * offset)
			else:
				var miter := (n0 + n1) / denom
				var mlen := miter.length()
				if mlen > 1.85:
					miter = miter / mlen * 1.85
				out.append(clean[i] + miter * offset)
	return out


## Rounds sharp polyline corners into smooth quadratic Bezier turning arcs.
static func smooth_path_corners(pts: Array[Vector3], corner_radius: float = 1.45, arc_steps: int = 3) -> Array[Vector3]:
	var clean := _simplify_collinear(pts)
	if clean.size() < 3:
		return clean
	var out: Array[Vector3] = [clean[0]]
	for i in range(1, clean.size() - 1):
		var p_prev := clean[i - 1]
		var p_cur := clean[i]
		var p_next := clean[i + 1]
		var v0 := p_prev - p_cur
		var v1 := p_next - p_cur
		var l0 := v0.length()
		var l1 := v1.length()
		if l0 < 0.15 or l1 < 0.15:
			out.append(p_cur)
			continue
		var d0 := v0 / l0
		var d1 := v1 / l1
		# Nearly straight -> skip rounding
		if d0.dot(d1) < -0.96:
			out.append(p_cur)
			continue
		var r := minf(corner_radius, minf(l0 * 0.44, l1 * 0.44))
		if r < 0.18:
			out.append(p_cur)
			continue
		var q0 := p_cur + d0 * r
		var q2 := p_cur + d1 * r
		for s in range(arc_steps + 1):
			var t := float(s) / float(arc_steps)
			var omt := 1.0 - t
			var pt := q0 * (omt * omt) + p_cur * (2.0 * omt * t) + q2 * (t * t)
			if out.is_empty() or out[out.size() - 1].distance_to(pt) > 0.08:
				out.append(pt)
	var last_pt: Vector3 = clean[clean.size() - 1]
	if out.is_empty() or out[out.size() - 1].distance_to(last_pt) > 0.08:
		out.append(last_pt)
	return out


static func _dir2(a: Vector3, b: Vector3) -> Vector3:
	var dx := b.x - a.x
	var dz := b.z - a.z
	var l := sqrt(dx * dx + dz * dz)
	if l < 1e-6:
		return Vector3(1.0, 0.0, 0.0)
	return Vector3(dx / l, 0.0, dz / l)


static func _simplify_collinear(pts: Array[Vector3]) -> Array[Vector3]:
	if pts.size() <= 2:
		return pts.duplicate()
	var dedup: Array[Vector3] = [pts[0]]
	for i in range(1, pts.size()):
		if pts[i].distance_to(dedup[dedup.size() - 1]) > 0.06:
			dedup.append(pts[i])
	if dedup.size() <= 2:
		return dedup
	var out: Array[Vector3] = [dedup[0]]
	for i in range(1, dedup.size() - 1):
		var d0 := _dir2(out[out.size() - 1], dedup[i])
		var d1 := _dir2(dedup[i], dedup[i + 1])
		if d0.dot(d1) < 0.996:
			out.append(dedup[i])
	out.append(dedup[dedup.size() - 1])
	return out


func highway_junction_clusters() -> Array[Dictionary]:
	return _junction_clusters


func _build_junction_clusters() -> void:
	_junction_clusters.clear()
	var xs: Array[int] = []
	for c: Vector2i in tiles.keys():
		if c.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z:
			xs.append(c.x)
	xs.sort()
	if xs.is_empty():
		return
	var run: Array[Vector2i] = []
	var prev := -999999
	for x in xs:
		if prev != -999999 and x != prev + 1:
			_append_cluster(run)
			run = []
		run.append(Vector2i(x, OutpostLayout.HIGHWAY_ENTRY_ROW_Z))
		prev = x
	if not run.is_empty():
		_append_cluster(run)


func _append_cluster(run: Array[Vector2i]) -> void:
	var min_x: int = run[0].x
	var max_x: int = run[run.size() - 1].x
	var cx := float(min_x + max_x) * 0.5 * OutpostLayout.GRID_CELL_SIZE
	_junction_clusters.append({
		"cells": run,
		"min_x": min_x,
		"max_x": max_x,
		"center_x": cx,
	})


## Returns whether a road cell belongs to a 2+ tile wide corridor along its travel axis.
func is_cell_two_lane(cell: Vector2i) -> bool:
	var has_n := tiles.has(Vector2i(cell.x, cell.y - 1))
	var has_s := tiles.has(Vector2i(cell.x, cell.y + 1)) or cell.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z
	var has_w := tiles.has(Vector2i(cell.x - 1, cell.y))
	var has_e := tiles.has(Vector2i(cell.x + 1, cell.y))
	if (has_n or has_s) and (has_w or has_e):
		return true
	return false


## Returns the ideal lane offset for a world position (wider on 2-lane roads, snug on 1-lane alleys).
func lane_offset_for_path(cells: Array[Vector2i]) -> float:
	if cells.is_empty():
		return TWO_LANE_OFFSET
	var wide_count := 0
	for c in cells:
		if is_cell_two_lane(c):
			wide_count += 1
	return TWO_LANE_OFFSET if wide_count * 2 >= cells.size() else ONE_LANE_OFFSET


func recompute(plots: Array, parking_lots: Array, decorations: Array) -> void:
	_dist_from_hw.clear()
	_parent.clear()
	_path_min_tier.clear()
	_build_junction_clusters()

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
			lot["entry_road_cell"] = best_adj
			var primary_cells := _reconstruct_cells(best_adj)
			lot["lane_offset"] = lane_offset_for_path(primary_cells)
			lot["drive_in_path"] = _cells_to_corridor_world_path(primary_cells)
			# Also compute routes from every reachable highway junction for multi-junction loop flow
			var multi_routes: Array[Dictionary] = []
			for cl in _junction_clusters:
				var j_cells := _bfs_cells_from_sources(cl["cells"], best_adj)
				if not j_cells.is_empty():
					multi_routes.append({
						"entry_x": float(cl["center_x"]),
						"path": _cells_to_corridor_world_path(j_cells),
						"lane_offset": lane_offset_for_path(j_cells),
					})
			lot["drive_in_routes"] = multi_routes
		elif directly_hw:
			lot["is_connected"] = true
			lot["connected_side"] = GameCatalog.LotEntrySide.SOUTH
			lot["entry_road_cell"] = Vector2i(gx + int(sz.x / 2), OutpostLayout.HIGHWAY_ENTRY_ROW_Z)
			lot["lane_offset"] = TWO_LANE_OFFSET
			var pos := OutpostLayout.footprint_center(gx, gz, sz.x, sz.y)
			var p_arr: Array[Vector3] = [Vector3(pos.x, 0.0, OutpostLayout.PARKING_AISLE_Z)]
			lot["drive_in_path"] = p_arr
			lot["drive_in_routes"] = [{"entry_x": pos.x, "path": p_arr, "lane_offset": TWO_LANE_OFFSET}]
		else:
			lot["is_connected"] = false
			lot["connected_side"] = -1
			lot["entry_road_cell"] = Vector2i.ZERO
			lot["lane_offset"] = TWO_LANE_OFFSET
			lot["drive_in_path"] = []
			lot["drive_in_routes"] = []

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


func _reconstruct_cells(end_cell: Vector2i) -> Array[Vector2i]:
	var rev: Array[Vector2i] = []
	var cur = end_cell
	var guard := 0
	while cur != null and guard < 256:
		guard += 1
		rev.append(cur)
		cur = _parent.get(cur, null)
	rev.reverse()
	return rev


func _bfs_cells_from_sources(sources: Array, target: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = []
	var parent: Dictionary = {}
	var head := 0
	for s in sources:
		var sv: Vector2i = s
		if tiles.has(sv):
			parent[sv] = null
			queue.append(sv)
	var found := false
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == target:
			found = true
			break
		for nxt in OutpostLayout.neighbors4(cur):
			if tiles.has(nxt) and not parent.has(nxt):
				parent[nxt] = cur
				queue.append(nxt)
	if not found:
		return []
	var rev: Array[Vector2i] = []
	var cur_p = target
	var guard := 0
	while cur_p != null and guard < 256:
		guard += 1
		rev.append(cur_p)
		cur_p = parent.get(cur_p, null)
	rev.reverse()
	return rev


## Maps a grid road cell onto the true geometric midline of a 2-tile-wide road corridor.
func _corridor_midline_pos(c: Vector2i, move_step: Vector2i) -> Vector3:
	const CS := OutpostLayout.GRID_CELL_SIZE
	var wx := float(c.x) * CS
	var wz := float(c.y) * CS
	var has_w := tiles.has(Vector2i(c.x - 1, c.y))
	var has_e := tiles.has(Vector2i(c.x + 1, c.y))
	var has_n := tiles.has(Vector2i(c.x, c.y - 1))
	var has_s := tiles.has(Vector2i(c.x, c.y + 1)) or c.y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z

	if move_step.y != 0:
		if has_e and not has_w:
			wx = (float(c.x) + 0.5) * CS
		elif has_w and not has_e:
			wx = (float(c.x) - 0.5) * CS
	elif move_step.x != 0:
		if has_s and not has_n:
			wz = (float(c.y) + 0.5) * CS
		elif has_n and not has_s:
			wz = (float(c.y) - 0.5) * CS
	else:
		if has_e and not has_w:
			wx = (float(c.x) + 0.5) * CS
		elif has_w and not has_e:
			wx = (float(c.x) - 0.5) * CS
		if has_s and not has_n:
			wz = (float(c.y) + 0.5) * CS
		elif has_n and not has_s:
			wz = (float(c.y) - 0.5) * CS
	return Vector3(wx, 0.0, wz)


## Converts a BFS cell chain into a clean corridor-centerline polyline with proper 90-degree intersections.
func _cells_to_corridor_world_path(cells: Array[Vector2i]) -> Array[Vector3]:
	if cells.is_empty():
		return []

	# Extract axis-aligned runs along the grid path
	var runs: Array[Dictionary] = []
	var i := 0
	while i < cells.size():
		if i + 1 >= cells.size():
			var c_last := cells[i]
			var step := Vector2i(0, -1)
			if i > 0:
				step = c_last - cells[i - 1]
			var pt := _corridor_midline_pos(c_last, step)
			if runs.is_empty():
				runs.append({"axis": "v", "coord": pt.x, "start": pt, "end": pt})
			break
		var step_dir := cells[i + 1] - cells[i]
		var j := i + 1
		while j + 1 < cells.size() and (cells[j + 1] - cells[j]) == step_dir:
			j += 1
		# Sample midline along the interior of the run (avoids junction tile confusion at ends)
		var sample_idx := (i + j) >> 1
		var mid_p := _corridor_midline_pos(cells[sample_idx], step_dir)
		var start_raw := OutpostLayout.cell_center_v(cells[i])
		var end_raw := OutpostLayout.cell_center_v(cells[j])
		if step_dir.y != 0:
			runs.append({
				"axis": "v",
				"coord": mid_p.x,
				"start": Vector3(mid_p.x, 0.0, start_raw.z),
				"end": Vector3(mid_p.x, 0.0, end_raw.z),
			})
		else:
			runs.append({
				"axis": "h",
				"coord": mid_p.z,
				"start": Vector3(start_raw.x, 0.0, mid_p.z),
				"end": Vector3(end_raw.x, 0.0, mid_p.z),
			})
		i = j

	# Merge consecutive runs on the same axis & close coordinate (removes zigzag steps inside 2-wide corridors)
	var merged: Array[Dictionary] = []
	for r in runs:
		if not merged.is_empty() and merged.back()["axis"] == r["axis"] and absf(float(merged.back()["coord"]) - float(r["coord"])) <= OutpostLayout.GRID_CELL_SIZE * 1.1:
			merged.back()["end"] = r["end"]
		else:
			merged.append(r)

	# Drop tiny 1-cell lateral jogs inside a 2-wide road (e.g. shifting between left/right tile of same boulevard)
	var clean_runs: Array[Dictionary] = []
	for k in range(merged.size()):
		var r := merged[k]
		var seg_len: float = (r["end"] as Vector3).distance_to(r["start"] as Vector3)
		if k > 0 and k < merged.size() - 1 and seg_len <= OutpostLayout.GRID_CELL_SIZE * 1.05:
			if merged[k - 1]["axis"] == merged[k + 1]["axis"]:
				continue
		clean_runs.append(r)

	if clean_runs.is_empty():
		clean_runs = merged

	# Snap entry X to the exact highway junction cluster center when starting on HIGHWAY_ENTRY_ROW_Z
	var entry_x := float((clean_runs[0]["start"] as Vector3).x)
	if cells[0].y == OutpostLayout.HIGHWAY_ENTRY_ROW_Z:
		for cl in _junction_clusters:
			if cells[0].x >= int(cl["min_x"]) and cells[0].x <= int(cl["max_x"]):
				entry_x = float(cl["center_x"])
				if clean_runs[0]["axis"] == "v":
					clean_runs[0]["coord"] = entry_x
					var s0: Vector3 = clean_runs[0]["start"]
					var e0: Vector3 = clean_runs[0]["end"]
					clean_runs[0]["start"] = Vector3(entry_x, 0.0, s0.z)
					clean_runs[0]["end"] = Vector3(entry_x, 0.0, e0.z)
				break

	var pts: Array[Vector3] = [Vector3(entry_x, 0.0, OutpostLayout.HIGHWAY_NORTH_EDGE_Z + 0.30)]
	pts.append(clean_runs[0]["start"])
	for k in range(clean_runs.size() - 1):
		var a := clean_runs[k]
		var b := clean_runs[k + 1]
		if a["axis"] != b["axis"]:
			var ix := float(a["coord"]) if a["axis"] == "v" else float(b["coord"])
			var iz := float(b["coord"]) if a["axis"] == "v" else float(a["coord"])
			pts.append(Vector3(ix, 0.0, iz))
		else:
			pts.append(a["end"])
	pts.append(clean_runs.back()["end"])
	return _simplify_collinear(pts)


func _reconstruct_world_path(end_cell: Vector2i) -> Array[Vector3]:
	return _cells_to_corridor_world_path(_reconstruct_cells(end_cell))


func _compute_sign_bonus(decorations: Array) -> float:
	var signs := 0
	for d in decorations:
		if d["kind"] == GameCatalog.DecorationKind.WOODEN_SIGNPOST:
			signs += 1
	return minf(0.16, float(signs) * 0.08)
