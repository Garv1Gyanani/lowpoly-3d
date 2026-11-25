class_name TrafficSim
extends RefCounted

## Highway traffic, parking bay assignment, collision-free merging/following,
## and visitor walk/shop/return AI extracted from GameState.

const LANE_OFFSET := RoadNetwork.TWO_LANE_OFFSET
const HIGHWAY_SPAWN_X := 96.0

var state
var _traffic_cooldown := 0.8


func _init(game_state) -> void:
	state = game_state


func reset_cooldown() -> void:
	_traffic_cooldown = 0.8


func seed_initial_traffic() -> void:
	state.vehicles.clear()
	state.visitors.clear()
	_spawn_vehicle(-40.0, 1)
	_spawn_vehicle(30.0, -1)
	_spawn_vehicle(-6.0, 1)
	if state.connected_built_count() < 2:
		return
	var seeded := 0
	for lot in state.parking_lots:
		if not lot["is_connected"] or lot["drive_in_path"].is_empty():
			continue
		var slots: Array[Vector3] = state.lot_slot_positions(lot)
		var aisle: Vector3 = state.lot_aisle_point(lot, 0)
		var v_dir := 1 if seeded % 2 == 0 else -1
		var exit_wps := _build_exit_waypoints(lot, aisle, v_dir, {})
		var v := {
			"id": state.alloc_entity_id(),
			"kind": GameCatalog.VehicleKind.PICKUP_TRUCK if seeded % 2 == 0 else GameCatalog.VehicleKind.CAMPER_RV,
			"color": _random_vehicle_color(),
			"pos": slots[0],
			"yaw": BuildingBuilder.lot_parked_yaw(BuildingBuilder.lot_effective_side(lot)),
			"speed": 5.8,
			"cur_speed": 0.0,
			"dir": v_dir,
			"phase": GameCatalog.VehiclePhase.PARKED,
			"lot_id": lot["id"],
			"slot_idx": 0,
			"park_timer": 4.5 + seeded * 1.4,
			"yield_wait": 0.0,
			"spawned_vis": true,
			"waypoints": [],
			"exit_wps": exit_wps,
			"considered_x": NAN,
		}
		state.vehicles.append(v)
		_spawn_visitors_from_vehicle(v)
		seeded += 1
		if seeded >= 2:
			break


func dispatch_immediate_customer(lot: Dictionary) -> void:
	var slots: Array[Vector3] = state.lot_slot_positions(lot)
	if slots.is_empty() or lot["drive_in_path"].is_empty():
		return
	var route: Dictionary = lot["drive_in_routes"][0] if not lot.get("drive_in_routes", []).is_empty() else {"entry_x": float(lot["drive_in_path"][0].x), "path": lot["drive_in_path"], "lane_offset": float(lot.get("lane_offset", LANE_OFFSET))}
	var entry_x: float = route["entry_x"]
	var v := {
		"id": state.alloc_entity_id(),
		"kind": GameCatalog.VehicleKind.PICKUP_TRUCK,
		"color": _random_vehicle_color(),
		"pos": Vector3(entry_x - 10.0, 0.0, OutpostLayout.HIGHWAY_EASTBOUND_Z),
		"yaw": 0.0,
		"speed": 5.4,
		"cur_speed": 5.4,
		"dir": 1,
		"phase": GameCatalog.VehiclePhase.HIGHWAY_CRUISE,
		"lot_id": "",
		"slot_idx": -1,
		"park_timer": 0.0,
		"yield_wait": 0.0,
		"spawned_vis": false,
		"waypoints": [],
		"exit_wps": [],
		"considered_x": entry_x,
	}
	_assign_bay(v, lot, 0, slots[0], route)
	state.vehicles.append(v)


func dispatch_delivery_truck(target_plot: Dictionary) -> bool:
	var chosen_lot: Dictionary = {}
	var chosen_slot := 0
	var chosen_pos := Vector3.ZERO
	var chosen_route: Dictionary = {}
	for lot in state.parking_lots:
		if not lot["is_connected"] or lot["drive_in_path"].is_empty():
			continue
		var slots: Array[Vector3] = state.lot_slot_positions(lot)
		if slots.is_empty():
			continue
		var route: Dictionary = lot["drive_in_routes"][0] if not lot.get("drive_in_routes", []).is_empty() else {"entry_x": float(lot["drive_in_path"][0].x), "path": lot["drive_in_path"], "lane_offset": float(lot.get("lane_offset", LANE_OFFSET))}
		# Prefer a free bay, otherwise reuse slot 0
		var free_idx := -1
		for i in range(slots.size()):
			var occ := false
			for v in state.vehicles:
				if v["lot_id"] == lot["id"] and int(v["slot_idx"]) == i:
					occ = true
					break
			if not occ:
				free_idx = i
				break
		if free_idx >= 0:
			chosen_lot = lot
			chosen_slot = free_idx
			chosen_pos = slots[free_idx]
			chosen_route = route
			break
		if chosen_lot.is_empty():
			chosen_lot = lot
			chosen_slot = 0
			chosen_pos = slots[0]
			chosen_route = route

	if chosen_lot.is_empty():
		return false
	var entry_x: float = float(chosen_route["entry_x"])
	var truck := {
		"id": state.alloc_entity_id(),
		"kind": GameCatalog.VehicleKind.DELIVERY_TRUCK,
		"color": DesertPalette.TERRACOTTA,
		"pos": Vector3(entry_x - 14.0, 0.0, OutpostLayout.HIGHWAY_EASTBOUND_Z),
		"yaw": 0.0,
		"speed": 6.4,
		"cur_speed": 6.4,
		"dir": 1,
		"phase": GameCatalog.VehiclePhase.HIGHWAY_CRUISE,
		"lot_id": "",
		"slot_idx": -1,
		"park_timer": 0.0,
		"yield_wait": 0.0,
		"spawned_vis": false,
		"delivery_plot_id": str(target_plot["id"]),
		"waypoints": [],
		"exit_wps": [],
		"considered_x": entry_x,
	}
	_assign_bay(truck, chosen_lot, chosen_slot, chosen_pos, chosen_route)
	state.vehicles.append(truck)
	return true


func evict_lot_vehicles(lot_id: String) -> void:
	var evicted: Dictionary = {}
	for i in range(state.vehicles.size() - 1, -1, -1):
		if state.vehicles[i]["lot_id"] == lot_id:
			evicted[state.vehicles[i]["id"]] = true
			state.vehicles.remove_at(i)
	for i in range(state.visitors.size() - 1, -1, -1):
		if evicted.has(state.visitors[i]["vehicle_id"]):
			state.visitors.remove_at(i)


func update(dt: float) -> void:
	if dt <= 0.0:
		return
	_update_vehicles(dt)
	_update_visitors(dt)


func _spawn_vehicle(init_x: float, dir: int) -> void:
	var lane_z := OutpostLayout.HIGHWAY_EASTBOUND_Z if dir == 1 else OutpostLayout.HIGHWAY_WESTBOUND_Z
	var spd: float = 5.4 + float(state.rng.randf()) * 2.4
	state.vehicles.append({
		"id": state.alloc_entity_id(),
		"kind": state.rng.randi_range(0, 4),
		"color": _random_vehicle_color(),
		"pos": Vector3(init_x, 0.0, lane_z),
		"yaw": 0.0 if dir == 1 else PI,
		"speed": spd,
		"cur_speed": spd,
		"dir": dir,
		"phase": GameCatalog.VehiclePhase.HIGHWAY_CRUISE,
		"lot_id": "",
		"slot_idx": -1,
		"park_timer": 0.0,
		"yield_wait": 0.0,
		"spawned_vis": false,
		"waypoints": [],
		"exit_wps": [],
		"considered_x": NAN,
	})


func _build_exit_waypoints(lot: Dictionary, aisle: Vector3, dir: int, fallback_route: Dictionary) -> Array[Vector3]:
	var chosen := fallback_route
	var routes: Array = lot.get("drive_in_routes", [])
	if routes.size() >= 2:
		var best_score := -1e9
		var entry_ref := float(fallback_route.get("entry_x", aisle.x))
		for r in routes:
			var rx: float = r["entry_x"]
			var path_len: int = (r["path"] as Array).size()
			var downstream := (rx - entry_ref) * float(dir)
			var sc := (25.0 if downstream > 2.0 else 0.0) - float(path_len) * 0.6
			if sc > best_score:
				best_score = sc
				chosen = r
	elif routes.size() == 1:
		chosen = routes[0]

	var center_path: Array[Vector3] = []
	var raw_p: Array = chosen.get("path", lot["drive_in_path"])
	for pt in raw_p:
		center_path.append(pt)
	var lane_off: float = float(chosen.get("lane_offset", lot.get("lane_offset", LANE_OFFSET)))

	var rev: Array[Vector3] = []
	for i in range(center_path.size() - 1, -1, -1):
		rev.append(center_path[i])

	var road_lane := RoadNetwork.offset_path_right(rev, lane_off)
	var smoothed := RoadNetwork.smooth_path_corners(road_lane, 1.55, 3)
	var out: Array[Vector3] = [aisle]
	out.append_array(smoothed)
	return out


func _assign_bay(v: Dictionary, lot: Dictionary, slot_idx: int, slot_pos: Vector3, route: Dictionary = {}) -> void:
	var aisle: Vector3 = state.lot_aisle_point(lot, slot_idx)
	v["lot_id"] = lot["id"]
	v["slot_idx"] = slot_idx
	v["phase"] = GameCatalog.VehiclePhase.PULLING_IN
	v["yield_wait"] = 0.0

	var typed_path: Array[Vector3] = []
	var raw_p: Array = route.get("path", lot["drive_in_path"])
	for pt in raw_p:
		typed_path.append(pt)
	var lane_off: float = float(route.get("lane_offset", lot.get("lane_offset", LANE_OFFSET)))
	var road_lane := RoadNetwork.offset_path_right(typed_path, lane_off)

	var combined: Array[Vector3] = []
	if not road_lane.is_empty():
		var first_lane := road_lane[0]
		var hw_z := OutpostLayout.HIGHWAY_EASTBOUND_Z if int(v["dir"]) == 1 else OutpostLayout.HIGHWAY_WESTBOUND_Z
		var approach_x := first_lane.x - float(v["dir"]) * 1.4
		if (v["pos"] as Vector3).distance_to(Vector3(approach_x, 0.0, hw_z)) > 1.0:
			combined.append(Vector3(approach_x, 0.0, hw_z))
	combined.append_array(road_lane)
	combined.append(aisle)
	var smooth_in := RoadNetwork.smooth_path_corners(combined, 1.45, 3)
	smooth_in.append(slot_pos)
	v["waypoints"] = smooth_in
	v["exit_wps"] = _build_exit_waypoints(lot, aisle, int(v["dir"]), route)


func _lot_by_id(lid: String) -> Dictionary:
	for l in state.parking_lots:
		if l["id"] == lid:
			return l
	return {}


func _compute_safe_speed(v: Dictionary, move_dir: Vector3, base_speed: float) -> float:
	var vpos: Vector3 = v["pos"]
	var vid: int = v["id"]
	var vphase: int = v["phase"]
	var safe := base_speed

	for o in state.vehicles:
		if int(o["id"]) == vid:
			continue
		var ophase: int = o["phase"]
		if ophase == GameCatalog.VehiclePhase.PARKED:
			continue
		var rel: Vector3 = (o["pos"] as Vector3) - vpos
		var d2 := rel.x * rel.x + rel.z * rel.z
		if d2 > 64.0:
			continue
		var ahead := rel.x * move_dir.x + rel.z * move_dir.z
		if ahead <= 0.15 or ahead > 7.4:
			continue
		var side := absf(-rel.x * move_dir.z + rel.z * move_dir.x)
		var o_yaw: float = o["yaw"]
		var o_fwd := Vector3(cos(o_yaw), 0.0, sin(o_yaw))
		var align := move_dir.x * o_fwd.x + move_dir.z * o_fwd.z

		if side < 1.25 and align > 0.45:
			var stop_gap := 3.45
			var slow_gap := 6.6
			if ahead <= stop_gap:
				return 0.0
			elif ahead < slow_gap:
				var factor := (ahead - stop_gap) / (slow_gap - stop_gap)
				var match_spd := maxf(float(o.get("cur_speed", 0.0)), 0.0)
				safe = minf(safe, lerpf(match_spd * 0.85, base_speed, factor))
		elif side < 1.70 and ahead < 4.5 and align > -0.62:
			var o_moving := float(o.get("cur_speed", 0.0)) > 0.35
			var o_priority := (ophase == GameCatalog.VehiclePhase.HIGHWAY_CRUISE and vphase != GameCatalog.VehiclePhase.HIGHWAY_CRUISE) or (vid > int(o["id"]))
			if o_priority or not o_moving:
				if ahead < 3.1:
					return 0.0
				safe = minf(safe, base_speed * clampf((ahead - 2.9) / 1.6, 0.0, 1.0))

	return safe


func _is_aisle_clear(v: Dictionary, target_pos: Vector3) -> bool:
	var vid: int = v["id"]
	for o in state.vehicles:
		if int(o["id"]) == vid:
			continue
		if int(o["phase"]) == GameCatalog.VehiclePhase.PARKED:
			continue
		if (o["pos"] as Vector3).distance_to(target_pos) < 3.6:
			return false
	return true


func _update_vehicles(dt: float) -> void:
	var spaces: int = state.total_parking_spaces()
	var max_v := 4 + mini(8, spaces)
	_traffic_cooldown -= dt
	if _traffic_cooldown <= 0.0 and state.vehicles.size() < max_v:
		var dir := 1 if state.rng.randf() < 0.5 else -1
		var spawn_x := -HIGHWAY_SPAWN_X if dir == 1 else HIGHWAY_SPAWN_X
		var lane_z := OutpostLayout.HIGHWAY_EASTBOUND_Z if dir == 1 else OutpostLayout.HIGHWAY_WESTBOUND_Z
		var clear := true
		for o in state.vehicles:
			if (o["pos"] as Vector3).distance_to(Vector3(spawn_x, 0.0, lane_z)) < 9.0:
				clear = false
				break
		if clear:
			_spawn_vehicle(spawn_x, dir)
		_traffic_cooldown = clampf(4.2 - float(spaces) * 0.22, 1.4, 4.2)

	var entry_xs: Array[float] = []
	if spaces > 0 and state.connected_built_count() > 0:
		for l in state.parking_lots:
			if not l["is_connected"]:
				continue
			var routes: Array = l.get("drive_in_routes", [])
			if not routes.is_empty():
				for r in routes:
					var ex: float = r["entry_x"]
					var dup := false
					for x in entry_xs:
						if absf(x - ex) < 0.05:
							dup = true
							break
					if not dup:
						entry_xs.append(ex)
			elif not l["drive_in_path"].is_empty():
				var ex: float = l["drive_in_path"][0].x
				var dup := false
				for x in entry_xs:
					if absf(x - ex) < 0.05:
						dup = true
						break
				if not dup:
					entry_xs.append(ex)

	var avg_access: float = state.average_access_score()
	for i in range(state.vehicles.size() - 1, -1, -1):
		var v: Dictionary = state.vehicles[i]
		match v["phase"]:
			GameCatalog.VehiclePhase.HIGHWAY_CRUISE:
				var fdir := Vector3(float(v["dir"]), 0.0, 0.0)
				var tgt_spd := _compute_safe_speed(v, fdir, float(v["speed"]))
				var cspd := lerpf(float(v.get("cur_speed", tgt_spd)), tgt_spd, clampf(dt * 5.0, 0.0, 1.0))
				v["cur_speed"] = cspd
				v["pos"].x += float(v["dir"]) * cspd * dt
				v["yaw"] = 0.0 if v["dir"] == 1 else PI
				if v["slot_idx"] == -1:
					for ex in entry_xs:
						var trigger_x := ex - float(v["dir"]) * 2.1
						if absf(v["pos"].x - trigger_x) < 2.2 and (is_nan(v["considered_x"]) or absf(v["considered_x"] - ex) > 0.05):
							v["considered_x"] = ex
							if state.rng.randf() < clampf(0.26 + avg_access * 0.54, 0.20, 0.90):
								var bay := _find_free_bay(ex)
								if not bay.is_empty():
									_assign_bay(v, bay[0], bay[1], bay[2], bay[3])
							break
				if absf(v["pos"].x) > HIGHWAY_SPAWN_X + 4.0:
					state.vehicles.remove_at(i)
			GameCatalog.VehiclePhase.PULLING_IN:
				var wps: Array = v["waypoints"]
				if wps.is_empty():
					var lot := _lot_by_id(v["lot_id"])
					if not lot.is_empty():
						v["yaw"] = BuildingBuilder.lot_parked_yaw(BuildingBuilder.lot_effective_side(lot))
					v["cur_speed"] = 0.0
					v["phase"] = GameCatalog.VehiclePhase.PARKED
					v["park_timer"] = 6.0 + state.rng.randf() * 3.5
					v["spawned_vis"] = false
				else:
					var wp: Vector3 = wps[0]
					var cur_p: Vector3 = v["pos"]
					var diff: Vector3 = wp - cur_p
					var dist: float = diff.length()
					var reach := 0.20 if wps.size() == 1 else 0.34
					if dist < reach:
						v["pos"] = wp
						wps.remove_at(0)
					else:
						var base_spd: float = state.road_network.vehicle_speed_at(cur_p)
						if wps.size() <= 2:
							base_spd = minf(base_spd, 3.6)
						var dir_v: Vector3 = diff / dist
						var tgt_spd := _compute_safe_speed(v, dir_v, base_spd)
						if tgt_spd < 0.1:
							v["yield_wait"] = float(v.get("yield_wait", 0.0)) + dt
							if float(v["yield_wait"]) > 4.5:
								tgt_spd = 2.2
						else:
							v["yield_wait"] = 0.0
						var cspd := lerpf(float(v.get("cur_speed", tgt_spd)), tgt_spd, clampf(dt * 6.0, 0.0, 1.0))
						v["cur_speed"] = cspd
						v["pos"] = cur_p + dir_v * minf(dist, cspd * dt)
						if cspd > 0.15:
							v["yaw"] = _lerp_angle(v["yaw"], atan2(dir_v.z, dir_v.x), clampf(dt * 8.5, 0.0, 1.0))
			GameCatalog.VehiclePhase.PARKED:
				if not v["spawned_vis"]:
					v["spawned_vis"] = true
					var del_pid: String = str(v.get("delivery_plot_id", ""))
					if not del_pid.is_empty():
						v["delivery_plot_id"] = ""
						v["park_timer"] = 2.2
						state.supply_sim.complete_delivery_for_plot(del_pid, state)
					else:
						_spawn_visitors_from_vehicle(v)
				v["park_timer"] -= dt
				var has_vis := false
				for vis in state.visitors:
					if vis["vehicle_id"] == v["id"]:
						has_vis = true
						break
				if v["park_timer"] <= 0.0 and not has_vis:
					var ewps: Array = v["exit_wps"]
					var cur_p2: Vector3 = v["pos"]
					var bt: Vector3 = ewps[0] if not ewps.is_empty() else Vector3(cur_p2.x, 0.0, OutpostLayout.PARKING_AISLE_Z)
					v["waypoints"] = [bt]
					v["yield_wait"] = 0.0
					v["phase"] = GameCatalog.VehiclePhase.BACKING_OUT
			GameCatalog.VehiclePhase.BACKING_OUT:
				var wps: Array = v["waypoints"]
				if wps.is_empty():
					_begin_pull_out(v)
				else:
					var bt: Vector3 = wps[0]
					var cur_p: Vector3 = v["pos"]
					var diff: Vector3 = bt - cur_p
					var dist: float = diff.length()
					if dist < 0.24:
						v["pos"] = bt
						wps.clear()
						_begin_pull_out(v)
					else:
						var can_back := _is_aisle_clear(v, bt) or float(v.get("yield_wait", 0.0)) > 4.0
						if not can_back:
							v["yield_wait"] = float(v.get("yield_wait", 0.0)) + dt
							v["cur_speed"] = 0.0
						else:
							var dir_v: Vector3 = diff / dist
							v["cur_speed"] = 2.4
							v["pos"] = cur_p + dir_v * minf(dist, 2.4 * dt)
							v["yaw"] = _lerp_angle(v["yaw"], atan2(-dir_v.z, -dir_v.x), clampf(dt * 3.2, 0.0, 1.0))
			GameCatalog.VehiclePhase.PULLING_OUT:
				var wps: Array = v["waypoints"]
				if wps.is_empty():
					v["lot_id"] = ""
					v["slot_idx"] = -1
					v["phase"] = GameCatalog.VehiclePhase.HIGHWAY_CRUISE
				else:
					var wp: Vector3 = wps[0]
					var cur_p: Vector3 = v["pos"]
					var diff: Vector3 = wp - cur_p
					var dist: float = diff.length()
					if dist < 0.34:
						v["pos"] = wp
						wps.remove_at(0)
					else:
						var base_spd: float = state.road_network.vehicle_speed_at(cur_p)
						var dir_v: Vector3 = diff / dist
						var tgt_spd := _compute_safe_speed(v, dir_v, base_spd)
						if tgt_spd < 0.1:
							v["yield_wait"] = float(v.get("yield_wait", 0.0)) + dt
							if float(v["yield_wait"]) > 4.5:
								tgt_spd = 2.4
						else:
							v["yield_wait"] = 0.0
						var cspd := lerpf(float(v.get("cur_speed", tgt_spd)), tgt_spd, clampf(dt * 6.0, 0.0, 1.0))
						v["cur_speed"] = cspd
						v["pos"] = cur_p + dir_v * minf(dist, cspd * dt)
						if cspd > 0.15:
							v["yaw"] = _lerp_angle(v["yaw"], atan2(dir_v.z, dir_v.x), clampf(dt * 8.0, 0.0, 1.0))


func _begin_pull_out(v: Dictionary) -> void:
	var ez := OutpostLayout.HIGHWAY_EASTBOUND_Z if v["dir"] == 1 else OutpostLayout.HIGHWAY_WESTBOUND_Z
	var wps: Array[Vector3] = []
	var ewps: Array = v["exit_wps"]
	for j in range(1, ewps.size()):
		wps.append(ewps[j])
	var lx: float = wps.back().x if not wps.is_empty() else v["pos"].x
	wps.append(Vector3(lx + float(v["dir"]) * 2.2, 0.0, ez))
	v["waypoints"] = RoadNetwork.smooth_path_corners(wps, 1.45, 3)
	v["yield_wait"] = 0.0
	v["phase"] = GameCatalog.VehiclePhase.PULLING_OUT


func _find_free_bay(entry_x: float) -> Array:
	var free: Array = []
	for lot in state.parking_lots:
		if not lot["is_connected"]:
			continue
		var matched_route: Dictionary = {}
		var routes: Array = lot.get("drive_in_routes", [])
		for r in routes:
			if absf(float(r["entry_x"]) - entry_x) <= 0.05:
				matched_route = r
				break
		if matched_route.is_empty():
			if not lot["drive_in_path"].is_empty() and absf(float(lot["drive_in_path"][0].x) - entry_x) <= 0.05:
				matched_route = {"entry_x": entry_x, "path": lot["drive_in_path"], "lane_offset": float(lot.get("lane_offset", LANE_OFFSET))}
			else:
				continue
		var slots: Array[Vector3] = state.lot_slot_positions(lot)
		for i in range(slots.size()):
			var occ := false
			for v in state.vehicles:
				if v["lot_id"] == lot["id"] and v["slot_idx"] == i:
					occ = true
					break
			if not occ:
				free.append([lot, i, slots[i], matched_route])
	if free.is_empty():
		return []
	return free[state.rng.randi_range(0, free.size() - 1)]


func _spawn_visitors_from_vehicle(v: Dictionary) -> void:
	var reachable: Array[Dictionary] = []
	var total_w := 0.0
	for p in state.plots:
		if p["is_built"] and float(p["access"]["score"]) > 0.0:
			reachable.append(p)
			total_w += float(p["access"]["score"])
	if reachable.is_empty():
		return
	var pcount := 3 if v["kind"] == GameCatalog.VehicleKind.TOURIST_VAN else (2 if v["kind"] == GameCatalog.VehicleKind.CAMPER_RV else (2 if (v["kind"] == GameCatalog.VehicleKind.SUV and state.rng.randf() < 0.5) else 1))
	var shirts := [DesertPalette.AWNING_RED, DesertPalette.TURQUOISE, DesertPalette.GOLD, DesertPalette.TERRACOTTA, DesertPalette.CREAM, Color("5d7ea8")]
	var hats := [DesertPalette.SAND, DesertPalette.WOOD_LIGHT, DesertPalette.CREAM, DesertPalette.SANDSTONE]
	var blocked: Dictionary = {}
	for p in state.plots:
		if p["is_built"]:
			var d: Dictionary = GameCatalog.BUSINESSES[p["type"]]
			for c in WorldGrid._rect_cells(p["grid_x"], p["grid_z"], d["grid_w"], d["grid_d"], p["rot"]):
				blocked[c] = true
	var lot := _lot_by_id(v["lot_id"])
	for i in range(pcount):
		var roll: float = state.rng.randf() * total_w
		var target_p: Dictionary = reachable.back()
		for p in reachable:
			roll -= float(p["access"]["score"])
			if roll <= 0.0:
				target_p = p
				break
		var vpos: Vector3 = v["pos"]
		var start: Vector3 = state.lot_visitor_spawn(lot, int(v["slot_idx"]), i) if (not lot.is_empty() and int(v["slot_idx"]) >= 0) else vpos + Vector3(0.42 + (float(i) - 0.5) * 0.34, 0.0, -0.95)
		var dest: Vector3 = state.plot_visitor_stop(target_p) + Vector3((i - 0.5) * 0.32, 0.0, 0.0)
		var outbound: Array[Vector3] = state.road_network.build_visitor_walk_path(start, dest, blocked)
		var inbound: Array[Vector3] = []
		for k in range(outbound.size() - 2, -1, -1):
			inbound.append(outbound[k])
		inbound.append(start)
		state.visitors.append({
			"id": state.alloc_entity_id(),
			"shirt": shirts[state.rng.randi_range(0, shirts.size() - 1)],
			"hat": hats[state.rng.randi_range(0, hats.size() - 1)],
			"pos": start,
			"target_plot_id": target_p["id"],
			"vehicle_id": v["id"],
			"phase": GameCatalog.VisitorPhase.WALKING_TO_BUSINESS,
			"yaw": -PI * 0.5,
			"walk_cycle": float(i) * 0.8,
			"wait_timer": 0.0,
			"outbound": outbound,
			"return_path": inbound,
		})


func _update_visitors(dt: float) -> void:
	for i in range(state.visitors.size() - 1, -1, -1):
		var vis: Dictionary = state.visitors[i]
		vis["walk_cycle"] += dt
		match vis["phase"]:
			GameCatalog.VisitorPhase.WALKING_TO_BUSINESS:
				var path: Array = vis["outbound"]
				if path.is_empty():
					vis["phase"] = GameCatalog.VisitorPhase.SHOPPING
					var shop_mult := 1.0
					for p in state.plots:
						if p["id"] == vis["target_plot_id"]:
							if state.plot_has_staff(p, "greeter"):
								shop_mult = 0.70
							break
					vis["wait_timer"] = (1.6 + state.rng.randf() * 1.4) * shop_mult
				else:
					var wp: Vector3 = path[0]
					var vpos: Vector3 = vis["pos"]
					var diff: Vector3 = wp - vpos
					var dist: float = diff.length()
					if dist < 0.22:
						vis["pos"] = wp
						path.remove_at(0)
					else:
						var dv: Vector3 = diff / dist
						vis["pos"] = vpos + dv * (2.15 * dt)
						vis["yaw"] = _lerp_angle(vis["yaw"], atan2(dv.z, dv.x), clampf(dt * 10.0, 0.0, 1.0))
			GameCatalog.VisitorPhase.SHOPPING:
				vis["wait_timer"] -= dt
				if vis["wait_timer"] <= 0.0:
					var target_p: Dictionary = state.plots[0]
					for p in state.plots:
						if p["id"] == vis["target_plot_id"]:
							target_p = p
							break
					state.complete_visitor_purchase(target_p)
					vis["phase"] = GameCatalog.VisitorPhase.RETURNING_TO_CAR
			GameCatalog.VisitorPhase.RETURNING_TO_CAR:
				var path: Array = vis["return_path"]
				if path.is_empty():
					state.visitors.remove_at(i)
				else:
					var wp: Vector3 = path[0]
					var vpos: Vector3 = vis["pos"]
					var diff: Vector3 = wp - vpos
					var dist: float = diff.length()
					if dist < 0.24:
						vis["pos"] = wp
						path.remove_at(0)
						if path.is_empty():
							state.visitors.remove_at(i)
					else:
						var dv: Vector3 = diff / dist
						vis["pos"] = vpos + dv * (2.15 * dt)
						vis["yaw"] = _lerp_angle(vis["yaw"], atan2(dv.z, dv.x), clampf(dt * 10.0, 0.0, 1.0))


func _lerp_angle(cur: float, tgt: float, t: float) -> float:
	var diff := fposmod(tgt - cur + PI, TAU) - PI
	return cur + diff * t


func _random_vehicle_color() -> Color:
	var pal := [Color("c85b43"), Color("4f9a94"), Color("e0b45a"), Color("dfd5c3"), Color("5a778e"), Color("7b855e"), Color("b56e4b")]
	return pal[state.rng.randi_range(0, pal.size() - 1)]
