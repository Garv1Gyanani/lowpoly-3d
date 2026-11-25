class_name StaffSim
extends RefCounted

## Manages specialized business staff perks, Outpost-Wide Roaming Crew (Lv 1-3),
## Staff Morale (linked to shaded Picnic/Campfire/Oasis spaces & utilities),
## transparent Crew wages, and 3D patrolling worker AI.

const MAX_CREW_LEVEL := 3

var crew_levels: Dictionary = {
	GameCatalog.CrewKind.GRID_TECH: 0,
	GameCatalog.CrewKind.PUMP_ENGINEER: 0,
	GameCatalog.CrewKind.LOGISTICS_RUNNER: 0,
}

var agents: Array[Dictionary] = [] # Live roaming 3D crew agents
var morale: float = 1.0            # 1.00 .. 1.20
var morale_breakdown: String = "Baseline 100%"
var total_wages_per_min: float = 0.0


func clear() -> void:
	for k in crew_levels.keys():
		crew_levels[k] = 0
	agents.clear()
	morale = 1.0
	morale_breakdown = "Baseline 100%"
	total_wages_per_min = 0.0


func crew_level(kind: int) -> int:
	return int(crew_levels.get(kind, 0))


func is_crew_unlocked(kind: int, state) -> bool:
	return state.outpost_stage() >= int(GameCatalog.OUTPOST_CREW[kind]["stage"])


func crew_lock_reason(kind: int, state) -> String:
	var lv := crew_level(kind)
	if lv >= MAX_CREW_LEVEL:
		return "MAX"
	var req_stg := int(GameCatalog.OUTPOST_CREW[kind]["stage"])
	if state.outpost_stage() < req_stg:
		return "STAGE %d" % req_stg
	return ""


func hire_or_train_crew(kind: int, state) -> bool:
	var lock := crew_lock_reason(kind, state)
	if not lock.is_empty():
		return false
	var cur_lv := crew_level(kind)
	var cost := GameCatalog.crew_action_cost(kind, cur_lv)
	if state.cash < cost:
		state.notify_shortfall(state.town_focus(), cost - state.cash)
		return false
	state.cash -= cost
	crew_levels[kind] = cur_lv + 1
	sync_agents(state)
	state.recompute_network()
	var spec: Dictionary = GameCatalog.OUTPOST_CREW[kind]
	var notice := "%s HIRED!" % str(spec["short"]).to_upper() if cur_lv == 0 else "%s LV %d!" % [str(spec["short"]).to_upper(), cur_lv + 1]
	state.float_notice(state.town_focus() + Vector3(0, 3.2, 0), notice, DesertPalette.GOLD, 1.45)
	state.save_state()
	state.hud_changed.emit()
	return true


# --- Outpost-Wide Crew Multipliers ---

func power_gen_mult() -> float:
	return 1.0 + GameCatalog.crew_boost_for_level(GameCatalog.CrewKind.GRID_TECH, crew_level(GameCatalog.CrewKind.GRID_TECH))


func diesel_upkeep_mult() -> float:
	return 0.70 if crew_level(GameCatalog.CrewKind.GRID_TECH) > 0 else 1.0


func water_well_mult() -> float:
	return 1.0 + GameCatalog.crew_boost_for_level(GameCatalog.CrewKind.PUMP_ENGINEER, crew_level(GameCatalog.CrewKind.PUMP_ENGINEER))


func oil_refinery_mult() -> float:
	return 1.0 + GameCatalog.crew_boost_for_level(GameCatalog.CrewKind.PUMP_ENGINEER, crew_level(GameCatalog.CrewKind.PUMP_ENGINEER))


func food_craft_prod_mult() -> float:
	return 1.0 + GameCatalog.crew_boost_for_level(GameCatalog.CrewKind.LOGISTICS_RUNNER, crew_level(GameCatalog.CrewKind.LOGISTICS_RUNNER))


func extra_wholesale_discount() -> float:
	return 0.10 if crew_level(GameCatalog.CrewKind.LOGISTICS_RUNNER) > 0 else 0.0


# --- Specialized Per-Business Staff Perks ---

func plot_has_perk(p: Dictionary, perk_id: String, state) -> bool:
	var btype: int = int(p["type"])
	var hired: Array = state.plot_staff_list(p)
	for base_role: Dictionary in GameCatalog.STAFF_ROLES:
		if not hired.has(str(base_role["id"])):
			continue
		var spec := GameCatalog.staff_role_for_business(btype, base_role)
		if str(spec.get("perk_id", "")) == perk_id:
			return true
	return false


func plot_water_mult(p: Dictionary, state) -> float:
	return 0.80 if plot_has_perk(p, "water_saver", state) else 1.0


func plot_stock_burn_mult(p: Dictionary, state) -> float:
	return 0.85 if plot_has_perk(p, "stock_saver", state) else 1.0


func plot_night_income_mult(p: Dictionary, is_night: bool, state) -> float:
	return 1.20 if (is_night and plot_has_perk(p, "night_boost", state)) else 1.0


func plot_picnic_synergy_mult(p: Dictionary, state) -> float:
	if not plot_has_perk(p, "picnic_synergy", state):
		return 1.0
	var social_count := 0
	for d in state.decorations:
		var dk: int = int(d["kind"])
		if dk == GameCatalog.DecorationKind.PICNIC_SET or dk == GameCatalog.DecorationKind.CAMPFIRE_RING:
			social_count += 1
	return 1.15 if social_count >= 1 else 1.0


func plot_repair_tip_mult(p: Dictionary, state) -> float:
	return 1.20 if plot_has_perk(p, "repair_tips", state) else 1.0


# --- Morale & 1 Hz Simulation Step ---

func recompute_morale(state) -> void:
	var m := 1.0
	var parts: Array[String] = []

	var picnic_n := 0
	for d in state.decorations:
		var dk: int = int(d["kind"])
		if dk == GameCatalog.DecorationKind.PICNIC_SET or dk == GameCatalog.DecorationKind.CAMPFIRE_RING:
			picnic_n += 1
	var picnic_bonus := minf(0.12, float(picnic_n) * 0.03)
	if picnic_bonus > 0.0:
		m += picnic_bonus
		parts.append("+%d%% Break Areas" % roundi(picnic_bonus * 100.0))

	var oasis_built := false
	for p in state.plots:
		if str(p["id"]) == "oasis_plaza" and bool(p["is_built"]):
			oasis_built = true
			break
	if oasis_built:
		m += 0.05
		parts.append("+5% Oasis Shade")

	var util_ok: bool = state.power_network.brownout_count == 0 and state.water_network.dry_count == 0
	if util_ok and state.built_count() >= 2:
		m += 0.03
		parts.append("+3% Utilities OK")

	morale = clampf(m, 1.0, 1.20)
	morale_breakdown = "Baseline 100%" if parts.is_empty() else " · ".join(parts)


func step(dt_sim: float, state) -> void:
	recompute_morale(state)
	var wages := 0.0
	for kind in [GameCatalog.CrewKind.GRID_TECH, GameCatalog.CrewKind.PUMP_ENGINEER, GameCatalog.CrewKind.LOGISTICS_RUNNER]:
		if crew_level(kind) > 0:
			wages += float(GameCatalog.OUTPOST_CREW[kind]["wage_per_min"])
	total_wages_per_min = wages
	if wages > 0.0 and dt_sim > 0.0 and state.cash > 0.0:
		state.cash = maxf(0.0, state.cash - (wages / 60.0) * dt_sim)


# --- Roaming 3D Crew Patrol AI ---

func sync_agents(state) -> void:
	var wanted: Dictionary = {}
	for kind in [GameCatalog.CrewKind.GRID_TECH, GameCatalog.CrewKind.PUMP_ENGINEER, GameCatalog.CrewKind.LOGISTICS_RUNNER]:
		if crew_level(kind) > 0:
			wanted[kind] = true

	# Remove agents whose crew is no longer hired
	for i in range(agents.size() - 1, -1, -1):
		if not wanted.has(int(agents[i]["kind"])):
			agents.remove_at(i)

	# Spawn missing agents
	for kind in wanted.keys():
		var exists := false
		for ag in agents:
			if int(ag["kind"]) == int(kind):
				exists = true
				break
		if not exists:
			var spawn_pos: Vector3 = state.town_focus() + Vector3(float(kind) * 1.1 - 1.1, 0.0, 1.8)
			agents.append({
				"id": "crew_%d" % int(kind),
				"kind": int(kind),
				"pos": spawn_pos,
				"yaw": 0.0,
				"walk_cycle": float(kind) * 1.3,
				"waypoints": [],
				"wait_timer": 0.4,
				"last_target_idx": -1,
			})


func update(sim_dt: float, state) -> void:
	if sim_dt <= 0.0:
		return
	if agents.is_empty():
		return
	for ag in agents:
		ag["walk_cycle"] = float(ag["walk_cycle"]) + sim_dt
		var wps: Array = ag["waypoints"]
		if not wps.is_empty():
			var wp: Vector3 = wps[0]
			var cur: Vector3 = ag["pos"]
			var diff: Vector3 = wp - cur
			var dist := diff.length()
			if dist < 0.25:
				ag["pos"] = wp
				wps.remove_at(0)
				if wps.is_empty():
					ag["wait_timer"] = 2.6
			else:
				var dv := diff / dist
				ag["pos"] = cur + dv * minf(dist, 2.35 * sim_dt)
				var target_yaw := atan2(dv.z, dv.x)
				var diff_y := fposmod(target_yaw - float(ag["yaw"]) + PI, TAU) - PI
				ag["yaw"] = float(ag["yaw"]) + diff_y * clampf(sim_dt * 9.0, 0.0, 1.0)
		else:
			ag["wait_timer"] = float(ag["wait_timer"]) - sim_dt
			if float(ag["wait_timer"]) <= 0.0:
				_assign_next_patrol(ag, state)


func _assign_next_patrol(ag: Dictionary, state) -> void:
	var kind: int = int(ag["kind"])
	var sites: Array[Vector3] = []
	for u in state.utilities:
		var grp := GameCatalog.utility_group(int(u["kind"]))
		var uk: int = int(u["kind"])
		if kind == GameCatalog.CrewKind.GRID_TECH and grp == "power":
			sites.append(state.utility_position(u) + Vector3(0.0, 0.0, 1.9))
		elif kind == GameCatalog.CrewKind.PUMP_ENGINEER and (grp == "water" or uk == GameCatalog.UtilityKind.OIL_PUMPJACK or uk == GameCatalog.UtilityKind.MINI_REFINERY):
			sites.append(state.utility_position(u) + Vector3(0.0, 0.0, 1.9))
		elif kind == GameCatalog.CrewKind.LOGISTICS_RUNNER and (uk == GameCatalog.UtilityKind.FREIGHT_DEPOT or uk == GameCatalog.UtilityKind.DESERT_GREENHOUSE or uk == GameCatalog.UtilityKind.CRAFT_WORKSHOP):
			sites.append(state.utility_position(u) + Vector3(0.0, 0.0, 1.9))

	if kind == GameCatalog.CrewKind.LOGISTICS_RUNNER or sites.is_empty():
		for p in state.plots:
			if p["is_built"]:
				sites.append(state.plot_visitor_stop(p))

	if sites.is_empty():
		ag["wait_timer"] = 2.0
		return

	var next_idx: int = (int(ag.get("last_target_idx", -1)) + 1) % sites.size()
	ag["last_target_idx"] = next_idx
	var dest: Vector3 = sites[next_idx]
	var cur: Vector3 = ag["pos"]
	if cur.distance_to(dest) < 0.6:
		ag["wait_timer"] = 2.4
		return
	var blocked: Dictionary = {}
	for p in state.plots:
		if p["is_built"]:
			var d: Dictionary = GameCatalog.BUSINESSES[p["type"]]
			for c in WorldGrid._rect_cells(p["grid_x"], p["grid_z"], d["grid_w"], d["grid_d"], p["rot"]):
				blocked[c] = true
	var path: Array[Vector3] = state.road_network.build_visitor_walk_path(cur, dest, blocked)
	if path.is_empty():
		path = [dest]
	ag["waypoints"] = path


func to_dict() -> Dictionary:
	return {
		"grid_tech": crew_level(GameCatalog.CrewKind.GRID_TECH),
		"pump_engineer": crew_level(GameCatalog.CrewKind.PUMP_ENGINEER),
		"logistics_runner": crew_level(GameCatalog.CrewKind.LOGISTICS_RUNNER),
	}


func from_dict(d: Dictionary) -> void:
	crew_levels[GameCatalog.CrewKind.GRID_TECH] = clampi(int(d.get("grid_tech", 0)), 0, MAX_CREW_LEVEL)
	crew_levels[GameCatalog.CrewKind.PUMP_ENGINEER] = clampi(int(d.get("pump_engineer", 0)), 0, MAX_CREW_LEVEL)
	crew_levels[GameCatalog.CrewKind.LOGISTICS_RUNNER] = clampi(int(d.get("logistics_runner", 0)), 0, MAX_CREW_LEVEL)
