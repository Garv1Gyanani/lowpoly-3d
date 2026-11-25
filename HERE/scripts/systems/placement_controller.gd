class_name PlacementController
extends RefCounted

## Tool modes, road corridor painting, land buying, freeform placement,
## footprint validation, hold-to-move dragging, and smart spot finding.

var state


func _init(game_state) -> void:
	state = game_state


func cancel_tool_mode(emit_sig: bool = true) -> void:
	var was_relocating: bool = not state.relocating_plot_id.is_empty() or not state.relocating_lot_id.is_empty() or not state.relocating_deco_id.is_empty() or not state.relocating_utility_id.is_empty()
	var was_lens_tool: bool = state.tool_mode == GameCatalog.WorldToolMode.PLACE_UTILITY or state.tool_mode == GameCatalog.WorldToolMode.PLACE_POWER_POLE or state.tool_mode == GameCatalog.WorldToolMode.PAINT_CONDUIT or state.tool_mode == GameCatalog.WorldToolMode.PAINT_WATER_PIPE
	state.tool_mode = GameCatalog.WorldToolMode.PLAY
	state.road_erase_mode = false
	state.has_road_start = false
	state.pending_building_type = -1
	state.relocating_plot_id = ""
	state.pending_parking_kind = -1
	state.relocating_lot_id = ""
	state.relocating_lot_is_upgrade = false
	state.pending_deco = {}
	state.relocating_deco_id = ""
	state.pending_utility_kind = -1
	state.relocating_utility_id = ""
	state.pole_erase_mode = false
	state.conduit_erase_mode = false
	state.has_conduit_start = false
	state.water_pipe_erase_mode = false
	state.has_water_pipe_start = false
	state.is_hold_dragging = false
	state.selected_plot_id = ""
	state.selected_entity_id = ""
	if was_lens_tool and state._prev_lens_before_tool >= 0:
		state.active_lens = state._prev_lens_before_tool
		state._prev_lens_before_tool = -1
	if emit_sig:
		if was_relocating:
			state.world_layout_changed.emit()
		else:
			state.overlay_changed.emit()
		state.hud_changed.emit()


func enter_road_mode(tier: int = -1, erase: bool = false) -> void:
	cancel_tool_mode(false)
	state.tool_mode = GameCatalog.WorldToolMode.PAINT_ROAD
	state.road_erase_mode = erase
	if tier >= 0 and state.is_road_tier_unlocked(tier):
		state.active_road_tier = tier
	elif not state.is_road_tier_unlocked(state.active_road_tier):
		state.active_road_tier = GameCatalog.RoadTier.DIRT
	if state.camera_ref != null:
		state.camera_ref.ensure_min_pitch(0.78)
	state.overlay_changed.emit()
	state.hud_changed.emit()


func set_road_brush(tier: int) -> void:
	if not state.is_road_tier_unlocked(tier):
		return
	state.active_road_tier = tier
	state.road_erase_mode = false
	state.overlay_changed.emit()
	state.hud_changed.emit()


func set_road_two_lane(enabled: bool) -> void:
	state.road_two_lane = enabled
	state.overlay_changed.emit()
	state.hud_changed.emit()


func set_road_erase(erase: bool) -> void:
	state.road_erase_mode = erase
	state.overlay_changed.emit()
	state.hud_changed.emit()


func road_line_tap(cell: Vector2i) -> void:
	if not state.has_road_start:
		state.has_road_start = true
		state.road_line_start = cell
		state.road_line_end = cell
	else:
		state.road_line_end = cell
	state.overlay_changed.emit()
	state.hud_changed.emit()


func clear_road_line() -> void:
	state.has_road_start = false
	state.overlay_changed.emit()
	state.hud_changed.emit()


func compute_road_line_preview() -> Dictionary:
	if state.tool_mode != GameCatalog.WorldToolMode.PAINT_ROAD or not state.has_road_start:
		return {"cells": [], "spine": [], "build": [], "skip": [], "blocked": [], "cost": 0.0, "reason": ""}
	var spine := RoadNetwork.line_path(state.road_line_start, state.road_line_end)
	var cells := RoadNetwork.corridor_path(state.road_line_start, state.road_line_end, state.world_grid, state.road_two_lane)
	var build: Array[Vector2i] = []
	var skip: Array[Vector2i] = []
	var blocked: Array[Vector2i] = []
	var cost := 0.0
	var reason := ""
	if state.road_erase_mode:
		for c in cells:
			var t: int = state.road_network.tile_tier(c)
			if t < 0:
				skip.append(c)
			else:
				build.append(c)
				cost -= round(float(GameCatalog.ROAD_TIERS[t]["cost_per_tile"]) * 0.5)
		if build.is_empty():
			reason = "No road tiles on this line"
		return {"cells": cells, "spine": spine, "build": build, "skip": skip, "blocked": blocked, "cost": cost, "reason": reason}

	var target_cost: float = GameCatalog.ROAD_TIERS[state.active_road_tier]["cost_per_tile"]
	for c in cells:
		if not OutpostLayout.is_cell_in_map(c.x, c.y):
			blocked.append(c)
			if reason.is_empty():
				reason = "Outside the desert map"
			continue
		if state.world_grid.is_occupied(c):
			blocked.append(c)
			if reason.is_empty():
				reason = "Blocked by a building, lot or prop"
			continue
		var ex: int = state.road_network.tile_tier(c)
		if ex >= state.active_road_tier:
			skip.append(c)
			continue
		var prev_c := float(GameCatalog.ROAD_TIERS[ex]["cost_per_tile"]) if ex >= 0 else 0.0
		build.append(c)
		cost += maxf(2.0, target_cost - prev_c)

	var cur_j: int = state.road_network.highway_turn_off_count()
	var nxt_j: int = state.road_network.highway_turn_off_count_with(build)
	if nxt_j > cur_j and nxt_j > int(state.stage_info()["max_highway_turn_offs"]):
		if reason.is_empty():
			reason = "Stage %d allows %d highway junction(s)" % [state.outpost_stage(), int(state.stage_info()["max_highway_turn_offs"])]
	if build.is_empty() and reason.is_empty():
		reason = "Already built at this tier"
	return {"cells": cells, "spine": spine, "build": build, "skip": skip, "blocked": blocked, "cost": cost, "reason": reason}


func confirm_road_line() -> bool:
	var prev := compute_road_line_preview()
	var build: Array = prev["build"]
	if not str(prev["reason"]).is_empty() or build.is_empty():
		return false
	var park_before: int = state.total_parking_spaces()
	var cost: float = prev["cost"]
	if state.road_erase_mode:
		for c in build:
			state.road_network.remove_tile(c)
		state.cash += -cost
	else:
		if state.cash < cost:
			state.notify_shortfall(OutpostLayout.cell_center_v(build.back()), cost - state.cash)
			return false
		state.cash -= cost
		for c in build:
			state.road_network.set_tile(c, state.active_road_tier)

	state.recompute_network()
	for i in range(0, build.size(), 3):
		state.spawn_dust(OutpostLayout.cell_center_v(build[i]), 3)
	state.float_notice(
		OutpostLayout.cell_center_v(build.back()) + Vector3(0, 1.8, 0),
		"+%s REFUND" % GameCatalog.format_cash(-cost) if state.road_erase_mode else "%d TILES BUILT" % build.size(),
		DesertPalette.GOLD
	)
	if park_before == 0 and state.total_parking_spaces() > 0:
		for l in state.parking_lots:
			if l["is_connected"]:
				state.traffic_sim.dispatch_immediate_customer(l)
				break
	state.has_road_start = false
	state.save_state()
	state.hud_changed.emit()
	return true


func suggest_access_road() -> void:
	var cart: Dictionary = state.cart_plot()
	var ent: Vector2i = state.plot_entrance_cell(cart)
	var base_x: int = cart["grid_x"]
	enter_road_mode(GameCatalog.RoadTier.DIRT, false)
	state.road_two_lane = true
	state.has_road_start = true
	state.road_line_start = Vector2i(base_x, OutpostLayout.HIGHWAY_ENTRY_ROW_Z)
	state.road_line_end = Vector2i(base_x, ent.y)
	if state.camera_ref != null:
		var a := OutpostLayout.cell_center_v(state.road_line_start)
		var b := OutpostLayout.cell_center_v(state.road_line_end)
		state.camera_ref.focus_on(a.lerp(b, 0.5) + Vector3(1.0, 1.0, 0.0), maxf(36.0, a.distance_to(b) * 1.25), maxf(state.camera_ref.pitch, 0.9))
	state.overlay_changed.emit()
	state.hud_changed.emit()


func enter_land_mode() -> void:
	cancel_tool_mode(false)
	state.tool_mode = GameCatalog.WorldToolMode.BUY_LAND
	if state.camera_ref != null:
		state.camera_ref.focus_on(state.town_focus() + Vector3(0, 1.0, 0), maxf(state.camera_ref.distance, 72.0), maxf(state.camera_ref.pitch, 0.95))
	state.overlay_changed.emit()
	state.hud_changed.emit()


func buy_parcel(p: Vector2i) -> bool:
	if state.world_grid.owned_parcels.has(p):
		return false
	var center := OutpostLayout.parcel_center(p.x, p.y)
	if not state.world_grid.is_parcel_purchasable(p):
		state.float_notice(center + Vector3(0, 2.0, 0), "MUST BORDER YOUR LAND")
		return false
	if not state.can_buy_more_land():
		state.float_notice(center + Vector3(0, 2.0, 0), "STAGE %d FOR MORE LAND" % (state.outpost_stage() + 1))
		return false
	var price: float = state.world_grid.next_parcel_price()
	if state.cash < price:
		state.notify_shortfall(center + Vector3(0, 1.6, 0), price - state.cash)
		return false
	state.cash -= price
	state.world_grid.buy_parcel(p)
	state.spawn_dust(center, 14)
	var tr_id: int = state.world_grid.parcel_trait(p)
	var notice := "LAND +1!" if tr_id == GameCatalog.ParcelTrait.NONE else "LAND +1 · %s!" % str(GameCatalog.parcel_trait_spec(tr_id)["short"])
	state.float_notice(center + Vector3(0, 2.4, 0), notice, DesertPalette.GOLD)
	state.world_layout_changed.emit()
	state.save_state()
	state.hud_changed.emit()
	return true


func cell_block_reason(cell: Vector2i, ignore_id: String = "") -> String:
	if not OutpostLayout.is_cell_in_map(cell.x, cell.y):
		return "Outside the desert map"
	if not state.world_grid.is_cell_owned(cell):
		return "Buy this land first"
	if state.road_network.has_road(cell):
		return "Overlaps a road"
	if state.world_grid.is_occupied_except(cell, ignore_id):
		return "Overlaps another structure"
	return ""


func validate_rect(gx: int, gz: int, base_w: int, base_d: int, rot: int, ignore_id: String = "", required_trait: int = GameCatalog.ParcelTrait.NONE) -> String:
	var sz := OutpostLayout.rotated_size(base_w, base_d, rot)
	for dx in range(sz.x):
		for dz in range(sz.y):
			var cell := Vector2i(gx + dx, gz + dz)
			var r := cell_block_reason(cell, ignore_id)
			if not r.is_empty():
				return r
			if required_trait != GameCatalog.ParcelTrait.NONE and state.world_grid.cell_trait(cell) != required_trait:
				return "Requires %s parcel" % str(GameCatalog.parcel_trait_spec(required_trait)["name"])
	return ""


func ghost_size() -> Vector2i:
	if state.tool_mode == GameCatalog.WorldToolMode.PLACE_BUILDING and state.pending_building_type >= 0:
		var d: Dictionary = GameCatalog.BUSINESSES[state.pending_building_type]
		return OutpostLayout.rotated_size(d["grid_w"], d["grid_d"], state.ghost_rotation)
	if state.tool_mode == GameCatalog.WorldToolMode.PLACE_PARKING and state.pending_parking_kind >= 0:
		var s: Dictionary = GameCatalog.PARKING_LOTS[state.pending_parking_kind]
		return OutpostLayout.rotated_size(s["grid_w"], s["grid_d"], state.ghost_rotation)
	if state.tool_mode == GameCatalog.WorldToolMode.PLACE_UTILITY and state.pending_utility_kind >= 0:
		var u: Dictionary = GameCatalog.UTILITIES[state.pending_utility_kind]
		return OutpostLayout.rotated_size(u["grid_w"], u["grid_d"], state.ghost_rotation)
	return Vector2i(1, 1)


func ghost_invalid_reason() -> String:
	match state.tool_mode:
		GameCatalog.WorldToolMode.PLACE_BUILDING:
			if state.pending_building_type < 0:
				return "No building"
			var d: Dictionary = GameCatalog.BUSINESSES[state.pending_building_type]
			var ign := "" if state.relocating_plot_id.is_empty() else "plot:%s" % state.relocating_plot_id
			var req_trait: int = int(d.get("required_trait", GameCatalog.ParcelTrait.NONE))
			return validate_rect(state.ghost_grid_x, state.ghost_grid_z, d["grid_w"], d["grid_d"], state.ghost_rotation, ign, req_trait)
		GameCatalog.WorldToolMode.PLACE_PARKING:
			if state.pending_parking_kind < 0:
				return "No lot"
			var s: Dictionary = GameCatalog.PARKING_LOTS[state.pending_parking_kind]
			var ign := "" if state.relocating_lot_id.is_empty() else "lot:%s" % state.relocating_lot_id
			return validate_rect(state.ghost_grid_x, state.ghost_grid_z, s["grid_w"], s["grid_d"], state.ghost_rotation, ign)
		GameCatalog.WorldToolMode.PLACE_DECORATION:
			var ign := "" if state.relocating_deco_id.is_empty() else "deco:%s" % state.relocating_deco_id
			return cell_block_reason(Vector2i(state.ghost_grid_x, state.ghost_grid_z), ign)
		GameCatalog.WorldToolMode.PLACE_UTILITY:
			if state.pending_utility_kind < 0:
				return "No utility"
			var u: Dictionary = GameCatalog.UTILITIES[state.pending_utility_kind]
			var ign := "" if state.relocating_utility_id.is_empty() else "util:%s" % state.relocating_utility_id
			var req_tr: int = int(u.get("required_trait", GameCatalog.ParcelTrait.NONE))
			return validate_rect(state.ghost_grid_x, state.ghost_grid_z, u["grid_w"], u["grid_d"], state.ghost_rotation, ign, req_tr)
	return ""


func ghost_access_preview() -> Dictionary:
	if state.tool_mode != GameCatalog.WorldToolMode.PLACE_BUILDING or state.pending_building_type < 0:
		return RoadNetwork.disconnected_report()
	return state.road_network.evaluate_building_access(state.pending_building_type, state.ghost_grid_x, state.ghost_grid_z, state.ghost_rotation, state.parking_lots)


func find_movable_object_at(screen_pos: Vector2) -> Dictionary:
	if state.camera_ref == null:
		return {}
	var gp: Vector3 = state.camera_ref.screen_to_ground(screen_pos, 0.0)
	var mp: Vector3 = state.camera_ref.screen_to_ground(screen_pos, 1.3)

	var best_kind := ""
	var best_item: Dictionary = {}
	var best_dist := 1e9

	for p in state.plots:
		if not p["is_built"]:
			continue
		var data: Dictionary = GameCatalog.BUSINESSES[p["type"]]
		var sz := OutpostLayout.rotated_size(data["grid_w"], data["grid_d"], p["rot"])
		var hw := float(sz.x) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.45
		var hd := float(sz.y) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.45
		var pos: Vector3 = state.plot_position(p)
		var hit := (absf(gp.x - pos.x) <= hw and absf(gp.z - pos.z) <= hd) or (absf(mp.x - pos.x) <= hw and absf(mp.z - pos.z) <= hd)
		if hit:
			var d := pos.distance_to(gp)
			if d < best_dist:
				best_dist = d
				best_kind = "plot"
				best_item = p

	for lot in state.parking_lots:
		var spec: Dictionary = GameCatalog.PARKING_LOTS[lot["kind"]]
		var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], lot["rot"])
		var hw := float(sz.x) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.25
		var hd := float(sz.y) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.25
		var pos: Vector3 = state.lot_position(lot)
		if absf(gp.x - pos.x) <= hw and absf(gp.z - pos.z) <= hd:
			var d := pos.distance_to(gp)
			if d < best_dist:
				best_dist = d
				best_kind = "lot"
				best_item = lot

	for dec in state.decorations:
		var pos := OutpostLayout.cell_center(int(dec["grid_x"]), int(dec["grid_z"]))
		var d := minf(pos.distance_to(gp), pos.distance_to(mp))
		if d <= 1.25 and d < best_dist:
			best_dist = d
			best_kind = "deco"
			best_item = dec

	for u in state.utilities:
		var spec: Dictionary = GameCatalog.UTILITIES[int(u["kind"])]
		var sz := OutpostLayout.rotated_size(spec["grid_w"], spec["grid_d"], int(u.get("rot", 0)))
		var hw := float(sz.x) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.35
		var hd := float(sz.y) * OutpostLayout.GRID_CELL_SIZE * 0.5 + 0.35
		var pos: Vector3 = state.utility_position(u)
		var hit := (absf(gp.x - pos.x) <= hw and absf(gp.z - pos.z) <= hd) or (absf(mp.x - pos.x) <= hw and absf(mp.z - pos.z) <= hd)
		if hit:
			var d := pos.distance_to(gp)
			if d < best_dist:
				best_dist = d
				best_kind = "util"
				best_item = u

	if best_kind.is_empty():
		return {}
	return {"kind": best_kind, "item": best_item}


func try_start_hold_move_at(screen_pos: Vector2) -> bool:
	var found := find_movable_object_at(screen_pos)
	if found.is_empty():
		return false
	var kind: String = found["kind"]
	var item: Dictionary = found["item"]
	var notice_pos := Vector3.ZERO
	if kind == "plot":
		start_relocating_plot(item, false)
		notice_pos = state.plot_position(item) + Vector3(0, 2.8, 0)
	elif kind == "lot":
		start_relocating_parking(item, -1, false)
		notice_pos = state.lot_position(item) + Vector3(0, 2.2, 0)
	elif kind == "deco":
		start_relocating_decoration(item, false)
		notice_pos = OutpostLayout.cell_center(int(item["grid_x"]), int(item["grid_z"])) + Vector3(0, 1.8, 0)
	elif kind == "util":
		start_relocating_utility(item, false)
		notice_pos = state.utility_position(item) + Vector3(0, 2.4, 0)
	else:
		return false
	state.is_hold_dragging = true
	state.hold_drag_origin = Vector2i(state.ghost_grid_x, state.ghost_grid_z)
	state.spawn_dust(Vector3(notice_pos.x, 0.0, notice_pos.z), 8)
	state.float_notice(notice_pos, "DRAG TO MOVE", DesertPalette.GOLD, 1.0)
	return true


func drag_ghost_to_screen(screen_pos: Vector2) -> void:
	if state.camera_ref == null:
		return
	var gp: Vector3 = state.camera_ref.screen_to_ground(screen_pos, 0.0)
	move_ghost_to_world(gp)


func finish_hold_move() -> void:
	state.is_hold_dragging = false
	var moved: bool = Vector2i(state.ghost_grid_x, state.ghost_grid_z) != state.hold_drag_origin
	if moved and ghost_invalid_reason().is_empty():
		confirm_placement()
	else:
		state.hud_changed.emit()


func start_placing_building(btype: int) -> void:
	for p in state.plots:
		if p["type"] == btype:
			if p["is_built"] or not state.is_plot_unlocked(p):
				return
			break
	cancel_tool_mode(false)
	state.tool_mode = GameCatalog.WorldToolMode.PLACE_BUILDING
	state.pending_building_type = btype
	state.ghost_rotation = 0
	var spot := _find_smart_building_spot(btype)
	state.ghost_grid_x = spot.x
	state.ghost_grid_z = spot.y
	_focus_ghost()
	state.overlay_changed.emit()
	state.hud_changed.emit()


func start_relocating_plot(p: Dictionary, focus_cam: bool = true) -> void:
	if not p["is_built"]:
		return
	cancel_tool_mode(false)
	state.tool_mode = GameCatalog.WorldToolMode.PLACE_BUILDING
	state.pending_building_type = p["type"]
	state.relocating_plot_id = p["id"]
	state.ghost_grid_x = p["grid_x"]
	state.ghost_grid_z = p["grid_z"]
	state.ghost_rotation = p["rot"]
	if focus_cam:
		_focus_ghost()
	state.world_layout_changed.emit()
	state.hud_changed.emit()


func start_placing_parking(kind: int) -> void:
	if not state.is_parking_kind_unlocked(kind):
		return
	cancel_tool_mode(false)
	state.tool_mode = GameCatalog.WorldToolMode.PLACE_PARKING
	state.pending_parking_kind = kind
	var res := _find_smart_parking_spot(kind)
	state.ghost_grid_x = res[0].x
	state.ghost_grid_z = res[0].y
	state.ghost_rotation = res[1]
	_focus_ghost()
	state.overlay_changed.emit()
	state.hud_changed.emit()


func start_relocating_parking(lot: Dictionary, upgrade_to: int = -1, focus_cam: bool = true) -> void:
	cancel_tool_mode(false)
	state.tool_mode = GameCatalog.WorldToolMode.PLACE_PARKING
	state.pending_parking_kind = upgrade_to if upgrade_to >= 0 else lot["kind"]
	state.relocating_lot_id = lot["id"]
	state.relocating_lot_is_upgrade = upgrade_to >= 0 and upgrade_to != lot["kind"]
	state.ghost_grid_x = lot["grid_x"]
	state.ghost_grid_z = lot["grid_z"]
	state.ghost_rotation = lot["rot"]
	if focus_cam:
		_focus_ghost()
	state.world_layout_changed.emit()
	state.hud_changed.emit()


func start_placing_decoration(deco_spec: Dictionary) -> void:
	var max_decos := GameCatalog.max_decorations_for_parcels(state.world_grid.owned_parcels.size())
	if not state.is_deco_unlocked(deco_spec["kind"]) or state.decorations.size() >= max_decos:
		return
	cancel_tool_mode(false)
	state.tool_mode = GameCatalog.WorldToolMode.PLACE_DECORATION
	state.pending_deco = deco_spec
	state.ghost_rotation = 0
	var spot := _find_smart_deco_spot()
	state.ghost_grid_x = spot.x
	state.ghost_grid_z = spot.y
	_focus_ghost()
	state.overlay_changed.emit()
	state.hud_changed.emit()


func start_relocating_decoration(deco: Dictionary, focus_cam: bool = true) -> void:
	cancel_tool_mode(false)
	state.tool_mode = GameCatalog.WorldToolMode.PLACE_DECORATION
	state.relocating_deco_id = deco["id"]
	state.pending_deco = {
		"kind": deco["kind"],
		"name": deco["name"],
		"cost": deco["cost"],
	}
	state.ghost_rotation = int(deco.get("rot", 0)) & 3
	state.ghost_grid_x = deco["grid_x"]
	state.ghost_grid_z = deco["grid_z"]
	if focus_cam:
		_focus_ghost()
	state.world_layout_changed.emit()
	state.hud_changed.emit()


func rotate_ghost() -> void:
	if state.tool_mode != GameCatalog.WorldToolMode.PLACE_BUILDING and state.tool_mode != GameCatalog.WorldToolMode.PLACE_PARKING and state.tool_mode != GameCatalog.WorldToolMode.PLACE_DECORATION and state.tool_mode != GameCatalog.WorldToolMode.PLACE_UTILITY:
		return
	state.ghost_rotation = (state.ghost_rotation + 1) & 3
	state.overlay_changed.emit()
	state.hud_changed.emit()


# --- Power Utility, Pole/Tower & Underground Conduit Tools ---

func _enable_lens_for_tool(lens: int) -> void:
	if state._prev_lens_before_tool < 0:
		state._prev_lens_before_tool = state.active_lens
	state.active_lens = lens


func _enable_power_lens_for_tool() -> void:
	_enable_lens_for_tool(GameCatalog.MapLens.POWER)


func _lens_for_utility_kind(kind: int) -> int:
	var grp := GameCatalog.utility_group(kind)
	if grp == "water":
		return GameCatalog.MapLens.WATER
	if grp == "supply":
		return GameCatalog.MapLens.LAND_TRAITS if kind == GameCatalog.UtilityKind.OIL_PUMPJACK else GameCatalog.MapLens.SUPPLY
	return GameCatalog.MapLens.POWER


func start_placing_utility(kind: int) -> void:
	if not state.is_utility_unlocked(kind):
		return
	cancel_tool_mode(false)
	_enable_lens_for_tool(_lens_for_utility_kind(kind))
	state.tool_mode = GameCatalog.WorldToolMode.PLACE_UTILITY
	state.pending_utility_kind = kind
	state.ghost_rotation = 0
	var spot := _find_smart_utility_spot(kind)
	state.ghost_grid_x = spot.x
	state.ghost_grid_z = spot.y
	_focus_ghost()
	state.overlay_changed.emit()
	state.hud_changed.emit()


func start_relocating_utility(u: Dictionary, focus_cam: bool = true) -> void:
	cancel_tool_mode(false)
	_enable_lens_for_tool(_lens_for_utility_kind(int(u["kind"])))
	state.tool_mode = GameCatalog.WorldToolMode.PLACE_UTILITY
	state.pending_utility_kind = int(u["kind"])
	state.relocating_utility_id = str(u["id"])
	state.ghost_grid_x = int(u["grid_x"])
	state.ghost_grid_z = int(u["grid_z"])
	state.ghost_rotation = int(u.get("rot", 0)) & 3
	if focus_cam:
		_focus_ghost()
	state.world_layout_changed.emit()
	state.hud_changed.emit()


func enter_pole_mode(kind: int = -1, erase: bool = false) -> void:
	cancel_tool_mode(false)
	_enable_power_lens_for_tool()
	state.tool_mode = GameCatalog.WorldToolMode.PLACE_POWER_POLE
	state.pole_erase_mode = erase
	if kind >= 0 and state.is_power_line_unlocked(kind):
		state.active_pole_kind = kind
	elif not state.is_power_line_unlocked(state.active_pole_kind):
		state.active_pole_kind = GameCatalog.PowerLineKind.WOOD_POLE
	if state.camera_ref != null:
		state.camera_ref.ensure_min_pitch(0.75)
	state.overlay_changed.emit()
	state.hud_changed.emit()


func set_pole_kind(kind: int) -> void:
	if not state.is_power_line_unlocked(kind):
		return
	state.active_pole_kind = kind
	state.pole_erase_mode = false
	state.overlay_changed.emit()
	state.hud_changed.emit()


func set_pole_erase(erase: bool) -> void:
	state.pole_erase_mode = erase
	state.overlay_changed.emit()
	state.hud_changed.emit()


func pole_tap(cell: Vector2i) -> bool:
	var wc := OutpostLayout.cell_center_v(cell)
	if state.pole_erase_mode:
		if not state.world_grid.has_power_pole(cell):
			return false
		var meta: Dictionary = state.world_grid.power_poles[cell]
		var pk: int = int(meta.get("kind", GameCatalog.PowerLineKind.WOOD_POLE))
		var refund := roundf(float(GameCatalog.POWER_LINES[pk]["cost"]) * 0.5)
		state.world_grid.remove_power_pole(cell)
		state.cash += refund
		state.recompute_network()
		state.float_notice(wc + Vector3(0, 2.2, 0), "+%s REFUND" % GameCatalog.format_cash(refund), DesertPalette.SAND_LIGHT)
		state.save_state()
		state.hud_changed.emit()
		return true

	var block := cell_block_reason(cell)
	if not block.is_empty():
		state.float_notice(wc + Vector3(0, 1.8, 0), block.to_upper())
		return false
	var pkind: int = state.active_pole_kind
	var cost: float = float(GameCatalog.POWER_LINES[pkind]["cost"])
	if state.cash < cost:
		state.notify_shortfall(wc, cost - state.cash)
		return false
	state.cash -= cost
	state.world_grid.set_power_pole(cell, {"kind": pkind})
	state.recompute_network()
	state.spawn_dust(wc, 6)
	state.float_notice(wc + Vector3(0, 2.4, 0), "%s!" % str(GameCatalog.POWER_LINES[pkind]["short"]).to_upper(), DesertPalette.GOLD, 1.0)
	state.save_state()
	state.hud_changed.emit()
	return true


func enter_conduit_mode(erase: bool = false) -> void:
	if not state.is_power_line_unlocked(GameCatalog.PowerLineKind.UNDERGROUND):
		return
	cancel_tool_mode(false)
	_enable_power_lens_for_tool()
	state.tool_mode = GameCatalog.WorldToolMode.PAINT_CONDUIT
	state.conduit_erase_mode = erase
	state.has_conduit_start = false
	if state.camera_ref != null:
		state.camera_ref.ensure_min_pitch(0.78)
	state.overlay_changed.emit()
	state.hud_changed.emit()


func set_conduit_erase(erase: bool) -> void:
	state.conduit_erase_mode = erase
	state.overlay_changed.emit()
	state.hud_changed.emit()


func conduit_line_tap(cell: Vector2i) -> void:
	if not state.has_conduit_start:
		state.has_conduit_start = true
		state.conduit_line_start = cell
		state.conduit_line_end = cell
	else:
		state.conduit_line_end = cell
	state.overlay_changed.emit()
	state.hud_changed.emit()


func clear_conduit_line() -> void:
	state.has_conduit_start = false
	state.overlay_changed.emit()
	state.hud_changed.emit()


func compute_conduit_line_preview() -> Dictionary:
	if state.tool_mode != GameCatalog.WorldToolMode.PAINT_CONDUIT or not state.has_conduit_start:
		return {"cells": [], "build": [], "skip": [], "blocked": [], "cost": 0.0, "reason": ""}
	var cells := RoadNetwork.line_path(state.conduit_line_start, state.conduit_line_end)
	var build: Array[Vector2i] = []
	var skip: Array[Vector2i] = []
	var blocked: Array[Vector2i] = []
	var cost := 0.0
	var reason := ""
	var unit_cost: float = float(GameCatalog.POWER_LINES[GameCatalog.PowerLineKind.UNDERGROUND]["cost"])

	if state.conduit_erase_mode:
		for c in cells:
			if state.world_grid.has_underground_power(c):
				build.append(c)
				cost -= roundf(unit_cost * 0.5)
			else:
				skip.append(c)
		if build.is_empty():
			reason = "No buried cables on this line"
		return {"cells": cells, "build": build, "skip": skip, "blocked": blocked, "cost": cost, "reason": reason}

	for c in cells:
		if not state.world_grid.can_place_underground_utility(c):
			blocked.append(c)
			if reason.is_empty():
				reason = "Buy this land first" if OutpostLayout.is_cell_in_map(c.x, c.y) else "Outside the desert map"
			continue
		if state.world_grid.has_underground_power(c):
			skip.append(c)
			continue
		build.append(c)
		cost += unit_cost
	if build.is_empty() and reason.is_empty():
		reason = "Conduit already laid here"
	return {"cells": cells, "build": build, "skip": skip, "blocked": blocked, "cost": cost, "reason": reason}


func confirm_conduit_line() -> bool:
	var prev := compute_conduit_line_preview()
	var build: Array = prev["build"]
	if not str(prev["reason"]).is_empty() or build.is_empty():
		return false
	var cost: float = prev["cost"]
	if state.conduit_erase_mode:
		for c in build:
			state.world_grid.remove_underground_power(c)
		state.cash += -cost
	else:
		if state.cash < cost:
			state.notify_shortfall(OutpostLayout.cell_center_v(build.back()), cost - state.cash)
			return false
		state.cash -= cost
		for c in build:
			state.world_grid.set_underground_power(c, {"kind": GameCatalog.PowerLineKind.UNDERGROUND})
	state.recompute_network()
	state.float_notice(
		OutpostLayout.cell_center_v(build.back()) + Vector3(0, 1.8, 0),
		"+%s REFUND" % GameCatalog.format_cash(-cost) if state.conduit_erase_mode else "%d BURIED CABLES!" % build.size(),
		DesertPalette.NEON_TURQUOISE
	)
	state.has_conduit_start = false
	state.save_state()
	state.hud_changed.emit()
	return true


func place_utility_at(kind: int, gx: int, gz: int, rot: int = 0) -> bool:
	if not state.is_utility_unlocked(kind):
		return false
	var spec: Dictionary = GameCatalog.UTILITIES[kind]
	var req_tr: int = int(spec.get("required_trait", GameCatalog.ParcelTrait.NONE))
	if not validate_rect(gx, gz, int(spec["grid_w"]), int(spec["grid_d"]), rot, "", req_tr).is_empty():
		return false
	var cost: float = float(spec["cost"])
	if state.cash < cost:
		state.notify_shortfall(OutpostLayout.cell_center(gx, gz), cost - state.cash)
		return false
	state.cash -= cost
	var u: Dictionary = state.make_utility(kind, gx, gz, rot)
	state.utilities.append(u)
	state.recompute_network()
	var pos: Vector3 = state.utility_position(u)
	state.spawn_dust(pos, 12)
	var tr_here: int = int(state.world_grid.cell_trait(Vector2i(gx, gz)))
	var wind_bonus: bool = kind == GameCatalog.UtilityKind.WINDMILL and tr_here == GameCatalog.ParcelTrait.WIND_CORRIDOR
	var aq_bonus: bool = kind == GameCatalog.UtilityKind.WATER_WELL and tr_here == GameCatalog.ParcelTrait.AQUIFER
	var msg := "WINDMILL +40% WIND!" if wind_bonus else ("AQUIFER WELL +80%!" if aq_bonus else "%s BUILT!" % str(spec["short"]).to_upper())
	state.float_notice(pos + Vector3(0, 2.5, 0), msg, DesertPalette.GOLD, 1.5)
	state.save_state()
	state.hud_changed.emit()
	return true


func enter_water_pipe_mode(erase: bool = false) -> void:
	if state.outpost_stage() < 2:
		return
	cancel_tool_mode(false)
	_enable_lens_for_tool(GameCatalog.MapLens.WATER)
	state.tool_mode = GameCatalog.WorldToolMode.PAINT_WATER_PIPE
	state.water_pipe_erase_mode = erase
	state.has_water_pipe_start = false
	if state.camera_ref != null:
		state.camera_ref.ensure_min_pitch(0.78)
	state.overlay_changed.emit()
	state.hud_changed.emit()


func set_water_pipe_erase(erase: bool) -> void:
	state.water_pipe_erase_mode = erase
	state.overlay_changed.emit()
	state.hud_changed.emit()


func water_pipe_line_tap(cell: Vector2i) -> void:
	if not state.has_water_pipe_start:
		state.has_water_pipe_start = true
		state.water_pipe_line_start = cell
		state.water_pipe_line_end = cell
	else:
		state.water_pipe_line_end = cell
	state.overlay_changed.emit()
	state.hud_changed.emit()


func clear_water_pipe_line() -> void:
	state.has_water_pipe_start = false
	state.overlay_changed.emit()
	state.hud_changed.emit()


func compute_water_pipe_line_preview() -> Dictionary:
	if state.tool_mode != GameCatalog.WorldToolMode.PAINT_WATER_PIPE or not state.has_water_pipe_start:
		return {"cells": [], "build": [], "skip": [], "blocked": [], "cost": 0.0, "reason": ""}
	var cells := RoadNetwork.line_path(state.water_pipe_line_start, state.water_pipe_line_end)
	var build: Array[Vector2i] = []
	var skip: Array[Vector2i] = []
	var blocked: Array[Vector2i] = []
	var cost := 0.0
	var reason := ""
	var unit_cost := GameCatalog.WATER_PIPE_COST

	if state.water_pipe_erase_mode:
		for c in cells:
			if state.world_grid.has_water_pipe(c):
				build.append(c)
				cost -= roundf(unit_cost * 0.5)
			else:
				skip.append(c)
		if build.is_empty():
			reason = "No water pipes on this line"
		return {"cells": cells, "build": build, "skip": skip, "blocked": blocked, "cost": cost, "reason": reason}

	for c in cells:
		if not state.world_grid.can_place_underground_utility(c):
			blocked.append(c)
			if reason.is_empty():
				reason = "Buy this land first" if OutpostLayout.is_cell_in_map(c.x, c.y) else "Outside the desert map"
			continue
		if state.world_grid.has_water_pipe(c):
			skip.append(c)
			continue
		build.append(c)
		cost += unit_cost
	if build.is_empty() and reason.is_empty():
		reason = "Water pipe already laid here"
	return {"cells": cells, "build": build, "skip": skip, "blocked": blocked, "cost": cost, "reason": reason}


func confirm_water_pipe_line() -> bool:
	var prev := compute_water_pipe_line_preview()
	var build: Array = prev["build"]
	if not str(prev["reason"]).is_empty() or build.is_empty():
		return false
	var cost: float = prev["cost"]
	if state.water_pipe_erase_mode:
		for c in build:
			state.world_grid.remove_water_pipe(c)
		state.cash += -cost
	else:
		if state.cash < cost:
			state.notify_shortfall(OutpostLayout.cell_center_v(build.back()), cost - state.cash)
			return false
		state.cash -= cost
		for c in build:
			state.world_grid.set_water_pipe(c, {"tier": 1})
	state.recompute_network()
	state.float_notice(
		OutpostLayout.cell_center_v(build.back()) + Vector3(0, 1.8, 0),
		"+%s REFUND" % GameCatalog.format_cash(-cost) if state.water_pipe_erase_mode else "%d WATER PIPES!" % build.size(),
		DesertPalette.WATER
	)
	state.has_water_pipe_start = false
	state.save_state()
	state.hud_changed.emit()
	return true


func remove_utility(u: Dictionary) -> void:
	var idx: int = state.utilities.find(u)
	if idx < 0:
		return
	var refund := roundf(float(GameCatalog.UTILITIES[int(u["kind"])]["cost"]) * 0.5)
	var pos: Vector3 = state.utility_position(u)
	state.utilities.remove_at(idx)
	state.recompute_network()
	state.cash += refund
	state.float_notice(pos + Vector3(0, 2.0, 0), "+%s REFUND" % GameCatalog.format_cash(refund), DesertPalette.SAND_LIGHT)
	state.save_state()
	state.hud_changed.emit()


func _find_smart_utility_spot(kind: int) -> Vector2i:
	var focus := OutpostLayout.world_to_cell(state.town_focus())
	var spec: Dictionary = GameCatalog.UTILITIES[kind]
	var req_tr: int = int(spec.get("required_trait", GameCatalog.ParcelTrait.NONE))
	var best := focus
	var best_sc := -1e9
	for c in _owned_cells():
		if not validate_rect(c.x, c.y, int(spec["grid_w"]), int(spec["grid_d"]), 0, "", req_tr).is_empty():
			continue
		var sc := -float(OutpostLayout.manhattan(c, focus))
		var tr_c: int = int(state.world_grid.cell_trait(c))
		if kind == GameCatalog.UtilityKind.WINDMILL and tr_c == GameCatalog.ParcelTrait.WIND_CORRIDOR:
			sc += 25.0
		elif kind == GameCatalog.UtilityKind.WATER_WELL and tr_c == GameCatalog.ParcelTrait.AQUIFER:
			sc += 35.0
		if sc > best_sc:
			best_sc = sc
			best = c
	return best


func move_ghost_to_world(world_pos: Vector3) -> void:
	var c := OutpostLayout.world_to_cell(world_pos)
	var sz := ghost_size()
	var nx := clampi(c.x - int(sz.x / 2), OutpostLayout.MIN_GRID_X, OutpostLayout.MAX_GRID_X - sz.x + 1)
	var nz := clampi(c.y - int(sz.y / 2), OutpostLayout.MIN_GRID_Z, OutpostLayout.MAX_GRID_Z - sz.y + 1)
	if nx != state.ghost_grid_x or nz != state.ghost_grid_z:
		state.ghost_grid_x = nx
		state.ghost_grid_z = nz
		state.overlay_changed.emit()
		state.hud_changed.emit()


func _focus_ghost() -> void:
	if state.camera_ref == null:
		return
	var sz := ghost_size()
	var center := OutpostLayout.footprint_center(state.ghost_grid_x, state.ghost_grid_z, sz.x, sz.y)
	state.camera_ref.focus_on(center + Vector3(0, 1.2, 0), clampf(state.camera_ref.distance, 22.0, 46.0))
	state.camera_ref.ensure_min_pitch(0.72)


func confirm_placement() -> bool:
	if not ghost_invalid_reason().is_empty():
		return false
	var ok := false
	match state.tool_mode:
		GameCatalog.WorldToolMode.PLACE_BUILDING:
			if not state.relocating_plot_id.is_empty():
				for p in state.plots:
					if p["id"] == state.relocating_plot_id:
						p["grid_x"] = state.ghost_grid_x
						p["grid_z"] = state.ghost_grid_z
						p["rot"] = state.ghost_rotation & 3
						p["bounce"] = 0.36
						state.recompute_network()
						state.spawn_dust(state.plot_position(p), 10)
						state.float_notice(state.plot_position(p) + Vector3(0, 2.6, 0), "MOVED · %d%%" % roundi(float(p["access"]["score"]) * 100.0), DesertPalette.NEON_TURQUOISE)
						ok = true
						break
			else:
				for p in state.plots:
					if p["type"] == state.pending_building_type and not p["is_built"]:
						var cost: float = GameCatalog.BUSINESSES[state.pending_building_type]["purchase_cost"]
						if state.cash < cost:
							state.notify_shortfall(OutpostLayout.cell_center(state.ghost_grid_x, state.ghost_grid_z), cost - state.cash)
							return false
						state.cash -= cost
						p["grid_x"] = state.ghost_grid_x
						p["grid_z"] = state.ghost_grid_z
						p["rot"] = state.ghost_rotation & 3
						p["is_built"] = true
						p["level"] = 1
						p["build_pop"] = 1.0
						p["bounce"] = 0.38
						state.recompute_network()
						state.spawn_dust(state.plot_position(p), 14)
						var sc: float = p["access"]["score"]
						state.float_notice(state.plot_position(p) + Vector3(0, 2.8, 0), "BUILT! %d%%" % roundi(sc * 100.0) if sc > 0.0 else "BUILT! ADD ROAD", DesertPalette.GOLD if sc > 0.0 else Color("ffb899"), 1.5)
						ok = true
						break
		GameCatalog.WorldToolMode.PLACE_PARKING:
			if not state.relocating_lot_id.is_empty():
				for l in state.parking_lots:
					if l["id"] == state.relocating_lot_id:
						ok = apply_relocate_parking(l, state.ghost_grid_x, state.ghost_grid_z, state.ghost_rotation, state.pending_parking_kind if state.relocating_lot_is_upgrade else -1)
						break
			else:
				ok = place_parking_lot_at(state.pending_parking_kind, state.ghost_grid_x, state.ghost_grid_z, state.ghost_rotation)
		GameCatalog.WorldToolMode.PLACE_DECORATION:
			if not state.relocating_deco_id.is_empty():
				for dec in state.decorations:
					if dec["id"] == state.relocating_deco_id:
						dec["grid_x"] = state.ghost_grid_x
						dec["grid_z"] = state.ghost_grid_z
						dec["rot"] = state.ghost_rotation & 3
						var spot := OutpostLayout.cell_center(state.ghost_grid_x, state.ghost_grid_z)
						state.recompute_network()
						state.spawn_dust(spot, 8)
						state.float_notice(spot + Vector3(0, 2.0, 0), "MOVED!", DesertPalette.NEON_TURQUOISE)
						ok = true
						break
			elif not state.pending_deco.is_empty():
				var cost: float = state.pending_deco["cost"]
				if state.cash < cost:
					state.notify_shortfall(OutpostLayout.cell_center(state.ghost_grid_x, state.ghost_grid_z), cost - state.cash)
					return false
				state.cash -= cost
				var spot := OutpostLayout.cell_center(state.ghost_grid_x, state.ghost_grid_z)
				state.decorations.append({
					"id": "deco_%d" % state.alloc_entity_id(),
					"kind": state.pending_deco["kind"],
					"name": state.pending_deco["name"],
					"cost": cost,
					"grid_x": state.ghost_grid_x,
					"grid_z": state.ghost_grid_z,
					"rot": state.ghost_rotation & 3,
				})
				state.recompute_network()
				state.spawn_dust(spot, 8)
				state.float_notice(spot + Vector3(0, 2.0, 0), "+8% TRAFFIC!" if state.pending_deco["kind"] == GameCatalog.DecorationKind.WOODEN_SIGNPOST else "+4% TIPS!", DesertPalette.GOLD_POPUP)
				ok = true
		GameCatalog.WorldToolMode.PLACE_UTILITY:
			if not state.relocating_utility_id.is_empty():
				for u in state.utilities:
					if u["id"] == state.relocating_utility_id:
						u["grid_x"] = state.ghost_grid_x
						u["grid_z"] = state.ghost_grid_z
						u["rot"] = state.ghost_rotation & 3
						state.recompute_network()
						var pos: Vector3 = state.utility_position(u)
						state.spawn_dust(pos, 10)
						state.float_notice(pos + Vector3(0, 2.4, 0), "MOVED!", DesertPalette.NEON_TURQUOISE)
						ok = true
						break
			else:
				ok = place_utility_at(state.pending_utility_kind, state.ghost_grid_x, state.ghost_grid_z, state.ghost_rotation)
	if ok:
		cancel_tool_mode(false)
		state.save_state()
		state.world_layout_changed.emit()
		state.hud_changed.emit()
	return ok


func place_parking_lot_at(kind: int, gx: int, gz: int, rot: int = 0) -> bool:
	if not state.is_parking_kind_unlocked(kind):
		return false
	var spec: Dictionary = GameCatalog.PARKING_LOTS[kind]
	if not validate_rect(gx, gz, spec["grid_w"], spec["grid_d"], rot).is_empty():
		return false
	var cost: float = spec["cost"]
	if state.cash < cost:
		state.notify_shortfall(OutpostLayout.cell_center(gx, gz), cost - state.cash)
		return false
	var park_before: int = state.total_parking_spaces()
	state.cash -= cost
	var lot: Dictionary = state.make_lot(kind, gx, gz, rot)
	state.parking_lots.append(lot)
	state.recompute_network()
	state.spawn_dust(state.lot_position(lot), 12)
	state.float_notice(state.lot_position(lot) + Vector3(0, 2.2, 0), "%s!" % str(spec["name"]).to_upper() if lot["is_connected"] else "CONNECT A ROAD!", DesertPalette.GOLD if lot["is_connected"] else Color("ffb899"), 1.5)
	if park_before == 0 and lot["is_connected"]:
		state.traffic_sim.dispatch_immediate_customer(lot)
	state.save_state()
	state.hud_changed.emit()
	return true


func upgrade_parking_lot(lot: Dictionary) -> bool:
	var lock: String = state.parking_upgrade_lock_reason(lot)
	if not lock.is_empty():
		state.float_notice(state.lot_position(lot) + Vector3(0, 2.2, 0), lock)
		return false
	var nxt := GameCatalog.next_parking_upgrade(lot["kind"])
	var cost: float = state.parking_upgrade_cost(lot)
	if state.cash < cost:
		state.notify_shortfall(state.lot_position(lot) + Vector3(0, 1.8, 0), cost - state.cash)
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
					if state.road_network.is_connected_to_highway(rc):
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
		return apply_relocate_parking(lot, best_gx, best_gz, best_rot, nxt)
	start_relocating_parking(lot, nxt)
	state.float_notice(state.lot_position(lot) + Vector3(0, 2.4, 0), "MOVE TO FIT BIGGER LOT")
	return false


func apply_relocate_parking(lot: Dictionary, gx: int, gz: int, rot: int, upgrade_to: int) -> bool:
	var target_kind: int = upgrade_to if upgrade_to >= 0 else int(lot["kind"])
	var is_upg: bool = upgrade_to >= 0 and upgrade_to != int(lot["kind"])
	var cost: float = state.parking_upgrade_cost(lot) if is_upg else 0.0
	if state.cash < cost:
		state.notify_shortfall(state.lot_position(lot), cost - state.cash)
		return false
	state.cash -= cost
	lot["kind"] = target_kind
	lot["grid_x"] = gx
	lot["grid_z"] = gz
	lot["rot"] = rot & 3
	state.traffic_sim.evict_lot_vehicles(lot["id"])
	state.recompute_network()
	state.spawn_dust(state.lot_position(lot), 14)
	state.float_notice(state.lot_position(lot) + Vector3(0, 2.4, 0), "%s!" % str(GameCatalog.PARKING_LOTS[target_kind]["name"]).to_upper() if is_upg else "LOT MOVED!", DesertPalette.GOLD if is_upg else DesertPalette.NEON_TURQUOISE)
	state.save_state()
	state.hud_changed.emit()
	return true


func remove_parking_lot(lot: Dictionary) -> void:
	var idx: int = state.parking_lots.find(lot)
	if idx < 0:
		return
	var refund: float = roundf(float(GameCatalog.PARKING_LOTS[lot["kind"]]["cost"]) * 0.5)
	var pos: Vector3 = state.lot_position(lot)
	var lid: String = lot["id"]
	state.parking_lots.remove_at(idx)
	state.traffic_sim.evict_lot_vehicles(lid)
	state.cash += refund
	state.recompute_network()
	state.float_notice(pos + Vector3(0, 1.8, 0), "+%s REFUND" % GameCatalog.format_cash(refund), DesertPalette.SAND_LIGHT)
	state.save_state()
	state.hud_changed.emit()


func quick_upgrade_or_place_parking() -> bool:
	for l in state.parking_lots:
		if state.parking_upgrade_lock_reason(l).is_empty() and state.cash >= state.parking_upgrade_cost(l):
			return upgrade_parking_lot(l)
	var kind: int = GameCatalog.ParkingLotKind.DIRT_PULL_OFF
	var res := _find_smart_parking_spot(kind)
	return place_parking_lot_at(kind, res[0].x, res[0].y, res[1])


func _owned_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: Vector2i in state.world_grid.owned_parcels.keys():
		var rect := OutpostLayout.parcel_cell_bounds(p.x, p.y)
		for gz in range(rect.position.y, rect.position.y + rect.size.y):
			for gx in range(rect.position.x, rect.position.x + rect.size.x):
				out.append(Vector2i(gx, gz))
	return out


func _find_smart_building_spot(btype: int) -> Vector2i:
	var focus := OutpostLayout.world_to_cell(state.town_focus())
	var d: Dictionary = GameCatalog.BUSINESSES[btype]
	var req_trait: int = int(d.get("required_trait", GameCatalog.ParcelTrait.NONE))
	var best := Vector2i(focus.x + 3, focus.y)
	var best_sc := -1e9
	for c in _owned_cells():
		if not validate_rect(c.x, c.y, d["grid_w"], d["grid_d"], 0, "", req_trait).is_empty():
			continue
		var rep: Dictionary = state.road_network.evaluate_building_access(btype, c.x, c.y, 0, state.parking_lots)
		var sc := float(rep["score"]) * 10.0 - float(OutpostLayout.manhattan(c, focus)) * 0.05
		if sc > best_sc:
			best_sc = sc
			best = c
	return best


func _find_smart_parking_spot(kind: int) -> Array:
	var spec: Dictionary = GameCatalog.PARKING_LOTS[kind]
	var cart: Dictionary = state.cart_plot()
	var ent: Vector2i = state.plot_entrance_cell(cart) if cart["is_built"] else OutpostLayout.world_to_cell(state.town_focus())
	var road_col_a: int = cart["grid_x"] if cart["is_built"] else ent.x - 1
	var road_col_b: int = road_col_a + 1
	var best := Vector2i(road_col_b + 1, ent.y - 2)
	var best_rot := 1
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
					if (cell.x == road_col_a or cell.x == road_col_b) and cell.y >= ent.y:
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
				if state.road_network.is_connected_to_highway(rc):
					rc_n += 1
				if (rc.x == road_col_a or rc.x == road_col_b) and rc.y >= ent.y:
					corr_n += 1
			var sc := rc_n * 60.0 + corr_n * 14.0 - float(min_d)
			if sc > best_sc:
				best_sc = sc
				best = c
				best_rot = rot
	return [best, best_rot]


func _find_smart_deco_spot() -> Vector2i:
	var focus := OutpostLayout.world_to_cell(state.town_focus())
	var best := focus
	var best_d := 99999
	for c in _owned_cells():
		if not cell_block_reason(c).is_empty():
			continue
		var d := OutpostLayout.manhattan(c, focus)
		if d >= 2 and d < best_d:
			best_d = d
			best = c
	return best
