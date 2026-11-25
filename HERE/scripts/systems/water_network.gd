class_name WaterNetwork
extends RefCounted

## Connected-component Desert Water Pipe Network:
## - Water Wells (2-tile auto-link, +80% on AQUIFER parcels, powered by PowerNetwork)
## - Water Towers (4-tile pressurized auto-link hub + 4 flow boost)
## - Underground Water Pipes (4-neighbor contiguous tiles; run cleanly under roads & props)
## - Forgiving 70% dry-building floor so businesses never hard-lock.

const DRY_FLOOR := 0.70

var networks: Array[Dictionary] = []
var total_supply: float = 0.0
var total_demand: float = 0.0
var dry_count: int = 0

var _node_net_map: Dictionary = {} # node_id -> net_idx


func clear() -> void:
	networks.clear()
	_node_net_map.clear()
	total_supply = 0.0
	total_demand = 0.0
	dry_count = 0


func network_for_node(node_id: String) -> Dictionary:
	if not _node_net_map.has(node_id):
		return {}
	var idx: int = int(_node_net_map[node_id])
	if idx < 0 or idx >= networks.size():
		return {}
	return networks[idx]


func rebuild_topology(state) -> void:
	networks.clear()
	_node_net_map.clear()

	var nodes: Dictionary = {}
	var cell_to_surface: Dictionary = {}

	for p in state.plots:
		if not p["is_built"]:
			continue
		var btype: int = int(p["type"])
		if float(GameCatalog.BUSINESSES[btype].get("water_need", 0.0)) <= 0.0:
			var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag(btype))
			rt["water_ratio"] = 1.0
			rt["water_demand"] = 0.0
			rt["water_supplied"] = 0.0
			p["runtime"] = rt
			continue
		var nid := "plot:%s" % str(p["id"])
		var d: Dictionary = GameCatalog.BUSINESSES[btype]
		var cells := WorldGrid._rect_cells(int(p["grid_x"]), int(p["grid_z"]), int(d["grid_w"]), int(d["grid_d"]), int(p["rot"]))
		nodes[nid] = {"id": nid, "kind": "plot", "ref": p, "cells": cells, "radius": 0}
		for c in cells:
			cell_to_surface[c] = nid

	var source_ids: Array[String] = []
	var consumer_ids: Array[String] = []
	for nid in nodes.keys():
		consumer_ids.append(nid)

	for u in state.utilities:
		var ukind: int = int(u["kind"])
		var spec: Dictionary = GameCatalog.UTILITIES[ukind]
		var wout := float(spec.get("water_output", 0.0))
		var wneed := float(spec.get("water_need", 0.0))
		if wout <= 0.0 and wneed <= 0.0:
			u["water_ratio"] = 1.0
			continue
		var nid := "util:%s" % str(u["id"])
		var cells := WorldGrid._rect_cells(int(u["grid_x"]), int(u["grid_z"]), int(spec["grid_w"]), int(spec["grid_d"]), int(u.get("rot", 0)))
		nodes[nid] = {"id": nid, "kind": "util", "ref": u, "cells": cells, "radius": int(spec.get("water_radius", 0))}
		for c in cells:
			cell_to_surface[c] = nid
		if wout > 0.0:
			source_ids.append(nid)
		if wneed > 0.0:
			consumer_ids.append(nid)

	for cell: Vector2i in state.world_grid.water_pipes.keys():
		var nid := "pipe:%d,%d" % [cell.x, cell.y]
		nodes[nid] = {"id": nid, "kind": "pipe", "cell": cell, "cells": [cell], "radius": 0}

	var parent: Dictionary = {}
	for nid in nodes.keys():
		parent[nid] = nid

	# Pipe adjacency (4-neighbors + touching/overlapping surface entities)
	for cell: Vector2i in state.world_grid.water_pipes.keys():
		var pid := "pipe:%d,%d" % [cell.x, cell.y]
		if cell_to_surface.has(cell):
			_uf_union(parent, pid, cell_to_surface[cell])
		for nb in OutpostLayout.neighbors4(cell):
			var npid := "pipe:%d,%d" % [nb.x, nb.y]
			if nodes.has(npid):
				_uf_union(parent, pid, npid)
			if cell_to_surface.has(nb):
				_uf_union(parent, pid, cell_to_surface[nb])

	# Local auto-link around Water Wells (2 tiles) & Water Towers (4 tiles)
	for sid in source_ids:
		var srad: int = int(nodes[sid]["radius"])
		var scells: Array = nodes[sid]["cells"]
		for cid in consumer_ids:
			if cid != sid and _min_chebyshev_dist(scells, nodes[cid]["cells"]) <= srad:
				_uf_union(parent, sid, cid)
		for sid2 in source_ids:
			if sid2 != sid and _min_chebyshev_dist(scells, nodes[sid2]["cells"]) <= maxi(srad, int(nodes[sid2]["radius"])):
				_uf_union(parent, sid, sid2)

	var root_to_net: Dictionary = {}
	for nid in nodes.keys():
		var r := _uf_find(parent, nid)
		if not root_to_net.has(r):
			var idx := networks.size()
			root_to_net[r] = idx
			networks.append({
				"id": idx,
				"plot_ids": [],
				"util_ids": [],
				"pipe_count": 0,
				"supply": 0.0,
				"demand": 0.0,
				"ratio": 1.0,
			})
		var idx: int = int(root_to_net[r])
		_node_net_map[nid] = idx
		var net: Dictionary = networks[idx]
		match str(nodes[nid]["kind"]):
			"plot":
				net["plot_ids"].append(str(nodes[nid]["ref"]["id"]))
			"util":
				net["util_ids"].append(str(nodes[nid]["ref"]["id"]))
			"pipe":
				net["pipe_count"] = int(net["pipe_count"]) + 1

	step(0.0, state)


func step(_dt_sim: float, state) -> void:
	var plot_by_id: Dictionary = {}
	for p in state.plots:
		if p["is_built"]:
			plot_by_id[str(p["id"])] = p
	var util_by_id: Dictionary = {}
	for u in state.utilities:
		util_by_id[str(u["id"])] = u

	total_supply = 0.0
	total_demand = 0.0
	dry_count = 0

	var well_crew_mult := float(state.staff_sim.water_well_mult()) if state.staff_sim != null else 1.0

	for net in networks:
		var sup := 0.0
		var dem := 0.0

		for uid_raw in net["util_ids"]:
			var uid := str(uid_raw)
			if not util_by_id.has(uid):
				continue
			var u: Dictionary = util_by_id[uid]
			var ukind: int = int(u["kind"])
			var spec: Dictionary = GameCatalog.UTILITIES[ukind]
			var wout := water_output_for_utility(u, state.world_grid)
			if wout > 0.0:
				if ukind == GameCatalog.UtilityKind.WATER_WELL:
					wout = snappedf(wout * well_crew_mult, 0.1)
				u["live_water"] = wout
				sup += wout
			dem += float(spec.get("water_need", 0.0))

		for pid_raw in net["plot_ids"]:
			var pid := str(pid_raw)
			if not plot_by_id.has(pid):
				continue
			var p: Dictionary = plot_by_id[pid]
			var wmult := float(state.staff_sim.plot_water_mult(p, state)) if state.staff_sim != null else 1.0
			dem += float(GameCatalog.BUSINESSES[int(p["type"])].get("water_need", 0.0)) * wmult

		var cov := 1.0 if dem <= 0.001 else clampf(sup / dem, 0.0, 1.0)
		var eff := 1.0 if cov >= 0.99 else lerpf(DRY_FLOOR, 1.0, cov)
		net["supply"] = snappedf(sup, 0.1)
		net["demand"] = snappedf(dem, 0.1)
		net["ratio"] = eff
		total_supply += sup
		total_demand += dem

		for uid_raw in net["util_ids"]:
			var uid := str(uid_raw)
			if not util_by_id.has(uid):
				continue
			var u: Dictionary = util_by_id[uid]
			var wneed := float(GameCatalog.UTILITIES[int(u["kind"])].get("water_need", 0.0))
			u["water_ratio"] = 1.0 if wneed <= 0.0 else eff

		for pid_raw in net["plot_ids"]:
			var pid := str(pid_raw)
			if not plot_by_id.has(pid):
				continue
			var p: Dictionary = plot_by_id[pid]
			var wmult := float(state.staff_sim.plot_water_mult(p, state)) if state.staff_sim != null else 1.0
			var wneed := snappedf(float(GameCatalog.BUSINESSES[int(p["type"])].get("water_need", 0.0)) * wmult, 0.1)
			var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag(int(p["type"])))
			p["runtime"] = rt
			rt["water_demand"] = wneed
			rt["water_supplied"] = snappedf(wneed * cov, 0.1)
			rt["water_ratio"] = 1.0 if wneed <= 0.0 else eff
			if wneed > 0.0 and eff < 0.99:
				dry_count += 1

	total_supply = snappedf(total_supply, 0.1)
	total_demand = snappedf(total_demand, 0.1)


static func water_output_for_utility(u: Dictionary, grid: WorldGrid) -> float:
	var ukind: int = int(u["kind"])
	var spec: Dictionary = GameCatalog.UTILITIES[ukind]
	var base := float(spec.get("water_output", 0.0))
	if base <= 0.0:
		return 0.0
	var mult := 1.0
	var aq_mult := float(spec.get("aquifer_mult", 1.0))
	if aq_mult > 1.0 and grid != null:
		if grid.cell_trait(Vector2i(int(u["grid_x"]), int(u["grid_z"]))) == GameCatalog.ParcelTrait.AQUIFER:
			mult = aq_mult
	var pwr_need := float(spec.get("power_need_kw", 0.0))
	var pwr_ratio := float(u.get("power_ratio", 1.0)) if pwr_need > 0.0 else 1.0
	return snappedf(base * mult * pwr_ratio, 0.1)


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
