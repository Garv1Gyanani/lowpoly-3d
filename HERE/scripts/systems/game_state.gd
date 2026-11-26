class_name GameState
extends Node

## Central simulation coordinator & signal bus for Desert Outpost.
## Delegates timekeeping (SimClock), placement/roads/land (PlacementController),
## traffic/visitors (TrafficSim), and versioned persistence (SaveManager).

signal hud_changed
signal world_layout_changed
signal overlay_changed
signal sim_tick(sim_dt: float)
signal lens_changed(lens: int)

const SAVE_PATH := SaveManager.SAVE_PATH
const MAX_DECORATIONS := 16
const DAY_CYCLE_RATE := SimClock.DAY_CYCLE_RATE
const LANE_OFFSET := RoadNetwork.TWO_LANE_OFFSET
const HIGHWAY_SPAWN_X := TrafficSim.HIGHWAY_SPAWN_X

const CITY_LAYOUT := {
	"vendor": Vector2i(-9, -8),
	"food_stand": Vector2i(-5, -8),
	"oasis_plaza": Vector2i(3, -16),
	"mart": Vector2i(-9, -17),
	"diner": Vector2i(-4, -17),
	"gas_station": Vector2i(5, -9),
	"motel": Vector2i(-9, -25),
	"lookout": Vector2i(2, -25),
}
const CAREER_CART_CELL := Vector2i(-1, -14)

var rng := RandomNumberGenerator.new()
var sim_clock := SimClock.new()
var road_network := RoadNetwork.new()
var world_grid := WorldGrid.new()
var power_network := PowerNetwork.new()
var water_network := WaterNetwork.new()
var supply_sim := SupplyChainSim.new()
var staff_sim := StaffSim.new()
var traffic_sim: TrafficSim
var placement: PlacementController
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

# Time & lens mirrors (kept synced with sim_clock)
var anim_time := 0.0
var time_of_day := 0.37
var auto_day_night := true
var active_lens: int = GameCatalog.MapLens.NONE

# Entities
var plots: Array[Dictionary] = []
var parking_lots: Array[Dictionary] = []
var decorations: Array[Dictionary] = []
var utilities: Array[Dictionary] = []
var vehicles: Array[Dictionary] = []
var visitors: Array[Dictionary] = []
var floating_cash: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var milestones: Array[Dictionary] = []

# Tool & selection state (managed by PlacementController)
var tool_mode: int = GameCatalog.WorldToolMode.PLAY
var active_road_tier: int = GameCatalog.RoadTier.DIRT
var road_two_lane := true
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
var relocating_deco_id := ""
var pending_utility_kind := -1
var relocating_utility_id := ""
var active_pole_kind: int = GameCatalog.PowerLineKind.WOOD_POLE
var pole_erase_mode := false
var conduit_erase_mode := false
var has_conduit_start := false
var conduit_line_start := Vector2i.ZERO
var conduit_line_end := Vector2i.ZERO
var water_pipe_erase_mode := false
var has_water_pipe_start := false
var water_pipe_line_start := Vector2i.ZERO
var water_pipe_line_end := Vector2i.ZERO
var _prev_lens_before_tool := -1
var ghost_grid_x := 0
var ghost_grid_z := -12
var ghost_rotation := 0
var is_hold_dragging := false
var hold_drag_origin := Vector2i(-9999, -9999)
var selected_plot_id := ""
var selected_entity_id := ""

var _next_entity_id := 1
var _autosave_accum := 0.0
var _staff_serve_ticks := 0
var _last_hud_cash := -1
var _last_claimables := -1
var _last_clock_phase := -1

var _highest_stage := 1
var _connected_built := 0
var _total_parking_spaces := 0
var _parking_tier := 0
var _avg_access := 0.0
var _suppress_stage_fx := false


func _init() -> void:
	traffic_sim = TrafficSim.new(self)
	placement = PlacementController.new(self)


func _ready() -> void:
	rng.seed = 42
	_suppress_stage_fx = true
	_init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	_init_milestones()
	SaveManager.load_from_disk(self)
	recompute_network()
	traffic_sim.seed_initial_traffic()
	_suppress_stage_fx = false
	_last_hud_cash = int(floor(cash))
	_last_claimables = claimable_milestone_count()
	_last_clock_phase = sim_clock.day_phase()


func alloc_entity_id() -> int:
	var id := _next_entity_id
	_next_entity_id += 1
	return id


func attach_camera(cam: DesertCamera) -> void:
	camera_ref = cam
	reset_camera_immediate()


func sync_clock_mirrors() -> void:
	time_of_day = sim_clock.time_of_day
	auto_day_night = sim_clock.auto_day_night


func set_highest_stage_raw(stage: int) -> void:
	_highest_stage = maxi(1, stage)


func _init_world(preset: int) -> void:
	active_preset = preset
	var full := preset == GameCatalog.OutpostPreset.FULL_CITY
	road_network.clear()
	world_grid.clear_utilities()
	power_network.clear()
	water_network.clear()
	supply_sim.clear()
	staff_sim.clear()
	parking_lots.clear()
	decorations.clear()
	utilities.clear()
	vehicles.clear()
	visitors.clear()
	floating_cash.clear()
	particles.clear()
	sim_clock.reset(1, 0.37, true, 1.0)
	sync_clock_mirrors()
	placement.cancel_tool_mode(false)
	_highest_stage = 1
	_staff_serve_ticks = 0
	_build_plots(full)

	if full:
		var parcels: Array[Vector2i] = [Vector2i(1, 5)]
		for px in range(2, 6):
			for pz in range(4, 8):
				parcels.append(Vector2i(px, pz))
		world_grid.reset_ownership(parcels)
		for gz in range(-22, OutpostLayout.HIGHWAY_ENTRY_ROW_Z + 1):
			road_network.set_tile(Vector2i(-12, gz), GameCatalog.RoadTier.PAVED)
			road_network.set_tile(Vector2i(-11, gz), GameCatalog.RoadTier.PAVED)
			road_network.set_tile(Vector2i(10, gz), GameCatalog.RoadTier.PAVED)
			road_network.set_tile(Vector2i(11, gz), GameCatalog.RoadTier.PAVED)
		for gx in range(-12, 12):
			for row in [-6, -5, -14, -13, -22, -21]:
				road_network.set_tile(Vector2i(gx, row), GameCatalog.RoadTier.PAVED)
		parking_lots.append(make_lot(GameCatalog.ParkingLotKind.PAVED_LOT, -3, -12, 2))
		parking_lots.append(make_lot(GameCatalog.ParkingLotKind.GRAVEL_LOT, 2, -20, 2))
		parking_lots.append(make_lot(GameCatalog.ParkingLotKind.DIRT_PULL_OFF, -9, -20, 2))
		# Full City showcase Power + Water + Supply Chain setup (balanced for 24/7 day & night loads!)
		utilities.append(make_utility(GameCatalog.UtilityKind.SOLAR_ARRAY, 13, -11, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.SOLAR_ARRAY, 13, -26, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.BATTERY_BANK, 13, -16, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.BATTERY_BANK, 13, -18, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.BATTERY_BANK, 13, 0, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.WINDMILL, 13, -20, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.WINDMILL, 13, -23, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.WINDMILL, 13, 3, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.DIESEL_GEN, -15, -18, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.DIESEL_GEN, -15, -21, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.DIESEL_GEN, -15, -9, 0))
		# Water Well on Aquifer parcel (5,6) + Water Tower + Supply Producers + Oil Pumpjack on Oil Seep (1,5)
		utilities.append(make_utility(GameCatalog.UtilityKind.WATER_WELL, 13, -7, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.WATER_TOWER, 9, -11, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.FREIGHT_DEPOT, 12, -3, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.DESERT_GREENHOUSE, -16, -12, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.OIL_PUMPJACK, -21, -15, 0))
		utilities.append(make_utility(GameCatalog.UtilityKind.MINI_REFINERY, -16, -24, 0))
		for pc in [Vector2i(12, -5), Vector2i(12, -10), Vector2i(12, -15), Vector2i(12, -20), Vector2i(12, -25), Vector2i(12, 1), Vector2i(9, -15), Vector2i(9, -23), Vector2i(-13, -16), Vector2i(-13, -12), Vector2i(-13, -9), Vector2i(-13, -23), Vector2i(-15, -16), Vector2i(-18, -15)]:
			world_grid.set_power_pole(pc, {"kind": GameCatalog.PowerLineKind.WOOD_POLE})
		for cx in range(-15, 14):
			world_grid.set_underground_power(Vector2i(cx, -14), {"kind": GameCatalog.PowerLineKind.UNDERGROUND})
			world_grid.set_water_pipe(Vector2i(cx, -12), {"tier": 1})
			world_grid.set_water_pipe(Vector2i(cx, -15), {"tier": 1})
		world_grid.set_underground_power(Vector2i(-15, -13), {"kind": GameCatalog.PowerLineKind.UNDERGROUND})
		for cz in range(-24, -6):
			world_grid.set_underground_power(Vector2i(-5, cz), {"kind": GameCatalog.PowerLineKind.UNDERGROUND})
			world_grid.set_underground_power(Vector2i(5, cz), {"kind": GameCatalog.PowerLineKind.UNDERGROUND})
			world_grid.set_water_pipe(Vector2i(-6, cz), {"tier": 1})
			world_grid.set_water_pipe(Vector2i(6, cz), {"tier": 1})
			world_grid.set_water_pipe(Vector2i(13, cz), {"tier": 1})
		for cz in range(-24, -11):
			world_grid.set_water_pipe(Vector2i(-14, cz), {"tier": 1})
		# Give Diner, Motel, Gas Station & Lookout rooftop solar + starter roaming Crew in Full City showcase
		for p in plots:
			if str(p["id"]) in ["diner", "motel", "gas_station", "lookout"]:
				p["runtime"]["roof_addons"] = ["solar"]
		staff_sim.crew_levels[GameCatalog.CrewKind.GRID_TECH] = 1
		staff_sim.crew_levels[GameCatalog.CrewKind.LOGISTICS_RUNNER] = 1
		staff_sim.sync_agents(self)
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
		var init_staff: Array = ["clerk"] if (full and bool(sp[2])) else []
		plots.append({
			"id": id,
			"type": sp[1],
			"grid_x": cell.x,
			"grid_z": cell.y,
			"rot": 0,
			"is_built": sp[2],
			"level": sp[3],
			"staff": init_staff,
			"runtime": GameCatalog.make_runtime_bag(int(sp[1])),
			"bounce": 0.0,
			"build_pop": 0.0,
			"access": RoadNetwork.disconnected_report(),
		})


func make_lot(kind: int, gx: int, gz: int, rot: int) -> Dictionary:
	return {
		"id": "lot_%d" % alloc_entity_id(),
		"kind": kind,
		"grid_x": gx,
		"grid_z": gz,
		"rot": rot & 3,
		"is_connected": false,
		"connected_side": -1,
		"entry_road_cell": Vector2i.ZERO,
		"lane_offset": RoadNetwork.TWO_LANE_OFFSET,
		"drive_in_path": [],
		"drive_in_routes": [],
	}


func make_utility(kind: int, gx: int, gz: int, rot: int = 0) -> Dictionary:
	var spec: Dictionary = GameCatalog.UTILITIES[kind]
	var bcap := float(spec.get("battery_kwh", 0.0))
	return {
		"id": "util_%d" % alloc_entity_id(),
		"kind": kind,
		"grid_x": gx,
		"grid_z": gz,
		"grid_w": int(spec["grid_w"]),
		"grid_d": int(spec["grid_d"]),
		"rot": rot & 3,
		"stored_kwh": bcap * 0.65 if bcap > 0.0 else 0.0,
		"live_kw": 0.0,
		"live_water": 0.0,
		"live_prod": 0.0,
		"power_ratio": 1.0,
		"water_ratio": 1.0,
	}


func utility_position(u: Dictionary) -> Vector3:
	var spec: Dictionary = GameCatalog.UTILITIES[int(u["kind"])]
	var sz := OutpostLayout.rotated_size(int(spec["grid_w"]), int(spec["grid_d"]), int(u.get("rot", 0)))
	return OutpostLayout.footprint_center(int(u["grid_x"]), int(u["grid_z"]), sz.x, sz.y)


func _init_milestones() -> void:
	milestones = [
		{"id": "m_park1", "title": "First Pull-Off", "desc": "Place a Dirt Pull-Off beside your cart", "reward": 40.0, "claimed": false},
		{"id": "m_road1", "title": "Desert Access Road", "desc": "Connect Route 163 to your cart with a road", "reward": 60.0, "claimed": false},
		{"id": "m_land", "title": "Land Rush", "desc": "Buy your first extra desert land parcel", "reward": 100.0, "claimed": false},
		{"id": "m_3biz", "title": "Desert Strip", "desc": "Operate at least 3 road-connected businesses", "reward": 160.0, "claimed": false},
		{"id": "m_paved_loop", "title": "Highway Loop", "desc": "Build 8+ Paved tiles & 2 Route 163 junctions", "reward": 420.0, "claimed": false},
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
		"m_paved_loop": return road_network.paved_road_count() >= 8 and road_network.highway_turn_off_count() >= 2
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
	float_notice(town_focus() + Vector3(0, 3.5, 0), "+%s BONUS!" % GameCatalog.format_cash(r), DesertPalette.GOLD)
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
	var usable := dims.x - 0.52
	var stall_f := dims.y * 0.5 - 2.30
	var out: Array[Vector3] = []
	for i in range(count):
		var off := ((float(i) + 0.5) / float(count) - 0.5) * usable
		out.append(c + u * off + f * stall_f)
	return out


func lot_aisle_point(lot: Dictionary, slot_idx: int) -> Vector3:
	var slots := lot_slot_positions(lot)
	var slot := slots[clampi(slot_idx, 0, slots.size() - 1)]
	var f := BuildingBuilder.lot_pull_in_dir(BuildingBuilder.lot_effective_side(lot))
	return slot - f * 2.85


func lot_visitor_spawn(lot: Dictionary, slot_idx: int, pass_idx: int) -> Vector3:
	var slots := lot_slot_positions(lot)
	var slot := slots[clampi(slot_idx, 0, slots.size() - 1)]
	var dims := BuildingBuilder.lot_oriented_dims(lot)
	var side := BuildingBuilder.lot_effective_side(lot)
	var count: int = GameCatalog.PARKING_LOTS[lot["kind"]]["spaces"]
	var pitch := (dims.x - 0.52) / float(count)
	return slot + BuildingBuilder.lot_bay_row_axis(side) * (pitch * 0.34) + BuildingBuilder.lot_pull_in_dir(side) * (0.48 - float(pass_idx) * 0.36)


func cart_plot() -> Dictionary:
	return plots[0]


func town_focus() -> Vector3:
	if not plots.is_empty() and plots[0]["is_built"]:
		return plot_position(plots[0])
	var sp := OutpostLayout.STARTER_PARCELS[0]
	return OutpostLayout.parcel_center(sp.x, sp.y)


# --- Progression, Lenses & Economy Metrics ---

func set_map_lens(lens: int) -> void:
	if active_lens == lens:
		return
	active_lens = lens
	lens_changed.emit(active_lens)
	overlay_changed.emit()
	hud_changed.emit()


func set_sim_speed(speed: float) -> void:
	sim_clock.set_speed(speed)
	hud_changed.emit()


func toggle_pause() -> void:
	sim_clock.toggle_pause()
	hud_changed.emit()


func cycle_sim_speed() -> void:
	sim_clock.cycle_speed()
	hud_changed.emit()


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


func plot_staff_list(p: Dictionary) -> Array:
	return p.get("staff", [])


func plot_has_staff(p: Dictionary, role_id: String) -> bool:
	return plot_staff_list(p).has(role_id)


func plot_staff_income_mult(p: Dictionary) -> float:
	var bonus := 0.0
	var hired: Array = plot_staff_list(p)
	for role: Dictionary in GameCatalog.STAFF_ROLES:
		if hired.has(role["id"]):
			bonus += float(role["income_bonus"])
	var morale_m := float(staff_sim.morale) if staff_sim != null else 1.0
	var picnic_m := float(staff_sim.plot_picnic_synergy_mult(p, self)) if staff_sim != null else 1.0
	return (1.0 + bonus * morale_m) * picnic_m


func hire_or_train_crew(kind: int) -> bool:
	return staff_sim.hire_or_train_crew(kind, self)


func plot_income_per_minute(p: Dictionary) -> float:
	if not p["is_built"]:
		return 0.0
	var sc: float = float(p["access"]["score"])
	if sc <= 0.0:
		return 0.0
	var rt: Dictionary = p.get("runtime", {})
	var p_r := float(rt.get("power_ratio", 1.0))
	var w_r := float(rt.get("water_ratio", 1.0))
	var s_r := float(rt.get("stock_ratio", 1.0))
	var tier := int(rt.get("price_tier", GameCatalog.PriceTier.FAIR))
	var price_m := float(GameCatalog.price_tier_spec(tier)["income_mult"])
	var night_m := float(staff_sim.plot_night_income_mult(p, sim_clock.is_night(), self)) if staff_sim != null else 1.0
	var eff := clampf(p_r * w_r * s_r * price_m * night_m, 0.0, 2.4)
	return round(GameCatalog.income_for_level(p["type"], p["level"]) * sc * plot_staff_income_mult(p) * decoration_bonus_mult() * eff)


func selected_plot() -> Dictionary:
	if selected_plot_id.is_empty():
		return {}
	for p in plots:
		if p["id"] == selected_plot_id and p["is_built"]:
			return p
	return {}


func selected_lot() -> Dictionary:
	if not selected_entity_id.begins_with("lot:"):
		return {}
	var lid := selected_entity_id.substr(4)
	for l in parking_lots:
		if l["id"] == lid:
			return l
	return {}


func selected_utility() -> Dictionary:
	if not selected_entity_id.begins_with("util:"):
		return {}
	var uid := selected_entity_id.substr(5)
	for u in utilities:
		if u["id"] == uid:
			return u
	return {}


func select_plot(plot_id: String) -> void:
	var eid := "plot:%s" % plot_id
	if selected_plot_id == plot_id and selected_entity_id == eid:
		return
	selected_plot_id = plot_id
	selected_entity_id = eid
	hud_changed.emit()


func select_lot(lot_id: String) -> void:
	var eid := "lot:%s" % lot_id
	if selected_entity_id == eid:
		return
	selected_plot_id = ""
	selected_entity_id = eid
	hud_changed.emit()


func select_utility(util_id: String) -> void:
	var eid := "util:%s" % util_id
	if selected_entity_id == eid:
		return
	selected_plot_id = ""
	selected_entity_id = eid
	hud_changed.emit()


func plot_has_rooftop_solar(p: Dictionary) -> bool:
	var rt: Dictionary = p.get("runtime", {})
	return (rt.get("roof_addons", []) as Array).has("solar")


func install_rooftop_solar(p: Dictionary) -> bool:
	if not p["is_built"] or plot_has_rooftop_solar(p):
		return false
	var btype: int = int(p["type"])
	if GameCatalog.rooftop_solar_kw(btype) <= 0.0:
		return false
	var cost := GameCatalog.rooftop_solar_cost(btype)
	if cash < cost:
		notify_shortfall(plot_position(p), cost - cash)
		return false
	cash -= cost
	var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag())
	var addons: Array = rt.get("roof_addons", [])
	addons.append("solar")
	rt["roof_addons"] = addons
	p["runtime"] = rt
	p["bounce"] = 0.36
	recompute_network()
	spawn_dust(plot_position(p), 10)
	float_notice(plot_position(p) + Vector3(0, 3.2, 0), "ROOFTOP SOLAR +%.1f kW!" % GameCatalog.rooftop_solar_kw(btype), DesertPalette.GOLD, 1.45)
	save_state()
	hud_changed.emit()
	return true


func clear_selected_plot() -> void:
	if not selected_plot_id.is_empty() or not selected_entity_id.is_empty():
		selected_plot_id = ""
		selected_entity_id = ""
		hud_changed.emit()


func staff_lock_reason(p: Dictionary, role_spec: Dictionary) -> String:
	if not p["is_built"]:
		return "UNBUILT"
	if plot_has_staff(p, str(role_spec["id"])):
		return "HIRED"
	var req_lv: int = int(role_spec["unlock_level"])
	if int(p["level"]) < req_lv:
		return "LV %d" % req_lv
	return ""


func hire_staff_for_plot(p: Dictionary, role_spec: Dictionary) -> bool:
	var lock := staff_lock_reason(p, role_spec)
	if not lock.is_empty():
		if lock != "HIRED":
			float_notice(plot_position(p) + Vector3(0, 2.8, 0), "UPGRADE TO %s" % lock)
		return false
	var cost := GameCatalog.staff_hire_cost(int(p["type"]), role_spec)
	if cash < cost:
		notify_shortfall(plot_position(p), cost - cash)
		return false
	cash -= cost
	var hired: Array = p.get("staff", [])
	hired.append(str(role_spec["id"]))
	p["staff"] = hired
	p["bounce"] = 0.36
	spawn_dust(plot_position(p), 10)
	float_notice(plot_position(p) + Vector3(0, 3.0, 0), "%s HIRED!" % str(role_spec["name"]).to_upper(), DesertPalette.GOLD, 1.45)
	world_layout_changed.emit()
	save_state()
	hud_changed.emit()
	return true


func order_restock_for_plot(p: Dictionary) -> bool:
	return supply_sim.order_restock(p, self, false)


func toggle_auto_restock_for_plot(p: Dictionary) -> bool:
	if not supply_sim.can_auto_restock_plot(p, self):
		float_notice(plot_position(p) + Vector3(0, 2.8, 0), "HIRE CLERK OR BUILD DEPOT")
		return false
	var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag(int(p["type"])))
	rt["auto_restock"] = not bool(rt.get("auto_restock", false))
	p["runtime"] = rt
	save_state()
	hud_changed.emit()
	return true


func set_plot_price_tier(p: Dictionary, tier: int) -> void:
	var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag(int(p["type"])))
	rt["price_tier"] = clampi(tier, GameCatalog.PriceTier.VALUE, GameCatalog.PriceTier.MARKUP)
	p["runtime"] = rt
	save_state()
	hud_changed.emit()


func income_per_minute() -> float:
	var s := 0.0
	if _total_parking_spaces > 0:
		for p in plots:
			if not p["is_built"] or float(p["access"]["score"]) <= 0.0:
				continue
			var rt: Dictionary = p.get("runtime", {})
			var p_r := float(rt.get("power_ratio", 1.0))
			var w_r := float(rt.get("water_ratio", 1.0))
			var s_r := float(rt.get("stock_ratio", 1.0))
			var tier := int(rt.get("price_tier", GameCatalog.PriceTier.FAIR))
			var price_m := float(GameCatalog.price_tier_spec(tier)["income_mult"])
			var night_m := float(staff_sim.plot_night_income_mult(p, sim_clock.is_night(), self)) if staff_sim != null else 1.0
			var eff := clampf(p_r * w_r * s_r * price_m * night_m, 0.0, 2.4)
			s += GameCatalog.income_for_level(p["type"], p["level"]) * float(p["access"]["score"]) * plot_staff_income_mult(p) * eff
	return round(s * decoration_bonus_mult() + supply_sim.export_income_per_min)


func total_power_demand_kw() -> float:
	var total := 0.0
	var night := sim_clock.is_night()
	for p in plots:
		if p["is_built"]:
			total += GameCatalog.business_power_demand_kw(int(p["type"]), int(p["level"]), night)
	return snappedf(total, 0.1)


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


func is_utility_unlocked(kind: int) -> bool:
	return _highest_stage >= int(GameCatalog.UTILITIES[kind]["stage"])


func is_power_line_unlocked(kind: int) -> bool:
	return _highest_stage >= int(GameCatalog.POWER_LINES[kind]["stage"])


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


func can_buy_more_land() -> bool:
	return world_grid.owned_parcels.size() < int(stage_info()["max_parcels"])


func is_world_point_occupied(x: float, z: float) -> bool:
	for ox in [-0.7, 0.7]:
		for oz in [-0.7, 0.7]:
			var c := OutpostLayout.world_to_cell(Vector3(x + ox, 0.0, z + oz))
			if road_network.has_road(c) or world_grid.is_occupied(c):
				return true
	return false


func recompute_network() -> void:
	road_network.recompute(plots, parking_lots, decorations)
	world_grid.rebuild_occupancy(plots, parking_lots, decorations, utilities)
	power_network.rebuild_topology(self)
	water_network.rebuild_topology(self)
	supply_sim.step(0.0, self)
	staff_sim.recompute_morale(self)
	staff_sim.sync_agents(self)
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
	if stage >= 2 and _connected_built >= 2 and (total_customers_served >= 4 or road_network.gravel_or_better_count() >= 6):
		stage = 3
	if stage >= 3 and _connected_built >= 4 and _total_parking_spaces >= 4:
		stage = 4
	if stage >= 4 and _connected_built >= 5 and (road_network.paved_road_count() >= 8 or _total_parking_spaces >= 6):
		stage = 5
	if stage >= 5 and _connected_built >= 7 and _total_parking_spaces >= 6:
		stage = 6

	if stage > _highest_stage:
		_highest_stage = stage
		if not _suppress_stage_fx:
			float_notice(town_focus() + Vector3(0, 4.2, 0), "STAGE %d · %s!" % [stage, str(stage_info()["title"]).to_upper()], DesertPalette.GOLD, 2.2)


# --- Simulation Tick ---

func _process(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if camera_ref != null:
		camera_ref.update_smoothing(dt)

	var step := sim_clock.advance(dt)
	sync_clock_mirrors()
	var sim_dt: float = step["sim_dt"]

	if sim_dt > 0.0:
		anim_time += sim_dt
		var ticks: int = step["ticks"]
		for _i in range(ticks):
			_on_sim_tick(SimClock.FIXED_TICK_SECONDS)

		for p in plots:
			if p["bounce"] > 0.0:
				p["bounce"] = maxf(0.0, p["bounce"] - sim_dt)
			if p["build_pop"] > 0.0:
				p["build_pop"] = maxf(0.0, p["build_pop"] - sim_dt * 1.45)

		for i in range(floating_cash.size() - 1, -1, -1):
			floating_cash[i]["age"] += sim_dt
			if floating_cash[i]["age"] >= floating_cash[i]["duration"]:
				floating_cash.remove_at(i)

		for i in range(particles.size() - 1, -1, -1):
			var pt := particles[i]
			pt["age"] += sim_dt
			if pt["age"] >= pt["duration"]:
				particles.remove_at(i)
				continue
			pt["pos"] += pt["vel"] * sim_dt
			var grav := 9.5 if pt["is_coin"] else 2.8
			pt["vel"] = Vector3(pt["vel"].x * 0.96, pt["vel"].y - grav * sim_dt, pt["vel"].z * 0.96)
			if pt["pos"].y < 0.05:
				pt["pos"].y = 0.05
				pt["vel"].x *= 0.6
				pt["vel"].y = 0.0
				pt["vel"].z *= 0.6

		traffic_sim.update(sim_dt)
		staff_sim.update(sim_dt, self)

	_autosave_accum += dt
	if _autosave_accum >= 6.0:
		_autosave_accum = 0.0
		save_state()

	var cfloor := int(floor(cash))
	var claims := claimable_milestone_count()
	var cur_phase: int = step["phase"]
	if cfloor != _last_hud_cash or claims != _last_claimables or cur_phase != _last_clock_phase or step["day_rolled"]:
		_last_hud_cash = cfloor
		_last_claimables = claims
		_last_clock_phase = cur_phase
		hud_changed.emit()


func _on_sim_tick(dt_sim: float) -> void:
	power_network.step(dt_sim, self)
	water_network.step(dt_sim, self)
	supply_sim.step(dt_sim, self)
	staff_sim.step(dt_sim, self)
	var earned := (income_per_minute() * 0.68 / 60.0) * dt_sim
	cash += earned
	total_cash_earned += earned

	_staff_serve_ticks += 1
	if _staff_serve_ticks >= 5:
		_staff_serve_ticks = 0
		for p in plots:
			if not p["is_built"] or not plot_has_staff(p, "clerk"):
				continue
			var active_ok: bool = float(p["access"]["score"]) > 0.0 or str(p["id"]) == "vendor"
			if not active_ok:
				continue
			var bonus := maxf(3.0, roundf(GameCatalog.income_for_level(p["type"], p["level"]) * 0.14 * decoration_bonus_mult()))
			cash += bonus
			total_cash_earned += bonus
			p["bounce"] = maxf(float(p["bounce"]), 0.22)
			floating_cash.append({
				"pos": plot_position(p) + Vector3(0.35, 2.45, 0.25),
				"text": "+%s" % GameCatalog.format_cash(bonus),
				"color": DesertPalette.EMERALD_POPUP,
				"drift_x": (rng.randf() - 0.5) * 0.45,
				"age": 0.0,
				"duration": 1.05,
			})

	sim_tick.emit(dt_sim)


func complete_visitor_purchase(target_p: Dictionary) -> void:
	var af := maxf(0.25, float(target_p["access"]["score"]))
	var vip_mult := 1.35 if plot_has_staff(target_p, "manager") else 1.0
	var repair_mult := float(staff_sim.plot_repair_tip_mult(target_p, self)) if staff_sim != null else 1.0
	var sale := maxf(3.0, roundf(GameCatalog.income_for_level(target_p["type"], target_p["level"]) * af * plot_staff_income_mult(target_p) * vip_mult * repair_mult * decoration_bonus_mult() / 15.0))
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
	_refresh_progression()
	hud_changed.emit()


# --- Player Actions, Notices & FX ---

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
	float_notice(world_pos + Vector3(0, 0.8, 0), "NEED %s" % GameCatalog.format_cash(ceil(needed)), Color("ffb899"), 0.95)


func float_notice(world_pos: Vector3, text: String, col: Color = Color("ffb899"), dur: float = 1.3) -> void:
	floating_cash.append({
		"pos": world_pos,
		"text": text,
		"color": col,
		"drift_x": (rng.randf() - 0.5) * 0.3,
		"age": 0.0,
		"duration": dur,
	})


func spawn_dust(center: Vector3, count: int = 12) -> void:
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
			placement.road_line_tap(OutpostLayout.world_to_cell(gp))
			return
		GameCatalog.WorldToolMode.PAINT_CONDUIT:
			placement.conduit_line_tap(OutpostLayout.world_to_cell(gp))
			return
		GameCatalog.WorldToolMode.PAINT_WATER_PIPE:
			placement.water_pipe_line_tap(OutpostLayout.world_to_cell(gp))
			return
		GameCatalog.WorldToolMode.PLACE_POWER_POLE:
			placement.pole_tap(OutpostLayout.world_to_cell(gp))
			return
		GameCatalog.WorldToolMode.PLACE_BUILDING, GameCatalog.WorldToolMode.PLACE_PARKING, GameCatalog.WorldToolMode.PLACE_DECORATION, GameCatalog.WorldToolMode.PLACE_UTILITY:
			placement.move_ghost_to_world(gp)
			return
		GameCatalog.WorldToolMode.BUY_LAND:
			var cell := OutpostLayout.world_to_cell(gp)
			if OutpostLayout.is_cell_in_map(cell.x, cell.y):
				placement.buy_parcel(OutpostLayout.parcel_of(cell.x, cell.y))
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
		select_plot(str(plots[best_idx]["id"]))
		return

	# Check parking lots for quick inspection
	var best_lot_id := ""
	var best_lot_d := 1e9
	for lot in parking_lots:
		var spec: Dictionary = GameCatalog.PARKING_LOTS[lot["kind"]]
		var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], lot["rot"])
		var hw := float(sz.x) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.35
		var hd := float(sz.y) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.35
		var pos := lot_position(lot)
		if absf(gp.x - pos.x) <= hw and absf(gp.z - pos.z) <= hd:
			var d := pos.distance_to(gp)
			if d < best_lot_d:
				best_lot_d = d
				best_lot_id = str(lot["id"])
	if not best_lot_id.is_empty():
		select_lot(best_lot_id)
		return

	# Check power utilities for inspection
	var best_util_id := ""
	var best_util_d := 1e9
	for u in utilities:
		var spec: Dictionary = GameCatalog.UTILITIES[int(u["kind"])]
		var sz := OutpostLayout.rotated_size(int(spec["grid_w"]), int(spec["grid_d"]), int(u.get("rot", 0)))
		var hw := float(sz.x) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.35
		var hd := float(sz.y) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.35
		var pos := utility_position(u)
		var hit := (absf(gp.x - pos.x) <= hw and absf(gp.z - pos.z) <= hd) or (absf(mp.x - pos.x) <= hw and absf(mp.z - pos.z) <= hd)
		if hit:
			var d := pos.distance_to(gp)
			if d < best_util_d:
				best_util_d = d
				best_util_id = str(u["id"])
	if not best_util_id.is_empty():
		select_utility(best_util_id)
	else:
		clear_selected_plot()


func upgrade_plot(p: Dictionary) -> bool:
	if not p["is_built"]:
		return false
	var lock := upgrade_lock_reason(p)
	if not lock.is_empty():
		float_notice(plot_position(p) + Vector3(0, 2.8, 0), lock)
		return false
	var cost := GameCatalog.upgrade_cost_for_level(p["type"], p["level"])
	if cash < cost:
		notify_shortfall(plot_position(p), cost - cash)
		return false
	cash -= cost
	p["level"] += 1
	p["bounce"] = 0.40
	spawn_dust(plot_position(p), 10)
	float_notice(plot_position(p) + Vector3(0, 3.0, 0), "LV %d!" % p["level"], DesertPalette.NEON_TURQUOISE, 1.35)
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
	float_notice(plot_position(plots[0]) + Vector3(0, 2.7, 0), "TAP +%s!" % GameCatalog.format_cash(tap_income()), DesertPalette.GOLD, 1.25)
	save_state()
	hud_changed.emit()
	return true


# --- Thin Forwarding Facade to PlacementController ---

func cancel_tool_mode(emit_sig: bool = true) -> void:
	placement.cancel_tool_mode(emit_sig)

func enter_road_mode(tier: int = -1, erase: bool = false) -> void:
	placement.enter_road_mode(tier, erase)

func set_road_brush(tier: int) -> void:
	placement.set_road_brush(tier)

func set_road_two_lane(enabled: bool) -> void:
	placement.set_road_two_lane(enabled)

func set_road_erase(erase: bool) -> void:
	placement.set_road_erase(erase)

func road_line_tap(cell: Vector2i) -> void:
	placement.road_line_tap(cell)

func clear_road_line() -> void:
	placement.clear_road_line()

func compute_road_line_preview() -> Dictionary:
	return placement.compute_road_line_preview()

func confirm_road_line() -> bool:
	return placement.confirm_road_line()

func suggest_access_road() -> void:
	placement.suggest_access_road()

func enter_land_mode() -> void:
	placement.enter_land_mode()

func buy_parcel(p: Vector2i) -> bool:
	return placement.buy_parcel(p)

func validate_rect(gx: int, gz: int, base_w: int, base_d: int, rot: int, ignore_id: String = "", required_trait: int = GameCatalog.ParcelTrait.NONE) -> String:
	return placement.validate_rect(gx, gz, base_w, base_d, rot, ignore_id, required_trait)

func ghost_size() -> Vector2i:
	return placement.ghost_size()

func ghost_invalid_reason() -> String:
	return placement.ghost_invalid_reason()

func ghost_access_preview() -> Dictionary:
	return placement.ghost_access_preview()

func find_movable_object_at(screen_pos: Vector2) -> Dictionary:
	return placement.find_movable_object_at(screen_pos)

func has_movable_object_at(screen_pos: Vector2) -> bool:
	return not placement.find_movable_object_at(screen_pos).is_empty()

func try_start_hold_move_at(screen_pos: Vector2) -> bool:
	return placement.try_start_hold_move_at(screen_pos)

func drag_ghost_to_screen(screen_pos: Vector2) -> void:
	placement.drag_ghost_to_screen(screen_pos)

func finish_hold_move() -> void:
	placement.finish_hold_move()

func start_placing_building(btype: int) -> void:
	placement.start_placing_building(btype)

func start_relocating_plot(p: Dictionary, focus_cam: bool = true) -> void:
	placement.start_relocating_plot(p, focus_cam)

func start_placing_parking(kind: int) -> void:
	placement.start_placing_parking(kind)

func start_relocating_parking(lot: Dictionary, upgrade_to: int = -1, focus_cam: bool = true) -> void:
	placement.start_relocating_parking(lot, upgrade_to, focus_cam)

func start_placing_decoration(deco_spec: Dictionary) -> void:
	placement.start_placing_decoration(deco_spec)

func start_relocating_decoration(deco: Dictionary, focus_cam: bool = true) -> void:
	placement.start_relocating_decoration(deco, focus_cam)

func rotate_ghost() -> void:
	placement.rotate_ghost()

func move_ghost_to_world(world_pos: Vector3) -> void:
	placement.move_ghost_to_world(world_pos)

func confirm_placement() -> bool:
	return placement.confirm_placement()

func place_parking_lot_at(kind: int, gx: int, gz: int, rot: int = 0) -> bool:
	return placement.place_parking_lot_at(kind, gx, gz, rot)

func upgrade_parking_lot(lot: Dictionary) -> bool:
	return placement.upgrade_parking_lot(lot)

func remove_parking_lot(lot: Dictionary) -> void:
	placement.remove_parking_lot(lot)

func quick_upgrade_or_place_parking() -> bool:
	return placement.quick_upgrade_or_place_parking()

func start_placing_utility(kind: int) -> void:
	placement.start_placing_utility(kind)

func start_relocating_utility(u: Dictionary, focus_cam: bool = true) -> void:
	placement.start_relocating_utility(u, focus_cam)

func place_utility_at(kind: int, gx: int, gz: int, rot: int = 0) -> bool:
	return placement.place_utility_at(kind, gx, gz, rot)

func remove_utility(u: Dictionary) -> void:
	placement.remove_utility(u)

func enter_pole_mode(kind: int = -1, erase: bool = false) -> void:
	placement.enter_pole_mode(kind, erase)

func set_pole_kind(kind: int) -> void:
	placement.set_pole_kind(kind)

func set_pole_erase(erase: bool) -> void:
	placement.set_pole_erase(erase)

func pole_tap(cell: Vector2i) -> bool:
	return placement.pole_tap(cell)

func enter_conduit_mode(erase: bool = false) -> void:
	placement.enter_conduit_mode(erase)

func set_conduit_erase(erase: bool) -> void:
	placement.set_conduit_erase(erase)

func conduit_line_tap(cell: Vector2i) -> void:
	placement.conduit_line_tap(cell)

func clear_conduit_line() -> void:
	placement.clear_conduit_line()

func compute_conduit_line_preview() -> Dictionary:
	return placement.compute_conduit_line_preview()

func confirm_conduit_line() -> bool:
	return placement.confirm_conduit_line()

func enter_water_pipe_mode(erase: bool = false) -> void:
	placement.enter_water_pipe_mode(erase)

func set_water_pipe_erase(erase: bool) -> void:
	placement.set_water_pipe_erase(erase)

func water_pipe_line_tap(cell: Vector2i) -> void:
	placement.water_pipe_line_tap(cell)

func clear_water_pipe_line() -> void:
	placement.clear_water_pipe_line()

func compute_water_pipe_line_preview() -> Dictionary:
	return placement.compute_water_pipe_line_preview()

func confirm_water_pipe_line() -> bool:
	return placement.confirm_water_pipe_line()


# --- Time, Presets, Camera & Persistence ---

func set_time_preset(t: float, pause_cycle: bool = true) -> void:
	sim_clock.set_time_preset(t, pause_cycle)
	sync_clock_mirrors()
	power_network.step(0.0, self)
	save_state()
	hud_changed.emit()


func toggle_auto_day_night() -> void:
	sim_clock.auto_day_night = not sim_clock.auto_day_night
	sync_clock_mirrors()
	save_state()
	hud_changed.emit()


func switch_preset(preset: int) -> void:
	_suppress_stage_fx = true
	_init_world(preset)
	_init_milestones()
	recompute_network()
	reset_camera_immediate()
	traffic_sim.seed_initial_traffic()
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


func save_state() -> void:
	SaveManager.save_to_disk(self)
