extends SceneTree

## Headless verification suite for Desert Outpost Phase 2 (Supply Chains, Oil, Water & Inventory).

const TEST_SAVE_PATH := "user://desert_outpost_phase2_test.json"

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
	print("=== Desert Outpost Phase 2 Headless Verification ===")
	_test_oil_seep_requirement_and_power_interlock()
	_test_water_aquifer_and_pipes_under_roads()
	_test_oil_refinery_fuel_and_diesel_coupling()
	_test_greenhouse_stock_burn_and_pricing()
	_test_delivery_truck_restock_and_auto_restock()
	_test_full_city_and_save_roundtrip()
	_test_3d_supply_builders_and_delivery_truck()

	print("=== Summary: %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _make_stage_state(stage: int = 5) -> GameState:
	var st := GameState.new()
	st._suppress_stage_fx = true
	st._init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	st._init_milestones()
	st.set_highest_stage_raw(stage)
	st.cash = 8000.0
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


func _test_oil_seep_requirement_and_power_interlock() -> void:
	print("\n[1] Oil Seep Parcel Requirement & Power Interlock")
	var st := _make_stage_state(5)
	# Standard sand parcel (3,5) -> x=-4, z=-14 should REJECT Oil Pumpjack
	var bad_place := st.place_utility_at(GameCatalog.UtilityKind.OIL_PUMPJACK, -4, -14, 0)
	_check(not bad_place, "Oil Pumpjack rejected on standard desert sand")

	# Oil Seep parcel (1,5) -> x=-20, z=-14 should ACCEPT Oil Pumpjack
	var ok_place := st.place_utility_at(GameCatalog.UtilityKind.OIL_PUMPJACK, -20, -14, 0)
	_check(ok_place, "Oil Pumpjack accepted on Oil Seep parcel (1,5)")
	var pump := st.utilities[0]
	var unpowered_prod := float(pump["live_prod"])
	_check(unpowered_prod < 10.0, "Unpowered Oil Pumpjack runs at brownout output (%.1f/min)" % unpowered_prod)
	_check(st.supply_sim.export_income_per_min > 0.0, "Crude Oil auto-exports at Stage 3+ for +$%.1f/min" % st.supply_sim.export_income_per_min)

	# Place Windmill beside Oil Pumpjack -> full 12.0 Crude/min!
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, -17, -14, 0)
	var powered_prod := float(pump["live_prod"])
	_check(is_equal_approx(powered_prod, 12.0), "Powered Oil Pumpjack outputs full 12.0 Crude/min (got %.1f)" % powered_prod)
	st.free()


func _test_water_aquifer_and_pipes_under_roads() -> void:
	print("\n[2] Water Well Aquifer Bonus & Underground Pipes Under Roads")
	var st := _make_stage_state(5)
	var motel := _find_plot(st, "motel")
	motel["is_built"] = true
	motel["grid_x"] = 2
	motel["grid_z"] = -8
	st.recompute_network()
	_check(is_equal_approx(float(motel["runtime"]["water_ratio"]), WaterNetwork.DRY_FLOOR), "Dry Motel hits forgiving 70%% water floor (got %.2f)" % float(motel["runtime"]["water_ratio"]))

	# Lay a paved road between Motel and Aquifer parcel (5,6) [x=8..15, z=-10..-3]
	for gz in range(-12, -2):
		st.road_network.set_tile(Vector2i(7, gz), GameCatalog.RoadTier.PAVED)
		st.road_network.set_tile(Vector2i(8, gz), GameCatalog.RoadTier.PAVED)
	# Place Water Well on Aquifer parcel (5,6) at (11, -8) + Windmill beside it for power
	st.place_utility_at(GameCatalog.UtilityKind.WATER_WELL, 11, -8, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, 14, -8, 0)
	var well_out := WaterNetwork.water_output_for_utility(st.utilities[0], st.world_grid)
	_check(is_equal_approx(well_out, 18.0), "Powered Aquifer Water Well produces 18.0 Water (+80%% bonus, got %.1f)" % well_out)

	# Lay underground water pipes straight under the paved road from Motel (x=5) to Well (x=11)
	st.enter_water_pipe_mode(false)
	st.water_pipe_line_tap(Vector2i(5, -8))
	st.water_pipe_line_tap(Vector2i(11, -8))
	var ok := st.confirm_water_pipe_line()
	_check(ok and st.world_grid.has_water_pipe(Vector2i(7, -8)) and st.road_network.has_road(Vector2i(7, -8)), "Water pipes run cleanly under paved road")
	_check(is_equal_approx(float(motel["runtime"]["water_ratio"]), 1.0), "Piped Aquifer water brings Motel to 100% water")
	st.free()


func _test_oil_refinery_fuel_and_diesel_coupling() -> void:
	print("\n[3] Oil -> Mini Refinery -> Gas Station & Free Diesel Coupling")
	var st := _make_stage_state(5)
	var gas := _find_plot(st, "gas_station")
	gas["is_built"] = true
	gas["grid_x"] = 0
	gas["grid_z"] = -14
	gas["runtime"]["stock_units"] = 40.0 # half full

	# Build Oil Pumpjack on Oil Seep (1,5), Mini Refinery, Water Well, and Diesel Gen + Windmill
	st.place_utility_at(GameCatalog.UtilityKind.OIL_PUMPJACK, -20, -14, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, -17, -14, 0)
	st.place_utility_at(GameCatalog.UtilityKind.MINI_REFINERY, -12, -14, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WATER_WELL, -9, -14, 0)
	st.place_utility_at(GameCatalog.UtilityKind.DIESEL_GEN, -12, -11, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, -9, -11, 0)
	st.recompute_network()

	var cash_before := st.cash
	for _i in range(10):
		st._on_sim_tick(1.0)
	_check(st.supply_sim.diesel_fuel_covered, "Refined Fuel cancels Diesel Generator cash upkeep")
	_check(float(st.supply_sim.production_per_min.get(GameCatalog.Commodity.REFINED_FUEL, 0.0)) >= 13.0, "Mini Refinery produces 14.0 Refined Fuel/min")
	_check(float(gas["runtime"]["stock_units"]) > 40.0, "Mini Refinery feeds Gas Station fuel stock for free (40.0 -> %.1f)" % float(gas["runtime"]["stock_units"]))
	_check(st.cash >= cash_before, "Surplus Refined Fuel generates positive export revenue")
	st.free()


func _test_greenhouse_stock_burn_and_pricing() -> void:
	print("\n[4] Greenhouse Local Food, Stockout Floor & 3-Tier Pricing")
	var st := _make_stage_state(5)
	# Connect road & parking so Diner earns & burns stock
	for gz in range(-14, OutpostLayout.HIGHWAY_ENTRY_ROW_Z + 1):
		st.road_network.set_tile(Vector2i(0, gz), GameCatalog.RoadTier.PAVED)
		st.road_network.set_tile(Vector2i(1, gz), GameCatalog.RoadTier.PAVED)
	st.place_parking_lot_at(GameCatalog.ParkingLotKind.DIRT_PULL_OFF, 2, -10, 1)
	var diner := _find_plot(st, "diner")
	diner["is_built"] = true
	diner["grid_x"] = 2
	diner["grid_z"] = -15
	st.place_utility_at(GameCatalog.UtilityKind.DIESEL_GEN, 6, -15, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WATER_WELL, 6, -12, 0)
	st.recompute_network()

	# Compare pricing tiers
	st.set_plot_price_tier(diner, GameCatalog.PriceTier.FAIR)
	var fair_inc := st.plot_income_per_minute(diner)
	st.set_plot_price_tier(diner, GameCatalog.PriceTier.MARKUP)
	var markup_inc := st.plot_income_per_minute(diner)
	_check(markup_inc > fair_inc, "MARKUP pricing raises income/min ($%.0f -> $%.0f)" % [fair_inc, markup_inc])

	# Empty stock hits forgiving 35% stockout floor
	diner["runtime"]["stock_units"] = 0.0
	st.supply_sim.step(1.0, st)
	_check(is_equal_approx(float(diner["runtime"]["stock_ratio"]), SupplyChainSim.STOCKOUT_FLOOR), "Empty Diner hits forgiving 35%% stockout floor (got %.2f)" % float(diner["runtime"]["stock_ratio"]))

	# Add Desert Greenhouse -> automatically refills Diner fresh food!
	st.place_utility_at(GameCatalog.UtilityKind.DESERT_GREENHOUSE, 8, -14, 0)
	st.place_utility_at(GameCatalog.UtilityKind.WINDMILL, 9, -11, 0)
	for _i in range(20):
		st._on_sim_tick(1.0)
	_check(float(diner["runtime"]["stock_units"]) > 0.0, "Desert Greenhouse feeds Diner fresh food locally (stock=%.1f)" % float(diner["runtime"]["stock_units"]))
	st.free()


func _test_delivery_truck_restock_and_auto_restock() -> void:
	print("\n[5] Route 163 Delivery Truck Restock & Auto-Restock")
	var st := _make_stage_state(5)
	for gz in range(-14, OutpostLayout.HIGHWAY_ENTRY_ROW_Z + 1):
		st.road_network.set_tile(Vector2i(0, gz), GameCatalog.RoadTier.PAVED)
		st.road_network.set_tile(Vector2i(1, gz), GameCatalog.RoadTier.PAVED)
	st.place_parking_lot_at(GameCatalog.ParkingLotKind.DIRT_PULL_OFF, 2, -10, 1)
	var mart := _find_plot(st, "mart")
	mart["is_built"] = true
	mart["grid_x"] = 2
	mart["grid_z"] = -14
	st.recompute_network()

	mart["runtime"]["stock_units"] = 10.0
	var ordered := st.order_restock_for_plot(mart)
	_check(ordered and bool(mart["runtime"]["restock_in_transit"]), "Manual restock dispatches Delivery Truck")
	var has_truck := false
	for v in st.vehicles:
		if int(v["kind"]) == GameCatalog.VehicleKind.DELIVERY_TRUCK:
			has_truck = true
			break
	_check(has_truck, "DELIVERY_TRUCK entity spawned on Route 163")

	# Simulate delivery arrival
	st.supply_sim.complete_delivery_for_plot("mart", st)
	_check(is_equal_approx(float(mart["runtime"]["stock_units"]), float(mart["runtime"]["stock_max"])) and not bool(mart["runtime"]["restock_in_transit"]), "Delivery arrival refills Mart shelves to 100%")

	# Build Freight Depot -> unlocks Auto-Restock & 20% wholesale discount
	var cost_before := st.supply_sim.restock_cost_for_plot(mart)
	mart["runtime"]["stock_units"] = 10.0
	cost_before = st.supply_sim.restock_cost_for_plot(mart)
	st.place_utility_at(GameCatalog.UtilityKind.FREIGHT_DEPOT, 6, -10, 0)
	var cost_after := st.supply_sim.restock_cost_for_plot(mart)
	_check(cost_after < cost_before, "Freight Depot grants 20%% wholesale discount ($%.0f -> $%.0f)" % [cost_before, cost_after])
	_check(st.toggle_auto_restock_for_plot(mart) and bool(mart["runtime"]["auto_restock"]), "Freight Depot unlocks Auto-Restock toggle")
	st.free()


func _test_full_city_and_save_roundtrip() -> void:
	print("\n[6] Full City Interconnected Economy & v5 Save Roundtrip")
	var st := GameState.new()
	st._suppress_stage_fx = true
	st._init_world(GameCatalog.OutpostPreset.FULL_CITY)
	st._init_milestones()
	st.recompute_network()
	st.sim_clock.reset(1, 0.50, false, 1.0)
	st._on_sim_tick(1.0)

	_check(st.power_network.brownout_count == 0, "Full City has 0 power brownouts with full supply chain")
	_check(st.water_network.dry_count == 0, "Full City has 0 dry buildings (water=%.1f/%.1f)" % [st.water_network.total_supply, st.water_network.total_demand])
	_check(st.supply_sim.has_freight_depot and st.supply_sim.diesel_fuel_covered, "Full City runs Freight Depot + Refinery-fueled Diesel Gen")
	_check(st.supply_sim.flow_links.size() >= 3, "Supply flow links computed for SUP lens (%d links)" % st.supply_sim.flow_links.size())

	var mart := _find_plot(st, "mart")
	st.set_plot_price_tier(mart, GameCatalog.PriceTier.MARKUP)
	st.toggle_auto_restock_for_plot(mart)
	mart["runtime"]["stock_units"] = 22.0

	var saved := SaveManager.save_to_disk(st, TEST_SAVE_PATH)
	_check(saved, "Full City Phase 2 state saved cleanly")
	var st2 := GameState.new()
	st2._suppress_stage_fx = true
	st2._init_world(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
	st2._init_milestones()
	var loaded := SaveManager.load_from_disk(st2, TEST_SAVE_PATH, false)
	var mart2 := _find_plot(st2, "mart")
	_check(loaded and int(mart2["runtime"]["price_tier"]) == GameCatalog.PriceTier.MARKUP, "v5 reload preserves store price tier")
	_check(bool(mart2["runtime"]["auto_restock"]) and is_equal_approx(float(mart2["runtime"]["stock_units"]), 22.0), "v5 reload preserves stock units & auto-restock")
	_check(st2.world_grid.water_pipes.size() == st.world_grid.water_pipes.size(), "v5 reload preserves all underground water pipes")

	var abs_test := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(abs_test)
	st.free()
	st2.free()


func _test_3d_supply_builders_and_delivery_truck() -> void:
	print("\n[7] 3D SupplyBuilder Models & Delivery Truck Mesh")
	for uk in [
		GameCatalog.UtilityKind.WATER_WELL,
		GameCatalog.UtilityKind.WATER_TOWER,
		GameCatalog.UtilityKind.FREIGHT_DEPOT,
		GameCatalog.UtilityKind.OIL_PUMPJACK,
		GameCatalog.UtilityKind.MINI_REFINERY,
		GameCatalog.UtilityKind.DESERT_GREENHOUSE,
		GameCatalog.UtilityKind.CRAFT_WORKSHOP,
	]:
		var n := PowerBuilder.build_utility_node(uk)
		_check(n != null and n.get_child_count() > 0, "SupplyBuilder builds UtilityKind %d mesh" % uk)
		if uk == GameCatalog.UtilityKind.OIL_PUMPJACK:
			_check(n.get_node_or_null("Beam") != null, "Oil Pumpjack includes animated Beam child node")
		n.free()

	var truck := EntityBuilder.build_vehicle_node(GameCatalog.VehicleKind.DELIVERY_TRUCK, DesertPalette.TERRACOTTA, true, false)
	_check(truck != null, "EntityBuilder builds DELIVERY_TRUCK mesh cleanly")
	truck.free()
