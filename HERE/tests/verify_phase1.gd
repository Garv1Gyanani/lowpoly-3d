extends SceneTree

## Headless verification suite for Desert Outpost Phase 1 (Off-Grid Power Grid).

const TEST_SAVE_PATH := "user://desert_outpost_phase1_test.json"

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
	print("=== Desert Outpost Phase 1 Headless Verification ===")
	_test_cart_and_brownout_floor()
	_test_local_link_and_wind_corridor()
	_test_rooftop_solar_day_night()
	_test_battery_charge_and_night_discharge()
	_test_pole_and_tower_spans()
	_test_underground_conduit_under_roads()
	_test_full_city_power_and_save_roundtrip()
	_test_3d_power_builders()

	print("=== Summary: %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _make_stage_state(stage: int = 4) -> GameState:
	var st := GameState.new()
	st._suppress_stage_fx = true
	st._init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	st._init_milestones()
	st.set_highest_stage_raw(stage)
	st.cash = 5000.0
	# Unlock wide grid of parcels for testing
	var parcels: Array[Vector2i] = []
	for px in range(0, 8):
		for pz in range(3, 8):
			parcels.append(Vector2i(px, pz))
	st.world_grid.reset_ownership(parcels)
	st.recompute_network()
	return st


func _find_plot(st: GameState, id: String) -> Dictionary:
	for p in st.plots:
		if str(p["id"]) == id:
			return p
	return {}


func _test_cart_and_brownout_floor() -> void:
	print("\n[1] Cart Self-Sufficiency & Forgiving Brownout Floor")
	var st := _make_stage_state(4)
	var cart := _find_plot(st, "vendor")
	_check(is_equal_approx(float(cart["runtime"]["power_ratio"]), 1.0), "Stage 1 Roadside Cart needs 0 kW and stays at 100% power")

	var mart := _find_plot(st, "mart")
	mart["is_built"] = true
	mart["grid_x"] = 2
	mart["grid_z"] = -14
	st.recompute_network()
	var pr := float(mart["runtime"]["power_ratio"])
	_check(is_equal_approx(pr, PowerNetwork.BROWNOUT_FLOOR), "Unpowered Outpost Mart hits forgiving 55%% brownout floor (got %.2f)" % pr)
	_check(st.power_network.brownout_count == 1, "Brownout counter tracks 1 underpowered building")
	st.free()


func _test_local_link_and_wind_corridor() -> void:
	print("\n[2] Local Proximity Auto-Link & Wind Corridor +40% Bonus")
	var st := _make_stage_state(4)
	var mart := _find_plot(st, "mart")
	mart["is_built"] = true
	mart["grid_x"] = 2
	mart["grid_z"] = -14
	st.recompute_network()

	# Place Windmill within 2 tiles of Mart (Mart spans x=2..4, z=-14..-12)
	var placed := st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, 6, -14, 0)
	_check(placed, "Windmill placed 2 tiles beside Outpost Mart")
	_check(is_equal_approx(float(mart["runtime"]["power_ratio"]), 1.0), "Local auto-link powers Mart at 100% without poles")
	var standard_kw := PowerNetwork.utility_output_kw(st.utilities[0], st.world_grid, 0.0)
	_check(is_equal_approx(standard_kw, 7.5), "Standard desert Windmill outputs 7.5 kW at night (got %.1f)" % standard_kw)

	# Place Windmill on Wind Corridor parcel (px=0, pz=5 -> x=-30, z=-14)
	var placed_wind := st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, -30, -14, 0)
	_check(placed_wind, "Windmill placed on Wind Corridor parcel (0,5)")
	var boosted_kw := PowerNetwork.utility_output_kw(st.utilities[1], st.world_grid, 0.0)
	_check(is_equal_approx(boosted_kw, 10.5), "Wind Corridor Windmill outputs 10.5 kW (+40%% bonus, got %.1f)" % boosted_kw)
	st.free()


func _test_rooftop_solar_day_night() -> void:
	print("\n[3] Rooftop Solar Noon vs Midnight Curve")
	var st := _make_stage_state(4)
	var mart := _find_plot(st, "mart")
	mart["is_built"] = true
	mart["grid_x"] = 2
	mart["grid_z"] = -14
	mart["level"] = 1 # 4.0 kW demand
	st.recompute_network()

	var ok := st.install_rooftop_solar(mart)
	_check(ok and st.plot_has_rooftop_solar(mart), "Rooftop Solar installed on Outpost Mart")

	# Noon (0.50): solar_factor ~1.0, rooftop solar produces 4.5 kW >= 4.0 kW demand
	st.sim_clock.reset(1, 0.50, true, 1.0)
	st.power_network.step(1.0, st)
	_check(is_equal_approx(float(mart["runtime"]["power_ratio"]), 1.0), "Rooftop Solar powers Mart 100% at solar noon")

	# Midnight (0.0): solar_factor = 0.0 -> drops back to brownout without battery/wind
	st.sim_clock.reset(1, 0.0, true, 1.0)
	st.power_network.step(1.0, st)
	_check(is_equal_approx(float(mart["runtime"]["power_ratio"]), PowerNetwork.BROWNOUT_FLOOR), "Rooftop Solar drops to brownout floor at midnight without battery")
	st.free()


func _test_battery_charge_and_night_discharge() -> void:
	print("\n[4] Battery Bank Daytime Charge & Nighttime Discharge")
	var st := _make_stage_state(4)
	var diner := _find_plot(st, "diner")
	diner["is_built"] = true
	diner["grid_x"] = 0
	diner["grid_z"] = -14
	diner["level"] = 1 # 8 kW day, 10.8 kW night
	st.place_utility_at(GameCatalog.UtilityKind.SOLAR_ARRAY, 5, -14, 0) # 24 kW peak day
	st.place_utility_at(GameCatalog.UtilityKind.BATTERY_BANK, 5, -10, 0) # 90 kWh
	var bat := st.utilities[1]
	bat["stored_kwh"] = 10.0

	# Simulate 20 seconds at solar noon -> surplus ~16 kW should charge battery
	st.sim_clock.reset(1, 0.50, false, 1.0)
	for _i in range(20):
		st.power_network.step(1.0, st)
	var after_day := float(bat["stored_kwh"])
	_check(after_day > 20.0, "Battery charges from solar surplus at noon (10.0 -> %.1f kWh)" % after_day)

	# Switch to midnight (0.0) -> solar = 0, battery should carry Diner at 100% and discharge!
	st.sim_clock.reset(1, 0.0, false, 1.0)
	for _i in range(10):
		st.power_network.step(1.0, st)
	var after_night := float(bat["stored_kwh"])
	_check(is_equal_approx(float(diner["runtime"]["power_ratio"]), 1.0), "Battery carries Diner at 100% through midnight")
	_check(after_night < after_day, "Battery discharges cleanly during nighttime deficit (%.1f -> %.1f kWh)" % [after_day, after_night])
	st.free()


func _test_pole_and_tower_spans() -> void:
	print("\n[5] Overhead Pole (5-tile) & Steel Tower (9-tile) Spans")
	var st := _make_stage_state(4)
	var mart := _find_plot(st, "mart")
	mart["is_built"] = true
	mart["grid_x"] = 0
	mart["grid_z"] = -14
	# Place remote Windmill 12 tiles east (far beyond local auto-link!)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, 14, -14, 0)
	_check(float(mart["runtime"]["power_ratio"]) < 0.9, "Remote Windmill 12 tiles away does NOT auto-link Mart")

	# Place two Wood Poles 8 tiles apart (exceeds 5-tile Wood Pole span)
	st.enter_pole_mode(GameCatalog.PowerLineKind.WOOD_POLE)
	st.pole_tap(Vector2i(4, -14))
	st.pole_tap(Vector2i(12, -14))
	_check(float(mart["runtime"]["power_ratio"]) < 0.9, "Wood Poles 8 tiles apart do NOT bridge 8-tile gap")

	# Add a middle Wood Pole at x=8 -> spans are 4 + 4 (<= 5 tiles!)
	st.pole_tap(Vector2i(8, -14))
	_check(is_equal_approx(float(mart["runtime"]["power_ratio"]), 1.0), "Middle Wood Pole bridges 4+4 tile spans and powers Mart 100%")
	_check(st.power_network.overhead_spans.size() >= 3, "Overhead MST generated sagging wire spans (%d)" % st.power_network.overhead_spans.size())

	# Remove middle pole and replace x=4 pole with Steel Tower (9-tile span bridges x=4 to x=12 directly!)
	st.set_pole_erase(true)
	st.pole_tap(Vector2i(8, -14))
	st.pole_tap(Vector2i(4, -14))
	st.set_pole_kind(GameCatalog.PowerLineKind.STEEL_TOWER)
	st.pole_tap(Vector2i(4, -14))
	_check(is_equal_approx(float(mart["runtime"]["power_ratio"]), 1.0), "Steel Tower bridges 8-tile gap directly (9-tile span)")
	st.free()


func _test_underground_conduit_under_roads() -> void:
	print("\n[6] Underground Conduit Routing Under Roads")
	var st := _make_stage_state(4)
	var mart := _find_plot(st, "mart")
	mart["is_built"] = true
	mart["grid_x"] = 0
	mart["grid_z"] = -14
	# Lay a Paved road strip right between Mart and remote Windmill
	for gz in range(-18, -8):
		st.road_network.set_tile(Vector2i(5, gz), GameCatalog.RoadTier.PAVED)
		st.road_network.set_tile(Vector2i(6, gz), GameCatalog.RoadTier.PAVED)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, 10, -14, 0)
	_check(float(mart["runtime"]["power_ratio"]) < 0.9, "Windmill across road is isolated before laying conduit")

	# Paint underground conduit straight across the paved road from Mart (x=2) to Windmill (x=10)
	st.enter_conduit_mode(false)
	st.conduit_line_tap(Vector2i(2, -14))
	st.conduit_line_tap(Vector2i(10, -14))
	var ok := st.confirm_conduit_line()
	_check(ok, "Underground conduit line built cleanly under paved road")
	_check(st.world_grid.has_underground_power(Vector2i(5, -14)) and st.road_network.has_road(Vector2i(5, -14)), "Road and buried conduit coexist on same tile")
	_check(is_equal_approx(float(mart["runtime"]["power_ratio"]), 1.0), "Underground conduit delivers 100% power across the road")
	st.free()


func _test_full_city_power_and_save_roundtrip() -> void:
	print("\n[7] Full City Showcase Power Grid & v5 Save Roundtrip")
	var st := GameState.new()
	st._suppress_stage_fx = true
	st._init_world(GameCatalog.OutpostPreset.FULL_CITY)
	st._init_milestones()
	st.recompute_network()
	st.sim_clock.reset(1, 0.50, false, 1.0)
	st.power_network.step(1.0, st)

	_check(st.utilities.size() >= 4, "Full City boots with showcase power utilities (%d)" % st.utilities.size())
	_check(st.power_network.total_gen_kw >= 40.0, "Full City generates substantial daytime power (%.1f kW)" % st.power_network.total_gen_kw)
	_check(st.power_network.brownout_count == 0, "Full City boots with 0 brownouts during daytime")

	var mart := _find_plot(st, "mart")
	st.install_rooftop_solar(mart)
	var saved := SaveManager.save_to_disk(st, TEST_SAVE_PATH)
	_check(saved, "Full City with utilities + rooftop solar + wires saved cleanly")

	var st2 := GameState.new()
	st2._suppress_stage_fx = true
	st2._init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	st2._init_milestones()
	var loaded := SaveManager.load_from_disk(st2, TEST_SAVE_PATH, false)
	_check(loaded and st2.utilities.size() == st.utilities.size(), "v5 reload restores all power utilities")
	_check(st2.plot_has_rooftop_solar(_find_plot(st2, "mart")), "v5 reload restores rooftop solar addon")
	_check(st2.world_grid.power_poles.size() == st.world_grid.power_poles.size() and st2.world_grid.power_underground.size() == st.world_grid.power_underground.size(), "v5 reload restores all overhead poles and buried conduits")

	var abs_test := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(abs_test)
	st.free()
	st2.free()


func _test_3d_power_builders() -> void:
	print("\n[8] 3D PowerBuilder Meshes & Rooftop Solar")
	for uk in [GameCatalog.UtilityKind.WINDMILL, GameCatalog.UtilityKind.SOLAR_ARRAY, GameCatalog.UtilityKind.DIESEL_GEN, GameCatalog.UtilityKind.BATTERY_BANK]:
		var n := PowerBuilder.build_utility_node(uk, {"stored_kwh": 45.0})
		_check(n != null and n.get_child_count() > 0, "PowerBuilder builds UtilityKind %d mesh" % uk)
		if uk == GameCatalog.UtilityKind.WINDMILL:
			_check(n.get_node_or_null("Rotor") != null, "Windmill includes separate animated Rotor child node")
		n.free()

	var b := BuildingBuilder.build_plot_node(GameCatalog.BusinessType.GAS_STATION, 3, 0.0, null, true)
	_check(b != null, "BuildingBuilder mounts Rooftop Solar on Gas Station cleanly")
	b.free()
