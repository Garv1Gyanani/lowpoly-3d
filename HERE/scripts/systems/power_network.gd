class_name PowerNetwork
extends RefCounted

## Connected-component Desert Power Grid solver:
## - Local auto-linking (generators/batteries within 2 tiles of structures)
## - Overhead Poles (5-tile span) & Steel Towers (9-tile span) with MST wire spans
## - Underground Conduits (4-neighbor contiguous tiles; pass cleanly under roads/props)
## - 1 Hz daytime Solar curve, Wind Corridor +40% bonus, Diesel upkeep, Battery charge/discharge,
##   and forgiving 55% brownout floor.

const LOCAL_LINK_TILES := 2
const BROWNOUT_FLOOR := 0.55

var grids: Array[Dictionary] = []
var overhead_spans: Array[Dictionary] = [] # [{"a": Vector3, "b": Vector3, "is_tower": bool, "grid_id": int}]

var total_gen_kw: float = 0.0
var total_demand_kw: float = 0.0
var total_battery_stored: float = 0.0
var total_battery_cap: float = 0.0
var total_upkeep_per_min: float = 0.0
var brownout_count: int = 0

var _node_grid_map: Dictionary = {} # node_id -> grid_idx


func clear() -> void:
	grids.clear()
	overhead_spans.clear()
	_node_grid_map.clear()
	total_gen_kw = 0.0
	total_demand_kw = 0.0
	total_battery_stored = 0.0
	total_battery_cap = 0.0
	total_upkeep_per_min = 0.0
	brownout_count = 0


func grid_for_node(node_id: String) -> Dictionary:
	if not _node_grid_map.has(node_id):
		return {}
	var idx: int = int(_node_grid_map[node_id])
	if idx < 0 or idx >= grids.size():
		return {}
	return grids[idx]


func rebuild_topology(state) -> void:
	grids.clear()
	overhead_spans.clear()
	_node_grid_map.clear()

	# 1. Collect all electrical nodes with cell footprints & wire anchor points
	var nodes: Dictionary = {} # node_id -> {kind, ref, cells, center_cell, anchor, span}
	var cell_to_surface_node: Dictionary = {} # Vector2i -> node_id

	for p in state.plots:
		if not p["is_built"]:
			continue
		var nid := "plot:%s" % str(p["id"])
		var btype: int = int(p["type"])
		var d: Dictionary = GameCatalog.BUSINESSES[btype]
		var cells := WorldGrid._rect_cells(int(p["grid_x"]), int(p["grid_z"]), int(d["grid_w"]), int(d["grid_d"]), int(p["rot"]))
		var pos: Vector3 = state.plot_position(p)
		nodes[nid] = {
			"id": nid,
			"kind": "plot",
			"ref": p,
			"cells": cells,
			"center_cell": Vector2(float(p["grid_x"]) + float(d["grid_w"]) * 0.5, float(p["grid_z"]) + float(d["grid_d"]) * 0.5),
			"anchor": Vector3(pos.x, 2.35, pos.z),
			"span": 0,
		}
		for c in cells:
			cell_to_surface_node[c] = nid

	for u in state.utilities:
		var nid := "util:%s" % str(u["id"])
		var spec: Dictionary = GameCatalog.UTILITIES[int(u["kind"])]
		var cells := WorldGrid._rect_cells(int(u["grid_x"]), int(u["grid_z"]), int(spec["grid_w"]), int(spec["grid_d"]), int(u.get("rot", 0)))
		var sz := OutpostLayout.rotated_size(int(spec["grid_w"]), int(spec["grid_d"]), int(u.get("rot", 0)))
		var pos := OutpostLayout.footprint_center(int(u["grid_x"]), int(u["grid_z"]), sz.x, sz.y)
		nodes[nid] = {
			"id": nid,
			"kind": "util",
			"ref": u,
			"cells": cells,
			"center_cell": Vector2(float(u["grid_x"]) + float(sz.x) * 0.5, float(u["grid_z"]) + float(sz.y) * 0.5),
			"anchor": Vector3(pos.x, float(spec.get("anchor_y", 2.0)), pos.z),
			"span": 0,
		}
		for c in cells:
			cell_to_surface_node[c] = nid

	var pole_ids: Array[String] = []
	for cell: Vector2i in state.world_grid.power_poles.keys():
		var meta: Dictionary = state.world_grid.power_poles[cell]
		var pkind: int = int(meta.get("kind", GameCatalog.PowerLineKind.WOOD_POLE))
		var pspec: Dictionary = GameCatalog.POWER_LINES.get(pkind, GameCatalog.POWER_LINES[GameCatalog.PowerLineKind.WOOD_POLE])
		var nid := "pole:%d,%d" % [cell.x, cell.y]
		var wc := OutpostLayout.cell_center_v(cell)
		nodes[nid] = {
			"id": nid,
			"kind": "pole",
			"pole_kind": pkind,
			"cell": cell,
			"cells": [cell],
			"center_cell": Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5),
			"anchor": Vector3(wc.x, float(pspec["anchor_y"]), wc.z),
			"span": int(pspec["span_tiles"]),
		}
		pole_ids.append(nid)
		cell_to_surface_node[cell] = nid

	for cell: Vector2i in state.world_grid.power_underground.keys():
		var nid := "cond:%d,%d" % [cell.x, cell.y]
		var wc := OutpostLayout.cell_center_v(cell)
		nodes[nid] = {
			"id": nid,
			"kind": "conduit",
			"cell": cell,
			"cells": [cell],
			"center_cell": Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5),
			"anchor": Vector3(wc.x, 0.05, wc.z),
			"span": 1,
		}

	# Union-Find helper
	var parent: Dictionary = {}
	for nid in nodes.keys():
		parent[nid] = nid

	# 2. Underground conduit adjacency (conduit <-> conduit & conduit <-> touching/overlapping plot/util/pole)
	for cell: Vector2i in state.world_grid.power_underground.keys():
		var cid := "cond:%d,%d" % [cell.x, cell.y]
		if cell_to_surface_node.has(cell):
			_uf_union(parent, cid, cell_to_surface_node[cell])
		for nb in OutpostLayout.neighbors4(cell):
			var ncid := "cond:%d,%d" % [nb.x, nb.y]
			if nodes.has(ncid):
				_uf_union(parent, cid, ncid)
			if cell_to_surface_node.has(nb):
				_uf_union(parent, cid, cell_to_surface_node[nb])

	# 3. Local proximity auto-link: power sources/batteries connect directly to plots/utilities within LOCAL_LINK_TILES
	var util_ids: Array[String] = []
	var source_util_ids: Array[String] = []
	var plot_ids: Array[String] = []
	for nid in nodes.keys():
		var k: String = nodes[nid]["kind"]
		if k == "util":
			util_ids.append(nid)
			var uref: Dictionary = nodes[nid]["ref"]
			var uspec: Dictionary = GameCatalog.UTILITIES[int(uref["kind"])]
			if float(uspec.get("base_kw", 0.0)) > 0.0 or float(uspec.get("battery_kwh", 0.0)) > 0.0:
				source_util_ids.append(nid)
		elif k == "plot":
			plot_ids.append(nid)

	for suid in source_util_ids:
		var ucells: Array = nodes[suid]["cells"]
		for uid2 in util_ids:
			if uid2 != suid and _min_chebyshev_dist(ucells, nodes[uid2]["cells"]) <= LOCAL_LINK_TILES:
				_uf_union(parent, suid, uid2)
		for pid in plot_ids:
			if _min_chebyshev_dist(ucells, nodes[pid]["cells"]) <= LOCAL_LINK_TILES:
				_uf_union(parent, suid, pid)

	# 4. Overhead pole/tower spans (pole <-> pole via Kruskal MST, plus nearest pole drop-lines to plots/utilities)
	var pole_edges: Array[Dictionary] = []
	for i in range(pole_ids.size()):
		var a_id: String = pole_ids[i]
		var a_node: Dictionary = nodes[a_id]
		var a_cell: Vector2i = a_node["cell"]
		var a_span: int = int(a_node["span"])
		for j in range(i + 1, pole_ids.size()):
			var b_id: String = pole_ids[j]
			var b_node: Dictionary = nodes[b_id]
			var b_cell: Vector2i = b_node["cell"]
			var max_span := maxi(a_span, int(b_node["span"]))
			var dist := Vector2(a_cell).distance_to(Vector2(b_cell))
			if dist <= float(max_span) + 0.05:
				pole_edges.append({
					"a": a_id,
					"b": b_id,
					"dist": dist,
					"is_tower": int(a_node["pole_kind"]) == GameCatalog.PowerLineKind.STEEL_TOWER or int(b_node["pole_kind"]) == GameCatalog.PowerLineKind.STEEL_TOWER,
				})

	pole_edges.sort_custom(func(x: Dictionary, y: Dictionary): return float(x["dist"]) < float(y["dist"]))
	var pole_mst_parent: Dictionary = {}
	for pid in pole_ids:
		pole_mst_parent[pid] = pid

	for e in pole_edges:
		var a_id: String = e["a"]
		var b_id: String = e["b"]
		if _uf_find(pole_mst_parent, a_id) != _uf_find(pole_mst_parent, b_id):
			_uf_union(pole_mst_parent, a_id, b_id)
			_uf_union(parent, a_id, b_id)
			overhead_spans.append({
				"a": nodes[a_id]["anchor"],
				"b": nodes[b_id]["anchor"],
				"node_a": a_id,
				"is_tower": bool(e["is_tower"]),
				"grid_id": -1,
			})

	# Connect each utility & plot to its single closest in-range pole/tower (clean service drop-line!)
	var targets: Array[String] = []
	targets.append_array(util_ids)
	targets.append_array(plot_ids)
	for tid in targets:
		var tnode: Dictionary = nodes[tid]
		var tcells: Array = tnode["cells"]
		var best_pole := ""
		var best_d := 1e9
		for pid in pole_ids:
			var pnode: Dictionary = nodes[pid]
			var pcell: Vector2i = pnode["cell"]
			var pspan: int = int(pnode["span"])
			var d := _min_euclid_cell_dist(pcell, tcells)
			if d <= float(pspan) + 0.05 and d < best_d:
				best_d = d
				best_pole = pid
		if not best_pole.is_empty():
			_uf_union(parent, best_pole, tid)
			overhead_spans.append({
				"a": nodes[best_pole]["anchor"],
				"b": tnode["anchor"],
				"node_a": best_pole,
				"is_tower": false,
				"grid_id": -1,
			})

	# 5. Group connected components into Grid objects
	var root_to_grid: Dictionary = {}
	for nid in nodes.keys():
		var r := _uf_find(parent, nid)
		if not root_to_grid.has(r):
			var gid := grids.size()
			root_to_grid[r] = gid
			grids.append({
				"id": gid,
				"plot_ids": [],
				"utility_ids": [],
				"pole_count": 0,
				"conduit_count": 0,
				"gen_kw": 0.0,
				"demand_kw": 0.0,
				"battery_stored": 0.0,
				"battery_cap": 0.0,
				"ratio": 1.0,
			})
		var gid: int = int(root_to_grid[r])
		_node_grid_map[nid] = gid
		var g: Dictionary = grids[gid]
		match str(nodes[nid]["kind"]):
			"plot":
				g["plot_ids"].append(str(nodes[nid]["ref"]["id"]))
			"util":
				g["utility_ids"].append(str(nodes[nid]["ref"]["id"]))
			"pole":
				g["pole_count"] = int(g["pole_count"]) + 1
			"conduit":
				g["conduit_count"] = int(g["conduit_count"]) + 1

	for sp in overhead_spans:
		var na: String = sp["node_a"]
		sp["grid_id"] = int(_node_grid_map.get(na, -1))

	# Run an immediate 0-dt evaluation so HUD & lens show fresh kW numbers immediately after building!
	step(0.0, state)


func step(dt_sim: float, state) -> void:
	var solar := float(state.sim_clock.solar_factor())
	var night := bool(state.sim_clock.is_night())
	var sim_hours := dt_sim * SimClock.DAY_CYCLE_RATE * 24.0
	var pwr_crew_mult := float(state.staff_sim.power_gen_mult()) if state.staff_sim != null else 1.0
	var diesel_mult := float(state.staff_sim.diesel_upkeep_mult()) if state.staff_sim != null else 1.0

	var plot_by_id: Dictionary = {}
	for p in state.plots:
		if p["is_built"]:
			plot_by_id[str(p["id"])] = p
	var util_by_id: Dictionary = {}
	for u in state.utilities:
		util_by_id[str(u["id"])] = u

	total_gen_kw = 0.0
	total_demand_kw = 0.0
	total_battery_stored = 0.0
	total_battery_cap = 0.0
	total_upkeep_per_min = 0.0
	brownout_count = 0

	for g in grids:
		var gen_kw := 0.0
		var demand_kw := 0.0
		var bat_cap := 0.0
		var bat_stored := 0.0
		var bat_io := 0.0
		var batteries: Array[Dictionary] = []

		for uid_raw in g["utility_ids"]:
			var uid := str(uid_raw)
			if not util_by_id.has(uid):
				continue
			var u: Dictionary = util_by_id[uid]
			var ukind: int = int(u["kind"])
			var spec: Dictionary = GameCatalog.UTILITIES[ukind]
			var out_kw := snappedf(utility_output_kw(u, state.world_grid, solar) * pwr_crew_mult, 0.1)
			u["live_kw"] = out_kw
			gen_kw += out_kw
			var p_need := float(spec.get("power_need_kw", 0.0))
			if p_need > 0.0:
				demand_kw += p_need

			var upkeep := float(spec.get("upkeep_per_min", 0.0)) * diesel_mult
			var fuel_covered := ukind == GameCatalog.UtilityKind.DIESEL_GEN and state.supply_sim != null and bool(state.supply_sim.diesel_fuel_covered)
			if upkeep > 0.0 and not fuel_covered:
				total_upkeep_per_min += upkeep
				if dt_sim > 0.0 and state.cash > 0.0:
					state.cash = maxf(0.0, state.cash - (upkeep / 60.0) * dt_sim)

			var bcap := float(spec.get("battery_kwh", 0.0))
			if bcap > 0.0:
				if not u.has("stored_kwh"):
					u["stored_kwh"] = bcap * 0.5
				u["stored_kwh"] = clampf(float(u["stored_kwh"]), 0.0, bcap)
				bat_cap += bcap
				bat_stored += float(u["stored_kwh"])
				bat_io += float(spec.get("max_io_kw", 15.0))
				batteries.append(u)

		for pid_raw in g["plot_ids"]:
			var pid := str(pid_raw)
			if not plot_by_id.has(pid):
				continue
			var p: Dictionary = plot_by_id[pid]
			var btype: int = int(p["type"])
			var dem := GameCatalog.business_power_demand_kw(btype, int(p["level"]), night)
			demand_kw += dem
			var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag())
			p["runtime"] = rt
			if (rt.get("roof_addons", []) as Array).has("solar"):
				gen_kw += GameCatalog.rooftop_solar_kw(btype) * solar

		var supplied_kw := gen_kw
		if gen_kw >= demand_kw:
			var surplus := gen_kw - demand_kw
			if not batteries.is_empty() and sim_hours > 0.0 and surplus > 0.0:
				var charge_kw := minf(surplus, bat_io)
				var add_kwh := charge_kw * sim_hours
				var room := maxf(0.0, bat_cap - bat_stored)
				var actual_add := minf(add_kwh, room)
				if room > 0.0001 and actual_add > 0.0:
					for b in batteries:
						var bcap := float(GameCatalog.UTILITIES[int(b["kind"])]["battery_kwh"])
						var b_room := maxf(0.0, bcap - float(b["stored_kwh"]))
						b["stored_kwh"] = minf(bcap, float(b["stored_kwh"]) + actual_add * (b_room / room))
					bat_stored += actual_add
		else:
			var deficit := demand_kw - gen_kw
			if not batteries.is_empty() and bat_stored > 0.001:
				var draw_kw := minf(deficit, bat_io)
				if sim_hours > 0.0:
					var need_kwh := draw_kw * sim_hours
					var actual_kwh := minf(need_kwh, bat_stored)
					var eff_kw := actual_kwh / sim_hours if sim_hours > 0.0001 else draw_kw
					supplied_kw += eff_kw
					if bat_stored > 0.0001:
						for b in batteries:
							var share := float(b["stored_kwh"]) / bat_stored
							b["stored_kwh"] = maxf(0.0, float(b["stored_kwh"]) - actual_kwh * share)
						bat_stored = maxf(0.0, bat_stored - actual_kwh)
				else:
					# Instant 0-dt preview: battery can cover up to draw_kw right now
					supplied_kw += draw_kw

		var cov := 1.0 if demand_kw <= 0.001 else clampf(supplied_kw / demand_kw, 0.0, 1.0)
		var eff_ratio := 1.0 if cov >= 0.99 else lerpf(BROWNOUT_FLOOR, 1.0, cov)

		g["gen_kw"] = snappedf(gen_kw, 0.1)
		g["demand_kw"] = snappedf(demand_kw, 0.1)
		g["supplied_kw"] = snappedf(minf(supplied_kw, demand_kw), 0.1)
		g["battery_stored"] = snappedf(bat_stored, 0.1)
		g["battery_cap"] = snappedf(bat_cap, 0.1)
		g["ratio"] = eff_ratio

		total_gen_kw += gen_kw
		total_demand_kw += demand_kw
		total_battery_stored += bat_stored
		total_battery_cap += bat_cap

		for uid_raw in g["utility_ids"]:
			var uid := str(uid_raw)
			if not util_by_id.has(uid):
				continue
			var u: Dictionary = util_by_id[uid]
			var p_need := float(GameCatalog.UTILITIES[int(u["kind"])].get("power_need_kw", 0.0))
			u["power_ratio"] = 1.0 if p_need <= 0.001 else eff_ratio

		for pid_raw in g["plot_ids"]:
			var pid := str(pid_raw)
			if not plot_by_id.has(pid):
				continue
			var p: Dictionary = plot_by_id[pid]
			var dem := GameCatalog.business_power_demand_kw(int(p["type"]), int(p["level"]), night)
			var rt: Dictionary = p["runtime"]
			rt["power_grid_id"] = int(g["id"])
			rt["power_demand_kw"] = dem
			rt["power_supplied_kw"] = snappedf(dem * cov, 0.1)
			rt["power_ratio"] = 1.0 if dem <= 0.001 else eff_ratio
			if dem > 0.001 and eff_ratio < 0.99:
				brownout_count += 1

	total_gen_kw = snappedf(total_gen_kw, 0.1)
	total_demand_kw = snappedf(total_demand_kw, 0.1)
	total_battery_stored = snappedf(total_battery_stored, 0.1)
	total_battery_cap = snappedf(total_battery_cap, 0.1)


static func utility_output_kw(u: Dictionary, grid: WorldGrid, solar_factor: float) -> float:
	var ukind: int = int(u["kind"])
	var spec: Dictionary = GameCatalog.UTILITIES[ukind]
	var base_kw := float(spec.get("base_kw", 0.0))
	if base_kw <= 0.0:
		return 0.0
	if bool(spec.get("is_solar", false)):
		return snappedf(base_kw * solar_factor, 0.1)
	var mult := 1.0
	var wind_mult := float(spec.get("wind_trait_mult", 1.0))
	if wind_mult > 1.0 and grid != null:
		var cell := Vector2i(int(u["grid_x"]), int(u["grid_z"]))
		if grid.cell_trait(cell) == GameCatalog.ParcelTrait.WIND_CORRIDOR:
			mult = wind_mult
	return snappedf(base_kw * mult, 0.1)


static func _uf_find(parent: Dictionary, x: String) -> String:
	var cur := x
	while parent[cur] != cur:
		parent[cur] = parent[parent[cur]]
		cur = parent[cur]
	return cur


static func _uf_union(parent: Dictionary, a: String, b: String) -> void:
	var ra := _uf_find(parent, a)
	var rb := _uf_find(parent, b)
	if ra != rb:
		parent[ra] = rb


static func _min_chebyshev_dist(cells_a: Array, cells_b: Array) -> int:
	var best := 999999
	for a_v in cells_a:
		var a: Vector2i = a_v
		for b_v in cells_b:
			var b: Vector2i = b_v
			var d := maxi(absi(a.x - b.x), absi(a.y - b.y))
			if d < best:
				best = d
	return best


static func _min_euclid_cell_dist(c: Vector2i, cells: Array) -> float:
	var best := 1e9
	var cv := Vector2(c)
	for o_v in cells:
		var o: Vector2i = o_v
		var d := cv.distance_to(Vector2(o))
		if d < best:
			best = d
	return best
