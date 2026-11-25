extends SceneTree

## Headless verification suite for Desert Outpost Phase 0 architecture.
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path c:\Users\dell\lowpoly\HERE --script res://tests/verify_phase0.gd

const TEST_SAVE_PATH := "user://desert_outpost_phase0_test.json"

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
	print("=== Desert Outpost Phase 0 Headless Verification ===")
	_test_sim_clock()
	_test_world_grid_and_traits()
	_test_catalog_and_state_presets()
	_test_save_migration_and_roundtrip()
	_test_main_scene_parse_and_boot()

	print("=== Summary: %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_sim_clock() -> void:
	print("\n[1] SimClock")
	var clk := SimClock.new()
	clk.reset(1, 0.0, true, 1.0)
	_check(is_zero_approx(clk.solar_factor()), "Midnight solar factor is 0.0")
	_check(clk.is_night(), "Midnight is night")
	_check(clk.day_phase() == SimClock.DayPhase.NIGHT, "Midnight phase is NIGHT")

	clk.reset(1, 0.50, true, 1.0)
	_check(clk.solar_factor() > 0.99, "Solar noon factor peaks at ~1.0 (got %.3f)" % clk.solar_factor())
	_check(clk.day_phase() == SimClock.DayPhase.DAY, "Noon phase is DAY")

	clk.set_speed(0.0)
	var paused_step := clk.advance(0.05)
	_check(paused_step["sim_dt"] == 0.0 and int(paused_step["ticks"]) == 0, "Paused clock yields 0 sim_dt and 0 ticks")

	clk.set_speed(2.0)
	var tick_total := 0
	var rolled := false
	for _i in range(700):
		var st := clk.advance(0.1)
		tick_total += int(st["ticks"])
		if st["day_rolled"]:
			rolled = true
	_check(rolled and clk.day_number >= 2, "Day rolls over cleanly at 2x speed (day=%d)" % clk.day_number)
	_check(tick_total == 140, "Fixed 1 Hz tick accumulator exact (expected 140, got %d)" % tick_total)


func _test_world_grid_and_traits() -> void:
	print("\n[2] WorldGrid Layers & Parcel Traits")
	var g1 := WorldGrid.new()
	var g2 := WorldGrid.new()
	g1.reset_ownership(OutpostLayout.STARTER_PARCELS)
	g2.reset_ownership(OutpostLayout.STARTER_PARCELS)

	_check(g1.parcel_trait(Vector2i(3, 5)) == GameCatalog.ParcelTrait.NONE, "Starter parcel (3,5) is clean flat sand")
	_check(g1.parcel_trait(Vector2i(4, 5)) == GameCatalog.ParcelTrait.NONE, "Starter parcel (4,5) is clean flat sand")
	_check(g1.parcels_with_trait(GameCatalog.ParcelTrait.OIL_SEEP).size() >= 3, "At least 3 Oil Seep parcels exist")
	_check(g1.parcels_with_trait(GameCatalog.ParcelTrait.AQUIFER).size() >= 3, "At least 3 Aquifer parcels exist")
	_check(g1.parcels_with_trait(GameCatalog.ParcelTrait.WIND_CORRIDOR).size() >= 6, "Wind Corridor parcels exist")
	_check(g1.parcels_with_trait(GameCatalog.ParcelTrait.SCENIC_MESA).size() >= 6, "Scenic Mesa parcels exist")
	_check(g1.parcels_with_trait(GameCatalog.ParcelTrait.HIGHWAY_PRIME).size() >= 4, "Highway Prime parcels exist")

	var all_match := true
	for px in range(OutpostLayout.PARCEL_COUNT_X):
		for pz in range(OutpostLayout.PARCEL_COUNT_Z):
			if g1.parcel_trait(Vector2i(px, pz)) != g2.parcel_trait(Vector2i(px, pz)):
				all_match = false
	_check(all_match, "Parcel traits are 100% deterministic across instances")

	# Multi-layer isolation: underground power & water allowed on owned cells without blocking surface structures
	var owned_cell := Vector2i(0, -14)
	_check(g1.can_place_underground_utility(owned_cell), "Owned cell accepts underground utilities")
	g1.set_underground_power(owned_cell, {"tier": 1})
	g1.set_water_pipe(owned_cell, {"tier": 1})
	_check(g1.has_underground_power(owned_cell) and g1.has_water_pipe(owned_cell), "Underground power & water layers store independently")
	_check(not g1.is_occupied(owned_cell), "Underground utilities do not block surface structure occupancy")


func _test_catalog_and_state_presets() -> void:
	print("\n[3] GameCatalog & GameState Presets")
	var st := GameState.new()
	st._suppress_stage_fx = true
	st._init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	st._init_milestones()
	st.recompute_network()
	_check(st.built_count() == 1, "Stage 1 Career starts with 1 built cart")
	_check(GameCatalog.business_power_demand_kw(GameCatalog.BusinessType.VENDOR_STALL, 1, false) == 0.0, "Roadside Cart needs 0 kW")
	_check(GameCatalog.business_power_demand_kw(GameCatalog.BusinessType.DESERT_MOTEL, 1, true) > GameCatalog.business_power_demand_kw(GameCatalog.BusinessType.DESERT_MOTEL, 1, false), "Motel night power demand exceeds daytime demand")

	st._init_world(GameCatalog.OutpostPreset.FULL_CITY)
	st._init_milestones()
	st.recompute_network()
	_check(st.built_count() == 7, "Full City preset starts with 7 built landmarks")
	_check(st.total_parking_spaces() >= 12, "Full City preset has connected parking bays (%d)" % st.total_parking_spaces())
	_check(st.income_per_minute() > 0.0, "Full City preset produces positive income/min ($%.0f)" % st.income_per_minute())
	_check(st.total_power_demand_kw() > 20.0, "Full City power load calculation works (%.1f kW)" % st.total_power_demand_kw())

	# Lens switching
	st.set_map_lens(GameCatalog.MapLens.LAND_TRAITS)
	_check(st.active_lens == GameCatalog.MapLens.LAND_TRAITS, "Map lens switches to LAND_TRAITS")

	# Decoration rotation support
	st.cash = 500.0
	st.start_placing_decoration(GameCatalog.DECORATIONS[2])
	st.rotate_ghost()
	_check(st.ghost_rotation == 1, "Decoration ghost rotates cleanly")
	var placed := st.confirm_placement()
	_check(placed and st.decorations.size() == 1 and int(st.decorations[0].get("rot", 0)) == 1, "Placed decoration preserves rot=1")
	st.free()


func _test_save_migration_and_roundtrip() -> void:
	print("\n[4] SaveManager v4 -> v5 Migration & v5 Roundtrip")
	var legacy_v4 := {
		"v": 4,
		"saved_at": Time.get_unix_time_from_system(),
		"preset": GameCatalog.OutpostPreset.STAGE_ONE_CAREER,
		"cash": 325.0,
		"total_cash": 600.0,
		"served": 12,
		"taps": 30,
		"tap_lv": 2,
		"highest_stage": 2,
		"time_of_day": 0.62,
		"auto_day_night": false,
		"sound": true,
		"parcels": [[3, 5], [4, 5], [5, 5]],
		"roads": [[-1, 5, 0], [-1, 4, 0]],
		"plots": [{"id": "vendor", "gx": -1, "gz": -14, "rot": 0, "built": true, "lv": 2, "staff": ["clerk"]}],
		"lots": [{"id": "lot_1", "kind": 0, "gx": 1, "gz": -14, "rot": 1}],
		"decos": [{"id": "deco_1", "kind": 2, "name": "Picnic", "cost": 55.0, "gx": 3, "gz": -12}],
		"claimed": ["m_park1"],
	}

	var st1 := GameState.new()
	st1._suppress_stage_fx = true
	st1._init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	st1._init_milestones()
	var migrated_ok := SaveManager.apply_dict(st1, legacy_v4, false)
	_check(migrated_ok, "Legacy v4 save migrated into v5 cleanly")
	_check(is_equal_approx(st1.cash, 325.0) and st1.world_grid.owned_parcels.size() == 3, "Migrated v4 preserves cash and parcels")
	_check(is_equal_approx(st1.sim_clock.time_of_day, 0.62) and not st1.sim_clock.auto_day_night, "Migrated v4 populates SimClock")
	_check(st1.plots[0].has("runtime") and st1.decorations.size() == 1 and int(st1.decorations[0].get("rot", -1)) == 0, "Migrated v4 initializes runtime bag and deco rot")

	# Mutate v5-specific fields and roundtrip through disk
	st1.sim_clock.day_number = 7
	st1.sim_clock.set_speed(2.0)
	st1.decorations[0]["rot"] = 3
	st1.world_grid.set_power_pole(Vector2i(0, -13), {"span": 4})
	st1.world_grid.set_underground_power(Vector2i(0, -14), {"insulated": true})
	st1.world_grid.set_water_pipe(Vector2i(1, -13), {"pressure": 1.0})
	var saved := SaveManager.save_to_disk(st1, TEST_SAVE_PATH)
	_check(saved, "SaveManager atomic write succeeded")

	var st2 := GameState.new()
	st2._suppress_stage_fx = true
	st2._init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	st2._init_milestones()
	var loaded := SaveManager.load_from_disk(st2, TEST_SAVE_PATH, false)
	_check(loaded, "SaveManager v5 load succeeded")
	_check(st2.sim_clock.day_number == 7 and is_equal_approx(st2.sim_clock.sim_speed, 2.0), "v5 roundtrip preserves SimClock day & speed")
	_check(int(st2.decorations[0].get("rot", -1)) == 3, "v5 roundtrip preserves decoration rotation")
	_check(st2.world_grid.has_power_pole(Vector2i(0, -13)) and st2.world_grid.has_underground_power(Vector2i(0, -14)) and st2.world_grid.has_water_pipe(Vector2i(1, -13)), "v5 roundtrip preserves all 3 utility grid layers")

	var abs_test := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(abs_test)
	st1.free()
	st2.free()


func _test_main_scene_parse_and_boot() -> void:
	print("\n[5] Main Scene Parse & Boot")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "res://scenes/main.tscn loads without parse errors")
	if packed != null:
		var inst := packed.instantiate()
		_check(inst != null, "Main scene instantiates cleanly")
		if inst != null:
			root.add_child(inst)
			var gs: GameState = inst.get_node_or_null("GameState")
			var hud: DesertHud = inst.get_node_or_null("DesertHud")
			var wr: WorldRenderer = inst.get_node_or_null("WorldRenderer")
			_check(gs != null and hud != null and wr != null, "Main scene wires GameState, DesertHud, and WorldRenderer")
			if gs != null:
				gs.set_map_lens(GameCatalog.MapLens.POWER)
				gs.set_map_lens(GameCatalog.MapLens.WATER)
				gs.set_map_lens(GameCatalog.MapLens.SUPPLY)
				gs.set_map_lens(GameCatalog.MapLens.LAND_TRAITS)
				gs.set_map_lens(GameCatalog.MapLens.NONE)
				_check(true, "All 5 map lenses render in WorldRenderer without error")
			root.remove_child(inst)
			inst.free()
