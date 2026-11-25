class_name SupplyChainSim
extends RefCounted

## Outpost Supply Chain, Local Production (Oil -> Refinery -> Fuel, Greenhouse -> Food,
## Craft Workshop -> Crafts), Diesel Fuel Coupling, Store Inventory, Auto-Restock,
## Pricing Tiers, and Surplus Highway Exports.

const STOCKOUT_FLOOR := 0.35
const AUTO_RESTOCK_THRESHOLD := 0.30

var has_freight_depot: bool = false
var diesel_fuel_covered: bool = false
var export_income_per_min: float = 0.0
var low_stock_count: int = 0
var flow_links: Array[Dictionary] = [] # [{"from": Vector3, "to": Vector3, "commodity": int}]
var production_per_min: Dictionary = {} # Commodity -> float
var _runner_discount: float = 0.0


func clear() -> void:
	has_freight_depot = false
	diesel_fuel_covered = false
	export_income_per_min = 0.0
	low_stock_count = 0
	flow_links.clear()
	production_per_min.clear()
	_runner_discount = 0.0


func can_auto_restock_plot(p: Dictionary, state) -> bool:
	return has_freight_depot or state.plot_has_staff(p, "clerk")


func wholesale_discount() -> float:
	return clampf((0.20 if has_freight_depot else 0.0) + _runner_discount, 0.0, 0.45)


func restock_cost_for_plot(p: Dictionary) -> float:
	var btype: int = int(p["type"])
	var spec: Dictionary = GameCatalog.BUSINESSES[btype]
	var cid: int = int(spec.get("stock_commodity", GameCatalog.Commodity.NONE))
	if cid == GameCatalog.Commodity.NONE:
		return 0.0
	var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag(btype))
	var smax := float(rt.get("stock_max", float(spec.get("stock_capacity", 30.0))))
	var scur := float(rt.get("stock_units", smax))
	var missing := maxf(0.0, smax - scur)
	if missing <= 0.1:
		return 0.0
	var unit_cost := float(GameCatalog.commodity_spec(cid)["wholesale_unit_cost"])
	var raw := missing * unit_cost * (1.0 - wholesale_discount())
	return maxf(5.0, roundf(raw))


func order_restock(p: Dictionary, state, is_auto: bool = false) -> bool:
	if not p["is_built"]:
		return false
	var btype: int = int(p["type"])
	var cid: int = int(GameCatalog.BUSINESSES[btype].get("stock_commodity", GameCatalog.Commodity.NONE))
	if cid == GameCatalog.Commodity.NONE:
		return false
	var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag(btype))
	p["runtime"] = rt
	if bool(rt.get("restock_in_transit", false)):
		return false
	var cost := restock_cost_for_plot(p)
	if cost <= 0.0:
		return false
	if state.cash < cost:
		if not is_auto:
			state.notify_shortfall(state.plot_position(p), cost - state.cash)
		return false
	state.cash -= cost
	var dispatched: bool = state.traffic_sim.dispatch_delivery_truck(p)
	if dispatched:
		rt["restock_in_transit"] = true
		if not is_auto:
			state.float_notice(state.plot_position(p) + Vector3(0, 2.8, 0), "TRUCK DISPATCHED!", DesertPalette.NEON_TURQUOISE, 1.2)
	else:
		# Fallback if roads/parking are not connected yet
		complete_delivery_for_plot(str(p["id"]), state)
	state.hud_changed.emit()
	return true


func complete_delivery_for_plot(plot_id: String, state) -> void:
	for p in state.plots:
		if str(p["id"]) == plot_id and p["is_built"]:
			var btype: int = int(p["type"])
			var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag(btype))
			var smax := float(rt.get("stock_max", float(GameCatalog.BUSINESSES[btype].get("stock_capacity", 30.0))))
			rt["stock_units"] = smax
			rt["stock_ratio"] = 1.0
			rt["restock_in_transit"] = false
			p["runtime"] = rt
			p["bounce"] = maxf(float(p["bounce"]), 0.28)
			state.float_notice(state.plot_position(p) + Vector3(0, 2.7, 0), "+STOCK DELIVERED!", DesertPalette.EMERALD_POPUP, 1.35)
			state.hud_changed.emit()
			return


func step(dt_sim: float, state) -> void:
	has_freight_depot = false
	diesel_fuel_covered = false
	export_income_per_min = 0.0
	low_stock_count = 0
	flow_links.clear()
	production_per_min.clear()

	var diesel_count := 0
	var refineries: Array[Dictionary] = []
	var prod_nodes_by_cid: Dictionary = {} # Commodity -> Array[Vector3]
	var produced_units: Dictionary = {}    # Commodity -> float (this tick)
	var mins := dt_sim / 60.0
	var oil_crew_mult := float(state.staff_sim.oil_refinery_mult()) if state.staff_sim != null else 1.0
	var food_crew_mult := float(state.staff_sim.food_craft_prod_mult()) if state.staff_sim != null else 1.0
	_runner_discount = float(state.staff_sim.extra_wholesale_discount()) if state.staff_sim != null else 0.0

	# 1. Primary producers (Oil Pumpjack, Greenhouse, Craft Workshop, Freight Depot)
	for u in state.utilities:
		var ukind: int = int(u["kind"])
		var spec: Dictionary = GameCatalog.UTILITIES[ukind]
		if ukind == GameCatalog.UtilityKind.FREIGHT_DEPOT:
			has_freight_depot = true
			continue
		if ukind == GameCatalog.UtilityKind.DIESEL_GEN:
			diesel_count += 1
			continue
		if ukind == GameCatalog.UtilityKind.MINI_REFINERY:
			refineries.append(u)
			continue

		var cid: int = int(spec.get("produces", GameCatalog.Commodity.NONE))
		var rate := float(spec.get("prod_per_min", 0.0))
		if cid == GameCatalog.Commodity.NONE or rate <= 0.0:
			continue
		var p_eff := float(u.get("power_ratio", 1.0)) if float(spec.get("power_need_kw", 0.0)) > 0.0 else 1.0
		var w_eff := float(u.get("water_ratio", 1.0)) if float(spec.get("water_need", 0.0)) > 0.0 else 1.0
		var crew_m := oil_crew_mult if cid == GameCatalog.Commodity.CRUDE_OIL else food_crew_mult
		var live_rate := snappedf(rate * p_eff * w_eff * crew_m, 0.1)
		u["live_prod"] = live_rate
		production_per_min[cid] = float(production_per_min.get(cid, 0.0)) + live_rate
		produced_units[cid] = float(produced_units.get(cid, 0.0)) + live_rate * mins
		if not prod_nodes_by_cid.has(cid):
			prod_nodes_by_cid[cid] = []
		(prod_nodes_by_cid[cid] as Array).append(state.utility_position(u))

	# 2. Secondary refining: Mini Refinery converts Crude Oil -> Refined Fuel
	var crude_avail_rate := float(production_per_min.get(GameCatalog.Commodity.CRUDE_OIL, 0.0))
	var crude_used_rate := 0.0
	for ref_u in refineries:
		var spec: Dictionary = GameCatalog.UTILITIES[GameCatalog.UtilityKind.MINI_REFINERY]
		var p_eff := float(ref_u.get("power_ratio", 1.0))
		var w_eff := float(ref_u.get("water_ratio", 1.0))
		var max_consume := float(spec["consume_per_min"]) * p_eff * w_eff
		var avail_left := maxf(0.0, crude_avail_rate - crude_used_rate)
		var used := minf(max_consume, avail_left)
		var fuel_out := snappedf((used / maxf(0.1, float(spec["consume_per_min"]))) * float(spec["prod_per_min"]) * oil_crew_mult, 0.1)
		crude_used_rate += used
		ref_u["live_prod"] = fuel_out
		if fuel_out > 0.0:
			production_per_min[GameCatalog.Commodity.REFINED_FUEL] = float(production_per_min.get(GameCatalog.Commodity.REFINED_FUEL, 0.0)) + fuel_out
			produced_units[GameCatalog.Commodity.REFINED_FUEL] = float(produced_units.get(GameCatalog.Commodity.REFINED_FUEL, 0.0)) + fuel_out * mins
			if not prod_nodes_by_cid.has(GameCatalog.Commodity.REFINED_FUEL):
				prod_nodes_by_cid[GameCatalog.Commodity.REFINED_FUEL] = []
			var rpos: Vector3 = state.utility_position(ref_u)
			(prod_nodes_by_cid[GameCatalog.Commodity.REFINED_FUEL] as Array).append(rpos)
			for opos in prod_nodes_by_cid.get(GameCatalog.Commodity.CRUDE_OIL, []):
				flow_links.append({"from": opos, "to": rpos, "commodity": GameCatalog.Commodity.CRUDE_OIL})

	# 3. Diesel Generator Fuel Coupling (2.0 Refined Fuel/min per Diesel Gen cancels cash upkeep!)
	var fuel_rate := float(production_per_min.get(GameCatalog.Commodity.REFINED_FUEL, 0.0))
	var diesel_fuel_need := float(diesel_count) * 2.0
	var fuel_used_rate := 0.0
	if diesel_count > 0 and fuel_rate >= diesel_fuel_need and diesel_fuel_need > 0.0:
		diesel_fuel_covered = true
		fuel_used_rate = diesel_fuel_need
		produced_units[GameCatalog.Commodity.REFINED_FUEL] = maxf(0.0, float(produced_units.get(GameCatalog.Commodity.REFINED_FUEL, 0.0)) - diesel_fuel_need * mins)

	# 4. Store shelf burn, local free restock, auto-restock & efficiency update
	var fuel_store_burn_rate := 0.0
	for p in state.plots:
		if not p["is_built"]:
			continue
		var btype: int = int(p["type"])
		var spec: Dictionary = GameCatalog.BUSINESSES[btype]
		var cid: int = int(spec.get("stock_commodity", GameCatalog.Commodity.NONE))
		var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag(btype))
		p["runtime"] = rt

		if cid == GameCatalog.Commodity.NONE:
			rt["stock_ratio"] = 1.0
			continue

		var cap := float(spec.get("stock_capacity", 30.0)) * (1.0 + float(maxi(0, int(p["level"]) - 1)) * 0.25)
		if not rt.has("stock_max") or float(rt["stock_max"]) <= 0.0:
			rt["stock_units"] = cap
		rt["stock_max"] = cap
		var units := clampf(float(rt.get("stock_units", cap)), 0.0, cap)

		# Feed from local production first (free!)
		var local_avail := float(produced_units.get(cid, 0.0))
		if float(production_per_min.get(cid, 0.0)) > 0.0:
			var ppos: Vector3 = state.plot_position(p)
			for src_pos in prod_nodes_by_cid.get(cid, []):
				flow_links.append({"from": src_pos, "to": ppos, "commodity": cid})
		if local_avail > 0.0 and units < cap:
			var room := cap - units
			var add := minf(room, local_avail)
			units += add
			produced_units[cid] = local_avail - add
			if cid == GameCatalog.Commodity.REFINED_FUEL and mins > 0.0:
				fuel_store_burn_rate += add / mins

		# Burn stock proportionally when operating
		var connected := float(p["access"]["score"]) > 0.0
		var tier := int(rt.get("price_tier", GameCatalog.PriceTier.FAIR))
		var burn_mult := float(GameCatalog.price_tier_spec(tier)["burn_mult"])
		var staff_burn_m := float(state.staff_sim.plot_stock_burn_mult(p, state)) if state.staff_sim != null else 1.0
		var burn_rate := float(spec.get("stock_burn_per_min", 4.0)) * (1.0 + float(maxi(0, int(p["level"]) - 1)) * 0.20) * burn_mult * staff_burn_m
		if connected and dt_sim > 0.0:
			if btype == GameCatalog.BusinessType.VENDOR_STALL and state.outpost_stage() <= 1:
				# Stage 1 career cart stays smoothly stocked so onboarding has zero friction
				units = maxf(units, cap * 0.65)
			else:
				units = maxf(0.0, units - burn_rate * mins)

		rt["stock_units"] = units
		var frac := clampf(units / maxf(1.0, cap), 0.0, 1.0)
		rt["stock_ratio"] = 1.0 if frac >= 0.15 else lerpf(STOCKOUT_FLOOR, 1.0, frac / 0.15)
		if frac < 0.25:
			low_stock_count += 1

		# Auto-restock trigger
		if bool(rt.get("auto_restock", false)) and can_auto_restock_plot(p, state) and frac < AUTO_RESTOCK_THRESHOLD and not bool(rt.get("restock_in_transit", false)) and dt_sim > 0.0:
			order_restock(p, state, true)

	# 5. Export surplus Crude Oil & Refined Fuel for wholesale highway revenue
	var surplus_crude_rate := maxf(0.0, crude_avail_rate - crude_used_rate)
	var surplus_fuel_rate := maxf(0.0, fuel_rate - fuel_used_rate - fuel_store_burn_rate)
	export_income_per_min = snappedf(
		surplus_crude_rate * float(GameCatalog.commodity_spec(GameCatalog.Commodity.CRUDE_OIL)["export_value_per_unit"])
		+ surplus_fuel_rate * float(GameCatalog.commodity_spec(GameCatalog.Commodity.REFINED_FUEL)["export_value_per_unit"]),
		0.1
	)
	if export_income_per_min > 0.0 and dt_sim > 0.0:
		var exp_cash := (export_income_per_min / 60.0) * dt_sim
		state.cash += exp_cash
		state.total_cash_earned += exp_cash
