class_name GameState
extends Node

## Central simulation, progression, economy, building, road, traffic & persistence hub.

signal hud_changed
signal world_layout_changed

const SAVE_PATH := "user://desert_outpost_save.json"
const MAX_DECORATIONS := 16
const DAY_CYCLE_RATE := 0.0085
const LANE_OFFSET := 0.42
const HIGHWAY_SPAWN_X := 96.0

const CITY_LAYOUT := {
	"vendor": Vector2i(-8, -8),
	"food_stand": Vector2i(-4, -8),
	"oasis_plaza": Vector2i(6, -5),
	"mart": Vector2i(-8, -16),
	"diner": Vector2i(-2, -16),
	"gas_station": Vector2i(4, -9),
	"motel": Vector2i(-8, -23),
	"lookout": Vector2i(2, -23),
}
const CAREER_CART_CELL := Vector2i(-1, -14)

var rng := RandomNumberGenerator.new()
var road_network := RoadNetwork.new()
var world_grid := WorldGrid.new()
var camera_ref: DesertCamera

# Economy & progression
var cash := 0.0
var total_cash_earned := 0.0
var total_customers_served := 0
var total_taps := 0
var tap_upgrade_level := 1
var active_preset: int = GameCatalog.OutpostPreset.STAGE_ONE_CAREER
var sound_enabled := true
var pending_offline_cash := 0.0
var pending_offline_minutes := 0

# Time & lighting
var anim_time := 0.0
var time_of_day := 0.37
var auto_day_night := true

# Entities
var plots: Array[Dictionary] = []
var parking_lots: Array[Dictionary] = []
var decorations: Array[Dictionary] = []
var vehicles: Array[Dictionary] = []
var visitors: Array[Dictionary] = []
var floating_cash: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var milestones: Array[Dictionary] = []

# Tool state
var tool_mode: int = GameCatalog.WorldToolMode.PLAY
var active_road_tier: int = GameCatalog.RoadTier.DIRT
var road_erase_mode := false
var has_road_start := false
var road_line_start := Vector2i.ZERO
var road_line_end := Vector2i.ZERO

var pending_building_type := -1
var relocating_plot_id := ""
var pending_parking_kind := -1
var relocating_lot_id := ""
var relocating_lot_is_upgrade := false
var pending_deco: Dictionary = {}
var ghost_grid_x := 0
var ghost_grid_z := -12
var ghost_rotation := 0

var _next_entity_id := 1
var _traffic_cooldown := 0.8
var _autosave_accum := 0.0
var _last_hud_cash := -1
var _last_claimables := -1

var _highest_stage := 1
var _connected_built := 0
var _total_parking_spaces := 0
var _parking_tier := 0
var _avg_access := 0.0
var _suppress_stage_fx := false


func _ready() -> void:
	rng.seed = 42
	_suppress_stage_fx = true
	_init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	_init_milestones()
	_load_saved_state()
	_recompute_network()
	_seed_initial_traffic()
	_suppress_stage_fx = false
	_last_hud_cash = int(floor(cash))
	_last_claimables = claimable_milestone_count()


func attach_camera(cam: DesertCamera) -> void:
	camera_ref = cam
	reset_camera_immediate()


func _init_world(preset: int) -> void:
	active_preset = preset
	var full := preset == GameCatalog.OutpostPreset.FULL_CITY
	road_network.clear()
	parking_lots.clear()
	decorations.clear()
	vehicles.clear()
	visitors.clear()
	floating_cash.clear()
	particles.clear()
	cancel_tool_mode(false)
	_highest_stage = 1
	_build_plots(full)

	if full:
		var parcels: Array[Vector2i] = []
		for px in range(2, 6):
			for pz in range(4, 7):
				parcels.append(Vector2i(px, pz))
		world_grid.reset_ownership(parcels)
		for gz in range(-20, OutpostLayout.HIGHWAY_ENTRY_ROW_Z + 1):
			road_network.set_tile(Vector2i(-10, gz), GameCatalog.RoadTier.PAVED)
			road_network.set_tile(Vector2i(10, gz), GameCatalog.RoadTier.PAVED)
		for gx in range(-10, 11):
			for row in [-6, -13, -20]:
				road_network.set_tile(Vector2i(gx, row), GameCatalog.RoadTier.PAVED)
		parking_lots.append(_make_lot(GameCatalog.ParkingLotKind.PAVED_LOT, 3, -12, 0))
		parking_lots.append(_make_lot(GameCatalog.ParkingLotKind.GRAVEL_LOT, -4, -12, 0))
		parking_lots.append(_make_lot(GameCatalog.ParkingLotKind.DIRT_PULL_OFF, -3, -19, 0))
		cash = 1450.0
		total_cash_earned = 3650.0
		total_customers_served = 42
		tap_upgrade_level = 2
	else:
		world_grid.reset_ownership(OutpostLayout.STARTER_PARCELS)
		cash = 0.0
		total_cash_earned = 0.0
		total_customers_served = 0
		tap_upgrade_level = 1
	total_taps = 0


func _build_plots(full: bool) -> void:
	plots.clear()
	var specs := [
		["vendor", GameCatalog.BusinessType.VENDOR_STALL, true, 4 if full else 1],
		["food_stand", GameCatalog.BusinessType.FOOD_STAND, full, 3 if full else 1],
		["oasis_plaza", GameCatalog.BusinessType.OASIS_PLAZA, false, 1],
		["mart", GameCatalog.BusinessType.CONVENIENCE_STORE, full, 3 if full else 1],
		["diner", GameCatalog.BusinessType.DESERT_DINER, full, 3 if full else 1],
		["gas_station", GameCatalog.BusinessType.GAS_STATION, full, 3 if full else 1],
		["motel", GameCatalog.BusinessType.DESERT_MOTEL, full, 3 if full else 1],
		["lookout", GameCatalog.BusinessType.LOOKOUT_CAMP, full, 3 if full else 1],
	]
	for sp in specs:
		var id: String = sp[0]
		var cell: Vector2i = CAREER_CART_CELL if (not full and id == "vendor") else CITY_LAYOUT[id]
		plots.append({
			"id": id,
			"type": sp[1],
			"grid_x": cell.x,
			"grid_z": cell.y,
			"rot": 0,
			"is_built": sp[2],
			"level": sp[3],
			"bounce": 0.0,
			"build_pop": 0.0,
			"access": RoadNetwork.disconnected_report(),
		})


func _make_lot(kind: int, gx: int, gz: int, rot: int) -> Dictionary:
	var lid := "lot_%d" % _next_entity_id
	_next_entity_id += 1
	return {
		"id": lid,
		"kind": kind,
		"grid_x": gx,
		"grid_z": gz,
		"rot": rot & 3,
		"is_connected": false,
		"connected_side": -1,
		"drive_in_path": [],
	}


func _init_milestones() -> void:
	milestones = [
		{"id": "m_park1", "title": "First Pull-Off", "desc": "Place a Dirt Pull-Off beside your cart", "reward": 40.0, "claimed": false},
		{"id": "m_road1", "title": "Desert Access Road", "desc": "Connect Route 163 to your cart with a road", "reward": 60.0, "claimed": false},
		{"id": "m_land", "title": "Land Rush", "desc": "Buy your first extra desert land parcel", "reward": 100.0, "claimed": false},
		{"id": "m_3biz", "title": "Desert Strip", "desc": "Operate at least 3 road-connected businesses", "reward": 160.0, "claimed": false},
		{"id": "m_paved_loop", "title": "Highway Loop", "desc": "Build 4+ Paved tiles & 2 Route 163 junctions", "reward": 420.0, "claimed": false},
		{"id": "m_oasis", "title": "Complete the Outpost", "desc": "Build all 8 desert city landmarks", "reward": 1000.0, "claimed": false},
		{"id": "m_taps", "title": "Friendly Host", "desc": "Serve 25 active taps at the outpost", "reward": 120.0, "claimed": false},
		{"id": "m_visitors", "title": "Desert Destination", "desc": "Serve 60 highway visitors", "reward": 400.0, "claimed": false},
	]


func is_milestone_completed(m: Dictionary) -> bool:
	match m["id"]:
		"m_park1": return not parking_lots.is_empty()
		"m_road1":
			for p in plots:
				if p["is_built"] and p["access"]["has_direct_road"]:
					return true
			return false
		"m_land": return world_grid.owned_parcels.size() > OutpostLayout.STARTER_PARCELS.size()
		"m_3biz": return _connected_built >= 3
		"m_paved_loop": return road_network.paved_road_count() >= 4 and road_network.highway_turn_off_count() >= 2
		"m_oasis": return built_count() == plots.size()
		"m_taps": return total_taps >= 25
		"m_visitors": return total_customers_served >= 60
		_: return false


func claimable_milestone_count() -> int:
	var n := 0
	for m in milestones:
		if not m["claimed"] and is_milestone_completed(m):
			n += 1
	return n


func next_active_milestone() -> Dictionary:
	for m in milestones:
		if not m["claimed"] and is_milestone_completed(m):
			return m
	for m in milestones:
		if not m["claimed"]:
			return m
	return {}


func claim_milestone(m: Dictionary) -> bool:
	if m.is_empty() or m["claimed"] or not is_milestone_completed(m):
		return false
	m["claimed"] = true
	var r: float = m["reward"]
	cash += r
	total_cash_earned += r
	_float_notice(town_focus() + Vector3(0, 3.5, 0), "+%s BONUS!" % GameCatalog.format_cash(r), DesertPalette.GOLD)
	save_state()
	hud_changed.emit()
	return true


# --- Helpers for Plot & Lot positions ---

func plot_position(p: Dictionary) -> Vector3:
	var data: Dictionary = GameCatalog.BUSINESSES[p["type"]]
	var sz := OutpostLayout.rotated_size(data["grid_w"], data["grid_d"], p["rot"])
	return OutpostLayout.footprint_center(p["grid_x"], p["grid_z"], sz.x, sz.y)


func plot_entrance_cell(p: Dictionary) -> Vector2i:
	var data: Dictionary = GameCatalog.BUSINESSES[p["type"]]
	var sz := OutpostLayout.rotated_size(data["grid_w"], data["grid_d"], p["rot"])
	var gx: int = p["grid_x"]
	var gz: int = p["grid_z"]
	match int(p["rot"]) & 3:
		0: return Vector2i(gx + int(sz.x / 2), gz + sz.y)
		1: return Vector2i(gx - 1, gz + int(sz.y / 2))
		2: return Vector2i(gx + int(sz.x / 2), gz - 1)
		_: return Vector2i(gx + sz.x, gz + int(sz.y / 2))


func plot_visitor_stop(p: Dictionary) -> Vector3:
	var step := OutpostLayout.forward_step_for_quarter_turn(p["rot"])
	var data: Dictionary = GameCatalog.BUSINESSES[p["type"]]
	var sz := OutpostLayout.rotated_size(data["grid_w"], data["grid_d"], p["rot"])
	var front_dist := float(sz.x if step.x != 0 else sz.y) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.55
	var c := plot_position(p)
	return Vector3(c.x + step.x * front_dist, 0.0, c.z + step.y * front_dist)


func lot_position(lot: Dictionary) -> Vector3:
	var spec: Dictionary = GameCatalog.PARKING_LOTS[lot["kind"]]
	var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], lot["rot"])
	return OutpostLayout.footprint_center(lot["grid_x"], lot["grid_z"], sz.x, sz.y)


func lot_slot_positions(lot: Dictionary) -> Array[Vector3]:
	var c := lot_position(lot)
	var count: int = GameCatalog.PARKING_LOTS[lot["kind"]]["spaces"]
	var dims := BuildingBuilder.lot_oriented_dims(lot)
	var side := BuildingBuilder.lot_effective_side(lot)
	var u := BuildingBuilder.lot_bay_row_axis(side)
	var f := BuildingBuilder.lot_pull_in_dir(side)
	var usable := dims.x - 0.36
	var out: Array[Vector3] = []
	for i in range(count):
		var off := ((float(i) + 0.5) / float(count) - 0.5) * usable
		out.append(c + u * off - f * 0.14)
	return out


func lot_aisle_point(lot: Dictionary, slot_idx: int) -> Vector3:
	var slots := lot_slot_positions(lot)
	var slot := slots[clampi(slot_idx, 0, slots.size() - 1)]
	var dims := BuildingBuilder.lot_oriented_dims(lot)
	var f := BuildingBuilder.lot_pull_in_dir(BuildingBuilder.lot_effective_side(lot))
	return slot - f * (dims.y * 0.5 + 0.85)


func lot_visitor_spawn(lot: Dictionary, slot_idx: int, pass_idx: int) -> Vector3:
	var slots := lot_slot_positions(lot)
	var slot := slots[clampi(slot_idx, 0, slots.size() - 1)]
	var dims := BuildingBuilder.lot_oriented_dims(lot)
	var side := BuildingBuilder.lot_effective_side(lot)
	var count: int = GameCatalog.PARKING_LOTS[lot["kind"]]["spaces"]
	var pitch := (dims.x - 0.36) / float(count)
	return slot + BuildingBuilder.lot_bay_row_axis(side) * (pitch * 0.42) + BuildingBuilder.lot_pull_in_dir(side) * (dims.y * 0.32 - float(pass_idx) * 0.36)


func cart_plot() -> Dictionary:
	return plots[0]


func town_focus() -> Vector3:
	if not plots.is_empty() and plots[0]["is_built"]:
		return plot_position(plots[0])
	var sp := OutpostLayout.STARTER_PARCELS[0]
	return OutpostLayout.parcel_center(sp.x, sp.y)


# --- Progression & Economy Metrics ---

func outpost_stage() -> int:
	return _highest_stage


func stage_info() -> Dictionary:
	return GameCatalog.STAGES[clampi(_highest_stage - 1, 0, GameCatalog.STAGES.size() - 1)]


func built_count() -> int:
	var n := 0
	for p in plots:
		if p["is_built"]:
			n += 1
	return n


func connected_built_count() -> int:
	return _connected_built


func total_parking_spaces() -> int:
	return _total_parking_spaces


func average_access_score() -> float:
	return _avg_access


func decoration_bonus_mult() -> float:
	return 1.0 + float(decorations.size()) * 0.04


func income_per_minute() -> float:
	if _total_parking_spaces <= 0:
		return 0.0
	var s := 0.0
	for p in plots:
		if not p["is_built"] or float(p["access"]["score"]) <= 0.0:
			continue
		s += GameCatalog.income_for_level(p["type"], p["level"]) * float(p["access"]["score"])
	return round(s * decoration_bonus_mult())


func tap_income() -> float:
	var base := 5.0 + float(tap_upgrade_level - 1) * 5.0
	var bonus := float(built_count() - 1) * 2.0
	return round((base + bonus) * decoration_bonus_mult())


func tap_upgrade_cost() -> float:
	return round(35.0 * pow(1.65, float(tap_upgrade_level - 1)))


func is_road_tier_unlocked(tier: int) -> bool:
	return _highest_stage >= int(GameCatalog.ROAD_TIERS[tier]["unlock_stage"])


func is_parking_kind_unlocked(kind: int) -> bool:
	return _highest_stage >= int(GameCatalog.PARKING_LOTS[kind]["unlock_stage"])


func is_deco_unlocked(kind: int) -> bool:
	return _highest_stage >= GameCatalog.decoration_unlock_stage(kind)


func is_plot_unlocked(p: Dictionary) -> bool:
	if p["is_built"]:
		return true
	return _highest_stage >= int(GameCatalog.BUSINESSES[p["type"]]["stage"])


func upgrade_lock_reason(p: Dictionary) -> String:
	if not p["is_built"]:
		return "UNBUILT"
	var max_lv: int = GameCatalog.BUSINESSES[p["type"]]["max_level"]
	if p["level"] >= max_lv:
		return "MAX"
	if not p["access"]["has_parking"] or float(p["access"]["score"]) <= 0.0:
		return "NO ROAD"
	var nxt: int = p["level"] + 1
	if nxt == 3 and _highest_stage < 3:
		return "STAGE 3"
	if nxt == 4:
		if _highest_stage < 4:
			return "STAGE 4"
		if int(p["access"]["road_tier"]) < GameCatalog.RoadTier.GRAVEL:
			return "NEED GRAVEL"
	if nxt == 5:
		if _highest_stage < 6:
			return "STAGE 6"
		if int(p["access"]["road_tier"]) != GameCatalog.RoadTier.PAVED:
			return "NEED PAVED"
	return ""


func parking_upgrade_cost(lot: Dictionary) -> float:
	var nxt := GameCatalog.next_parking_upgrade(lot["kind"])
	if nxt < 0:
		return 0.0
	return maxf(20.0, float(GameCatalog.PARKING_LOTS[nxt]["cost"]) - float(GameCatalog.PARKING_LOTS[lot["kind"]]["cost"]))


func parking_upgrade_lock_reason(lot: Dictionary) -> String:
	var nxt := GameCatalog.next_parking_upgrade(lot["kind"])
	if nxt < 0:
		return "MAX"
	if not is_parking_kind_unlocked(nxt):
		return "STAGE %d" % int(GameCatalog.PARKING_LOTS[nxt]["unlock_stage"])
	return ""


func needs_access_road() -> bool:
	if road_network.highway_turn_off_count() == 0:
		return true
	for p in plots:
		if p["is_built"] and p["access"]["has_direct_road"]:
			return false
	return true


func is_world_point_occupied(x: float, z: float) -> bool:
	for ox in [-0.7, 0.7]:
		for oz in [-0.7, 0.7]:
			var c := OutpostLayout.world_to_cell(Vector3(x + ox, 0.0, z + oz))
			if road_network.has_road(c) or world_grid.is_occupied(c):
				return true
	return false


func _recompute_network() -> void:
	road_network.recompute(plots, parking_lots, decorations)
	world_grid.rebuild_occupancy(plots, parking_lots, decorations)
	_refresh_progression()
	world_layout_changed.emit()


func _refresh_progression() -> void:
	_connected_built = 0
	var built_n := 0
	var score_sum := 0.0
	for p in plots:
		if p["is_built"]:
			built_n += 1
			var sc: float = p["access"]["score"]
			score_sum += sc
			if sc > 0.0:
				_connected_built += 1
	_avg_access = 0.0 if built_n == 0 else score_sum / float(built_n)

	_total_parking_spaces = 0
	var has_paved := false
	var has_gravel := false
	for l in parking_lots:
		if l["is_connected"]:
			_total_parking_spaces += int(GameCatalog.PARKING_LOTS[l["kind"]]["spaces"])
			if l["kind"] == GameCatalog.ParkingLotKind.PAVED_LOT:
				has_paved = true
			elif l["kind"] == GameCatalog.ParkingLotKind.GRAVEL_LOT:
				has_gravel = true
	_parking_tier = 0 if _total_parking_spaces == 0 else (3 if (has_paved or _total_parking_spaces >= 6) else (2 if (has_gravel or _total_parking_spaces >= 4) else 1))

	var stage := 1
	if _total_parking_spaces >= 2 and road_network.highway_turn_off_count() > 0:
		stage = 2
	if stage >= 2 and _connected_built >= 2 and (total_customers_served >= 4 or road_network.gravel_or_better_count() >= 3):
		stage = 3
	if stage >= 3 and _connected_built >= 4 and _total_parking_spaces >= 4:
		stage = 4
	if stage >= 4 and _connected_built >= 5 and (road_network.paved_road_count() >= 4 or _total_parking_spaces >= 6):
		stage = 5
	if stage >= 5 and _connected_built >= 7 and _total_parking_spaces >= 6:
		stage = 6

	if stage > _highest_stage:
		_highest_stage = stage
		if not _suppress_stage_fx:
			_float_notice(town_focus() + Vector3(0, 4.2, 0), "STAGE %d · %s!" % [stage, str(stage_info()["title"]).to_upper()], DesertPalette.GOLD, 2.2)


# --- Simulation Tick ---

func _process(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	anim_time += dt
	if camera_ref != null:
		camera_ref.update_smoothing(dt)
	if auto_day_night:
		time_of_day = fmod(time_of_day + dt * DAY_CYCLE_RATE, 1.0)

	var earned := (income_per_minute() * 0.68 / 60.0) * dt
	cash += earned
	total_cash_earned += earned

	_autosave_accum += dt
	if _autosave_accum >= 6.0:
		_autosave_accum = 0.0
		save_state()

	for p in plots:
		if p["bounce"] > 0.0:
			p["bounce"] = maxf(0.0, p["bounce"] - dt)
		if p["build_pop"] > 0.0:
			p["build_pop"] = maxf(0.0, p["build_pop"] - dt * 1.45)

	for i in range(floating_cash.size() - 1, -1, -1):
		floating_cash[i]["age"] += dt
		if floating_cash[i]["age"] >= floating_cash[i]["duration"]:
			floating_cash.remove_at(i)

	for i in range(particles.size() - 1, -1, -1):
		var pt := particles[i]
		pt["age"] += dt
		if pt["age"] >= pt["duration"]:
			particles.remove_at(i)
			continue
		pt["pos"] += pt["vel"] * dt
		var grav := 9.5 if pt["is_coin"] else 2.8
		pt["vel"] = Vector3(pt["vel"].x * 0.96, pt["vel"].y - grav * dt, pt["vel"].z * 0.96)
		if pt["pos"].y < 0.05:
			pt["pos"].y = 0.05
			pt["vel"].x *= 0.6
			pt["vel"].y = 0.0
			pt["vel"].z *= 0.6

	_update_vehicles(dt)
	_update_visitors(dt)

	var cfloor := int(floor(cash))
	var claims := claimable_milestone_count()
	if cfloor != _last_hud_cash or claims != _last_claimables:
		_last_hud_cash = cfloor
		_last_claimables = claims
		hud_changed.emit()


# --- Player Actions & Tap ---

func perform_active_tap(plot_idx: int = 0) -> void:
	var p := plots[clampi(plot_idx, 0, plots.size() - 1)]
	var gain := tap_income()
	cash += gain
	total_cash_earned += gain
	total_taps += 1
	p["bounce"] = 0.36
	var origin := plot_position(p) + Vector3(0, 2.35, 0.35)
	var sign_x := 1.0 if total_taps % 2 == 0 else -1.0
	floating_cash.append({
		"pos": origin + Vector3(sign_x * 0.22, 0.15, 0.0),
		"text": "+%s" % GameCatalog.format_cash(gain),
		"color": DesertPalette.GOLD_POPUP,
		"drift_x": sign_x * (0.45 + rng.randf() * 0.55),
		"age": 0.0,
		"duration": 1.15,
	})
	for i in range(6):
		var a := rng.randf() * TAU
		var spd := 1.6 + rng.randf() * 2.0
		particles.append({
			"pos": origin,
			"vel": Vector3(cos(a) * spd, 3.0 + rng.randf() * 1.6, sin(a) * spd),
			"color": DesertPalette.GOLD,
			"size": 0.16,
			"age": 0.0,
			"duration": 0.68,
			"is_coin": true,
		})
	hud_changed.emit()


func notify_shortfall(world_pos: Vector3, needed: float) -> void:
	_float_notice(world_pos + Vector3(0, 0.8, 0), "NEED %s" % GameCatalog.format_cash(ceil(needed)), Color("ffb899"), 0.95)


func _float_notice(world_pos: Vector3, text: String, col: Color = Color("ffb899"), dur: float = 1.3) -> void:
	floating_cash.append({
		"pos": world_pos,
		"text": text,
		"color": col,
		"drift_x": (rng.randf() - 0.5) * 0.3,
		"age": 0.0,
		"duration": dur,
	})


func _spawn_dust(center: Vector3, count: int = 12) -> void:
	for i in range(count):
		var a := (float(i) / float(count)) * TAU + rng.randf() * 0.4
		var spd := 1.6 + rng.randf() * 2.0
		particles.append({
			"pos": center + Vector3(cos(a) * 0.6, 0.3, sin(a) * 0.6),
			"vel": Vector3(cos(a) * spd, 1.4 + rng.randf() * 1.4, sin(a) * spd),
			"color": DesertPalette.SAND_LIGHT,
			"size": 0.28 + rng.randf() * 0.14,
			"age": 0.0,
			"duration": 0.85,
			"is_coin": false,
		})


func handle_world_tap(screen_pos: Vector2) -> void:
	if camera_ref == null:
		return
	var gp := camera_ref.screen_to_ground(screen_pos, 0.0)
	match tool_mode:
		GameCatalog.WorldToolMode.PAINT_ROAD:
			road_line_tap(OutpostLayout.world_to_cell(gp))
			return
		GameCatalog.WorldToolMode.PLACE_BUILDING, GameCatalog.WorldToolMode.PLACE_PARKING, GameCatalog.WorldToolMode.PLACE_DECORATION:
			move_ghost_to_world(gp)
			return
		GameCatalog.WorldToolMode.BUY_LAND:
			var cell := OutpostLayout.world_to_cell(gp)
			if OutpostLayout.is_cell_in_map(cell.x, cell.y):
				buy_parcel(OutpostLayout.parcel_of(cell.x, cell.y))
			return

	var mp := camera_ref.screen_to_ground(screen_pos, 1.4)
	var best_idx := -1
	var best_d := 1e9
	for i in range(plots.size()):
		var p := plots[i]
		if not p["is_built"]:
			continue
		var data: Dictionary = GameCatalog.BUSINESSES[p["type"]]
		var sz := OutpostLayout.rotated_size(data["grid_w"], data["grid_d"], p["rot"])
		var hw := float(sz.x) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.9
		var hd := float(sz.y) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.9
		var pos := plot_position(p)
		var hit := (absf(gp.x - pos.x) <= hw and absf(gp.z - pos.z) <= hd) or (absf(mp.x - pos.x) <= hw and absf(mp.z - pos.z) <= hd)
		if hit:
			var d := pos.distance_to(gp)
			if d < best_d:
				best_d = d
				best_idx = i
	if best_idx >= 0:
		perform_active_tap(best_idx)


func upgrade_plot(p: Dictionary) -> bool:
	if not p["is_built"]:
		return false
	var lock := upgrade_lock_reason(p)
	if not lock.is_empty():
		_float_notice(plot_position(p) + Vector3(0, 2.8, 0), lock)
		return false
	var cost := GameCatalog.upgrade_cost_for_level(p["type"], p["level"])
	if cash < cost:
		notify_shortfall(plot_position(p), cost - cash)
		return false
	cash -= cost
	p["level"] += 1
	p["bounce"] = 0.40
	_spawn_dust(plot_position(p), 10)
	_float_notice(plot_position(p) + Vector3(0, 3.0, 0), "LV %d!" % p["level"], DesertPalette.NEON_TURQUOISE, 1.35)
	world_layout_changed.emit()
	save_state()
	hud_changed.emit()
	return true


func upgrade_tap_power() -> bool:
	var cost := tap_upgrade_cost()
	if cash < cost:
		return false
	cash -= cost
	tap_upgrade_level += 1
	_float_notice(plot_position(plots[0]) + Vector3(0, 2.7, 0), "TAP +%s!" % GameCatalog.format_cash(tap_income()), DesertPalette.GOLD, 1.25)
	save_state()
	hud_changed.emit()
	return true


# --- Land, Roads & Freeform Placement ---

func cancel_tool_mode(emit_sig: bool = true) -> void:
	tool_mode = GameCatalog.WorldToolMode.PLAY
	road_erase_mode = false
	has_road_start = false
	pending_building_type = -1
	relocating_plot_id = ""
	pending_parking_kind = -1
	relocating_lot_id = ""
	relocating_lot_is_upgrade = false
	pending_deco = {}
	if emit_sig:
		world_layout_changed.emit()
		hud_changed.emit()


func enter_road_mode(tier: int = -1, erase: bool = false) -> void:
	cancel_tool_mode(false)
	tool_mode = GameCatalog.WorldToolMode.PAINT_ROAD
	road_erase_mode = erase
	if tier >= 0 and is_road_tier_unlocked(tier):
		active_road_tier = tier
	elif not is_road_tier_unlocked(active_road_tier):
		active_road_tier = GameCatalog.RoadTier.DIRT
	if camera_ref != null:
		camera_ref.ensure_min_pitch(0.78)
	world_layout_changed.emit()
	hud_changed.emit()


func set_road_brush(tier: int) -> void:
	if not is_road_tier_unlocked(tier):
		return
	active_road_tier = tier
	road_erase_mode = false
	hud_changed.emit()


func set_road_erase(erase: bool) -> void:
	road_erase_mode = erase
	hud_changed.emit()


func road_line_tap(cell: Vector2i) -> void:
	if not has_road_start:
		has_road_start = true
		road_line_start = cell
		road_line_end = cell
	else:
		road_line_end = cell
	world_layout_changed.emit()
	hud_changed.emit()


func clear_road_line() -> void:
	has_road_start = false
	world_layout_changed.emit()
	hud_changed.emit()


func compute_road_line_preview() -> Dictionary:
	if tool_mode != GameCatalog.WorldToolMode.PAINT_ROAD or not has_road_start:
		return {"cells": [], "build": [], "skip": [], "blocked": [], "cost": 0.0, "reason": ""}
	var cells := RoadNetwork.line_path(road_line_start, road_line_end)
	var build: Array[Vector2i] = []
	var skip: Array[Vector2i] = []
	var blocked: Array[Vector2i] = []
	var cost := 0.0
	var reason := ""
	if road_erase_mode:
		for c in cells:
			var t := road_network.tile_tier(c)
			if t < 0:
				skip.append(c)
			else:
				build.append(c)
				cost -= round(float(GameCatalog.ROAD_TIERS[t]["cost_per_tile"]) * 0.5)
		if build.is_empty():
			reason = "No road tiles on this line"
		return {"cells": cells, "build": build, "skip": skip, "blocked": blocked, "cost": cost, "reason": reason}

	var target_cost: float = GameCatalog.ROAD_TIERS[active_road_tier]["cost_per_tile"]
	for c in cells:
		if not OutpostLayout.is_cell_in_map(c.x, c.y):
			blocked.append(c)
			if reason.is_empty(): reason = "Outside the desert map"
			continue
		if world_grid.is_occupied(c):
			blocked.append(c)
			if reason.is_empty(): reason = "Blocked by a building, lot or prop"
			continue
		var ex := road_network.tile_tier(c)
		if ex >= active_road_tier:
			skip.append(c)
			continue
		var prev_c := float(GameCatalog.ROAD_TIERS[ex]["cost_per_tile"]) if ex >= 0 else 0.0
		build.append(c)
		cost += maxf(2.0, target_cost - prev_c)

	var cur_j := road_network.highway_turn_off_count()
	var nxt_j := road_network.highway_turn_off_count_with(build)
	if nxt_j > cur_j and nxt_j > int(stage_info()["max_highway_turn_offs"]):
		if reason.is_empty():
			reason = "Stage %d allows %d highway junction(s)" % [_highest_stage, int(stage_info()["max_highway_turn_offs"])]
	if build.is_empty() and reason.is_empty():
		reason = "Already built at this tier"
	return {"cells": cells, "build": build, "skip": skip, "blocked": blocked, "cost": cost, "reason": reason}


func confirm_road_line() -> bool:
	var prev := compute_road_line_preview()
	var build: Array = prev["build"]
	if not str(prev["reason"]).is_empty() or build.is_empty():
		return false
	var park_before := _total_parking_spaces
	var cost: float = prev["cost"]
	if road_erase_mode:
		for c in build:
			road_network.remove_tile(c)
		cash += -cost
	else:
		if cash < cost:
			notify_shortfall(OutpostLayout.cell_center_v(build.back()), cost - cash)
			return false
		cash -= cost
		for c in build:
			road_network.set_tile(c, active_road_tier)

	_recompute_network()
	for i in range(0, build.size(), 3):
		_spawn_dust(OutpostLayout.cell_center_v(build[i]), 3)
	_float_notice(
		OutpostLayout.cell_center_v(build.back()) + Vector3(0, 1.8, 0),
		"+%s REFUND" % GameCatalog.format_cash(-cost) if road_erase_mode else "%d TILES BUILT" % build.size(),
		DesertPalette.GOLD
	)
	if park_before == 0 and _total_parking_spaces > 0:
		for l in parking_lots:
			if l["is_connected"]:
				_dispatch_immediate_customer(l)
				break
	has_road_start = false
	save_state()
	hud_changed.emit()
	return true


func suggest_access_road() -> void:
	var ent := plot_entrance_cell(cart_plot())
	enter_road_mode(GameCatalog.RoadTier.DIRT, false)
	has_road_start = true
	road_line_start = Vector2i(ent.x, OutpostLayout.HIGHWAY_ENTRY_ROW_Z)
	road_line_end = ent
	if camera_ref != null:
		var a := OutpostLayout.cell_center_v(road_line_start)
		var b := OutpostLayout.cell_center_v(ent)
		camera_ref.focus_on(a.lerp(b, 0.5) + Vector3(0, 1.0, 0), maxf(34.0, a.distance_to(b) * 1.25), maxf(camera_ref.pitch, 0.9))
	world_layout_changed.emit()
	hud_changed.emit()


func enter_land_mode() -> void:
	cancel_tool_mode(false)
	tool_mode = GameCatalog.WorldToolMode.BUY_LAND
	if camera_ref != null:
		camera_ref.focus_on(town_focus() + Vector3(0, 1.0, 0), maxf(camera_ref.distance, 72.0), maxf(camera_ref.pitch, 0.95))
	world_layout_changed.emit()
	hud_changed.emit()


func can_buy_more_land() -> bool:
	return world_grid.owned_parcels.size() < int(stage_info()["max_parcels"])


func buy_parcel(p: Vector2i) -> bool:
	if world_grid.owned_parcels.has(p):
		return false
	var center := OutpostLayout.parcel_center(p.x, p.y)
	if not world_grid.is_parcel_purchasable(p):
		_float_notice(center + Vector3(0, 2.0, 0), "MUST BORDER YOUR LAND")
		return false
	if not can_buy_more_land():
		_float_notice(center + Vector3(0, 2.0, 0), "STAGE %d FOR MORE LAND" % (_highest_stage + 1))
		return false
	var price := world_grid.next_parcel_price()
	if cash < price:
		notify_shortfall(center + Vector3(0, 1.6, 0), price - cash)
		return false
	cash -= price
	world_grid.buy_parcel(p)
	_spawn_dust(center, 14)
	_float_notice(center + Vector3(0, 2.4, 0), "LAND +1!", DesertPalette.GOLD)
	world_layout_changed.emit()
	save_state()
	hud_changed.emit()
	return true


func _cell_block_reason(cell: Vector2i, ignore_id: String = "") -> String:
	if not OutpostLayout.is_cell_in_map(cell.x, cell.y):
		return "Outside the desert map"
	if not world_grid.is_cell_owned(cell):
		return "Buy this land first"
	if road_network.has_road(cell):
		return "Overlaps a road"
	if world_grid.is_occupied_except(cell, ignore_id):
		return "Overlaps another structure"
	return ""


func validate_rect(gx: int, gz: int, base_w: int, base_d: int, rot: int, ignore_id: String = "") -> String:
	var sz := OutpostLayout.rotated_size(base_w, base_d, rot)
	for dx in range(sz.x):
		for dz in range(sz.y):
			var r := _cell_block_reason(Vector2i(gx + dx, gz + dz), ignore_id)
			if not r.is_empty():
				return r
	return ""


func ghost_size() -> Vector2i:
	if tool_mode == GameCatalog.WorldToolMode.PLACE_BUILDING and pending_building_type >= 0:
		var d: Dictionary = GameCatalog.BUSINESSES[pending_building_type]
		return OutpostLayout.rotated_size(d["grid_w"], d["grid_d"], ghost_rotation)
	if tool_mode == GameCatalog.WorldToolMode.PLACE_PARKING and pending_parking_kind >= 0:
		var s: Dictionary = GameCatalog.PARKING_LOTS[pending_parking_kind]
		return OutpostLayout.rotated_size(s["grid_w"], s["grid_d"], ghost_rotation)
	return Vector2i(1, 1)


func ghost_invalid_reason() -> String:
	match tool_mode:
		GameCatalog.WorldToolMode.PLACE_BUILDING:
			if pending_building_type < 0: return "No building"
			var d: Dictionary = GameCatalog.BUSINESSES[pending_building_type]
			var ign := "" if relocating_plot_id.is_empty() else "plot:%s" % relocating_plot_id
			return validate_rect(ghost_grid_x, ghost_grid_z, d["grid_w"], d["grid_d"], ghost_rotation, ign)
		GameCatalog.WorldToolMode.PLACE_PARKING:
			if pending_parking_kind < 0: return "No lot"
			var s: Dictionary = GameCatalog.PARKING_LOTS[pending_parking_kind]
			var ign := "" if relocating_lot_id.is_empty() else "lot:%s" % relocating_lot_id
			return validate_rect(ghost_grid_x, ghost_grid_z, s["grid_w"], s["grid_d"], ghost_rotation, ign)
		GameCatalog.WorldToolMode.PLACE_DECORATION:
			return _cell_block_reason(Vector2i(ghost_grid_x, ghost_grid_z))
	return ""


func ghost_access_preview() -> Dictionary:
	if tool_mode != GameCatalog.WorldToolMode.PLACE_BUILDING or pending_building_type < 0:
		return RoadNetwork.disconnected_report()
	return road_network.evaluate_building_access(pending_building_type, ghost_grid_x, ghost_grid_z, ghost_rotation, parking_lots)


func start_placing_building(btype: int) -> void:
	for p in plots:
		if p["type"] == btype:
			if p["is_built"] or not is_plot_unlocked(p):
				return
			break
	cancel_tool_mode(false)
	tool_mode = GameCatalog.WorldToolMode.PLACE_BUILDING
	pending_building_type = btype
	ghost_rotation = 0
	var spot := _find_smart_building_spot(btype)
	ghost_grid_x = spot.x
	ghost_grid_z = spot.y
	_focus_ghost()
	world_layout_changed.emit()
	hud_changed.emit()


func start_relocating_plot(p: Dictionary) -> void:
	if not p["is_built"]:
		return
	cancel_tool_mode(false)
	tool_mode = GameCatalog.WorldToolMode.PLACE_BUILDING
	pending_building_type = p["type"]
	relocating_plot_id = p["id"]
	ghost_grid_x = p["grid_x"]
	ghost_grid_z = p["grid_z"]
	ghost_rotation = p["rot"]
	_focus_ghost()
	world_layout_changed.emit()
	hud_changed.emit()


func start_placing_parking(kind: int) -> void:
	if not is_parking_kind_unlocked(kind):
		return
	cancel_tool_mode(false)
	tool_mode = GameCatalog.WorldToolMode.PLACE_PARKING
	pending_parking_kind = kind
	var res := _find_smart_parking_spot(kind)
	ghost_grid_x = res[0].x
	ghost_grid_z = res[0].y
	ghost_rotation = res[1]
	_focus_ghost()
	world_layout_changed.emit()
	hud_changed.emit()


func start_relocating_parking(lot: Dictionary, upgrade_to: int = -1) -> void:
	cancel_tool_mode(false)
	tool_mode = GameCatalog.WorldToolMode.PLACE_PARKING
	pending_parking_kind = upgrade_to if upgrade_to >= 0 else lot["kind"]
	relocating_lot_id = lot["id"]
	relocating_lot_is_upgrade = upgrade_to >= 0 and upgrade_to != lot["kind"]
	ghost_grid_x = lot["grid_x"]
	ghost_grid_z = lot["grid_z"]
	ghost_rotation = lot["rot"]
	_focus_ghost()
	world_layout_changed.emit()
	hud_changed.emit()


func start_placing_decoration(deco_spec: Dictionary) -> void:
	if not is_deco_unlocked(deco_spec["kind"]) or decorations.size() >= MAX_DECORATIONS:
		return
	cancel_tool_mode(false)
	tool_mode = GameCatalog.WorldToolMode.PLACE_DECORATION
	pending_deco = deco_spec
	ghost_rotation = 0
	var spot := _find_smart_deco_spot()
	ghost_grid_x = spot.x
	ghost_grid_z = spot.y
	_focus_ghost()
	world_layout_changed.emit()
	hud_changed.emit()


func rotate_ghost() -> void:
	if tool_mode != GameCatalog.WorldToolMode.PLACE_BUILDING and tool_mode != GameCatalog.WorldToolMode.PLACE_PARKING:
		return
	ghost_rotation = (ghost_rotation + 1) & 3
	world_layout_changed.emit()
	hud_changed.emit()


func move_ghost_to_world(world_pos: Vector3) -> void:
	var c := OutpostLayout.world_to_cell(world_pos)
	var sz := ghost_size()
	var nx := clampi(c.x - int(sz.x / 2), OutpostLayout.MIN_GRID_X, OutpostLayout.MAX_GRID_X - sz.x + 1)
	var nz := clampi(c.y - int(sz.y / 2), OutpostLayout.MIN_GRID_Z, OutpostLayout.MAX_GRID_Z - sz.y + 1)
	if nx != ghost_grid_x or nz != ghost_grid_z:
		ghost_grid_x = nx
		ghost_grid_z = nz
		world_layout_changed.emit()
		hud_changed.emit()


func _focus_ghost() -> void:
	if camera_ref == null:
		return
	var sz := ghost_size()
	var center := OutpostLayout.footprint_center(ghost_grid_x, ghost_grid_z, sz.x, sz.y)
	camera_ref.focus_on(center + Vector3(0, 1.2, 0), clampf(camera_ref.distance, 22.0, 46.0))
	camera_ref.ensure_min_pitch(0.72)


func confirm_placement() -> bool:
	if not ghost_invalid_reason().is_empty():
		return false
	var ok := false
	match tool_mode:
		GameCatalog.WorldToolMode.PLACE_BUILDING:
			if not relocating_plot_id.is_empty():
				for p in plots:
					if p["id"] == relocating_plot_id:
						p["grid_x"] = ghost_grid_x
						p["grid_z"] = ghost_grid_z
						p["rot"] = ghost_rotation & 3
						p["bounce"] = 0.36
						_recompute_network()
						_spawn_dust(plot_position(p), 10)
						_float_notice(plot_position(p) + Vector3(0, 2.6, 0), "MOVED · %d%%" % roundi(float(p["access"]["score"]) * 100.0), DesertPalette.NEON_TURQUOISE)
						ok = true
						break
			else:
				for p in plots:
					if p["type"] == pending_building_type and not p["is_built"]:
						var cost: float = GameCatalog.BUSINESSES[pending_building_type]["purchase_cost"]
						if cash < cost:
							notify_shortfall(OutpostLayout.cell_center(ghost_grid_x, ghost_grid_z), cost - cash)
							return false
						cash -= cost
						p["grid_x"] = ghost_grid_x
						p["grid_z"] = ghost_grid_z
						p["rot"] = ghost_rotation & 3
						p["is_built"] = true
						p["level"] = 1
						p["build_pop"] = 1.0
						p["bounce"] = 0.38
						_recompute_network()
						_spawn_dust(plot_position(p), 14)
						var sc: float = p["access"]["score"]
						_float_notice(plot_position(p) + Vector3(0, 2.8, 0), "BUILT! %d%%" % roundi(sc * 100.0) if sc > 0.0 else "BUILT! ADD ROAD", DesertPalette.GOLD if sc > 0.0 else Color("ffb899"), 1.5)
						ok = true
						break
		GameCatalog.WorldToolMode.PLACE_PARKING:
			if not relocating_lot_id.is_empty():
				for l in parking_lots:
					if l["id"] == relocating_lot_id:
						ok = _apply_relocate_parking(l, ghost_grid_x, ghost_grid_z, ghost_rotation, pending_parking_kind if relocating_lot_is_upgrade else -1)
						break
			else:
				ok = place_parking_lot_at(pending_parking_kind, ghost_grid_x, ghost_grid_z, ghost_rotation)
		GameCatalog.WorldToolMode.PLACE_DECORATION:
			if not pending_deco.is_empty():
				var cost: float = pending_deco["cost"]
				if cash < cost:
					notify_shortfall(OutpostLayout.cell_center(ghost_grid_x, ghost_grid_z), cost - cash)
					return false
				cash -= cost
				var spot := OutpostLayout.cell_center(ghost_grid_x, ghost_grid_z)
				decorations.append({
					"id": "deco_%d" % _next_entity_id,
					"kind": pending_deco["kind"],
					"name": pending_deco["name"],
					"cost": cost,
					"grid_x": ghost_grid_x,
					"grid_z": ghost_grid_z,
				})
				_next_entity_id += 1
				_recompute_network()
				_spawn_dust(spot, 8)
				_float_notice(spot + Vector3(0, 2.0, 0), "+8% TRAFFIC!" if pending_deco["kind"] == GameCatalog.DecorationKind.WOODEN_SIGNPOST else "+4% TIPS!", DesertPalette.GOLD_POPUP)
				ok = true
	if ok:
		cancel_tool_mode(false)
		save_state()
		world_layout_changed.emit()
		hud_changed.emit()
	return ok


func place_parking_lot_at(kind: int, gx: int, gz: int, rot: int = 0) -> bool:
	if not is_parking_kind_unlocked(kind):
		return false
	var spec: Dictionary = GameCatalog.PARKING_LOTS[kind]
	if not validate_rect(gx, gz, spec["grid_w"], spec["grid_d"], rot).is_empty():
		return false
	var cost: float = spec["cost"]
	if cash < cost:
		notify_shortfall(OutpostLayout.cell_center(gx, gz), cost - cash)
		return false
	var park_before := _total_parking_spaces
	cash -= cost
	var lot := _make_lot(kind, gx, gz, rot)
	parking_lots.append(lot)
	_recompute_network()
	_spawn_dust(lot_position(lot), 12)
	_float_notice(lot_position(lot) + Vector3(0, 2.2, 0), "%s!" % str(spec["name"]).to_upper() if lot["is_connected"] else "CONNECT A ROAD!", DesertPalette.GOLD if lot["is_connected"] else Color("ffb899"), 1.5)
	if park_before == 0 and lot["is_connected"]:
		_dispatch_immediate_customer(lot)
	save_state()
	hud_changed.emit()
	return true


func upgrade_parking_lot(lot: Dictionary) -> bool:
	var lock := parking_upgrade_lock_reason(lot)
	if not lock.is_empty():
		_float_notice(lot_position(lot) + Vector3(0, 2.2, 0), lock)
		return false
	var nxt := GameCatalog.next_parking_upgrade(lot["kind"])
	var cost := parking_upgrade_cost(lot)
	if cash < cost:
		notify_shortfall(lot_position(lot) + Vector3(0, 1.8, 0), cost - cash)
		return false
	var was_conn: bool = lot["is_connected"]
	var shifts := [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-2, 0), Vector2i(0, -2)]
	var spec: Dictionary = GameCatalog.PARKING_LOTS[nxt]
	var found := false
	var best_gx := 0
	var best_gz := 0
	var best_rot := 0
	var best_score := -1e9
	var ign := "lot:%s" % lot["id"]
	for rot in [0, 1, 2, 3]:
		var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], rot)
		for sh: Vector2i in shifts:
			var gx: int = lot["grid_x"] + sh.x
			var gz: int = lot["grid_z"] + sh.y
			if not validate_rect(gx, gz, spec["grid_w"], spec["grid_d"], rot, ign).is_empty():
				continue
			var total_c := 0
			var prim_c := 0
			var borders := [
				[0, RoadNetwork._side_cells_x(gx, sz.x, gz + sz.y)],
				[1, RoadNetwork._side_cells_z(gx - 1, gz, sz.y)],
				[2, RoadNetwork._side_cells_x(gx, sz.x, gz - 1)],
				[3, RoadNetwork._side_cells_z(gx + sz.x, gz, sz.y)],
			]
			for b in borders:
				for rc: Vector2i in b[1]:
					if road_network.is_connected_to_highway(rc):
						total_c += 1
						if int(b[0]) == rot:
							prim_c += 1
			if was_conn and total_c == 0:
				continue
			var sc := prim_c * 50.0 + total_c * 20.0 - float(absi(sh.x) + absi(sh.y)) * 4.0
			if sc > best_score:
				best_score = sc
				best_gx = gx
				best_gz = gz
				best_rot = rot
				found = true
	if found:
		return _apply_relocate_parking(lot, best_gx, best_gz, best_rot, nxt)
	start_relocating_parking(lot, nxt)
	_float_notice(lot_position(lot) + Vector3(0, 2.4, 0), "MOVE TO FIT BIGGER LOT")
	return false


func _apply_relocate_parking(lot: Dictionary, gx: int, gz: int, rot: int, upgrade_to: int) -> bool:
	var target_kind: int = upgrade_to if upgrade_to >= 0 else int(lot["kind"])
	var is_upg: bool = upgrade_to >= 0 and upgrade_to != int(lot["kind"])
	var cost: float = parking_upgrade_cost(lot) if is_upg else 0.0
	if cash < cost:
		notify_shortfall(lot_position(lot), cost - cash)
		return false
	cash -= cost
	lot["kind"] = target_kind
	lot["grid_x"] = gx
	lot["grid_z"] = gz
	lot["rot"] = rot & 3
	_evict_lot_vehicles(lot["id"])
	_recompute_network()
	_spawn_dust(lot_position(lot), 14)
	_float_notice(lot_position(lot) + Vector3(0, 2.4, 0), "%s!" % str(GameCatalog.PARKING_LOTS[target_kind]["name"]).to_upper() if is_upg else "LOT MOVED!", DesertPalette.GOLD if is_upg else DesertPalette.NEON_TURQUOISE)
	save_state()
	hud_changed.emit()
	return true


func remove_parking_lot(lot: Dictionary) -> void:
	var idx := parking_lots.find(lot)
	if idx < 0:
		return
	var refund: float = roundf(float(GameCatalog.PARKING_LOTS[lot["kind"]]["cost"]) * 0.5)
	var pos := lot_position(lot)
	var lid: String = lot["id"]
	parking_lots.remove_at(idx)
	_evict_lot_vehicles(lid)
	cash += refund
	_recompute_network()
	_float_notice(pos + Vector3(0, 1.8, 0), "+%s REFUND" % GameCatalog.format_cash(refund), DesertPalette.SAND_LIGHT)
	save_state()
	hud_changed.emit()


func quick_upgrade_or_place_parking() -> bool:
	for l in parking_lots:
		if parking_upgrade_lock_reason(l).is_empty() and cash >= parking_upgrade_cost(l):
			return upgrade_parking_lot(l)
	var kind: int = GameCatalog.ParkingLotKind.DIRT_PULL_OFF
	var res := _find_smart_parking_spot(kind)
	return place_parking_lot_at(kind, res[0].x, res[0].y, res[1])


func _evict_lot_vehicles(lot_id: String) -> void:
	var evicted: Dictionary = {}
	for i in range(vehicles.size() - 1, -1, -1):
		if vehicles[i]["lot_id"] == lot_id:
			evicted[vehicles[i]["id"]] = true
			vehicles.remove_at(i)
	for i in range(visitors.size() - 1, -1, -1):
		if evicted.has(visitors[i]["vehicle_id"]):
			visitors.remove_at(i)


func _owned_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: Vector2i in world_grid.owned_parcels.keys():
		var rect := OutpostLayout.parcel_cell_bounds(p.x, p.y)
		for gz in range(rect.position.y, rect.position.y + rect.size.y):
			for gx in range(rect.position.x, rect.position.x + rect.size.x):
				out.append(Vector2i(gx, gz))
	return out


func _find_smart_building_spot(btype: int) -> Vector2i:
	var focus := OutpostLayout.world_to_cell(town_focus())
	var d: Dictionary = GameCatalog.BUSINESSES[btype]
	var best := Vector2i(focus.x + 3, focus.y)
	var best_sc := -1e9
	for c in _owned_cells():
		if not validate_rect(c.x, c.y, d["grid_w"], d["grid_d"], 0).is_empty():
			continue
		var rep := road_network.evaluate_building_access(btype, c.x, c.y, 0, parking_lots)
		var sc := float(rep["score"]) * 10.0 - float(OutpostLayout.manhattan(c, focus)) * 0.05
		if sc > best_sc:
			best_sc = sc
			best = c
	return best


func _find_smart_parking_spot(kind: int) -> Array:
	var spec: Dictionary = GameCatalog.PARKING_LOTS[kind]
	var ent := plot_entrance_cell(cart_plot()) if cart_plot()["is_built"] else OutpostLayout.world_to_cell(town_focus())
	var best := Vector2i(ent.x - 2, ent.y)
	var best_rot := 0
	var best_sc := -1e9
	for c in _owned_cells():
		for rot in [0, 3, 1, 2]:
			if not validate_rect(c.x, c.y, spec["grid_w"], spec["grid_d"], rot).is_empty():
				continue
			var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], rot)
			var blocks := false
			var min_d := 9999
			for dx in range(sz.x):
				for dz in range(sz.y):
					var cell := Vector2i(c.x + dx, c.y + dz)
					if cell.x == ent.x and cell.y >= ent.y:
						blocks = true
					min_d = mini(min_d, OutpostLayout.manhattan(cell, ent))
			if blocks:
				continue
			var border: Array[Vector2i] = []
			match rot & 3:
				0: border = RoadNetwork._side_cells_x(c.x, sz.x, c.y + sz.y)
				1: border = RoadNetwork._side_cells_z(c.x - 1, c.y, sz.y)
				2: border = RoadNetwork._side_cells_x(c.x, sz.x, c.y - 1)
				_: border = RoadNetwork._side_cells_z(c.x + sz.x, c.y, sz.y)
			var rc_n := 0
			var corr_n := 0
			for rc in border:
				if road_network.is_connected_to_highway(rc):
					rc_n += 1
				if rc.x == ent.x and rc.y >= ent.y:
					corr_n += 1
			var sc := rc_n * 60.0 + corr_n * 12.0 - float(min_d)
			if sc > best_sc:
				best_sc = sc
				best = c
				best_rot = rot
	return [best, best_rot]


func _find_smart_deco_spot() -> Vector2i:
	var focus := OutpostLayout.world_to_cell(town_focus())
	var best := focus
	var best_d := 99999
	for c in _owned_cells():
		if not _cell_block_reason(c).is_empty():
			continue
		var d := OutpostLayout.manhattan(c, focus)
		if d >= 2 and d < best_d:
			best_d = d
			best = c
	return best


# --- Traffic & Visitor AI ---

func _seed_initial_traffic() -> void:
	vehicles.clear()
	visitors.clear()
	_spawn_vehicle(-40.0, 1)
	_spawn_vehicle(30.0, -1)
	_spawn_vehicle(-6.0, 1)
	if _connected_built < 2:
		return
	var seeded := 0
	for lot in parking_lots:
		if not lot["is_connected"] or lot["drive_in_path"].is_empty():
			continue
		var slots := lot_slot_positions(lot)
		var aisle := lot_aisle_point(lot, 0)
		var rev: Array[Vector3] = []
		for i in range(lot["drive_in_path"].size() - 1, -1, -1):
			rev.append(lot["drive_in_path"][i])
		var exit_wps: Array[Vector3] = [aisle]
		exit_wps.append_array(RoadNetwork.offset_path_right(rev, LANE_OFFSET))
		var v := {
			"id": _next_entity_id,
			"kind": GameCatalog.VehicleKind.PICKUP_TRUCK if seeded % 2 == 0 else GameCatalog.VehicleKind.CAMPER_RV,
			"color": _random_vehicle_color(),
			"pos": slots[0],
			"yaw": BuildingBuilder.lot_parked_yaw(BuildingBuilder.lot_effective_side(lot)),
			"speed": 5.5,
			"dir": 1,
			"phase": GameCatalog.VehiclePhase.PARKED,
			"lot_id": lot["id"],
			"slot_idx": 0,
			"park_timer": 4.5 + seeded * 1.4,
			"spawned_vis": true,
			"waypoints": [],
			"exit_wps": exit_wps,
			"considered_x": NAN,
		}
		_next_entity_id += 1
		vehicles.append(v)
		_spawn_visitors_from_vehicle(v)
		seeded += 1
		if seeded >= 2:
			break


func _spawn_vehicle(init_x: float, dir: int) -> void:
	var lane_z := OutpostLayout.HIGHWAY_EASTBOUND_Z if dir == 1 else OutpostLayout.HIGHWAY_WESTBOUND_Z
	vehicles.append({
		"id": _next_entity_id,
		"kind": rng.randi_range(0, 4),
		"color": _random_vehicle_color(),
		"pos": Vector3(init_x, 0.0, lane_z),
		"yaw": 0.0 if dir == 1 else PI,
		"speed": 5.2 + rng.randf() * 2.6,
		"dir": dir,
		"phase": GameCatalog.VehiclePhase.HIGHWAY_CRUISE,
		"lot_id": "",
		"slot_idx": -1,
		"park_timer": 0.0,
		"spawned_vis": false,
		"waypoints": [],
		"exit_wps": [],
		"considered_x": NAN,
	})
	_next_entity_id += 1


func _dispatch_immediate_customer(lot: Dictionary) -> void:
	var slots := lot_slot_positions(lot)
	if slots.is_empty() or lot["drive_in_path"].is_empty():
		return
	var entry_x: float = lot["drive_in_path"][0].x
	var v := {
		"id": _next_entity_id,
		"kind": GameCatalog.VehicleKind.PICKUP_TRUCK,
		"color": _random_vehicle_color(),
		"pos": Vector3(entry_x - 9.0, 0.0, OutpostLayout.HIGHWAY_EASTBOUND_Z),
		"yaw": 0.0,
		"speed": 5.2,
		"dir": 1,
		"phase": GameCatalog.VehiclePhase.HIGHWAY_CRUISE,
		"lot_id": "",
		"slot_idx": -1,
		"park_timer": 0.0,
		"spawned_vis": false,
		"waypoints": [],
		"exit_wps": [],
		"considered_x": entry_x,
	}
	_next_entity_id += 1
	_assign_bay(v, lot, 0, slots[0])
	vehicles.append(v)


func _assign_bay(v: Dictionary, lot: Dictionary, slot_idx: int, slot_pos: Vector3) -> void:
	var aisle := lot_aisle_point(lot, slot_idx)
	v["lot_id"] = lot["id"]
	v["slot_idx"] = slot_idx
	v["phase"] = GameCatalog.VehiclePhase.PULLING_IN
	var typed_path: Array[Vector3] = []
	for pt in lot["drive_in_path"]:
		typed_path.append(pt)
	var wps := RoadNetwork.offset_path_right(typed_path, LANE_OFFSET)
	wps.append(aisle)
	wps.append(slot_pos)
	v["waypoints"] = wps
	var rev: Array[Vector3] = []
	for i in range(typed_path.size() - 1, -1, -1):
		rev.append(typed_path[i])
	var ewps: Array[Vector3] = [aisle]
	ewps.append_array(RoadNetwork.offset_path_right(rev, LANE_OFFSET))
	v["exit_wps"] = ewps


func _lot_by_id(lid: String) -> Dictionary:
	for l in parking_lots:
		if l["id"] == lid:
			return l
	return {}


func _update_vehicles(dt: float) -> void:
	var max_v := 4 + mini(8, _total_parking_spaces)
	_traffic_cooldown -= dt
	if _traffic_cooldown <= 0.0 and vehicles.size() < max_v:
		var dir := 1 if rng.randf() < 0.5 else -1
		_spawn_vehicle(-HIGHWAY_SPAWN_X if dir == 1 else HIGHWAY_SPAWN_X, dir)
		_traffic_cooldown = clampf(4.2 - float(_total_parking_spaces) * 0.22, 1.4, 4.2)

	var entry_xs: Array[float] = []
	if _total_parking_spaces > 0 and _connected_built > 0:
		for l in parking_lots:
			if l["is_connected"] and not l["drive_in_path"].is_empty():
				var ex: float = l["drive_in_path"][0].x
				var dup := false
				for x in entry_xs:
					if absf(x - ex) < 0.01:
						dup = true
						break
				if not dup:
					entry_xs.append(ex)

	for i in range(vehicles.size() - 1, -1, -1):
		var v := vehicles[i]
		match v["phase"]:
			GameCatalog.VehiclePhase.HIGHWAY_CRUISE:
				v["pos"].x += float(v["dir"]) * float(v["speed"]) * dt
				v["yaw"] = 0.0 if v["dir"] == 1 else PI
				if v["slot_idx"] == -1:
					for ex in entry_xs:
						if absf(v["pos"].x - ex) < 2.4 and (is_nan(v["considered_x"]) or absf(v["considered_x"] - ex) > 0.01):
							v["considered_x"] = ex
							if rng.randf() < clampf(0.24 + _avg_access * 0.52, 0.18, 0.88):
								var bay := _find_free_bay(ex)
								if not bay.is_empty():
									_assign_bay(v, bay[0], bay[1], bay[2])
							break
				if absf(v["pos"].x) > HIGHWAY_SPAWN_X + 4.0:
					vehicles.remove_at(i)
			GameCatalog.VehiclePhase.PULLING_IN:
				var wps: Array = v["waypoints"]
				if wps.is_empty():
					var lot := _lot_by_id(v["lot_id"])
					if not lot.is_empty():
						v["yaw"] = BuildingBuilder.lot_parked_yaw(BuildingBuilder.lot_effective_side(lot))
					v["phase"] = GameCatalog.VehiclePhase.PARKED
					v["park_timer"] = 6.0 + rng.randf() * 3.5
					v["spawned_vis"] = false
				else:
					var wp: Vector3 = wps[0]
					var cur_p: Vector3 = v["pos"]
					var diff: Vector3 = wp - cur_p
					var dist: float = diff.length()
					if dist < 0.25:
						v["pos"] = wp
						wps.remove_at(0)
					else:
						var spd := road_network.vehicle_speed_at(cur_p)
						var dir_v: Vector3 = diff / dist
						v["pos"] = cur_p + dir_v * minf(dist, spd * dt)
						v["yaw"] = _lerp_angle(v["yaw"], atan2(dir_v.z, dir_v.x), clampf(dt * 8.5, 0.0, 1.0))
			GameCatalog.VehiclePhase.PARKED:
				if not v["spawned_vis"]:
					v["spawned_vis"] = true
					_spawn_visitors_from_vehicle(v)
				v["park_timer"] -= dt
				var has_vis := false
				for vis in visitors:
					if vis["vehicle_id"] == v["id"]:
						has_vis = true
						break
				if v["park_timer"] <= 0.0 and not has_vis:
					var ewps: Array = v["exit_wps"]
					var cur_p2: Vector3 = v["pos"]
					var bt: Vector3 = ewps[0] if not ewps.is_empty() else Vector3(cur_p2.x, 0.0, OutpostLayout.PARKING_AISLE_Z)
					v["waypoints"] = [bt]
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
					if dist < 0.22:
						v["pos"] = bt
						wps.clear()
						_begin_pull_out(v)
					else:
						var dir_v: Vector3 = diff / dist
						v["pos"] = cur_p + dir_v * minf(dist, 2.3 * dt)
						v["yaw"] = _lerp_angle(v["yaw"], atan2(-dir_v.z, -dir_v.x), clampf(dt * 3.0, 0.0, 1.0))
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
					if dist < 0.26:
						v["pos"] = wp
						wps.remove_at(0)
					else:
						var spd := road_network.vehicle_speed_at(cur_p)
						var dir_v: Vector3 = diff / dist
						v["pos"] = cur_p + dir_v * minf(dist, spd * dt)
						v["yaw"] = _lerp_angle(v["yaw"], atan2(dir_v.z, dir_v.x), clampf(dt * 8.0, 0.0, 1.0))


func _begin_pull_out(v: Dictionary) -> void:
	var ez := OutpostLayout.HIGHWAY_EASTBOUND_Z if v["dir"] == 1 else OutpostLayout.HIGHWAY_WESTBOUND_Z
	var wps: Array[Vector3] = []
	var ewps: Array = v["exit_wps"]
	for j in range(1, ewps.size()):
		wps.append(ewps[j])
	var lx: float = wps.back().x if not wps.is_empty() else v["pos"].x
	wps.append(Vector3(lx + float(v["dir"]) * 1.8, 0.0, ez))
	v["waypoints"] = wps
	v["phase"] = GameCatalog.VehiclePhase.PULLING_OUT


func _find_free_bay(entry_x: float) -> Array:
	var free: Array = []
	for lot in parking_lots:
		if not lot["is_connected"] or lot["drive_in_path"].is_empty():
			continue
		if absf(float(lot["drive_in_path"][0].x) - entry_x) > 0.01:
			continue
		var slots := lot_slot_positions(lot)
		for i in range(slots.size()):
			var occ := false
			for v in vehicles:
				if v["lot_id"] == lot["id"] and v["slot_idx"] == i:
					occ = true
					break
			if not occ:
				free.append([lot, i, slots[i]])
	if free.is_empty():
		return []
	return free[rng.randi_range(0, free.size() - 1)]


func _spawn_visitors_from_vehicle(v: Dictionary) -> void:
	var reachable: Array[Dictionary] = []
	var total_w := 0.0
	for p in plots:
		if p["is_built"] and float(p["access"]["score"]) > 0.0:
			reachable.append(p)
			total_w += float(p["access"]["score"])
	if reachable.is_empty():
		return
	var pcount := 3 if v["kind"] == GameCatalog.VehicleKind.TOURIST_VAN else (2 if v["kind"] == GameCatalog.VehicleKind.CAMPER_RV else (2 if (v["kind"] == GameCatalog.VehicleKind.SUV and rng.randf() < 0.5) else 1))
	var shirts := [DesertPalette.AWNING_RED, DesertPalette.TURQUOISE, DesertPalette.GOLD, DesertPalette.TERRACOTTA, DesertPalette.CREAM, Color("5d7ea8")]
	var hats := [DesertPalette.SAND, DesertPalette.WOOD_LIGHT, DesertPalette.CREAM, DesertPalette.SANDSTONE]
	var blocked: Dictionary = {}
	for p in plots:
		if p["is_built"]:
			var d: Dictionary = GameCatalog.BUSINESSES[p["type"]]
			for c in WorldGrid._rect_cells(p["grid_x"], p["grid_z"], d["grid_w"], d["grid_d"], p["rot"]):
				blocked[c] = true
	var lot := _lot_by_id(v["lot_id"])
	for i in range(pcount):
		var roll := rng.randf() * total_w
		var target_p: Dictionary = reachable.back()
		for p in reachable:
			roll -= float(p["access"]["score"])
			if roll <= 0.0:
				target_p = p
				break
		var vpos: Vector3 = v["pos"]
		var start: Vector3 = lot_visitor_spawn(lot, int(v["slot_idx"]), i) if (not lot.is_empty() and int(v["slot_idx"]) >= 0) else vpos + Vector3(0.42 + (float(i) - 0.5) * 0.34, 0.0, -0.95)
		var dest := plot_visitor_stop(target_p) + Vector3((i - 0.5) * 0.32, 0.0, 0.0)
		var outbound := road_network.build_visitor_walk_path(start, dest, blocked)
		var inbound: Array[Vector3] = []
		for k in range(outbound.size() - 2, -1, -1):
			inbound.append(outbound[k])
		inbound.append(start)
		visitors.append({
			"id": _next_entity_id,
			"shirt": shirts[rng.randi_range(0, shirts.size() - 1)],
			"hat": hats[rng.randi_range(0, hats.size() - 1)],
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
		_next_entity_id += 1


func _update_visitors(dt: float) -> void:
	for i in range(visitors.size() - 1, -1, -1):
		var vis := visitors[i]
		vis["walk_cycle"] += dt
		match vis["phase"]:
			GameCatalog.VisitorPhase.WALKING_TO_BUSINESS:
				var path: Array = vis["outbound"]
				if path.is_empty():
					vis["phase"] = GameCatalog.VisitorPhase.SHOPPING
					vis["wait_timer"] = 1.6 + rng.randf() * 1.4
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
					var target_p := plots[0]
					for p in plots:
						if p["id"] == vis["target_plot_id"]:
							target_p = p
							break
					var af := maxf(0.25, float(target_p["access"]["score"]))
					var sale := maxf(3.0, roundf(GameCatalog.income_for_level(target_p["type"], target_p["level"]) * af * decoration_bonus_mult() / 15.0))
					cash += sale
					total_cash_earned += sale
					total_customers_served += 1
					target_p["bounce"] = 0.28
					floating_cash.append({
						"pos": plot_position(target_p) + Vector3(0, 2.5, 0),
						"text": "+%s" % GameCatalog.format_cash(sale),
						"color": DesertPalette.GOLD_POPUP,
						"drift_x": (rng.randf() - 0.5) * 0.65,
						"age": 0.0,
						"duration": 1.15,
					})
					vis["phase"] = GameCatalog.VisitorPhase.RETURNING_TO_CAR
					_refresh_progression()
					hud_changed.emit()
			GameCatalog.VisitorPhase.RETURNING_TO_CAR:
				var path: Array = vis["return_path"]
				if path.is_empty():
					visitors.remove_at(i)
				else:
					var wp: Vector3 = path[0]
					var vpos: Vector3 = vis["pos"]
					var diff: Vector3 = wp - vpos
					var dist: float = diff.length()
					if dist < 0.24:
						vis["pos"] = wp
						path.remove_at(0)
						if path.is_empty():
							visitors.remove_at(i)
					else:
						var dv: Vector3 = diff / dist
						vis["pos"] = vpos + dv * (2.15 * dt)
						vis["yaw"] = _lerp_angle(vis["yaw"], atan2(dv.z, dv.x), clampf(dt * 10.0, 0.0, 1.0))


func _lerp_angle(cur: float, tgt: float, t: float) -> float:
	var diff := fposmod(tgt - cur + PI, TAU) - PI
	return cur + diff * t


func _random_vehicle_color() -> Color:
	var pal := [Color("c85b43"), Color("4f9a94"), Color("e0b45a"), Color("dfd5c3"), Color("5a778e"), Color("7b855e"), Color("b56e4b")]
	return pal[rng.randi_range(0, pal.size() - 1)]


# --- Time, Presets & Camera ---

func set_time_preset(t: float, pause_cycle: bool = true) -> void:
	time_of_day = fmod(t, 1.0)
	auto_day_night = not pause_cycle
	save_state()
	hud_changed.emit()


func toggle_auto_day_night() -> void:
	auto_day_night = not auto_day_night
	save_state()
	hud_changed.emit()


func switch_preset(preset: int) -> void:
	_suppress_stage_fx = true
	_init_world(preset)
	_init_milestones()
	_recompute_network()
	reset_camera_immediate()
	_seed_initial_traffic()
	_suppress_stage_fx = false
	save_state()
	hud_changed.emit()


func reset_camera_immediate() -> void:
	if camera_ref == null:
		return
	if active_preset == GameCatalog.OutpostPreset.FULL_CITY:
		camera_ref.reset_immediate(Vector3(0.0, 1.8, -12.0), 58.0)
	else:
		camera_ref.reset_immediate(town_focus() + Vector3(0.0, 1.6, 0.0), DesertCamera.STAGE_ONE_DISTANCE)


func reset_camera_smooth() -> void:
	if camera_ref == null:
		return
	camera_ref.focus_on(
		town_focus() + Vector3(0.0, 1.6, 0.0),
		58.0 if active_preset == GameCatalog.OutpostPreset.FULL_CITY else 34.0,
		DesertCamera.DEFAULT_PITCH,
		DesertCamera.DEFAULT_YAW
	)


# --- JSON Persistence + Offline Earnings ---

func save_state() -> void:
	var data := {
		"v": 3,
		"saved_at": Time.get_unix_time_from_system(),
		"preset": active_preset,
		"cash": cash,
		"total_cash": total_cash_earned,
		"served": total_customers_served,
		"taps": total_taps,
		"tap_lv": tap_upgrade_level,
		"highest_stage": _highest_stage,
		"time_of_day": time_of_day,
		"auto_day_night": auto_day_night,
		"sound": sound_enabled,
		"parcels": world_grid.owned_parcels.keys().map(func(p: Vector2i): return [p.x, p.y]),
		"roads": road_network.tiles.keys().map(func(c: Vector2i): return [c.x, c.y, road_network.tiles[c]]),
		"plots": plots.map(func(p): return {"id": p["id"], "gx": p["grid_x"], "gz": p["grid_z"], "rot": p["rot"], "built": p["is_built"], "lv": p["level"]}),
		"lots": parking_lots.map(func(l): return {"id": l["id"], "kind": l["kind"], "gx": l["grid_x"], "gz": l["grid_z"], "rot": l["rot"]}),
		"decos": decorations.map(func(d): return {"id": d["id"], "kind": d["kind"], "name": d["name"], "cost": d["cost"], "gx": d["grid_x"], "gz": d["grid_z"]}),
		"claimed": milestones.filter(func(m): return m["claimed"]).map(func(m): return m["id"]),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


func _load_saved_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary) or int(parsed.get("v", 0)) < 3:
		return
	active_preset = int(parsed.get("preset", GameCatalog.OutpostPreset.STAGE_ONE_CAREER))
	cash = float(parsed.get("cash", 0.0))
	total_cash_earned = float(parsed.get("total_cash", 0.0))
	total_customers_served = int(parsed.get("served", 0))
	total_taps = int(parsed.get("taps", 0))
	tap_upgrade_level = int(parsed.get("tap_lv", 1))
	_highest_stage = maxi(1, int(parsed.get("highest_stage", 1)))
	time_of_day = float(parsed.get("time_of_day", 0.37))
	auto_day_night = bool(parsed.get("auto_day_night", true))
	sound_enabled = bool(parsed.get("sound", true))

	var parcels: Array[Vector2i] = []
	for p in parsed.get("parcels", []):
		parcels.append(Vector2i(int(p[0]), int(p[1])))
	if not parcels.is_empty():
		world_grid.reset_ownership(parcels)

	road_network.clear()
	for r in parsed.get("roads", []):
		road_network.set_tile(Vector2i(int(r[0]), int(r[1])), int(r[2]))

	for sp in parsed.get("plots", []):
		for p in plots:
			if p["id"] == sp["id"]:
				p["grid_x"] = int(sp["gx"])
				p["grid_z"] = int(sp["gz"])
				p["rot"] = int(sp["rot"])
				p["is_built"] = bool(sp["built"])
				p["level"] = int(sp["lv"])

	parking_lots.clear()
	for sl in parsed.get("lots", []):
		parking_lots.append({
			"id": str(sl["id"]),
			"kind": int(sl["kind"]),
			"grid_x": int(sl["gx"]),
			"grid_z": int(sl["gz"]),
			"rot": int(sl["rot"]),
			"is_connected": false,
			"connected_side": -1,
			"drive_in_path": [],
		})

	decorations.clear()
	for sd in parsed.get("decos", []):
		decorations.append({
			"id": str(sd["id"]),
			"kind": int(sd["kind"]),
			"name": str(sd["name"]),
			"cost": float(sd["cost"]),
			"grid_x": int(sd["gx"]),
			"grid_z": int(sd["gz"]),
		})

	var claimed: Array = parsed.get("claimed", [])
	for m in milestones:
		m["claimed"] = claimed.has(m["id"])

	# Offline welcome earnings (capped at 4 hours, 45% offline efficiency)
	_recompute_network()
	var saved_at := float(parsed.get("saved_at", 0.0))
	var now := Time.get_unix_time_from_system()
	var mins := int(clampf((now - saved_at) / 60.0, 0.0, 240.0))
	if mins >= 2 and income_per_minute() > 0.0:
		var offline: float = roundf(income_per_minute() * float(mins) * 0.45)
		if offline > 0.0:
			cash += offline
			total_cash_earned += offline
			pending_offline_cash = offline
			pending_offline_minutes = mins
