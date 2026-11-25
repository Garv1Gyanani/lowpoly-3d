class_name SaveManager
extends RefCounted

## Versioned JSON persistence, v4 -> v5 migration, atomic write-and-rename,
## and offline welcome earnings calculation.

const SAVE_PATH := "user://desert_outpost_save.json"
const CURRENT_VERSION := 5


static func serialize(state) -> Dictionary:
	var overhead: Array = []
	for c: Vector2i in state.world_grid.power_poles.keys():
		overhead.append({"x": c.x, "z": c.y, "meta": state.world_grid.power_poles[c]})
	var underground: Array = []
	for c: Vector2i in state.world_grid.power_underground.keys():
		underground.append({"x": c.x, "z": c.y, "meta": state.world_grid.power_underground[c]})
	var pipes: Array = []
	for c: Vector2i in state.world_grid.water_pipes.keys():
		pipes.append({"x": c.x, "z": c.y, "meta": state.world_grid.water_pipes[c]})

	var plot_rows: Array = []
	for p in state.plots:
		plot_rows.append({
			"id": p["id"],
			"gx": p["grid_x"],
			"gz": p["grid_z"],
			"rot": p["rot"],
			"built": p["is_built"],
			"lv": p["level"],
			"staff": p.get("staff", []),
			"runtime": p.get("runtime", GameCatalog.make_runtime_bag()),
		})

	return {
		"v": CURRENT_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"preset": state.active_preset,
		"cash": state.cash,
		"total_cash": state.total_cash_earned,
		"served": state.total_customers_served,
		"taps": state.total_taps,
		"tap_lv": state.tap_upgrade_level,
		"highest_stage": state.outpost_stage(),
		"clock": state.sim_clock.to_dict(),
		"time_of_day": state.sim_clock.time_of_day,
		"auto_day_night": state.sim_clock.auto_day_night,
		"sound": state.sound_enabled,
		"parcels": state.world_grid.owned_parcels.keys().map(func(p: Vector2i): return [p.x, p.y]),
		"roads": state.road_network.tiles.keys().map(func(c: Vector2i): return [c.x, c.y, state.road_network.tiles[c]]),
		"plots": plot_rows,
		"lots": state.parking_lots.map(func(l): return {"id": l["id"], "kind": l["kind"], "gx": l["grid_x"], "gz": l["grid_z"], "rot": l["rot"]}),
		"decos": state.decorations.map(func(d): return {"id": d["id"], "kind": d["kind"], "name": d["name"], "cost": d["cost"], "gx": d["grid_x"], "gz": d["grid_z"], "rot": int(d.get("rot", 0))}),
		"utilities": state.utilities,
		"crew": state.staff_sim.to_dict(),
		"power_overhead": overhead,
		"power_underground": underground,
		"water_pipes": pipes,
		"claimed": state.milestones.filter(func(m): return m["claimed"]).map(func(m): return m["id"]),
	}


static func migrate(raw: Dictionary) -> Dictionary:
	var ver := int(raw.get("v", 0))
	if ver < 4:
		return {}
	var data := raw.duplicate(true)
	if ver == 4:
		data = _migrate_v4_to_v5(data)
	return data


static func _migrate_v4_to_v5(data: Dictionary) -> Dictionary:
	data["v"] = 5
	if not data.has("clock"):
		data["clock"] = {
			"day": 1,
			"time_of_day": float(data.get("time_of_day", 0.37)),
			"auto_day_night": bool(data.get("auto_day_night", true)),
			"sim_speed": 1.0,
		}
	for sp in data.get("plots", []):
		if not sp.has("runtime"):
			sp["runtime"] = GameCatalog.make_runtime_bag()
	for sd in data.get("decos", []):
		if not sd.has("rot"):
			sd["rot"] = 0
	if not data.has("utilities"):
		data["utilities"] = []
	if not data.has("power_overhead"):
		data["power_overhead"] = []
	if not data.has("power_underground"):
		data["power_underground"] = []
	if not data.has("water_pipes"):
		data["water_pipes"] = []
	return data


static func save_to_disk(state, path: String = SAVE_PATH) -> bool:
	var json_str := JSON.stringify(serialize(state))
	var tmp_path := "%s.tmp" % path
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return false
		f.store_string(json_str)
		f.close()
		return true
	f.store_string(json_str)
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp_path)
	var abs_dst := ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(abs_tmp, abs_dst) != OK:
		# Fallback if rename over existing file is blocked on Windows
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(abs_dst)
		if DirAccess.rename_absolute(abs_tmp, abs_dst) != OK:
			var df := FileAccess.open(path, FileAccess.WRITE)
			if df == null:
				return false
			df.store_string(json_str)
			df.close()
			DirAccess.remove_absolute(abs_tmp)
	return true


static func load_from_disk(state, path: String = SAVE_PATH, apply_offline: bool = true) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	return apply_dict(state, parsed, apply_offline)


static func apply_dict(state, raw: Dictionary, apply_offline: bool = true) -> bool:
	var data := migrate(raw)
	if data.is_empty():
		return false

	state.active_preset = int(data.get("preset", GameCatalog.OutpostPreset.STAGE_ONE_CAREER))
	state.cash = float(data.get("cash", 0.0))
	state.total_cash_earned = float(data.get("total_cash", 0.0))
	state.total_customers_served = int(data.get("served", 0))
	state.total_taps = int(data.get("taps", 0))
	state.tap_upgrade_level = int(data.get("tap_lv", 1))
	state.set_highest_stage_raw(maxi(1, int(data.get("highest_stage", 1))))
	state.sound_enabled = bool(data.get("sound", true))

	var clk: Dictionary = data.get("clock", {})
	state.sim_clock.from_dict(clk)
	state.sync_clock_mirrors()

	var parcels: Array[Vector2i] = []
	for p in data.get("parcels", []):
		parcels.append(Vector2i(int(p[0]), int(p[1])))
	if not parcels.is_empty():
		state.world_grid.reset_ownership(parcels)

	state.road_network.clear()
	for r in data.get("roads", []):
		state.road_network.set_tile(Vector2i(int(r[0]), int(r[1])), int(r[2]))

	for sp in data.get("plots", []):
		for p in state.plots:
			if p["id"] == sp["id"]:
				p["grid_x"] = int(sp["gx"])
				p["grid_z"] = int(sp["gz"])
				p["rot"] = int(sp["rot"])
				p["is_built"] = bool(sp["built"])
				p["level"] = int(sp["lv"])
				var st_arr: Array = []
				for sid in sp.get("staff", []):
					st_arr.append(str(sid))
				p["staff"] = st_arr
				var rt: Dictionary = GameCatalog.make_runtime_bag()
				var saved_rt = sp.get("runtime", {})
				if saved_rt is Dictionary:
					for k in saved_rt.keys():
						rt[k] = saved_rt[k]
				p["runtime"] = rt

	state.parking_lots.clear()
	for sl in data.get("lots", []):
		state.parking_lots.append({
			"id": str(sl["id"]),
			"kind": int(sl["kind"]),
			"grid_x": int(sl["gx"]),
			"grid_z": int(sl["gz"]),
			"rot": int(sl["rot"]),
			"is_connected": false,
			"connected_side": -1,
			"entry_road_cell": Vector2i.ZERO,
			"lane_offset": RoadNetwork.TWO_LANE_OFFSET,
			"drive_in_path": [],
			"drive_in_routes": [],
		})

	state.decorations.clear()
	for sd in data.get("decos", []):
		state.decorations.append({
			"id": str(sd["id"]),
			"kind": int(sd["kind"]),
			"name": str(sd["name"]),
			"cost": float(sd["cost"]),
			"grid_x": int(sd["gx"]),
			"grid_z": int(sd["gz"]),
			"rot": int(sd.get("rot", 0)) & 3,
		})

	state.utilities.clear()
	for su in data.get("utilities", []):
		if su is Dictionary:
			state.utilities.append(su.duplicate(true))

	state.staff_sim.from_dict(data.get("crew", {}))
	state.staff_sim.sync_agents(state)

	state.world_grid.clear_utilities()
	for po in data.get("power_overhead", []):
		if po is Dictionary:
			state.world_grid.set_power_pole(Vector2i(int(po["x"]), int(po["z"])), po.get("meta", {}))
	for pu in data.get("power_underground", []):
		if pu is Dictionary:
			state.world_grid.set_underground_power(Vector2i(int(pu["x"]), int(pu["z"])), pu.get("meta", {}))
	for wp in data.get("water_pipes", []):
		if wp is Dictionary:
			state.world_grid.set_water_pipe(Vector2i(int(wp["x"]), int(wp["z"])), wp.get("meta", {}))

	var claimed: Array = data.get("claimed", [])
	for m in state.milestones:
		m["claimed"] = claimed.has(m["id"])

	state.recompute_network()
	if apply_offline:
		var saved_at := float(data.get("saved_at", 0.0))
		var now := Time.get_unix_time_from_system()
		var mins := int(clampf((now - saved_at) / 60.0, 0.0, 240.0))
		if mins >= 2 and state.income_per_minute() > 0.0:
			var offline: float = roundf(state.income_per_minute() * float(mins) * 0.45)
			if offline > 0.0:
				state.cash += offline
				state.total_cash_earned += offline
				state.pending_offline_cash = offline
				state.pending_offline_minutes = mins
	return true
