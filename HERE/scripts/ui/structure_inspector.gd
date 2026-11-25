class_name StructureInspector
extends PanelContainer

## Modular tabbed inspector drawer for Desert Outpost structures.
## Dynamically builds tabs declared by each structure (Overview, Staff, Power, Stock)
## and supports inspecting both Businesses and Parking Lots.

var state: GameState
var _display_font: Font
var _ui_font: Font
var _staff_portraits: Dictionary = {}

var _active_tab := "overview"
var _last_entity_id := ""

var _title_lbl: Label
var _lv_badge: Label
var _status_badge: Label
var _move_btn: Button
var _upg_btn: Button
var _del_btn: Button
var _tabs_row: HBoxContainer
var _chips_row: HBoxContainer
var _body_box: VBoxContainer


func setup(game_state: GameState, display_font: Font, ui_font: Font) -> void:
	state = game_state
	_display_font = display_font
	_ui_font = ui_font
	_build_ui()


func _make_box(bg: Color, border: Color, radius: int = 14, border_w: int = 2, shadow_y: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	if shadow_y > 0:
		sb.shadow_color = Color(0.14, 0.08, 0.04, 0.42)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(0, shadow_y)
	return sb


func _style_button(btn: Button, top_col: Color, base_col: Color, text_col: Color = Color.WHITE, font_size: int = 12, radius: int = 13, use_display: bool = true) -> void:
	var normal := _make_box(top_col, DesertPalette.UI_WOOD_FRAME, radius, 2, 3)
	normal.border_width_bottom = 4
	var hover := _make_box(top_col.lightened(0.08), DesertPalette.UI_WOOD_FRAME, radius, 2, 3)
	hover.border_width_bottom = 4
	var pressed := _make_box(base_col, DesertPalette.UI_WOOD_FRAME, radius, 2, 1)
	var disabled := _make_box(DesertPalette.UI_STONE_BASE, DesertPalette.UI_WOOD_FRAME, radius, 2, 1)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	btn.add_theme_font_size_override("font_size", font_size)
	var f := _display_font if use_display else _ui_font
	if f != null:
		btn.add_theme_font_override("font", f)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _style_label(lbl: Label, col: Color, size: int, use_display: bool = false) -> void:
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", size)
	var f := _display_font if use_display else _ui_font
	if f != null:
		lbl.add_theme_font_override("font", f)


func _get_staff_portrait(res_path: String) -> Texture2D:
	if _staff_portraits.has(res_path):
		return _staff_portraits[res_path]
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		var loaded: Resource = load(res_path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.new()
			if img.load(abs_path) == OK:
				tex = ImageTexture.create_from_image(img)
	_staff_portraits[res_path] = tex
	return tex


func _build_ui() -> void:
	visible = false
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(780, 0)
	var outer_sb := _make_box(DesertPalette.UI_PARCHMENT, DesertPalette.UI_WOOD_FRAME, 18, 3, 5)
	outer_sb.content_margin_left = 10
	outer_sb.content_margin_right = 10
	outer_sb.content_margin_top = 10
	outer_sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", outer_sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	# Carved-wood header banner
	var hdr_panel := PanelContainer.new()
	var hdr_sb := _make_box(DesertPalette.UI_WOOD_DEEP, DesertPalette.UI_WOOD_RIM, 12, 2, 2)
	hdr_sb.content_margin_left = 12
	hdr_sb.content_margin_right = 8
	hdr_sb.content_margin_top = 7
	hdr_sb.content_margin_bottom = 7
	hdr_panel.add_theme_stylebox_override("panel", hdr_sb)
	vb.add_child(hdr_panel)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	hdr_panel.add_child(hdr)

	_title_lbl = Label.new()
	_style_label(_title_lbl, Color("fff4dc"), 14, true)
	hdr.add_child(_title_lbl)

	_lv_badge = Label.new()
	_lv_badge.add_theme_stylebox_override("normal", _make_box(DesertPalette.UI_GOLD_TOP, DesertPalette.UI_WOOD_FRAME, 8, 1, 0))
	_style_label(_lv_badge, DesertPalette.UI_INK, 10, true)
	hdr.add_child(_lv_badge)

	_status_badge = Label.new()
	_style_label(_status_badge, Color.WHITE, 10, true)
	hdr.add_child(_status_badge)

	var hsp := Control.new()
	hsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hsp)

	_del_btn = Button.new()
	_del_btn.text = "DEL"
	_style_button(_del_btn, DesertPalette.UI_TERRA_TOP, DesertPalette.UI_TERRA_BASE, Color.WHITE, 10, 10)
	_del_btn.pressed.connect(_on_delete_pressed)
	hdr.add_child(_del_btn)

	_move_btn = Button.new()
	_move_btn.text = "MOVE"
	_style_button(_move_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 10, 10)
	_move_btn.pressed.connect(_on_move_pressed)
	hdr.add_child(_move_btn)

	_upg_btn = Button.new()
	_upg_btn.pressed.connect(_on_upgrade_pressed)
	hdr.add_child(_upg_btn)

	var close_b := Button.new()
	close_b.text = "✕"
	close_b.custom_minimum_size = Vector2(32, 0)
	_style_button(close_b, DesertPalette.UI_TERRA_TOP, DesertPalette.UI_TERRA_BASE, Color.WHITE, 11, 10)
	close_b.pressed.connect(func(): state.clear_selected_plot())
	hdr.add_child(close_b)

	# Tabs + quick stat chips row
	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	vb.add_child(sub_row)

	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 6)
	sub_row.add_child(_tabs_row)

	var sub_sp := Control.new()
	sub_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_row.add_child(sub_sp)

	_chips_row = HBoxContainer.new()
	_chips_row.add_theme_constant_override("separation", 6)
	sub_row.add_child(_chips_row)

	# Dynamic tab body
	_body_box = VBoxContainer.new()
	_body_box.add_theme_constant_override("separation", 8)
	vb.add_child(_body_box)


func open_tab(tab_id: String) -> void:
	_active_tab = tab_id
	refresh()


func refresh() -> void:
	var sel_plot := state.selected_plot()
	var sel_lot := state.selected_lot()
	var sel_util := state.selected_utility()
	if sel_plot.is_empty() and sel_lot.is_empty() and sel_util.is_empty():
		visible = false
		return

	if state.selected_entity_id != _last_entity_id:
		_last_entity_id = state.selected_entity_id
		_active_tab = "staff" if not sel_plot.is_empty() else "overview"

	if not sel_plot.is_empty():
		_refresh_plot(sel_plot)
	elif not sel_lot.is_empty():
		_refresh_lot(sel_lot)
	else:
		_refresh_utility(sel_util)


func _clear_container(box: Container) -> void:
	for c in box.get_children():
		c.queue_free()


func _add_chip(text_s: String, border_col: Color) -> void:
	var lbl := Label.new()
	lbl.text = " %s " % text_s
	lbl.add_theme_stylebox_override("normal", _make_box(DesertPalette.UI_PARCHMENT_DARK, border_col, 9, 1, 0))
	_style_label(lbl, DesertPalette.UI_INK, 10, true)
	_chips_row.add_child(lbl)


func _rebuild_tabs(tabs: Array) -> void:
	_clear_container(_tabs_row)
	if not tabs.has(_active_tab):
		_active_tab = str(tabs[0]) if not tabs.is_empty() else "overview"
	var labels := {
		"overview": "OVERVIEW",
		"staff": "STAFF",
		"power": "POWER",
		"stock": "STOCK",
	}
	for t in tabs:
		var tab_id := str(t)
		var btn := Button.new()
		btn.text = str(labels.get(tab_id, tab_id.to_upper()))
		var active := tab_id == _active_tab
		_style_button(
			btn,
			DesertPalette.UI_GOLD_TOP if active else DesertPalette.UI_WOOD_BODY,
			DesertPalette.UI_GOLD_BASE if active else DesertPalette.UI_WOOD_DEEP,
			DesertPalette.UI_INK if active else Color("fff2d4"),
			10,
			10
		)
		btn.pressed.connect(func():
			_active_tab = tab_id
			refresh()
		)
		_tabs_row.add_child(btn)


func _refresh_plot(p: Dictionary) -> void:
	var btype: int = int(p["type"])
	var lv: int = int(p["level"])
	var spec: Dictionary = GameCatalog.BUSINESSES[btype]
	var max_lv: int = int(spec["max_level"])
	var sc: float = float(p["access"]["score"])
	var staff_mult := state.plot_staff_income_mult(p)
	var staff_pct := roundi((staff_mult - 1.0) * 100.0)
	var inc := state.plot_income_per_minute(p)

	_title_lbl.text = str(spec["name"]).to_upper()
	_lv_badge.text = " LV %d/%d " % [lv, max_lv]
	var badge_col := DesertPalette.UI_TERRA_TOP if sc <= 0.0 else (DesertPalette.UI_GREEN_BASE if sc >= 0.88 else DesertPalette.UI_GOLD_BASE)
	_status_badge.text = " %s " % str(p["access"]["status_label"])
	_status_badge.add_theme_stylebox_override("normal", _make_box(badge_col, DesertPalette.UI_WOOD_FRAME, 8, 1, 0))
	_del_btn.visible = false

	var lock := state.upgrade_lock_reason(p)
	var upg_cost := GameCatalog.upgrade_cost_for_level(btype, lv)
	var can_upg := lock.is_empty() and state.cash >= upg_cost
	_upg_btn.visible = true
	_upg_btn.disabled = not can_upg
	_upg_btn.text = lock if not lock.is_empty() else "↑ LV%d · %s" % [lv + 1, GameCatalog.format_cash(upg_cost)]
	_style_button(
		_upg_btn,
		DesertPalette.UI_GOLD_TOP if can_upg else DesertPalette.UI_STONE_BASE,
		DesertPalette.UI_GOLD_BASE if can_upg else DesertPalette.UI_STONE_BASE,
		DesertPalette.UI_INK if can_upg else Color.WHITE,
		10,
		10
	)

	var tabs := GameCatalog.business_inspector_tabs(btype)
	_rebuild_tabs(tabs)

	_clear_container(_chips_row)
	_add_chip("+%s/MIN" % GameCatalog.format_cash(inc), DesertPalette.UI_GOLD_BASE)
	_add_chip("STAFF %d/%d (+%d%%)" % [state.plot_staff_list(p).size(), GameCatalog.STAFF_ROLES.size(), staff_pct], DesertPalette.TURQUOISE)
	var kw_now := GameCatalog.business_power_demand_kw(btype, lv, state.sim_clock.is_night())
	var rt: Dictionary = p.get("runtime", {})
	if kw_now > 0.0:
		var pr := float(rt.get("power_ratio", 1.0))
		var p_txt := "⚡ %.1f kW OK" % kw_now if pr >= 0.99 else "⚡ LOW %d%%" % roundi(pr * 100.0)
		_add_chip(p_txt, DesertPalette.UI_GREEN_BASE if pr >= 0.99 else DesertPalette.UI_TERRA_TOP)
	if float(spec.get("water_need", 0.0)) > 0.0:
		var wr := float(rt.get("water_ratio", 1.0))
		_add_chip("💧 OK" if wr >= 0.99 else "💧 LOW %d%%" % roundi(wr * 100.0), DesertPalette.WATER if wr >= 0.99 else DesertPalette.UI_TERRA_TOP)
	if int(spec.get("stock_commodity", GameCatalog.Commodity.NONE)) != GameCatalog.Commodity.NONE:
		var smax := float(rt.get("stock_max", 1.0))
		var spct := roundi(clampf(float(rt.get("stock_units", smax)) / maxf(1.0, smax), 0.0, 1.0) * 100.0)
		_add_chip("📦 %d%%" % spct, DesertPalette.UI_GREEN_BASE if spct >= 35 else DesertPalette.UI_TERRA_TOP)

	_clear_container(_body_box)
	match _active_tab:
		"staff":
			_build_staff_tab(p, btype)
		"power":
			_build_power_tab(p, btype, lv, spec)
		"stock":
			_build_stock_tab(p, spec)
		_:
			_build_overview_tab(p, btype, lv, spec)


func _build_overview_tab(p: Dictionary, btype: int, lv: int, spec: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body_box.add_child(row)

	var parcel := OutpostLayout.parcel_of(int(p["grid_x"]), int(p["grid_z"]))
	var tr_id := state.world_grid.parcel_trait(parcel)
	var tr_spec := GameCatalog.parcel_trait_spec(tr_id)
	var appeal := state.world_grid.tile_appeal(Vector2i(int(p["grid_x"]), int(p["grid_z"])))

	_add_info_card(row, "ACCESS & LOCATION", [
		"Road Access: %d%% (%s)" % [roundi(float(p["access"]["score"]) * 100.0), str(p["access"]["status_label"])],
		"Zone Trait: %s" % str(tr_spec["name"]),
		"Local Appeal Bonus: +%d%%" % roundi(appeal * 100.0),
	])
	var day_kw := GameCatalog.business_power_demand_kw(btype, lv, false)
	var night_kw := GameCatalog.business_power_demand_kw(btype, lv, true)
	var water_need := float(spec.get("water_need", 0.0))
	_add_info_card(row, "UTILITY PROFILE", [
		"Power Need: %s" % ("Off-Grid (0 kW)" if day_kw <= 0.0 else "%.1f kW day · %.1f kW night" % [day_kw, night_kw]),
		"Water Need: %s" % ("None" if water_need <= 0.0 else "%.0f units/day" % water_need),
		"Rooftop Solar: %s" % ("Supported" if bool(spec.get("power_profile", {}).get("supports_rooftop_solar", false)) else "Not supported"),
	])


func _build_power_tab(p: Dictionary, btype: int, lv: int, spec: Dictionary) -> void:
	var prof: Dictionary = spec.get("power_profile", {})
	var rt: Dictionary = p.get("runtime", {})
	var day_kw := GameCatalog.business_power_demand_kw(btype, lv, false)
	var night_kw := GameCatalog.business_power_demand_kw(btype, lv, true)
	var sup_kw := float(rt.get("power_supplied_kw", 0.0))
	var dem_kw := float(rt.get("power_demand_kw", day_kw))
	var ratio := float(rt.get("power_ratio", 1.0))
	var solar_pct := roundi(state.sim_clock.solar_factor() * 100.0)
	var g := state.power_network.grid_for_node("plot:%s" % str(p["id"]))
	var g_bat_cap := float(g.get("battery_cap", 0.0))
	var g_bat_str := "No batteries on grid" if g_bat_cap <= 0.0 else "Grid Batteries: %.0f / %.0f kWh" % [float(g.get("battery_stored", 0.0)), g_bat_cap]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body_box.add_child(row)
	_add_info_card(row, "LIVE POWER STATUS", [
		"Supply: %.1f / %.1f kW  (%d%% Efficiency)" % [sup_kw, dem_kw, roundi(ratio * 100.0)],
		"Day Load: %.1f kW  |  Night Peak: %.1f kW" % [day_kw, night_kw],
		"%s  ·  Solar %d%% (%s)" % [g_bat_str, solar_pct, state.sim_clock.phase_name()],
	])

	# Interactive Rooftop Solar Kit card
	var solar_card := PanelContainer.new()
	solar_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var has_solar := state.plot_has_rooftop_solar(p)
	var sb := _make_box(Color("e6f0de") if has_solar else DesertPalette.UI_PARCHMENT_DARK, DesertPalette.UI_GREEN_BASE if has_solar else DesertPalette.UI_WOOD_RIM, 12, 2, 2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	solar_card.add_theme_stylebox_override("panel", sb)
	row.add_child(solar_card)

	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 6)
	solar_card.add_child(svb)
	var sh := Label.new()
	sh.text = "ROOFTOP SOLAR PANELS"
	_style_label(sh, DesertPalette.UI_WOOD_DEEP, 10, true)
	svb.add_child(sh)

	var supports := bool(prof.get("supports_rooftop_solar", false))
	var rkw := GameCatalog.rooftop_solar_kw(btype)
	var rcost := GameCatalog.rooftop_solar_cost(btype)
	var sl := Label.new()
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if not supports:
		sl.text = "This open-air structure cannot mount rooftop panels. Connect via Windmill, Pole, or Buried Wire."
	elif has_solar:
		sl.text = "Generating %.1f / %.1f kW right now (%d%% sun). Surplus exports to connected grid." % [rkw * state.sim_clock.solar_factor(), rkw, solar_pct]
	else:
		sl.text = "Zero land used · +%.1f kW peak daytime power · Exports surplus to your grid." % rkw
	_style_label(sl, DesertPalette.UI_INK, 11, false)
	svb.add_child(sl)

	if supports:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 32)
		if has_solar:
			btn.text = "ROOFTOP SOLAR INSTALLED ✓"
			btn.disabled = true
			_style_button(btn, DesertPalette.UI_GREEN_TOP, DesertPalette.UI_GREEN_BASE, Color.WHITE, 10, 10)
		else:
			var can_buy := state.cash >= rcost and state.outpost_stage() >= 2
			btn.text = "STAGE 2 REQUIRED" if state.outpost_stage() < 2 else "INSTALL SOLAR (+%.1f kW) · %s" % [rkw, GameCatalog.format_cash(rcost)]
			btn.disabled = not can_buy
			_style_button(btn, DesertPalette.UI_GREEN_TOP if can_buy else DesertPalette.UI_STONE_BASE, DesertPalette.UI_GREEN_BASE if can_buy else DesertPalette.UI_STONE_BASE, Color.WHITE, 10, 10)
			var p_ref: Dictionary = p
			btn.pressed.connect(func(): state.install_rooftop_solar(p_ref))
		svb.add_child(btn)


func _build_stock_tab(p: Dictionary, spec: Dictionary) -> void:
	var cid: int = int(spec.get("stock_commodity", GameCatalog.Commodity.NONE))
	var cspec := GameCatalog.commodity_spec(cid)
	var rt: Dictionary = p.get("runtime", GameCatalog.make_runtime_bag(int(p["type"])))
	var smax := float(rt.get("stock_max", float(spec.get("stock_capacity", 30.0))))
	var scur := clampf(float(rt.get("stock_units", smax)), 0.0, maxf(1.0, smax))
	var pct := roundi((scur / maxf(1.0, smax)) * 100.0)
	var in_transit := bool(rt.get("restock_in_transit", false))
	var auto_on := bool(rt.get("auto_restock", false))
	var can_auto := state.supply_sim.can_auto_restock_plot(p, state)
	var local_prod := float(state.supply_sim.production_per_min.get(cid, 0.0))
	var rcost := state.supply_sim.restock_cost_for_plot(p)
	var tier := int(rt.get("price_tier", GameCatalog.PriceTier.FAIR))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body_box.add_child(row)

	# Left card: Inventory & Restock Controls
	var inv_card := PanelContainer.new()
	inv_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var isb := _make_box(DesertPalette.UI_PARCHMENT_DARK, DesertPalette.UI_WOOD_RIM, 12, 2, 2)
	isb.content_margin_left = 12
	isb.content_margin_right = 12
	isb.content_margin_top = 8
	isb.content_margin_bottom = 8
	inv_card.add_theme_stylebox_override("panel", isb)
	row.add_child(inv_card)

	var ivb := VBoxContainer.new()
	ivb.add_theme_constant_override("separation", 6)
	inv_card.add_child(ivb)
	var ih := Label.new()
	ih.text = "SHELF INVENTORY · %s" % str(cspec["name"]).to_upper()
	_style_label(ih, DesertPalette.UI_WOOD_DEEP, 10, true)
	ivb.add_child(ih)

	var il := Label.new()
	var src_txt := "Local supply: +%.1f/min free!" % local_prod if local_prod > 0.0 else ("Wholesale: -20% Depot discount" if state.supply_sim.has_freight_depot else "Wholesale: Route 163 Delivery Truck")
	il.text = "Stock: %.0f / %.0f (%d%%)  ·  %s" % [scur, smax, pct, src_txt]
	il.autowrap_mode = TextServer.AUTOWRAP_WORD
	_style_label(il, DesertPalette.UI_INK, 11, false)
	ivb.add_child(il)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	ivb.add_child(btn_row)

	var restock_b := Button.new()
	restock_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restock_b.custom_minimum_size = Vector2(0, 32)
	if in_transit:
		restock_b.text = "TRUCK EN ROUTE..."
		restock_b.disabled = true
		_style_button(restock_b, DesertPalette.UI_GOLD_TOP, DesertPalette.UI_GOLD_BASE, DesertPalette.UI_INK, 10, 10)
	elif rcost <= 0.0:
		restock_b.text = "SHELVES FULL ✓"
		restock_b.disabled = true
		_style_button(restock_b, DesertPalette.UI_GREEN_TOP, DesertPalette.UI_GREEN_BASE, Color.WHITE, 10, 10)
	else:
		var ok := state.cash >= rcost
		restock_b.text = "RESTOCK · %s" % GameCatalog.format_cash(rcost)
		restock_b.disabled = not ok
		_style_button(restock_b, DesertPalette.UI_GREEN_TOP if ok else DesertPalette.UI_STONE_BASE, DesertPalette.UI_GREEN_BASE if ok else DesertPalette.UI_STONE_BASE, Color.WHITE, 10, 10)
		var p_ref: Dictionary = p
		restock_b.pressed.connect(func(): state.order_restock_for_plot(p_ref))
	btn_row.add_child(restock_b)

	var auto_b := Button.new()
	auto_b.custom_minimum_size = Vector2(138, 32)
	if not can_auto:
		auto_b.text = "AUTO (CLERK/DEPOT)"
		auto_b.disabled = true
		_style_button(auto_b, DesertPalette.UI_STONE_BASE, DesertPalette.UI_STONE_BASE, Color.WHITE, 9, 10)
	else:
		auto_b.text = "AUTO: ON ✓" if auto_on else "AUTO: OFF"
		_style_button(auto_b, DesertPalette.UI_GREEN_TOP if auto_on else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_GREEN_BASE if auto_on else DesertPalette.UI_WOOD_DEEP, Color.WHITE, 10, 10)
		var p_ref2: Dictionary = p
		auto_b.pressed.connect(func(): state.toggle_auto_restock_for_plot(p_ref2))
	btn_row.add_child(auto_b)

	# Right card: 3-Tier Pricing Controls
	var pr_card := PanelContainer.new()
	pr_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr_card.add_theme_stylebox_override("panel", isb)
	row.add_child(pr_card)

	var pvb := VBoxContainer.new()
	pvb.add_theme_constant_override("separation", 6)
	pr_card.add_child(pvb)
	var ph := Label.new()
	ph.text = "STORE PRICING TIER"
	_style_label(ph, DesertPalette.UI_WOOD_DEEP, 10, true)
	pvb.add_child(ph)

	var pl := Label.new()
	pl.text = str(GameCatalog.price_tier_spec(tier)["desc"])
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_style_label(pl, DesertPalette.UI_INK, 11, false)
	pvb.add_child(pl)

	var t_row := HBoxContainer.new()
	t_row.add_theme_constant_override("separation", 6)
	pvb.add_child(t_row)
	for tid_raw in [GameCatalog.PriceTier.VALUE, GameCatalog.PriceTier.FAIR, GameCatalog.PriceTier.MARKUP]:
		var tid: int = int(tid_raw)
		var tspec := GameCatalog.price_tier_spec(tid)
		var tb := Button.new()
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 32)
		tb.text = "%s\n%s" % [tspec["name"], tspec["short"]]
		var sel: bool = tid == tier
		_style_button(tb, DesertPalette.UI_GOLD_TOP if sel else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_GOLD_BASE if sel else DesertPalette.UI_WOOD_DEEP, DesertPalette.UI_INK if sel else Color.WHITE, 9, 9)
		var p_ref3: Dictionary = p
		var t_val: int = tid
		tb.pressed.connect(func(): state.set_plot_price_tier(p_ref3, t_val))
		t_row.add_child(tb)


func _build_staff_tab(p: Dictionary, btype: int) -> void:
	var m_pct := roundi(state.staff_sim.morale * 100.0)
	var m_lbl := Label.new()
	m_lbl.text = "STAFF MORALE %d%% (%s) · Multiplies all staff income bonuses" % [m_pct, state.staff_sim.morale_breakdown]
	_style_label(m_lbl, DesertPalette.UI_INK_MUTED, 11, false)
	_body_box.add_child(m_lbl)

	var staff_list := HBoxContainer.new()
	staff_list.add_theme_constant_override("separation", 10)
	_body_box.add_child(staff_list)

	for role_item in GameCatalog.STAFF_ROLES:
		var role: Dictionary = GameCatalog.staff_role_for_business(btype, role_item)
		var hired := state.plot_has_staff(p, str(role["id"]))
		var r_lock := state.staff_lock_reason(p, role)
		var r_cost := GameCatalog.staff_hire_cost(btype, role)
		var can_hire := r_lock.is_empty() and state.cash >= r_cost
		var accent: Color = role["accent"]

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_bg := Color("e6f0de") if hired else DesertPalette.UI_PARCHMENT_DARK
		var card_border := DesertPalette.UI_GREEN_BASE if hired else DesertPalette.UI_WOOD_RIM
		var card_sb := _make_box(card_bg, card_border, 14, 2, 3)
		card_sb.content_margin_left = 10
		card_sb.content_margin_right = 10
		card_sb.content_margin_top = 9
		card_sb.content_margin_bottom = 9
		card.add_theme_stylebox_override("panel", card_sb)
		staff_list.add_child(card)

		var cvb := VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 8)
		card.add_child(cvb)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)
		cvb.add_child(top_row)

		var p_frame := PanelContainer.new()
		p_frame.custom_minimum_size = Vector2(72, 72)
		var pf_sb := _make_box(DesertPalette.UI_WOOD_DEEP, DesertPalette.UI_GREEN_TOP if hired else accent, 12, 2, 2)
		pf_sb.content_margin_left = 2
		pf_sb.content_margin_right = 2
		pf_sb.content_margin_top = 2
		pf_sb.content_margin_bottom = 2
		p_frame.add_theme_stylebox_override("panel", pf_sb)
		p_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		top_row.add_child(p_frame)

		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		var portrait_tex := _get_staff_portrait(str(role["portrait"]))
		if portrait_tex != null:
			tr.texture = portrait_tex
		p_frame.add_child(tr)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		info_vb.add_theme_constant_override("separation", 4)
		top_row.add_child(info_vb)

		var name_l := Label.new()
		name_l.text = str(role["name"]).to_upper()
		_style_label(name_l, DesertPalette.UI_INK, 11, true)
		info_vb.add_child(name_l)

		var tag_l := Label.new()
		tag_l.text = " %s " % str(role["boost_tag"])
		tag_l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var tag_sb := _make_box(accent, DesertPalette.UI_WOOD_FRAME, 7, 1, 0)
		tag_sb.content_margin_left = 6
		tag_sb.content_margin_right = 6
		tag_sb.content_margin_top = 2
		tag_sb.content_margin_bottom = 2
		tag_l.add_theme_stylebox_override("normal", tag_sb)
		_style_label(tag_l, Color.WHITE, 9, true)
		info_vb.add_child(tag_l)

		var perk_l := Label.new()
		perk_l.text = str(role["perk_short"])
		perk_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_style_label(perk_l, DesertPalette.UI_INK, 11, false)
		info_vb.add_child(perk_l)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 32)
		if hired:
			btn.text = "ON DUTY ✓"
			btn.disabled = true
			_style_button(btn, DesertPalette.UI_GREEN_TOP, DesertPalette.UI_GREEN_BASE, Color.WHITE, 11, 10)
		elif not r_lock.is_empty():
			btn.text = "UNLOCKS AT %s" % r_lock
			btn.disabled = true
			_style_button(btn, DesertPalette.UI_STONE_BASE, DesertPalette.UI_STONE_BASE, Color.WHITE, 10, 10)
		else:
			btn.text = "HIRE · %s" % GameCatalog.format_cash(r_cost)
			btn.disabled = not can_hire
			_style_button(
				btn,
				DesertPalette.UI_GREEN_TOP if can_hire else DesertPalette.UI_STONE_BASE,
				DesertPalette.UI_GREEN_BASE if can_hire else DesertPalette.UI_STONE_BASE,
				Color.WHITE,
				11,
				10
			)
			var p_ref: Dictionary = p
			var r_ref: Dictionary = role
			btn.pressed.connect(func(): state.hire_staff_for_plot(p_ref, r_ref))
		cvb.add_child(btn)


func _refresh_lot(lot: Dictionary) -> void:
	var spec: Dictionary = GameCatalog.PARKING_LOTS[lot["kind"]]
	var conn := bool(lot["is_connected"])
	var lock := state.parking_upgrade_lock_reason(lot)
	var cost := state.parking_upgrade_cost(lot)
	var can_upg := lock.is_empty() and state.cash >= cost

	_title_lbl.text = str(spec["name"]).to_upper()
	_lv_badge.text = " %d BAYS " % int(spec["spaces"])
	_status_badge.text = " ROAD OK " if conn else " NO ROAD "
	_status_badge.add_theme_stylebox_override("normal", _make_box(DesertPalette.UI_GREEN_BASE if conn else DesertPalette.UI_TERRA_TOP, DesertPalette.UI_WOOD_FRAME, 8, 1, 0))
	_del_btn.visible = true

	_upg_btn.visible = true
	_upg_btn.disabled = not can_upg
	_upg_btn.text = lock if not lock.is_empty() else "↑ UPGRADE · %s" % GameCatalog.format_cash(cost)
	_style_button(
		_upg_btn,
		DesertPalette.UI_GOLD_TOP if can_upg else DesertPalette.UI_STONE_BASE,
		DesertPalette.UI_GOLD_BASE if can_upg else DesertPalette.UI_STONE_BASE,
		DesertPalette.UI_INK if can_upg else Color.WHITE,
		10,
		10
	)

	_rebuild_tabs(["overview"])
	_clear_container(_chips_row)
	_add_chip("TIER %d" % int(spec["tier"]), DesertPalette.UI_WOOD_RIM)

	_clear_container(_body_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body_box.add_child(row)
	_add_info_card(row, "PARKING LOT DETAILS", [
		str(spec["subtitle"]),
		"Highway Link: %s" % ("Connected · Accepting Route 163 traffic" if conn else "Disconnected · Build a road adjacent to the lot"),
	])


func _add_info_card(parent: HBoxContainer, heading: String, lines: Array) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := _make_box(DesertPalette.UI_PARCHMENT_DARK, DesertPalette.UI_WOOD_RIM, 12, 2, 2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var hl := Label.new()
	hl.text = heading
	_style_label(hl, DesertPalette.UI_WOOD_DEEP, 10, true)
	vb.add_child(hl)

	for ln in lines:
		var l := Label.new()
		l.text = str(ln)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_style_label(l, DesertPalette.UI_INK, 11, false)
		vb.add_child(l)


func _refresh_utility(u: Dictionary) -> void:
	var ukind: int = int(u["kind"])
	var spec: Dictionary = GameCatalog.UTILITIES[ukind]
	var grp := GameCatalog.utility_group(ukind)
	var live_kw := PowerNetwork.utility_output_kw(u, state.world_grid, state.sim_clock.solar_factor())
	var bcap := float(spec.get("battery_kwh", 0.0))
	var wout := WaterNetwork.water_output_for_utility(u, state.world_grid)
	var prod := float(u.get("live_prod", 0.0))
	var p_need := float(spec.get("power_need_kw", 0.0))
	var w_need := float(spec.get("water_need", 0.0))
	var p_ratio := float(u.get("power_ratio", 1.0))
	var w_ratio := float(u.get("water_ratio", 1.0))
	var g := state.power_network.grid_for_node("util:%s" % str(u["id"]))
	var g_plots := (g.get("plot_ids", []) as Array).size()

	_title_lbl.text = str(spec["name"]).to_upper()
	if bcap > 0.0:
		var soc := roundi(clampf(float(u.get("stored_kwh", 0.0)) / bcap, 0.0, 1.0) * 100.0)
		_lv_badge.text = " %d%% CHARGE " % soc
	elif grp == "water":
		_lv_badge.text = " +%.1f WATER " % wout
	elif grp == "supply":
		if ukind == GameCatalog.UtilityKind.FREIGHT_DEPOT:
			_lv_badge.text = " -20% WHOLESALE "
		else:
			var cid := int(spec.get("produces", GameCatalog.Commodity.NONE))
			_lv_badge.text = " +%.1f %s/M " % [prod, str(GameCatalog.commodity_spec(cid)["short"])]
	else:
		_lv_badge.text = " %.1f kW " % live_kw

	var healthy := (p_need <= 0.0 or p_ratio >= 0.99) and (w_need <= 0.0 or w_ratio >= 0.99)
	if grp == "power":
		_status_badge.text = " %d BLDGS LINKED " % g_plots if g_plots > 0 else " STANDALONE "
		_status_badge.add_theme_stylebox_override("normal", _make_box(DesertPalette.UI_GREEN_BASE if g_plots > 0 else DesertPalette.UI_GOLD_BASE, DesertPalette.UI_WOOD_FRAME, 8, 1, 0))
	else:
		_status_badge.text = " ACTIVE 100% " if healthy else " LOW UTILITY "
		_status_badge.add_theme_stylebox_override("normal", _make_box(DesertPalette.UI_GREEN_BASE if healthy else DesertPalette.UI_TERRA_TOP, DesertPalette.UI_WOOD_FRAME, 8, 1, 0))
	_del_btn.visible = true
	_upg_btn.visible = false

	_rebuild_tabs(["overview"])
	_clear_container(_chips_row)
	var cell := Vector2i(int(u["grid_x"]), int(u["grid_z"]))
	if ukind == GameCatalog.UtilityKind.WINDMILL and state.world_grid.cell_trait(cell) == GameCatalog.ParcelTrait.WIND_CORRIDOR:
		_add_chip("+40% WIND CORRIDOR", DesertPalette.TURQUOISE)
	if ukind == GameCatalog.UtilityKind.WATER_WELL and state.world_grid.cell_trait(cell) == GameCatalog.ParcelTrait.AQUIFER:
		_add_chip("+80% AQUIFER", DesertPalette.WATER)
	if ukind == GameCatalog.UtilityKind.OIL_PUMPJACK:
		_add_chip("OIL SEEP", DesertPalette.UI_GOLD_BASE)
	if p_need > 0.0:
		_add_chip("⚡ %.0f kW (%d%%)" % [p_need, roundi(p_ratio * 100.0)], DesertPalette.UI_GREEN_BASE if p_ratio >= 0.99 else DesertPalette.UI_TERRA_TOP)
	if w_need > 0.0:
		_add_chip("💧 %.0f (%d%%)" % [w_need, roundi(w_ratio * 100.0)], DesertPalette.WATER if w_ratio >= 0.99 else DesertPalette.UI_TERRA_TOP)
	if float(spec.get("upkeep_per_min", 0.0)) > 0.0:
		if state.supply_sim.diesel_fuel_covered:
			_add_chip("REFINED FUEL FREE ✓", DesertPalette.UI_GREEN_BASE)
		else:
			_add_chip("-$%.0f/MIN FUEL" % float(spec["upkeep_per_min"]), DesertPalette.UI_TERRA_TOP)

	_clear_container(_body_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body_box.add_child(row)
	var lines: Array = [str(spec["subtitle"])]
	if bcap > 0.0:
		lines.append("Stored Energy: %.1f / %.0f kWh (Max %.0f kW charge/discharge)" % [float(u.get("stored_kwh", 0.0)), bcap, float(spec["max_io_kw"])])
	elif grp == "water":
		var wnet := state.water_network.network_for_node("util:%s" % str(u["id"]))
		lines.append("Connected Pipe Network: %.1f supply / %.1f demand" % [float(wnet.get("supply", wout)), float(wnet.get("demand", 0.0))])
	elif grp == "supply":
		if ukind == GameCatalog.UtilityKind.FREIGHT_DEPOT:
			lines.append("All stores can enable Auto-Restock and enjoy 20% cheaper Route 163 truck deliveries.")
		else:
			lines.append("Output: %.1f / min  |  Surplus Oil/Fuel Auto-Exports: +$%.1f/min" % [prod, state.supply_sim.export_income_per_min])
	elif bool(spec.get("is_solar", false)):
		lines.append("Live Solar Output: %.1f / %.1f kW (%d%% sun)" % [live_kw, float(spec["base_kw"]), roundi(state.sim_clock.solar_factor() * 100.0)])
	else:
		lines.append("Live Output: %.1f kW (24/7 steady generation)" % live_kw)
	if grp == "power":
		lines.append("Connected Grid: %.1f kW gen / %.1f kW load" % [float(g.get("gen_kw", live_kw)), float(g.get("demand_kw", 0.0))])
	_add_info_card(row, "%s TELEMETRY" % grp.to_upper(), lines)


func _on_move_pressed() -> void:
	var p := state.selected_plot()
	if not p.is_empty():
		state.start_relocating_plot(p)
		return
	var l := state.selected_lot()
	if not l.is_empty():
		state.start_relocating_parking(l)
		return
	var u := state.selected_utility()
	if not u.is_empty():
		state.start_relocating_utility(u)


func _on_upgrade_pressed() -> void:
	var p := state.selected_plot()
	if not p.is_empty():
		state.upgrade_plot(p)
		return
	var l := state.selected_lot()
	if not l.is_empty():
		state.upgrade_parking_lot(l)


func _on_delete_pressed() -> void:
	var l := state.selected_lot()
	if not l.is_empty():
		state.remove_parking_lot(l)
		state.clear_selected_plot()
		return
	var u := state.selected_utility()
	if not u.is_empty():
		state.remove_utility(u)
		state.clear_selected_plot()
