extends SceneTree

## Headless verification suite for Desert Outpost Phase 3 (Specialized Staff, Outpost Crew & Morale).

const TEST_SAVE_PATH := "user://desert_outpost_phase3_test.json"

var _passed := 0
var _failed := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % msg)
		print("  [FAIL] %s" % msg)


func _initialize() -> void:
	print("=== Desert Outpost Phase 3 Headless Verification ===")
	_test_specialized_business_roles()
	_test_motel_and_store_perks()
	_test_outpost_crew_hiring_and_boosts()
	_test_morale_and_picnic_synergy()
	_test_roaming_crew_patrol_ai()
	_test_full_city_and_save_roundtrip()
	_test_3d_crew_and_store_staff_models()

	print("=== Summary: %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _make_stage_state(stage: int = 5) -> GameState:
	var st := GameState.new()
	st._suppress_stage_fx = true
	st._init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	st._init_milestones()
	st.set_highest_stage_raw(stage)
	st.cash = 10000.0
	var parcels: Array[Vector2i] = []
	for px in range(0, 8):
		for pz in range(3, 8):
			parcels.append(Vector2i(px, pz))
	st.world_grid.reset_ownership(parcels)
	for gz in range(-18, OutpostLayout.HIGHWAY_ENTRY_ROW_Z + 1):
		st.road_network.set_tile(Vector2i(0, gz), GameCatalog.RoadTier.PAVED)
		st.road_network.set_tile(Vector2i(1, gz), GameCatalog.RoadTier.PAVED)
	st.place_parking_lot_at(GameCatalog.ParkingLotKind.DIRT_PULL_OFF, 2, -10, 1)
	st.recompute_network()
	return st


func _find_plot(st: GameState, id: String) -> Dictionary:
	for p in st.plots:
		if str(p["id"]) == id:
			return p
	return {}


func _test_specialized_business_roles() -> void:
	print("\n[1] Specialized Business Staff Identities")
	var diner_c := GameCatalog.staff_role_for_business(GameCatalog.BusinessType.DESERT_DINER, GameCatalog.STAFF_ROLES[0])
	var diner_m := GameCatalog.staff_role_for_business(GameCatalog.BusinessType.DESERT_DINER, GameCatalog.STAFF_ROLES[2])
	var gas_g := GameCatalog.staff_role_for_business(GameCatalog.BusinessType.GAS_STATION, GameCatalog.STAFF_ROLES[1])
	var motel_c := GameCatalog.staff_role_for_business(GameCatalog.BusinessType.DESERT_MOTEL, GameCatalog.STAFF_ROLES[0])
	var lookout_g := GameCatalog.staff_role_for_business(GameCatalog.BusinessType.LOOKOUT_CAMP, GameCatalog.STAFF_ROLES[1])

	_check(str(diner_c["name"]) == "Line Cook" and str(diner_c["id"]) == "clerk", "Diner slot 1 is Line Cook (id=clerk)")
	_check(str(diner_m["name"]) == "Head Chef" and str(diner_m["perk_id"]) == "stock_saver", "Diner slot 3 is Head Chef with stock_saver")
	_check(str(gas_g["name"]) == "Bay Mechanic" and str(gas_g["perk_id"]) == "repair_tips", "Gas Station slot 2 is Bay Mechanic")
	_check(str(motel_c["name"]) == "Night Clerk" and str(motel_c["perk_id"]) == "night_boost", "Motel slot 1 is Night Clerk")
	_check(str(lookout_g["name"]) == "Trail Guide", "Lookout Camp slot 2 is Trail Guide")


func _test_motel_and_store_perks() -> void:
	print("\n[2] Motel Night Clerk & Housekeeper Water Reduction")
	var st := _make_stage_state(5)
	var motel := _find_plot(st, "motel")
	motel["is_built"] = true
	motel["level"] = 2
	motel["grid_x"] = 2
	motel["grid_z"] = -15
	st.place_utility_at(GameCatalog.UtilityKind.DIESEL_GEN, 6, -15, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, 6, -12, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WATER_WELL, 6, -18, 0)
	st.recompute_network()

	var water_before := float(motel["runtime"]["water_demand"])
	st.hire_staff_for_plot(motel, GameCatalog.STAFF_ROLES[0]) # Night Clerk
	st.hire_staff_for_plot(motel, GameCatalog.STAFF_ROLES[1]) # Housekeeper
	st.recompute_network()
	var water_after := float(motel["runtime"]["water_demand"])
	_check(water_after < water_before, "Motel Housekeeper cuts water demand by 20%% (%.1f -> %.1f)" % [water_before, water_after])

	st.sim_clock.reset(1, 0.50, false, 1.0) # Noon
	var day_inc := st.plot_income_per_minute(motel)
	st.sim_clock.reset(1, 0.0, false, 1.0) # Midnight
	var night_inc := st.plot_income_per_minute(motel)
	_check(night_inc > day_inc, "Motel Night Clerk boosts nighttime income ($%.0f day -> $%.0f night)" % [day_inc, night_inc])
	st.free()


func _test_outpost_crew_hiring_and_boosts() -> void:
	print("\n[3] Outpost Crew Hiring, Lv 1->3 Training & Multipliers")
	var st := _make_stage_state(5)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, 6, -14, 0)
	st.place_utility_at(GameCatalog.UtilityKind.OIL_PUMPJACK, -20, -14, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, -17, -14, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WATER_WELL, 11, -8, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, 14, -8, 0)
	st.recompute_network()

	var gen_before := st.power_network.total_gen_kw
	var oil_before := float(st.supply_sim.production_per_min.get(GameCatalog.Commodity.CRUDE_OIL, 0.0))
	var water_before := st.water_network.total_supply

	_check(st.hire_or_train_crew(GameCatalog.CrewKind.GRID_TECH), "Grid Technician Lv1 hired")
	_check(st.hire_or_train_crew(GameCatalog.CrewKind.GRID_TECH), "Grid Technician trained to Lv2")
	_check(st.hire_or_train_crew(GameCatalog.CrewKind.PUMP_ENGINEER), "Pump & Pipe Engineer Lv1 hired")
	_check(st.hire_or_train_crew(GameCatalog.CrewKind.LOGISTICS_RUNNER), "Logistics Runner Lv1 hired")
	st.recompute_network()

	_check(st.power_network.total_gen_kw > gen_before * 1.18, "Grid Tech Lv2 boosts power gen +20%% (%.1f -> %.1f kW)" % [gen_before, st.power_network.total_gen_kw])
	var oil_after := float(st.supply_sim.production_per_min.get(GameCatalog.Commodity.CRUDE_OIL, 0.0))
	_check(oil_after > oil_before * 1.12, "Pump Engineer Lv1 boosts Oil output +15%% (%.1f -> %.1f)" % [oil_before, oil_after])
	_check(st.water_network.total_supply > water_before * 1.12, "Pump Engineer Lv1 boosts Water Well output +15%% (%.1f -> %.1f)" % [water_before, st.water_network.total_supply])
	_check(is_equal_approx(st.supply_sim.wholesale_discount(), 0.10), "Logistics Runner grants 10% extra wholesale discount")
	st.free()


func _test_morale_and_picnic_synergy() -> void:
	print("\n[4] Staff Morale & Picnic Break Area Synergy")
	var st := _make_stage_state(5)
	var diner := _find_plot(st, "diner")
	diner["is_built"] = true
	diner["level"] = 2
	diner["grid_x"] = 2
	diner["grid_z"] = -15
	st.place_utility_at(GameCatalog.UtilityKind.DIESEL_GEN, 6, -15, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WATER_WELL, 6, -12, 0)
	st.hire_staff_for_plot(diner, GameCatalog.STAFF_ROLES[0])
	st.hire_staff_for_plot(diner, GameCatalog.STAFF_ROLES[1]) # Patio Server (picnic_synergy)
	st.recompute_network()

	var morale_before := st.staff_sim.morale
	var mult_before := st.plot_staff_income_mult(diner)

	# Place 2 Picnic Sets
	for i in range(2):
		st.decorations.append({"id": "pic_%d" % i, "kind": GameCatalog.DecorationKind.PICNIC_SET, "name": "Picnic", "cost": 55.0, "grid_x": -3 - i, "grid_z": -12, "rot": 0})
	st.recompute_network()
	_check(st.staff_sim.morale > morale_before, "Picnic Sets raise Staff Morale (%.2f -> %.2f)" % [morale_before, st.staff_sim.morale])
	_check(st.plot_staff_income_mult(diner) > mult_before * 1.10, "Morale + Patio Server Picnic Synergy boost Diner staff mult (%.2f -> %.2f)" % [mult_before, st.plot_staff_income_mult(diner)])
	st.free()


func _test_roaming_crew_patrol_ai() -> void:
	print("\n[5] Roaming 3D Crew Patrol AI & Pause Freeze")
	var st := _make_stage_state(5)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, 6, -14, 0)
	st.place_utility_at(GameCatalog.UtilityKind.SOLAR_ARRAY, 10, -14, 0)
	st.hire_or_train_crew(GameCatalog.CrewKind.GRID_TECH)
	_check(st.staff_sim.agents.size() == 1, "Hiring Grid Tech spawns 1 roaming 3D agent")

	var start_pos: Vector3 = st.staff_sim.agents[0]["pos"]
	for _i in range(40):
		st.staff_sim.update(0.1, st)
	var moved_pos: Vector3 = st.staff_sim.agents[0]["pos"]
	_check(start_pos.distance_to(moved_pos) > 0.5, "Grid Tech walks cleanly toward power sites (moved %.2fm)" % start_pos.distance_to(moved_pos))

	# Pause freezes movement (sim_dt = 0)
	st.staff_sim.update(0.0, st)
	_check(st.staff_sim.agents[0]["pos"] == moved_pos, "Paused sim_dt=0 freezes roaming crew cleanly")
	st.free()


func _test_full_city_and_save_roundtrip() -> void:
	print("\n[6] Full City Starter Crew & v5 Save Roundtrip")
	var st := GameState.new()
	st._suppress_stage_fx = true
	st._init_world(GameCatalog.OutpostPreset.FULL_CITY)
	st._init_milestones()
	st.recompute_network()
	_check(st.staff_sim.crew_level(GameCatalog.CrewKind.GRID_TECH) == 1 and st.staff_sim.crew_level(GameCatalog.CrewKind.LOGISTICS_RUNNER) == 1, "Full City boots with Lv1 Grid Tech & Logistics Runner")
	_check(st.staff_sim.agents.size() == 2, "Full City spawns 2 patrolling 3D crew agents")

	st.cash = 5000.0
	st.hire_or_train_crew(GameCatalog.CrewKind.PUMP_ENGINEER)
	st.hire_or_train_crew(GameCatalog.CrewKind.GRID_TECH) # Lv 2
	var saved := SaveManager.save_to_disk(st, TEST_SAVE_PATH)
	_check(saved, "Phase 3 crew state saved cleanly")

	var st2 := GameState.new()
	st2._suppress_stage_fx = true
	st2._init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	st2._init_milestones()
	var loaded := SaveManager.load_from_disk(st2, TEST_SAVE_PATH, false)
	_check(loaded and st2.staff_sim.crew_level(GameCatalog.CrewKind.GRID_TECH) == 2 and st2.staff_sim.crew_level(GameCatalog.CrewKind.PUMP_ENGINEER) == 1, "v5 reload restores exact Outpost Crew levels")
	_check(st2.staff_sim.agents.size() == 3, "v5 reload spawns all 3 patrolling crew agents")

	var abs_test := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(abs_test)
	st.free()
	st2.free()


func _test_3d_crew_and_store_staff_models() -> void:
	print("\n[7] 3D Crew & Store Staff Mesh Builders")
	for ck in [GameCatalog.CrewKind.GRID_TECH, GameCatalog.CrewKind.PUMP_ENGINEER, GameCatalog.CrewKind.LOGISTICS_RUNNER]:
		var n := EntityBuilder.build_crew_node(ck)
		_check(n != null, "EntityBuilder builds CrewKind %d 3D figure" % ck)
		n.free()
	var sn := EntityBuilder.build_store_staff_node(GameCatalog.STAFF_ROLES[2])
	_check(sn != null, "EntityBuilder builds on-site Store Staff 3D figure")
	sn.free()
