class_name DesertHud
extends CanvasLayer

## Full Desert Outpost carved-wood & parchment HUD:
## Top cash/stage/milestone bar, right camera controls, 3D-projected floating bubbles
## & cash popups, bottom play bar, horizontal Build & Upgrade/Move trays,
## Road Line / Placement / Land tool bars, and Settings & Milestones modal.

var state: GameState
var camera: DesertCamera

enum TrayMode { NONE, BUILD, UPGRADE, CREW }
var _tray_mode: int = TrayMode.NONE
var _menu_open := false

var _display_font: Font
var _ui_font: Font

# Layers
var _bubbles_layer: Control
var _popups_layer: Control
var _top_bar: MarginContainer
var _offline_btn: Button
var _cash_lbl: Label
var _rate_lbl: Label
var _stage_btn: Button
var _clock_lbl: Label
var _speed_btn: Button
var _power_btn: Button
var _water_btn: Button
var _milestone_btn: Button
var _menu_badge: Label
var _lens_banner: Label
var _lens_btns: Dictionary = {} # MapLens -> Button

var _bottom_host: MarginContainer
var _tray_panel: PanelContainer
var _tray_title: Label
var _tray_filters_row: HBoxContainer
var _build_filter := "all"
var _tray_list: HBoxContainer
var _inspector: StructureInspector
var _play_bar: HBoxContainer
var _serve_btn: Button
var _build_dot: ColorRect
var _roads_dot: ColorRect
var _crew_dot: ColorRect
var _upgrade_dot: ColorRect

var _road_bar: PanelContainer
var _road_hint: Label
var _road_junc: Label
var _road_tier_btns: Array[Button] = []
var _road_width_btn: Button
var _road_erase_btn: Button
var _road_clear_btn: Button
var _road_confirm_btn: Button

var _pole_bar: PanelContainer
var _pole_hint: Label
var _pole_kind_btns: Array[Button] = []
var _pole_erase_btn: Button

var _conduit_bar: PanelContainer
var _conduit_hint: Label
var _conduit_erase_btn: Button
var _conduit_clear_btn: Button
var _conduit_confirm_btn: Button

var _pipe_bar: PanelContainer
var _pipe_hint: Label
var _pipe_erase_btn: Button
var _pipe_clear_btn: Button
var _pipe_confirm_btn: Button

var _place_bar: PanelContainer
var _place_badge: Label
var _place_title: Label
var _place_hint: Label
var _place_rot_btn: Button
var _place_confirm_btn: Button

var _land_bar: PanelContainer
var _land_title: Label
var _land_hint: Label

var _menu_backdrop: ColorRect
var _menu_stats: Array[Label] = []
var _menu_stage_lbl: Label
var _menu_auto_btn: Button
var _menu_milestones_box: VBoxContainer

var _bubble_pool: Array[Button] = []
var _popup_pool: Array[Label] = []
var _hold_ring: Control
var _hold_ring_pos := Vector2.ZERO
var _hold_ring_prog := 0.0
var _hud_dirty := true


func setup(game_state: GameState, cam: DesertCamera) -> void:
	state = game_state
	camera = cam
	_display_font = DesertPalette.get_display_font()
	_ui_font = DesertPalette.get_ui_font()
	_build_ui()
	state.hud_changed.connect(func(): _hud_dirty = true)
	state.world_layout_changed.connect(func(): _hud_dirty = true)
	state.overlay_changed.connect(func(): _hud_dirty = true)
	_refresh_hud()


func is_modal_open() -> bool:
	return _menu_open


func close_tray_if_open() -> void:
	if _tray_mode != TrayMode.NONE:
		_tray_mode = TrayMode.NONE
		_refresh_hud()


func set_hold_indicator(screen_pos: Vector2, progress: float) -> void:
	_hold_ring_pos = screen_pos
	_hold_ring_prog = clampf(progress, 0.0, 1.0)
	if _hold_ring != null:
		_hold_ring.visible = _hold_ring_prog > 0.0
		_hold_ring.queue_redraw()


func clear_hold_indicator() -> void:
	if _hold_ring_prog > 0.0:
		_hold_ring_prog = 0.0
		if _hold_ring != null:
			_hold_ring.visible = false
			_hold_ring.queue_redraw()


func _draw_hold_ring() -> void:
	if _hold_ring == null or _hold_ring_prog <= 0.0:
		return
	var r := lerpf(16.0, 30.0, _hold_ring_prog)
	_hold_ring.draw_arc(_hold_ring_pos, r, 0.0, TAU, 28, Color(0.18, 0.11, 0.06, 0.55), 5.0, true)
	_hold_ring.draw_arc(_hold_ring_pos, r, -PI * 0.5, -PI * 0.5 + TAU * _hold_ring_prog, 28, DesertPalette.UI_GOLD_TOP, 3.5, true)


# --- Styled Widget Helpers ---

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
	normal.border_color = DesertPalette.UI_WOOD_FRAME
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


# --- Build Complete UI Tree ---

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 1. Floating in-world bubbles & rising cash popups behind HUD chrome
	_bubbles_layer = Control.new()
	_bubbles_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bubbles_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bubbles_layer)

	_popups_layer = Control.new()
	_popups_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popups_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_popups_layer)

	_hold_ring = Control.new()
	_hold_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hold_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_ring.visible = false
	_hold_ring.draw.connect(_draw_hold_ring)
	root.add_child(_hold_ring)

	# 2. Top HUD Bar
	_top_bar = MarginContainer.new()
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.add_theme_constant_override("margin_left", 14)
	_top_bar.add_theme_constant_override("margin_right", 14)
	_top_bar.add_theme_constant_override("margin_top", 12)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top_bar)

	var top_col := VBoxContainer.new()
	top_col.add_theme_constant_override("separation", 8)
	top_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(top_col)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_col.add_child(top_row)

	# Cash pill
	var cash_panel := PanelContainer.new()
	cash_panel.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_WOOD_FRAME, DesertPalette.UI_GOLD_TOP, 18, 2, 3))
	top_row.add_child(cash_panel)
	var cash_hb := HBoxContainer.new()
	cash_hb.add_theme_constant_override("separation", 8)
	cash_panel.add_child(cash_hb)
	var coin_lbl := Label.new()
	coin_lbl.text = "$"
	_style_label(coin_lbl, DesertPalette.UI_GOLD_TOP, 18, true)
	cash_hb.add_child(coin_lbl)
	var cash_vb := VBoxContainer.new()
	cash_vb.add_theme_constant_override("separation", -2)
	cash_hb.add_child(cash_vb)
	_cash_lbl = Label.new()
	_style_label(_cash_lbl, Color.WHITE, 16, true)
	cash_vb.add_child(_cash_lbl)
	_rate_lbl = Label.new()
	_style_label(_rate_lbl, Color("ffd991"), 11, false)
	cash_vb.add_child(_rate_lbl)

	# Stage badge
	_stage_btn = Button.new()
	_style_button(_stage_btn, DesertPalette.UI_WOOD_FRAME, DesertPalette.UI_WOOD_DEEP, DesertPalette.UI_GOLD_TOP, 11, 14)
	_stage_btn.pressed.connect(_open_menu)
	top_row.add_child(_stage_btn)

	# Clock & Sim Speed Pill
	var clock_panel := PanelContainer.new()
	clock_panel.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_WOOD_FRAME, DesertPalette.UI_WOOD_RIM, 14, 2, 2))
	top_row.add_child(clock_panel)
	var clk_hb := HBoxContainer.new()
	clk_hb.add_theme_constant_override("separation", 6)
	clock_panel.add_child(clk_hb)
	_clock_lbl = Label.new()
	_style_label(_clock_lbl, Color("fff2d4"), 11, true)
	clk_hb.add_child(_clock_lbl)
	_speed_btn = Button.new()
	_speed_btn.custom_minimum_size = Vector2(36, 26)
	_style_button(_speed_btn, DesertPalette.UI_GOLD_TOP, DesertPalette.UI_GOLD_BASE, DesertPalette.UI_INK, 10, 9)
	_speed_btn.pressed.connect(func(): state.cycle_sim_speed())
	clk_hb.add_child(_speed_btn)

	# Compact Power Grid Status Pill (toggles PWR lens)
	_power_btn = Button.new()
	_power_btn.visible = false
	_style_button(_power_btn, DesertPalette.UI_WOOD_FRAME, DesertPalette.UI_WOOD_DEEP, DesertPalette.UI_GOLD_TOP, 10, 14)
	_power_btn.pressed.connect(func():
		var nxt := GameCatalog.MapLens.NONE if state.active_lens == GameCatalog.MapLens.POWER else GameCatalog.MapLens.POWER
		state.set_map_lens(nxt)
	)
	top_row.add_child(_power_btn)

	# Compact Water Pipe Status Pill (toggles H2O lens)
	_water_btn = Button.new()
	_water_btn.visible = false
	_style_button(_water_btn, DesertPalette.UI_WOOD_FRAME, DesertPalette.UI_WOOD_DEEP, Color("8ee6f5"), 10, 14)
	_water_btn.pressed.connect(func():
		var nxt := GameCatalog.MapLens.NONE if state.active_lens == GameCatalog.MapLens.WATER else GameCatalog.MapLens.WATER
		state.set_map_lens(nxt)
	)
	top_row.add_child(_water_btn)

	# Milestone pill
	_milestone_btn = Button.new()
	_style_button(_milestone_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 11, 16)
	_milestone_btn.pressed.connect(_on_milestone_pill_pressed)
	top_row.add_child(_milestone_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)

	# Settings gear button + badge
	var gear_wrap := Control.new()
	gear_wrap.custom_minimum_size = Vector2(44, 42)
	top_row.add_child(gear_wrap)
	var gear_btn := Button.new()
	gear_btn.text = "MENU"
	gear_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_button(gear_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 10, 14)
	gear_btn.pressed.connect(_open_menu)
	gear_wrap.add_child(gear_btn)
	_menu_badge = Label.new()
	_menu_badge.position = Vector2(28, -6)
	_menu_badge.add_theme_stylebox_override("normal", _make_box(DesertPalette.UI_GOLD_TOP, DesertPalette.UI_WOOD_FRAME, 8, 1, 0))
	_style_label(_menu_badge, DesertPalette.UI_INK, 10, true)
	gear_wrap.add_child(_menu_badge)

	# Active map lens banner
	_lens_banner = Label.new()
	_lens_banner.visible = false
	_lens_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lens_banner.add_theme_stylebox_override("normal", _make_box(DesertPalette.UI_WOOD_DEEP, DesertPalette.UI_GOLD_TOP, 12, 2, 2))
	_style_label(_lens_banner, Color("fff4dc"), 11, true)
	top_col.add_child(_lens_banner)

	# Offline welcome back banner
	_offline_btn = Button.new()
	_offline_btn.visible = false
	_offline_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(_offline_btn, DesertPalette.UI_GOLD_TOP, DesertPalette.UI_GOLD_BASE, DesertPalette.UI_INK, 11, 14)
	_offline_btn.pressed.connect(func():
		state.pending_offline_cash = 0.0
		state.pending_offline_minutes = 0
		_refresh_hud()
	)
	top_col.add_child(_offline_btn)

	# 3. Right-edge Camera Controls + Map Lens Strip
	var cam_box := VBoxContainer.new()
	cam_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cam_box.offset_left = -58
	cam_box.offset_right = -12
	cam_box.offset_top = 80
	cam_box.add_theme_constant_override("separation", 7)
	root.add_child(cam_box)
	for spec in [
		["↺", func(): camera.rotate_quarter(-1)],
		["↻", func(): camera.rotate_quarter(1)],
		["3D", func(): camera.cycle_pitch_preset()],
		["◎", func(): state.reset_camera_smooth()],
	]:
		var cb := Button.new()
		cb.text = spec[0]
		cb.custom_minimum_size = Vector2(44, 38)
		_style_button(cb, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 13, 12)
		cb.pressed.connect(spec[1])
		cam_box.add_child(cb)

	var lens_div := Control.new()
	lens_div.custom_minimum_size = Vector2(0, 6)
	cam_box.add_child(lens_div)

	for lspec in GameCatalog.MAP_LENSES:
		var lid: int = int(lspec["id"])
		var lb := Button.new()
		lb.text = str(lspec["short"])
		lb.tooltip_text = "%s — %s" % [str(lspec["name"]), str(lspec["hint"])]
		lb.custom_minimum_size = Vector2(44, 32)
		lb.pressed.connect(func():
			var next_l := GameCatalog.MapLens.NONE if (state.active_lens == lid and lid != GameCatalog.MapLens.NONE) else lid
			state.set_map_lens(next_l)
		)
		cam_box.add_child(lb)
		_lens_btns[lid] = lb

	# 4. Bottom Controls Host
	_bottom_host = MarginContainer.new()
	_bottom_host.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_host.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom_host.add_theme_constant_override("margin_left", 14)
	_bottom_host.add_theme_constant_override("margin_right", 14)
	_bottom_host.add_theme_constant_override("margin_bottom", 14)
	_bottom_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bottom_host)

	var bot_vb := VBoxContainer.new()
	bot_vb.add_theme_constant_override("separation", 8)
	bot_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_host.add_child(bot_vb)

	# Expandable BUILD / UPGRADE Tray
	_tray_panel = PanelContainer.new()
	_tray_panel.visible = false
	_tray_panel.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT, DesertPalette.UI_WOOD_FRAME, 18, 3, 4))
	bot_vb.add_child(_tray_panel)
	var tray_vb := VBoxContainer.new()
	tray_vb.add_theme_constant_override("separation", 8)
	_tray_panel.add_child(tray_vb)
	var tray_hdr := HBoxContainer.new()
	tray_hdr.add_theme_constant_override("separation", 8)
	tray_vb.add_child(tray_hdr)
	_tray_title = Label.new()
	_style_label(_tray_title, DesertPalette.UI_INK, 12, true)
	tray_hdr.add_child(_tray_title)
	_tray_filters_row = HBoxContainer.new()
	_tray_filters_row.add_theme_constant_override("separation", 5)
	tray_hdr.add_child(_tray_filters_row)
	var tsp := Control.new()
	tsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray_hdr.add_child(tsp)
	var close_tray := Button.new()
	close_tray.text = "✕"
	_style_button(close_tray, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color.WHITE, 11, 8)
	close_tray.pressed.connect(func():
		_tray_mode = TrayMode.NONE
		_refresh_hud()
	)
	tray_hdr.add_child(close_tray)
	var tray_scroll := ScrollContainer.new()
	tray_scroll.custom_minimum_size = Vector2(0, 134)
	tray_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray_vb.add_child(tray_scroll)
	_tray_list = HBoxContainer.new()
	_tray_list.add_theme_constant_override("separation", 8)
	tray_scroll.add_child(_tray_list)

	# Modular Tabbed Structure Inspector (opens on single tap of built business or parking lot)
	_inspector = StructureInspector.new()
	_inspector.setup(state, _display_font, _ui_font)
	bot_vb.add_child(_inspector)

	# Play Bottom Row: BUILD | ROADS   [SELL/SERVE +$X]   UPGRADE
	_play_bar = HBoxContainer.new()
	_play_bar.add_theme_constant_override("separation", 10)
	_play_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_vb.add_child(_play_bar)

	var b_wrap := _make_corner_btn("BUILD", func(): _toggle_tray(TrayMode.BUILD))
	_build_dot = b_wrap[1]
	_play_bar.add_child(b_wrap[0])

	var r_wrap := _make_corner_btn("ROADS", func():
		_tray_mode = TrayMode.NONE
		state.enter_road_mode()
	)
	_roads_dot = r_wrap[1]
	_play_bar.add_child(r_wrap[0])

	var sp_l := Control.new()
	sp_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_bar.add_child(sp_l)

	_serve_btn = Button.new()
	_serve_btn.custom_minimum_size = Vector2(180, 52)
	_style_button(_serve_btn, DesertPalette.UI_TERRA_TOP, DesertPalette.UI_TERRA_BASE, Color.WHITE, 14, 22)
	_serve_btn.pressed.connect(func(): state.perform_active_tap(0))
	_play_bar.add_child(_serve_btn)

	var sp_r := Control.new()
	sp_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_bar.add_child(sp_r)

	var c_wrap := _make_corner_btn("CREW", func(): _toggle_tray(TrayMode.CREW))
	_crew_dot = c_wrap[1]
	_play_bar.add_child(c_wrap[0])

	var u_wrap := _make_corner_btn("UPGRADE", func(): _toggle_tray(TrayMode.UPGRADE))
	_upgrade_dot = u_wrap[1]
	_play_bar.add_child(u_wrap[0])

	# Road Line Tool Bar
	_build_road_bar(bot_vb)
	# Power Pole, Underground Conduit & Water Pipe Bars
	_build_pole_bar(bot_vb)
	_build_conduit_bar(bot_vb)
	_build_water_pipe_bar(bot_vb)
	# Placement Confirm Bar
	_build_placement_bar(bot_vb)
	# Buy Land Bar
	_build_land_bar(bot_vb)
	# Settings / Milestones / Presets Modal
	_build_menu_modal(root)


func _make_corner_btn(label_text: String, callback: Callable) -> Array:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(76, 52)
	var btn := Button.new()
	btn.text = label_text
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_button(btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 11, 16)
	btn.pressed.connect(callback)
	wrap.add_child(btn)
	var dot := ColorRect.new()
	dot.color = DesertPalette.UI_GREEN_TOP
	dot.size = Vector2(12, 12)
	dot.position = Vector2(64, -2)
	dot.visible = false
	wrap.add_child(dot)
	return [wrap, dot]


func _build_road_bar(parent: VBoxContainer) -> void:
	_road_bar = PanelContainer.new()
	_road_bar.visible = false
	_road_bar.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT, DesertPalette.UI_WOOD_FRAME, 18, 3, 4))
	parent.add_child(_road_bar)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_road_bar.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	_road_hint = Label.new()
	_road_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(_road_hint, DesertPalette.UI_INK, 12, false)
	hdr.add_child(_road_hint)
	_road_junc = Label.new()
	_style_label(_road_junc, DesertPalette.UI_INK_MUTED, 10, true)
	hdr.add_child(_road_junc)

	var tiers_row := HBoxContainer.new()
	tiers_row.add_theme_constant_override("separation", 6)
	vb.add_child(tiers_row)
	for tier in [GameCatalog.RoadTier.DIRT, GameCatalog.RoadTier.GRAVEL, GameCatalog.RoadTier.PAVED]:
		var tb := Button.new()
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t_val: int = tier
		tb.pressed.connect(func(): state.set_road_brush(t_val))
		tiers_row.add_child(tb)
		_road_tier_btns.append(tb)
	_road_width_btn = Button.new()
	_road_width_btn.text = "2-LANE"
	_road_width_btn.pressed.connect(func(): state.set_road_two_lane(not state.road_two_lane))
	tiers_row.add_child(_road_width_btn)

	_road_erase_btn = Button.new()
	_road_erase_btn.text = "ERASE"
	_road_erase_btn.pressed.connect(func(): state.set_road_erase(not state.road_erase_mode))
	tiers_row.add_child(_road_erase_btn)

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 6)
	vb.add_child(act_row)
	_road_clear_btn = Button.new()
	_road_clear_btn.text = "CLEAR"
	_style_button(_road_clear_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 11, 12)
	_road_clear_btn.pressed.connect(func(): state.clear_road_line())
	act_row.add_child(_road_clear_btn)

	_road_confirm_btn = Button.new()
	_road_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_road_confirm_btn.pressed.connect(func(): state.confirm_road_line())
	act_row.add_child(_road_confirm_btn)

	var done_btn := Button.new()
	done_btn.text = "DONE"
	_style_button(done_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color.WHITE, 11, 12)
	done_btn.pressed.connect(func(): state.cancel_tool_mode())
	act_row.add_child(done_btn)


func _build_pole_bar(parent: VBoxContainer) -> void:
	_pole_bar = PanelContainer.new()
	_pole_bar.visible = false
	_pole_bar.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT, DesertPalette.UI_WOOD_FRAME, 18, 3, 4))
	parent.add_child(_pole_bar)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_pole_bar.add_child(vb)

	_pole_hint = Label.new()
	_style_label(_pole_hint, DesertPalette.UI_INK, 12, false)
	vb.add_child(_pole_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	for pk in [GameCatalog.PowerLineKind.WOOD_POLE, GameCatalog.PowerLineKind.STEEL_TOWER]:
		var pb := Button.new()
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pk_val: int = pk
		pb.pressed.connect(func(): state.set_pole_kind(pk_val))
		row.add_child(pb)
		_pole_kind_btns.append(pb)

	_pole_erase_btn = Button.new()
	_pole_erase_btn.text = "ERASE"
	_pole_erase_btn.pressed.connect(func(): state.set_pole_erase(not state.pole_erase_mode))
	row.add_child(_pole_erase_btn)

	var done_b := Button.new()
	done_b.text = "DONE"
	_style_button(done_b, DesertPalette.UI_GREEN_TOP, DesertPalette.UI_GREEN_BASE, Color.WHITE, 11, 12)
	done_b.pressed.connect(func(): state.cancel_tool_mode())
	row.add_child(done_b)


func _build_conduit_bar(parent: VBoxContainer) -> void:
	_conduit_bar = PanelContainer.new()
	_conduit_bar.visible = false
	_conduit_bar.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT, DesertPalette.UI_WOOD_FRAME, 18, 3, 4))
	parent.add_child(_conduit_bar)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_conduit_bar.add_child(vb)

	_conduit_hint = Label.new()
	_style_label(_conduit_hint, DesertPalette.UI_INK, 12, false)
	vb.add_child(_conduit_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	_conduit_erase_btn = Button.new()
	_conduit_erase_btn.text = "ERASE"
	_conduit_erase_btn.pressed.connect(func(): state.set_conduit_erase(not state.conduit_erase_mode))
	row.add_child(_conduit_erase_btn)

	_conduit_clear_btn = Button.new()
	_conduit_clear_btn.text = "CLEAR"
	_style_button(_conduit_clear_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 11, 12)
	_conduit_clear_btn.pressed.connect(func(): state.clear_conduit_line())
	row.add_child(_conduit_clear_btn)

	_conduit_confirm_btn = Button.new()
	_conduit_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conduit_confirm_btn.pressed.connect(func(): state.confirm_conduit_line())
	row.add_child(_conduit_confirm_btn)

	var done_b := Button.new()
	done_b.text = "DONE"
	_style_button(done_b, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color.WHITE, 11, 12)
	done_b.pressed.connect(func(): state.cancel_tool_mode())
	row.add_child(done_b)


func _build_water_pipe_bar(parent: VBoxContainer) -> void:
	_pipe_bar = PanelContainer.new()
	_pipe_bar.visible = false
	_pipe_bar.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT, DesertPalette.UI_WOOD_FRAME, 18, 3, 4))
	parent.add_child(_pipe_bar)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_pipe_bar.add_child(vb)

	_pipe_hint = Label.new()
	_style_label(_pipe_hint, DesertPalette.UI_INK, 12, false)
	vb.add_child(_pipe_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	_pipe_erase_btn = Button.new()
	_pipe_erase_btn.text = "ERASE"
	_pipe_erase_btn.pressed.connect(func(): state.set_water_pipe_erase(not state.water_pipe_erase_mode))
	row.add_child(_pipe_erase_btn)

	_pipe_clear_btn = Button.new()
	_pipe_clear_btn.text = "CLEAR"
	_style_button(_pipe_clear_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 11, 12)
	_pipe_clear_btn.pressed.connect(func(): state.clear_water_pipe_line())
	row.add_child(_pipe_clear_btn)

	_pipe_confirm_btn = Button.new()
	_pipe_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pipe_confirm_btn.pressed.connect(func(): state.confirm_water_pipe_line())
	row.add_child(_pipe_confirm_btn)

	var done_b := Button.new()
	done_b.text = "DONE"
	_style_button(done_b, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color.WHITE, 11, 12)
	done_b.pressed.connect(func(): state.cancel_tool_mode())
	row.add_child(done_b)


func _build_placement_bar(parent: VBoxContainer) -> void:
	_place_bar = PanelContainer.new()
	_place_bar.visible = false
	_place_bar.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT, DesertPalette.UI_WOOD_FRAME, 18, 3, 4))
	parent.add_child(_place_bar)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_place_bar.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vb.add_child(hdr)
	_place_badge = Label.new()
	_style_label(_place_badge, Color.WHITE, 10, true)
	hdr.add_child(_place_badge)
	var tvb := VBoxContainer.new()
	tvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(tvb)
	_place_title = Label.new()
	_style_label(_place_title, DesertPalette.UI_INK, 11, true)
	tvb.add_child(_place_title)
	_place_hint = Label.new()
	_style_label(_place_hint, DesertPalette.UI_INK_MUTED, 11, false)
	tvb.add_child(_place_hint)

	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 8)
	vb.add_child(act)
	_place_rot_btn = Button.new()
	_place_rot_btn.text = "ROTATE (R)"
	_style_button(_place_rot_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 11, 12)
	_place_rot_btn.pressed.connect(func(): state.rotate_ghost())
	act.add_child(_place_rot_btn)

	_place_confirm_btn = Button.new()
	_place_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_place_confirm_btn, DesertPalette.UI_GREEN_TOP, DesertPalette.UI_GREEN_BASE, Color.WHITE, 12, 12)
	_place_confirm_btn.pressed.connect(func(): state.confirm_placement())
	act.add_child(_place_confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "✕"
	_style_button(cancel_btn, DesertPalette.UI_TERRA_TOP, DesertPalette.UI_TERRA_BASE, Color.WHITE, 12, 12)
	cancel_btn.pressed.connect(func(): state.cancel_tool_mode())
	act.add_child(cancel_btn)


func _build_land_bar(parent: VBoxContainer) -> void:
	_land_bar = PanelContainer.new()
	_land_bar.visible = false
	_land_bar.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT, DesertPalette.UI_WOOD_FRAME, 18, 3, 4))
	parent.add_child(_land_bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	_land_bar.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	_land_title = Label.new()
	_style_label(_land_title, DesertPalette.UI_INK, 12, true)
	vb.add_child(_land_title)
	_land_hint = Label.new()
	_style_label(_land_hint, DesertPalette.UI_INK_MUTED, 11, false)
	vb.add_child(_land_hint)
	var done := Button.new()
	done.text = "DONE"
	_style_button(done, DesertPalette.UI_GREEN_TOP, DesertPalette.UI_GREEN_BASE, Color.WHITE, 12, 12)
	done.pressed.connect(func(): state.cancel_tool_mode())
	hb.add_child(done)


func _build_menu_modal(root: Control) -> void:
	_menu_backdrop = ColorRect.new()
	_menu_backdrop.visible = false
	_menu_backdrop.color = Color(0, 0, 0, 0.50)
	_menu_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_menu_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_backdrop.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 520)
	panel.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT, DesertPalette.UI_WOOD_FRAME, 22, 3, 6))
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	var title := Label.new()
	title.text = "DESERT OUTPOST"
	_style_label(title, DesertPalette.UI_INK, 15, true)
	hdr.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)
	var close_btn := Button.new()
	close_btn.text = "✕"
	_style_button(close_btn, DesertPalette.UI_TERRA_TOP, DesertPalette.UI_TERRA_BASE, Color.WHITE, 12, 10)
	close_btn.pressed.connect(_close_menu)
	hdr.add_child(close_btn)

	# 4 mini stat badges
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 6)
	vb.add_child(stats_row)
	for cap in ["STAGE", "ACCESS", "PARKING", "ROADS"]:
		var bp := PanelContainer.new()
		bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bp.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT_DARK, DesertPalette.UI_WOOD_RIM, 10, 1, 0))
		stats_row.add_child(bp)
		var bvb := VBoxContainer.new()
		bvb.alignment = BoxContainer.ALIGNMENT_CENTER
		bp.add_child(bvb)
		var val_l := Label.new()
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(val_l, DesertPalette.UI_INK, 13, true)
		bvb.add_child(val_l)
		var cap_l := Label.new()
		cap_l.text = cap
		cap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(cap_l, DesertPalette.UI_INK_MUTED, 9, false)
		bvb.add_child(cap_l)
		_menu_stats.append(val_l)

	_menu_stage_lbl = Label.new()
	_menu_stage_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_style_label(_menu_stage_lbl, DesertPalette.UI_INK, 11, false)
	vb.add_child(_menu_stage_lbl)

	# Sky & Lighting
	var sky_hdr := Label.new()
	sky_hdr.text = "SKY & LIGHTING"
	_style_label(sky_hdr, DesertPalette.UI_INK_MUTED, 10, true)
	vb.add_child(sky_hdr)
	var sky_row := HBoxContainer.new()
	sky_row.add_theme_constant_override("separation", 6)
	vb.add_child(sky_row)
	for sp_t in [["DAY", 0.40], ["SUNSET", 0.74], ["NIGHT", 0.96]]:
		var b := Button.new()
		b.text = sp_t[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(b, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color.WHITE, 10, 10)
		var tv: float = sp_t[1]
		b.pressed.connect(func(): state.set_time_preset(tv, true))
		sky_row.add_child(b)
	_menu_auto_btn = Button.new()
	_menu_auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_auto_btn.pressed.connect(func(): state.toggle_auto_day_night())
	sky_row.add_child(_menu_auto_btn)

	# Presets
	var mode_hdr := Label.new()
	mode_hdr.text = "MODES & PRESETS"
	_style_label(mode_hdr, DesertPalette.UI_INK_MUTED, 10, true)
	vb.add_child(mode_hdr)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	vb.add_child(mode_row)
	var lv1_btn := Button.new()
	lv1_btn.text = "LV1 CART"
	lv1_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(lv1_btn, DesertPalette.UI_TERRA_TOP, DesertPalette.UI_TERRA_BASE, Color.WHITE, 11, 10)
	lv1_btn.pressed.connect(func():
		state.switch_preset(GameCatalog.OutpostPreset.STAGE_ONE_CAREER)
		_close_menu()
	)
	mode_row.add_child(lv1_btn)

	var city_btn := Button.new()
	city_btn.text = "FULL CITY"
	city_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(city_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color.WHITE, 11, 10)
	city_btn.pressed.connect(func():
		state.switch_preset(GameCatalog.OutpostPreset.FULL_CITY)
		_close_menu()
	)
	mode_row.add_child(city_btn)

	var home_btn := Button.new()
	home_btn.text = "RESET VIEW"
	home_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(home_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("ffe7b8"), 10, 10)
	home_btn.pressed.connect(func():
		state.reset_camera_smooth()
		_close_menu()
	)
	mode_row.add_child(home_btn)

	# Milestones Scroll
	var ms_hdr := Label.new()
	ms_hdr.text = "REWARDS & GOALS"
	_style_label(ms_hdr, DesertPalette.UI_INK_MUTED, 10, true)
	vb.add_child(ms_hdr)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	_menu_milestones_box = VBoxContainer.new()
	_menu_milestones_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_milestones_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_menu_milestones_box)


# --- Interactions ---

func _toggle_tray(mode: int) -> void:
	if state.tool_mode != GameCatalog.WorldToolMode.PLAY:
		state.cancel_tool_mode()
	state.clear_selected_plot()
	_tray_mode = TrayMode.NONE if _tray_mode == mode else mode
	_refresh_hud()


func _open_menu() -> void:
	_tray_mode = TrayMode.NONE
	state.clear_selected_plot()
	_menu_open = true
	_menu_backdrop.visible = true
	_refresh_hud()


func _close_menu() -> void:
	_menu_open = false
	_menu_backdrop.visible = false
	_refresh_hud()


func _on_milestone_pill_pressed() -> void:
	var m := state.next_active_milestone()
	if not m.is_empty() and not m["claimed"] and state.is_milestone_completed(m):
		state.claim_milestone(m)
	else:
		_open_menu()


# --- Per-Frame Projection (In-World Bubbles & Popups) + Dirty HUD Refresh ---

func _process(_delta: float) -> void:
	if state == null or camera == null:
		return
	if _hud_dirty:
		_hud_dirty = false
		_refresh_hud()
	_update_in_world_bubbles()
	_update_floating_popups()


func _refresh_hud() -> void:
	var inc := state.income_per_minute()
	_cash_lbl.text = GameCatalog.format_cash(state.cash)
	_rate_lbl.text = "+%s/min" % GameCatalog.format_cash(inc) if inc > 0.0 else "Tap cart to earn"
	_stage_btn.text = "STG %d" % state.outpost_stage()

	_clock_lbl.text = state.sim_clock.hud_label()
	_speed_btn.text = state.sim_clock.speed_label()
	var paused := state.sim_clock.is_paused()
	_style_button(
		_speed_btn,
		DesertPalette.UI_TERRA_TOP if paused else (DesertPalette.UI_GREEN_TOP if state.sim_clock.sim_speed >= 1.5 else DesertPalette.UI_GOLD_TOP),
		DesertPalette.UI_TERRA_BASE if paused else (DesertPalette.UI_GREEN_BASE if state.sim_clock.sim_speed >= 1.5 else DesertPalette.UI_GOLD_BASE),
		Color.WHITE if paused or state.sim_clock.sim_speed >= 1.5 else DesertPalette.UI_INK,
		10,
		9
	)

	# Top-bar live Power Grid pill
	var pn := state.power_network
	var show_pwr := pn.total_demand_kw > 0.0 or pn.total_gen_kw > 0.0 or not state.utilities.is_empty()
	_power_btn.visible = show_pwr
	if show_pwr:
		var bat_tag := ""
		if pn.total_battery_cap > 0.0:
			bat_tag = " · BAT %d%%" % roundi((pn.total_battery_stored / pn.total_battery_cap) * 100.0)
		_power_btn.text = "⚡ %.0f/%.0f kW%s" % [pn.total_gen_kw, pn.total_demand_kw, bat_tag]
		var low := pn.brownout_count > 0
		_style_button(
			_power_btn,
			DesertPalette.UI_TERRA_TOP if low else DesertPalette.UI_WOOD_FRAME,
			DesertPalette.UI_TERRA_BASE if low else DesertPalette.UI_WOOD_DEEP,
			Color.WHITE if low else DesertPalette.UI_GOLD_TOP,
			10,
			14
		)

	# Top-bar live Water Network pill
	var wn := state.water_network
	var show_h2o := wn.total_demand > 0.0 or wn.total_supply > 0.0
	_water_btn.visible = show_h2o
	if show_h2o:
		_water_btn.text = "💧 %.0f/%.0f" % [wn.total_supply, wn.total_demand]
		var dry := wn.dry_count > 0
		_style_button(
			_water_btn,
			DesertPalette.UI_TERRA_TOP if dry else DesertPalette.UI_WOOD_FRAME,
			DesertPalette.UI_TERRA_BASE if dry else DesertPalette.UI_WOOD_DEEP,
			Color.WHITE if dry else Color("8ee6f5"),
			10,
			14
		)

	# Refresh map lens buttons & banner
	for lspec in GameCatalog.MAP_LENSES:
		var lid: int = int(lspec["id"])
		if _lens_btns.has(lid):
			var lb: Button = _lens_btns[lid]
			var active := state.active_lens == lid
			_style_button(
				lb,
				DesertPalette.UI_GOLD_TOP if active else DesertPalette.UI_WOOD_BODY,
				DesertPalette.UI_GOLD_BASE if active else DesertPalette.UI_WOOD_DEEP,
				DesertPalette.UI_INK if active else Color("fff2d4"),
				9,
				10
			)
	if state.active_lens == GameCatalog.MapLens.NONE:
		_lens_banner.visible = false
	else:
		_lens_banner.visible = true
		for lspec in GameCatalog.MAP_LENSES:
			if int(lspec["id"]) == state.active_lens:
				var extra := ""
				if state.active_lens == GameCatalog.MapLens.POWER:
					extra = " · LOAD %.1f kW · SOLAR %d%%" % [state.total_power_demand_kw(), roundi(state.sim_clock.solar_factor() * 100.0)]
				_lens_banner.text = " %s LENS: %s%s " % [str(lspec["name"]).to_upper(), str(lspec["hint"]), extra]
				break

	var claimable := state.claimable_milestone_count()
	_menu_badge.visible = claimable > 0
	_menu_badge.text = " %d " % claimable

	var ms := state.next_active_milestone()
	if ms.is_empty():
		_milestone_btn.visible = false
	else:
		_milestone_btn.visible = true
		var ready: bool = not bool(ms["claimed"]) and state.is_milestone_completed(ms)
		if ready:
			_milestone_btn.text = "★ CLAIM +%s" % GameCatalog.format_cash(ms["reward"])
			_style_button(_milestone_btn, DesertPalette.UI_GOLD_TOP, DesertPalette.UI_GOLD_BASE, DesertPalette.UI_INK, 11, 16)
		else:
			_milestone_btn.text = "★ %s" % ms["title"]
			_style_button(_milestone_btn, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 11, 16)

	_offline_btn.visible = state.pending_offline_cash > 0.0
	if _offline_btn.visible:
		_offline_btn.text = "WELCOME BACK! +%s EARNED (%dM)" % [GameCatalog.format_cash(state.pending_offline_cash), state.pending_offline_minutes]

	# Bottom mode bars
	var tm := state.tool_mode
	var has_sel := not state.selected_plot().is_empty() or not state.selected_lot().is_empty() or not state.selected_utility().is_empty()
	if has_sel and _tray_mode != TrayMode.NONE:
		_tray_mode = TrayMode.NONE
	_play_bar.visible = tm == GameCatalog.WorldToolMode.PLAY
	_tray_panel.visible = tm == GameCatalog.WorldToolMode.PLAY and _tray_mode != TrayMode.NONE
	_inspector.visible = tm == GameCatalog.WorldToolMode.PLAY and _tray_mode == TrayMode.NONE and has_sel and not _menu_open
	_road_bar.visible = tm == GameCatalog.WorldToolMode.PAINT_ROAD
	_pole_bar.visible = tm == GameCatalog.WorldToolMode.PLACE_POWER_POLE
	_conduit_bar.visible = tm == GameCatalog.WorldToolMode.PAINT_CONDUIT
	_pipe_bar.visible = tm == GameCatalog.WorldToolMode.PAINT_WATER_PIPE
	_place_bar.visible = tm == GameCatalog.WorldToolMode.PLACE_BUILDING or tm == GameCatalog.WorldToolMode.PLACE_PARKING or tm == GameCatalog.WorldToolMode.PLACE_DECORATION or tm == GameCatalog.WorldToolMode.PLACE_UTILITY
	_land_bar.visible = tm == GameCatalog.WorldToolMode.BUY_LAND

	if _play_bar.visible:
		_serve_btn.text = ("%s  +%s" % ["SELL" if state.parking_lots.is_empty() else "SERVE", GameCatalog.format_cash(state.tap_income())])
		var can_build := state.parking_lots.is_empty() and state.cash >= 40.0
		if not can_build:
			for p in state.plots:
				if not p["is_built"] and state.is_plot_unlocked(p) and state.cash >= float(GameCatalog.BUSINESSES[p["type"]]["purchase_cost"]):
					can_build = true
					break
		var can_upg := state.cash >= state.tap_upgrade_cost()
		if not can_upg:
			for l in state.parking_lots:
				if state.parking_upgrade_lock_reason(l).is_empty() and state.cash >= state.parking_upgrade_cost(l):
					can_upg = true
					break
		if not can_upg:
			for p in state.plots:
				if p["is_built"] and state.upgrade_lock_reason(p).is_empty() and state.cash >= GameCatalog.upgrade_cost_for_level(p["type"], p["level"]):
					can_upg = true
					break
		var can_crew := false
		for ck in [GameCatalog.CrewKind.GRID_TECH, GameCatalog.CrewKind.PUMP_ENGINEER, GameCatalog.CrewKind.LOGISTICS_RUNNER]:
			var lock_c := state.staff_sim.crew_lock_reason(ck, state)
			if lock_c.is_empty():
				var cc := GameCatalog.crew_action_cost(ck, state.staff_sim.crew_level(ck))
				if state.cash >= cc:
					can_crew = true
					break
		_build_dot.visible = can_build and _tray_mode != TrayMode.BUILD
		_roads_dot.visible = state.needs_access_road() and state.cash >= 20.0
		_crew_dot.visible = can_crew and _tray_mode != TrayMode.CREW
		_upgrade_dot.visible = can_upg and _tray_mode != TrayMode.UPGRADE
		if _tray_panel.visible:
			_rebuild_tray_cards()
		if _inspector.visible:
			_inspector.refresh()

	if _road_bar.visible:
		_refresh_road_bar()
	if _pole_bar.visible:
		_refresh_pole_bar()
	if _conduit_bar.visible:
		_refresh_conduit_bar()
	if _pipe_bar.visible:
		_refresh_water_pipe_bar()
	if _place_bar.visible:
		_refresh_placement_bar()
	if _land_bar.visible:
		_land_title.text = "BUY LAND · %d/%d PARCELS" % [state.world_grid.owned_parcels.size(), int(state.stage_info()["max_parcels"])]
		_land_hint.text = "Tap a highlighted parcel bordering your land · Traits shown · next %s" % GameCatalog.format_cash(state.world_grid.next_parcel_price()) if state.can_buy_more_land() else "Reach Stage %d to buy more land" % (state.outpost_stage() + 1)
	if _menu_open:
		_refresh_menu_modal()


func _refresh_road_bar() -> void:
	var prev := state.compute_road_line_preview()
	var erase := state.road_erase_mode
	var tiles: int = prev["build"].size()
	var cost: float = prev["cost"]
	var reason: String = prev["reason"]
	var affordable := erase or state.cash >= cost
	var can_ok := reason.is_empty() and tiles > 0 and affordable

	var width_lbl := "2-LANE" if state.road_two_lane else "1-LANE"
	if not state.has_road_start:
		_road_hint.text = "TAP START TILE TO ERASE (%s)" % width_lbl if erase else "TAP START TILE, THEN END TILE (%s ROAD · STRAIGHT OR L-SHAPE)" % width_lbl
	elif not reason.is_empty():
		_road_hint.text = reason.to_upper()
	elif not affordable:
		_road_hint.text = "NEED %s MORE" % GameCatalog.format_cash(cost - state.cash)
	else:
		_road_hint.text = "REMOVE %d TILES (%s)" % [tiles, width_lbl] if erase else "%d NEW TILES READY (%s)" % [tiles, width_lbl]
	_road_junc.text = "JUNCTIONS %d/%d" % [state.road_network.highway_turn_off_count(), int(state.stage_info()["max_highway_turn_offs"])]

	var tiers := [GameCatalog.RoadTier.DIRT, GameCatalog.RoadTier.GRAVEL, GameCatalog.RoadTier.PAVED]
	for i in range(3):
		var t: int = tiers[i]
		var spec: Dictionary = GameCatalog.ROAD_TIERS[t]
		var unl := state.is_road_tier_unlocked(t)
		var sel := not erase and state.active_road_tier == t
		var btn := _road_tier_btns[i]
		btn.disabled = not unl
		btn.text = "%s\n%s" % [spec["short"], "%s/t" % GameCatalog.format_cash(spec["cost_per_tile"]) if unl else "STG %d" % int(spec["unlock_stage"])]
		_style_button(btn, DesertPalette.UI_GOLD_TOP if sel else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_GOLD_BASE if sel else DesertPalette.UI_WOOD_DEEP, DesertPalette.UI_INK if sel else Color.WHITE, 10, 12)

	_road_width_btn.text = "2-LANE\n4M" if state.road_two_lane else "1-LANE\n2M"
	_style_button(_road_width_btn, DesertPalette.UI_GREEN_TOP if state.road_two_lane else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_GREEN_BASE if state.road_two_lane else DesertPalette.UI_WOOD_DEEP, Color.WHITE, 10, 12)
	_style_button(_road_erase_btn, DesertPalette.UI_TERRA_TOP if erase else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_TERRA_BASE if erase else DesertPalette.UI_WOOD_DEEP, Color.WHITE, 10, 12)
	_road_clear_btn.disabled = not state.has_road_start
	_road_confirm_btn.disabled = not can_ok
	_road_confirm_btn.text = ("REMOVE · +%s" % GameCatalog.format_cash(-cost) if tiles > 0 else "REMOVE") if erase else ("BUILD · %s" % GameCatalog.format_cash(cost) if tiles > 0 else "BUILD")
	_style_button(_road_confirm_btn, DesertPalette.UI_TERRA_TOP if erase else DesertPalette.UI_GREEN_TOP, DesertPalette.UI_TERRA_BASE if erase else DesertPalette.UI_GREEN_BASE, Color.WHITE, 11, 12)


func _refresh_pole_bar() -> void:
	var erase := state.pole_erase_mode
	_pole_hint.text = "TAP ANY POWER POLE OR TOWER TO REMOVE (50% REFUND)" if erase else "TAP OWNED SAND TO PLACE POLES · WIRES AUTO-CONNECT TO BUILDINGS & GENERATORS"
	var kinds := [GameCatalog.PowerLineKind.WOOD_POLE, GameCatalog.PowerLineKind.STEEL_TOWER]
	for i in range(2):
		var pk: int = kinds[i]
		var spec: Dictionary = GameCatalog.POWER_LINES[pk]
		var unl := state.is_power_line_unlocked(pk)
		var sel := not erase and state.active_pole_kind == pk
		var btn := _pole_kind_btns[i]
		btn.disabled = not unl
		btn.text = "%s (%dt) · %s" % [spec["short"], int(spec["span_tiles"]), GameCatalog.format_cash(spec["cost"]) if unl else "STG %d" % int(spec["stage"])]
		_style_button(btn, DesertPalette.UI_GOLD_TOP if sel else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_GOLD_BASE if sel else DesertPalette.UI_WOOD_DEEP, DesertPalette.UI_INK if sel else Color.WHITE, 10, 12)
	_style_button(_pole_erase_btn, DesertPalette.UI_TERRA_TOP if erase else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_TERRA_BASE if erase else DesertPalette.UI_WOOD_DEEP, Color.WHITE, 10, 12)


func _refresh_conduit_bar() -> void:
	var prev := state.compute_conduit_line_preview()
	var erase := state.conduit_erase_mode
	var tiles: int = prev["build"].size()
	var cost: float = prev["cost"]
	var reason: String = prev["reason"]
	var affordable := erase or state.cash >= cost
	var can_ok := reason.is_empty() and tiles > 0 and affordable

	if not state.has_conduit_start:
		_conduit_hint.text = "TAP START TILE TO DIG UP BURIED CABLES" if erase else "TAP START TILE, THEN END TILE · BURIED WIRES RUN CLEANLY UNDER ROADS & PLAZAS"
	elif not reason.is_empty():
		_conduit_hint.text = reason.to_upper()
	elif not affordable:
		_conduit_hint.text = "NEED %s MORE" % GameCatalog.format_cash(cost - state.cash)
	else:
		_conduit_hint.text = "REMOVE %d CABLES" % tiles if erase else "%d UNDERGROUND CONDUIT TILES READY" % tiles
	_style_button(_conduit_erase_btn, DesertPalette.UI_TERRA_TOP if erase else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_TERRA_BASE if erase else DesertPalette.UI_WOOD_DEEP, Color.WHITE, 10, 12)
	_conduit_clear_btn.disabled = not state.has_conduit_start
	_conduit_confirm_btn.disabled = not can_ok
	_conduit_confirm_btn.text = ("REMOVE · +%s" % GameCatalog.format_cash(-cost) if tiles > 0 else "REMOVE") if erase else ("BURY CABLES · %s" % GameCatalog.format_cash(cost) if tiles > 0 else "BURY CABLES")
	_style_button(_conduit_confirm_btn, DesertPalette.UI_TERRA_TOP if erase else DesertPalette.UI_GREEN_TOP, DesertPalette.UI_TERRA_BASE if erase else DesertPalette.UI_GREEN_BASE, Color.WHITE, 11, 12)


func _refresh_water_pipe_bar() -> void:
	var prev := state.compute_water_pipe_line_preview()
	var erase := state.water_pipe_erase_mode
	var tiles: int = prev["build"].size()
	var cost: float = prev["cost"]
	var reason: String = prev["reason"]
	var affordable := erase or state.cash >= cost
	var can_ok := reason.is_empty() and tiles > 0 and affordable

	if not state.has_water_pipe_start:
		_pipe_hint.text = "TAP START TILE TO DIG UP WATER PIPES" if erase else "TAP START TILE, THEN END TILE · WATER PIPES RUN CLEANLY UNDER ROADS & PLAZAS"
	elif not reason.is_empty():
		_pipe_hint.text = reason.to_upper()
	elif not affordable:
		_pipe_hint.text = "NEED %s MORE" % GameCatalog.format_cash(cost - state.cash)
	else:
		_pipe_hint.text = "REMOVE %d PIPES" % tiles if erase else "%d UNDERGROUND WATER PIPES READY" % tiles
	_style_button(_pipe_erase_btn, DesertPalette.UI_TERRA_TOP if erase else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_TERRA_BASE if erase else DesertPalette.UI_WOOD_DEEP, Color.WHITE, 10, 12)
	_pipe_clear_btn.disabled = not state.has_water_pipe_start
	_pipe_confirm_btn.disabled = not can_ok
	_pipe_confirm_btn.text = ("REMOVE · +%s" % GameCatalog.format_cash(-cost) if tiles > 0 else "REMOVE") if erase else ("LAY PIPES · %s" % GameCatalog.format_cash(cost) if tiles > 0 else "LAY PIPES")
	_style_button(_pipe_confirm_btn, DesertPalette.UI_TERRA_TOP if erase else DesertPalette.UI_GREEN_TOP, DesertPalette.UI_TERRA_BASE if erase else DesertPalette.UI_GREEN_BASE, Color.WHITE, 11, 12)


func _refresh_placement_bar() -> void:
	var mode := state.tool_mode
	var inv := state.ghost_invalid_reason()
	var valid := inv.is_empty()
	var title := "PLACE"
	var cost := 0.0
	var is_move := false

	if mode == GameCatalog.WorldToolMode.PLACE_BUILDING and state.pending_building_type >= 0:
		var d: Dictionary = GameCatalog.BUSINESSES[state.pending_building_type]
		is_move = not state.relocating_plot_id.is_empty()
		title = ("MOVE " if is_move else "PLACE ") + str(d["name"]).to_upper()
		cost = 0.0 if is_move else float(d["purchase_cost"])
	elif mode == GameCatalog.WorldToolMode.PLACE_PARKING and state.pending_parking_kind >= 0:
		var s: Dictionary = GameCatalog.PARKING_LOTS[state.pending_parking_kind]
		if not state.relocating_lot_id.is_empty() and state.relocating_lot_is_upgrade:
			title = "UPGRADE TO " + str(s["name"]).to_upper()
			for l in state.parking_lots:
				if l["id"] == state.relocating_lot_id:
					cost = state.parking_upgrade_cost(l)
					break
		elif not state.relocating_lot_id.is_empty():
			is_move = true
			title = "MOVE " + str(s["name"]).to_upper()
		else:
			title = "PLACE " + str(s["name"]).to_upper()
			cost = float(s["cost"])
	elif mode == GameCatalog.WorldToolMode.PLACE_DECORATION and not state.pending_deco.is_empty():
		is_move = not state.relocating_deco_id.is_empty()
		title = ("MOVE " if is_move else "PLACE ") + str(state.pending_deco["name"]).to_upper()
		cost = 0.0 if is_move else float(state.pending_deco["cost"])
	elif mode == GameCatalog.WorldToolMode.PLACE_UTILITY and state.pending_utility_kind >= 0:
		var u: Dictionary = GameCatalog.UTILITIES[state.pending_utility_kind]
		is_move = not state.relocating_utility_id.is_empty()
		title = ("MOVE " if is_move else "PLACE ") + str(u["name"]).to_upper()
		cost = 0.0 if is_move else float(u["cost"])

	var badge_col := DesertPalette.UI_GREEN_BASE
	if not valid:
		badge_col = DesertPalette.UI_TERRA_BASE
		_place_badge.text = " BLOCKED "
		_place_hint.text = inv
	elif mode == GameCatalog.WorldToolMode.PLACE_BUILDING:
		var acc := state.ghost_access_preview()
		var sc: float = acc["score"]
		badge_col = DesertPalette.UI_TERRA_TOP if sc <= 0.0 else (DesertPalette.UI_GREEN_BASE if sc >= 0.88 else DesertPalette.UI_GOLD_BASE)
		_place_badge.text = " %s " % acc["status_label"]
		_place_hint.text = acc["hint"]
	elif mode == GameCatalog.WorldToolMode.PLACE_UTILITY and state.pending_utility_kind == GameCatalog.UtilityKind.WINDMILL and state.world_grid.cell_trait(Vector2i(state.ghost_grid_x, state.ghost_grid_z)) == GameCatalog.ParcelTrait.WIND_CORRIDOR:
		badge_col = DesertPalette.TURQUOISE
		_place_badge.text = " +40% WIND! "
		_place_hint.text = "Wind Corridor bonus active (10.5 kW steady 24/7) · Gold frame shows local auto-link reach"
	elif mode == GameCatalog.WorldToolMode.PLACE_UTILITY and state.pending_utility_kind == GameCatalog.UtilityKind.WATER_WELL and state.world_grid.cell_trait(Vector2i(state.ghost_grid_x, state.ghost_grid_z)) == GameCatalog.ParcelTrait.AQUIFER:
		badge_col = DesertPalette.WATER
		_place_badge.text = " +80% AQUIFER! "
		_place_hint.text = "Desert Aquifer bonus active (18 Water) · Blue frame shows local auto-link reach"
	elif mode == GameCatalog.WorldToolMode.PLACE_UTILITY and state.pending_utility_kind == GameCatalog.UtilityKind.OIL_PUMPJACK:
		badge_col = DesertPalette.UI_GOLD_BASE
		_place_badge.text = " OIL SEEP OK "
		_place_hint.text = "Produces 12 Crude/min when powered (6 kW) · Connect via Poles or Buried Wire"
	elif mode == GameCatalog.WorldToolMode.PLACE_UTILITY:
		_place_badge.text = " READY "
		_place_hint.text = "Tap sand to position · Connect Power / Pipes for remote units"
	else:
		_place_badge.text = " READY "
		_place_hint.text = "Tap sand to position · drag to orbit/pan"
	_place_badge.add_theme_stylebox_override("normal", _make_box(badge_col, DesertPalette.UI_WOOD_FRAME, 8, 1, 0))
	_place_title.text = title
	_place_rot_btn.visible = true
	_place_confirm_btn.disabled = not (valid and state.cash >= cost)
	_place_confirm_btn.text = "MOVE HERE" if is_move else ("PLACE · %s" % GameCatalog.format_cash(cost) if cost > 0.0 else "PLACE")


func _rebuild_tray_cards() -> void:
	for c in _tray_list.get_children():
		c.queue_free()
	for c in _tray_filters_row.get_children():
		c.queue_free()

	if _tray_mode == TrayMode.BUILD:
		_tray_title.text = "BUILD · STG %d" % state.outpost_stage()
		for fspec in [["all", "ALL"], ["stores", "STORES"], ["power", "POWER"], ["water", "WATER"], ["supply", "SUPPLY"], ["decor", "DECOR"]]:
			var fid: String = fspec[0]
			var fb := Button.new()
			fb.text = fspec[1]
			var active := _build_filter == fid
			_style_button(fb, DesertPalette.UI_GOLD_TOP if active else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_GOLD_BASE if active else DesertPalette.UI_WOOD_DEEP, DesertPalette.UI_INK if active else Color("fff2d4"), 9, 8)
			fb.pressed.connect(func():
				_build_filter = fid
				_rebuild_tray_cards()
			)
			_tray_filters_row.add_child(fb)

		var f := _build_filter
		if f == "all" or f == "stores":
			_add_card("Build Roads", "%d tiles laid" % state.road_network.road_count(), "DRAW", true, func():
				_tray_mode = TrayMode.NONE
				state.enter_road_mode()
			)
			_add_card("Buy Land", "%d/%d parcels" % [state.world_grid.owned_parcels.size(), int(state.stage_info()["max_parcels"])], GameCatalog.format_cash(state.world_grid.next_parcel_price()) if state.can_buy_more_land() else "STAGE %d" % (state.outpost_stage() + 1), state.can_buy_more_land(), func():
				_tray_mode = TrayMode.NONE
				state.enter_land_mode()
			)
			for kind in [GameCatalog.ParkingLotKind.DIRT_PULL_OFF, GameCatalog.ParkingLotKind.GRAVEL_LOT, GameCatalog.ParkingLotKind.PAVED_LOT]:
				if not state.is_parking_kind_unlocked(kind):
					continue
				var spec: Dictionary = GameCatalog.PARKING_LOTS[kind]
				var k_val: int = kind
				_add_card(spec["name"], "%d bays · Place" % int(spec["spaces"]), GameCatalog.format_cash(spec["cost"]), state.cash >= float(spec["cost"]), func():
					_tray_mode = TrayMode.NONE
					state.start_placing_parking(k_val)
				)
			for p in state.plots:
				if p["is_built"]:
					continue
				var d: Dictionary = GameCatalog.BUSINESSES[p["type"]]
				var unl := state.is_plot_unlocked(p)
				var bt: int = p["type"]
				_add_card(d["short"], "+%s/m" % GameCatalog.format_cash(d["base_income_per_min"]) if unl else "Stage %d" % int(d["stage"]), GameCatalog.format_cash(d["purchase_cost"]) if unl else "STG %d" % int(d["stage"]), unl and state.cash >= float(d["purchase_cost"]), func():
					if unl:
						_tray_mode = TrayMode.NONE
						state.start_placing_building(bt)
				)

		if f == "all" or f == "power":
			for ukind in [GameCatalog.UtilityKind.WINDMILL, GameCatalog.UtilityKind.DIESEL_GEN, GameCatalog.UtilityKind.SOLAR_ARRAY, GameCatalog.UtilityKind.BATTERY_BANK]:
				var uspec: Dictionary = GameCatalog.UTILITIES[ukind]
				var unl := state.is_utility_unlocked(ukind)
				var uk_val: int = ukind
				var sub := "%.0f kWh store" % float(uspec["battery_kwh"]) if float(uspec["battery_kwh"]) > 0.0 else ("%.0f kW solar" % float(uspec["base_kw"]) if bool(uspec["is_solar"]) else "%.1f kW 24/7" % float(uspec["base_kw"]))
				_add_card(uspec["short"], sub if unl else "Stage %d" % int(uspec["stage"]), GameCatalog.format_cash(uspec["cost"]) if unl else "STG %d" % int(uspec["stage"]), unl and state.cash >= float(uspec["cost"]), func():
					if unl:
						_tray_mode = TrayMode.NONE
						state.start_placing_utility(uk_val)
				)
			var pole_unl := state.is_power_line_unlocked(GameCatalog.PowerLineKind.WOOD_POLE)
			_add_card("Power Poles", "Overhead wires" if pole_unl else "Stage 2", "$12+" if pole_unl else "STG 2", pole_unl, func():
				if pole_unl:
					_tray_mode = TrayMode.NONE
					state.enter_pole_mode(GameCatalog.PowerLineKind.WOOD_POLE)
			)
			var cond_unl := state.is_power_line_unlocked(GameCatalog.PowerLineKind.UNDERGROUND)
			_add_card("Buried Wire", "Under roads" if cond_unl else "Stage 2", "$18/t" if cond_unl else "STG 2", cond_unl, func():
				if cond_unl:
					_tray_mode = TrayMode.NONE
					state.enter_conduit_mode()
			)

		if f == "all" or f == "water":
			for ukind in [GameCatalog.UtilityKind.WATER_WELL, GameCatalog.UtilityKind.WATER_TOWER]:
				var uspec: Dictionary = GameCatalog.UTILITIES[ukind]
				var unl := state.is_utility_unlocked(ukind)
				var uk_val: int = ukind
				var sub := "10-18 H2O" if ukind == GameCatalog.UtilityKind.WATER_WELL else "+4 H2O · 4t hub"
				_add_card(uspec["short"], sub if unl else "Stage %d" % int(uspec["stage"]), GameCatalog.format_cash(uspec["cost"]) if unl else "STG %d" % int(uspec["stage"]), unl and state.cash >= float(uspec["cost"]), func():
					if unl:
						_tray_mode = TrayMode.NONE
						state.start_placing_utility(uk_val)
				)
			var pipe_unl := state.outpost_stage() >= 2
			_add_card("Water Pipes", "Under roads" if pipe_unl else "Stage 2", "$12/t" if pipe_unl else "STG 2", pipe_unl, func():
				if pipe_unl:
					_tray_mode = TrayMode.NONE
					state.enter_water_pipe_mode()
			)

		if f == "all" or f == "supply":
			for ukind in [GameCatalog.UtilityKind.FREIGHT_DEPOT, GameCatalog.UtilityKind.OIL_PUMPJACK, GameCatalog.UtilityKind.DESERT_GREENHOUSE, GameCatalog.UtilityKind.MINI_REFINERY, GameCatalog.UtilityKind.CRAFT_WORKSHOP]:
				var uspec: Dictionary = GameCatalog.UTILITIES[ukind]
				var unl := state.is_utility_unlocked(ukind)
				var uk_val: int = ukind
				var sub := "Auto-restock" if ukind == GameCatalog.UtilityKind.FREIGHT_DEPOT else ("Oil Seep only" if ukind == GameCatalog.UtilityKind.OIL_PUMPJACK else ("+12 Food/m" if ukind == GameCatalog.UtilityKind.DESERT_GREENHOUSE else ("+14 Fuel/m" if ukind == GameCatalog.UtilityKind.MINI_REFINERY else "+10 Crafts/m")))
				_add_card(uspec["short"], sub if unl else "Stage %d" % int(uspec["stage"]), GameCatalog.format_cash(uspec["cost"]) if unl else "STG %d" % int(uspec["stage"]), unl and state.cash >= float(uspec["cost"]), func():
					if unl:
						_tray_mode = TrayMode.NONE
						state.start_placing_utility(uk_val)
				)

		if f == "all" or f == "decor":
			for dec in GameCatalog.DECORATIONS:
				var unl := state.is_deco_unlocked(dec["kind"])
				var d_copy: Dictionary = dec
				_add_card(dec["name"], dec["bonus"], GameCatalog.format_cash(dec["cost"]) if unl else "STG %d" % int(dec["stage"]), unl and state.cash >= float(dec["cost"]), func():
					if unl:
						_tray_mode = TrayMode.NONE
						state.start_placing_decoration(d_copy)
				)
	elif _tray_mode == TrayMode.CREW:
		var m_pct := roundi(state.staff_sim.morale * 100.0)
		var wages := state.staff_sim.total_wages_per_min
		_tray_title.text = "OUTPOST CREW · MORALE %d%% · WAGES $%.0f/M" % [m_pct, wages]
		var ml := Label.new()
		ml.text = state.staff_sim.morale_breakdown
		_style_label(ml, DesertPalette.UI_INK_MUTED, 10, false)
		_tray_filters_row.add_child(ml)

		for ck in [GameCatalog.CrewKind.GRID_TECH, GameCatalog.CrewKind.PUMP_ENGINEER, GameCatalog.CrewKind.LOGISTICS_RUNNER]:
			var spec: Dictionary = GameCatalog.OUTPOST_CREW[ck]
			var lv := state.staff_sim.crew_level(ck)
			var lock := state.staff_sim.crew_lock_reason(ck, state)
			var cost := GameCatalog.crew_action_cost(ck, lv)
			var can_act := lock.is_empty() and state.cash >= cost
			var next_lv := mini(StaffSim.MAX_CREW_LEVEL, lv + 1)
			var pct_now := roundi(GameCatalog.crew_boost_for_level(ck, lv) * 100.0)
			var pct_nxt := roundi(GameCatalog.crew_boost_for_level(ck, next_lv) * 100.0)
			var title_s := "%s Lv%d" % [spec["short"], lv] if lv > 0 else str(spec["short"])
			var sub_s := ("+%d%% MAX · $%.0f/m" % [pct_now, float(spec["wage_per_min"])]) if lv >= StaffSim.MAX_CREW_LEVEL else ("+%d%% → +%d%% · $%.0f/m" % [pct_now, pct_nxt, float(spec["wage_per_min"])] if lv > 0 else "+%d%% · $%.0f/m" % [pct_nxt, float(spec["wage_per_min"])])
			var btn_t := lock if not lock.is_empty() else (("HIRE " if lv == 0 else "LV%d " % next_lv) + GameCatalog.format_cash(cost))
			var ck_val: int = ck
			_add_card(title_s, sub_s, btn_t, can_act, func(): state.hire_or_train_crew(ck_val), lv > 0)
	else:
		_tray_title.text = "UPGRADE & MOVE"
		var tc := state.tap_upgrade_cost()
		_add_card("Tap Power", "Lv %d → +$5" % state.tap_upgrade_level, GameCatalog.format_cash(tc), state.cash >= tc, func(): state.upgrade_tap_power(), true)
		for lot in state.parking_lots:
			var spec: Dictionary = GameCatalog.PARKING_LOTS[lot["kind"]]
			var lock := state.parking_upgrade_lock_reason(lot)
			var cost := state.parking_upgrade_cost(lot)
			var nxt := GameCatalog.next_parking_upgrade(lot["kind"])
			var sub := "NO ROAD" if not lot["is_connected"] else ("%d bays · MAX" % int(spec["spaces"]) if nxt < 0 else "%d → %d bays" % [int(spec["spaces"]), int(GameCatalog.PARKING_LOTS[nxt]["spaces"])])
			var btn_t := lock if not lock.is_empty() else GameCatalog.format_cash(cost)
			var ok := lock.is_empty() and state.cash >= cost
			var l_ref: Dictionary = lot
			_add_card(spec["name"], sub, btn_t, ok, func(): state.upgrade_parking_lot(l_ref), true, func():
				_tray_mode = TrayMode.NONE
				state.start_relocating_parking(l_ref)
			, func(): state.remove_parking_lot(l_ref))
		for p in state.plots:
			if not p["is_built"]:
				continue
			var d: Dictionary = GameCatalog.BUSINESSES[p["type"]]
			var lock := state.upgrade_lock_reason(p)
			var cost := GameCatalog.upgrade_cost_for_level(p["type"], p["level"])
			var pct := roundi(float(p["access"]["score"]) * 100.0)
			var btn_t := lock if not lock.is_empty() else GameCatalog.format_cash(cost)
			var ok := lock.is_empty() and state.cash >= cost
			var p_ref: Dictionary = p
			_add_card("%s Lv%d" % [d["short"], int(p["level"])], "Access %d%%" % pct, btn_t, ok, func(): state.upgrade_plot(p_ref), true, func():
				_tray_mode = TrayMode.NONE
				state.start_relocating_plot(p_ref)
			)


func _add_card(title_s: String, sub_s: String, cost_s: String, enabled: bool, on_press: Callable, is_upg: bool = false, on_move: Callable = Callable(), on_del: Callable = Callable()) -> void:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(128, 122)
	pc.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT_DARK, DesertPalette.UI_WOOD_RIM, 12, 2, 2))
	_tray_list.add_child(pc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)

	if on_move.is_valid() or on_del.is_valid():
		var top_a := HBoxContainer.new()
		top_a.add_theme_constant_override("separation", 4)
		vb.add_child(top_a)
		if on_del.is_valid():
			var db := Button.new()
			db.text = "DEL"
			_style_button(db, DesertPalette.UI_TERRA_TOP, DesertPalette.UI_TERRA_BASE, Color.WHITE, 9, 7)
			db.pressed.connect(on_del)
			top_a.add_child(db)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_a.add_child(sp)
		if on_move.is_valid():
			var mb := Button.new()
			mb.text = "MOVE"
			_style_button(mb, DesertPalette.UI_WOOD_BODY, DesertPalette.UI_WOOD_DEEP, Color("fff2d4"), 9, 7)
			mb.pressed.connect(on_move)
			top_a.add_child(mb)

	var tl := Label.new()
	tl.text = title_s
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.clip_text = true
	_style_label(tl, DesertPalette.UI_INK, 11, false)
	vb.add_child(tl)

	var sl := Label.new()
	sl.text = sub_s
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.clip_text = true
	_style_label(sl, DesertPalette.UI_INK_MUTED, 10, false)
	vb.add_child(sl)

	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp2)

	var btn := Button.new()
	btn.text = cost_s
	btn.disabled = not enabled
	var tc := (DesertPalette.UI_GOLD_TOP if is_upg else DesertPalette.UI_GREEN_TOP) if enabled else DesertPalette.UI_STONE_BASE
	var bc := (DesertPalette.UI_GOLD_BASE if is_upg else DesertPalette.UI_GREEN_BASE) if enabled else DesertPalette.UI_STONE_BASE
	var fc := DesertPalette.UI_INK if (is_upg and enabled) else Color.WHITE
	_style_button(btn, tc, bc, fc, 10, 9)
	btn.pressed.connect(on_press)
	vb.add_child(btn)


func _refresh_menu_modal() -> void:
	_menu_stats[0].text = "%d/6" % state.outpost_stage()
	_menu_stats[1].text = "%d%%" % roundi(state.average_access_score() * 100.0)
	_menu_stats[2].text = "%d" % state.total_parking_spaces()
	_menu_stats[3].text = "%d" % state.road_network.road_count()
	var si := state.stage_info()
	_menu_stage_lbl.text = "Stage %d · %s — Next: %s" % [state.outpost_stage(), si["title"], si["next_requirement"]]
	_menu_auto_btn.text = "AUTO" if state.auto_day_night else "HOLD"
	_style_button(_menu_auto_btn, DesertPalette.UI_GREEN_TOP if state.auto_day_night else DesertPalette.UI_WOOD_BODY, DesertPalette.UI_GREEN_BASE if state.auto_day_night else DesertPalette.UI_WOOD_DEEP, Color.WHITE, 10, 10)

	for c in _menu_milestones_box.get_children():
		c.queue_free()
	for m in state.milestones:
		var done := state.is_milestone_completed(m)
		var row_p := PanelContainer.new()
		row_p.add_theme_stylebox_override("panel", _make_box(DesertPalette.UI_PARCHMENT_DARK, DesertPalette.UI_GOLD_BASE if (done and not m["claimed"]) else DesertPalette.UI_WOOD_RIM, 12, 2, 0))
		_menu_milestones_box.add_child(row_p)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		row_p.add_child(hb)
		var ivb := VBoxContainer.new()
		ivb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(ivb)
		var tl := Label.new()
		tl.text = m["title"]
		_style_label(tl, DesertPalette.UI_INK, 12, false)
		ivb.add_child(tl)
		var dl := Label.new()
		dl.text = m["desc"]
		_style_label(dl, DesertPalette.UI_INK_MUTED, 10, false)
		ivb.add_child(dl)
		if m["claimed"]:
			var cl := Label.new()
			cl.text = "DONE"
			_style_label(cl, DesertPalette.UI_GREEN_BASE, 10, true)
			hb.add_child(cl)
		elif done:
			var cb := Button.new()
			cb.text = "+%s" % GameCatalog.format_cash(m["reward"])
			_style_button(cb, DesertPalette.UI_GOLD_TOP, DesertPalette.UI_GOLD_BASE, DesertPalette.UI_INK, 10, 9)
			var m_ref: Dictionary = m
			cb.pressed.connect(func(): state.claim_milestone(m_ref))
			hb.add_child(cb)
		else:
			var rl := Label.new()
			rl.text = "+%s" % GameCatalog.format_cash(m["reward"])
			_style_label(rl, DesertPalette.UI_INK_MUTED, 10, true)
			hb.add_child(rl)


# --- 3D-Projected In-World Action Bubbles & Rising Popups ---

func _update_in_world_bubbles() -> void:
	var entries: Array[Dictionary] = []
	var bob := sin(state.anim_time * 3.4) * 4.0

	if state.tool_mode == GameCatalog.WorldToolMode.BUY_LAND:
		var price := state.world_grid.next_parcel_price()
		var can_more := state.can_buy_more_land()
		for p in state.world_grid.purchasable_parcels():
			var p_ref: Vector2i = p
			var tr_id := state.world_grid.parcel_trait(p)
			var tr_spec := GameCatalog.parcel_trait_spec(tr_id)
			var prefix := "%s · " % str(tr_spec["short"]) if tr_id != GameCatalog.ParcelTrait.NONE else "LAND "
			entries.append({
				"pos": OutpostLayout.parcel_center(p.x, p.y) + Vector3(0, 1.2, 0),
				"text": "%s%s" % [prefix, GameCatalog.format_cash(price)] if can_more else "%sLOCKED" % prefix,
				"top": DesertPalette.UI_GREEN_TOP if (can_more and state.cash >= price) else DesertPalette.UI_WOOD_BODY,
				"base": DesertPalette.UI_GREEN_BASE if (can_more and state.cash >= price) else DesertPalette.UI_WOOD_DEEP,
				"fg": Color.WHITE,
				"cb": func(): state.buy_parcel(p_ref),
			})
	elif state.tool_mode == GameCatalog.WorldToolMode.PLAY and not _menu_open:
		var cart := state.cart_plot()
		if state.parking_lots.is_empty() and cart["is_built"]:
			var ok := state.cash >= 40.0
			var wp := state.plot_position(cart) + Vector3(2.6, 1.8, 2.4)
			var dirt_cb := func():
				if state.cash >= 40.0:
					state.quick_upgrade_or_place_parking()
				else:
					state.notify_shortfall(wp, 40.0 - state.cash)
			entries.append({
				"pos": wp,
				"text": "P  DIRT LOT $40",
				"top": DesertPalette.UI_GREEN_TOP if ok else DesertPalette.UI_WOOD_BODY,
				"base": DesertPalette.UI_GREEN_BASE if ok else DesertPalette.UI_WOOD_DEEP,
				"fg": Color.WHITE,
				"bob": bob if ok else 0.0,
				"cb": dirt_cb,
			})
		if state.needs_access_road() and cart["is_built"]:
			entries.append({
				"pos": state.plot_position(cart) + Vector3(-2.6, 1.8, 2.4),
				"text": "ACCESS ROAD",
				"top": DesertPalette.UI_GOLD_TOP,
				"base": DesertPalette.UI_GOLD_BASE,
				"fg": DesertPalette.UI_INK,
				"bob": bob * 0.6,
				"cb": func(): state.suggest_access_road(),
			})
		for lot in state.parking_lots:
			if not lot["is_connected"]:
				entries.append({
					"pos": state.lot_position(lot) + Vector3(0, 2.0, 0),
					"text": "CONNECT ROAD",
					"top": DesertPalette.UI_TERRA_TOP,
					"base": DesertPalette.UI_TERRA_BASE,
					"fg": Color.WHITE,
					"bob": bob * 0.6,
					"cb": func(): state.enter_road_mode(),
				})
			elif state.parking_upgrade_lock_reason(lot).is_empty():
				var cost := state.parking_upgrade_cost(lot)
				var nxt := GameCatalog.next_parking_upgrade(lot["kind"])
				if nxt >= 0 and state.cash >= cost:
					var l_ref: Dictionary = lot
					entries.append({
						"pos": state.lot_position(lot) + Vector3(0, 2.2, 0),
						"text": "↑ %s %s" % [GameCatalog.PARKING_LOTS[nxt]["short"], GameCatalog.format_cash(cost)],
						"top": DesertPalette.UI_GOLD_TOP,
						"base": DesertPalette.UI_GOLD_BASE,
						"fg": DesertPalette.UI_INK,
						"bob": bob,
						"cb": func(): state.upgrade_parking_lot(l_ref),
					})
		for p in state.plots:
			if not p["is_built"]:
				continue
			var rt: Dictionary = p.get("runtime", {})
			var low_pwr: bool = float(rt.get("power_demand_kw", 0.0)) > 0.0 and float(rt.get("power_ratio", 1.0)) < 0.99
			var low_h2o: bool = float(rt.get("water_demand", 0.0)) > 0.0 and float(rt.get("water_ratio", 1.0)) < 0.99
			var smax := float(rt.get("stock_max", 0.0))
			var low_stk: bool = smax > 0.0 and (float(rt.get("stock_units", smax)) / smax) < 0.20 and not bool(rt.get("restock_in_transit", false))
			if not state.parking_lots.is_empty() and float(p["access"]["score"]) <= 0.0:
				entries.append({
					"pos": state.plot_position(p) + Vector3(0, 3.6, 0),
					"text": "! %s" % p["access"]["status_label"],
					"top": DesertPalette.UI_TERRA_TOP,
					"base": DesertPalette.UI_TERRA_BASE,
					"fg": Color.WHITE,
					"bob": bob * 0.6,
					"cb": func(): state.enter_road_mode(),
				})
			elif low_pwr:
				var pid_ref: String = str(p["id"])
				entries.append({
					"pos": state.plot_position(p) + Vector3(0, 3.6, 0),
					"text": "⚡ LOW POWER",
					"top": DesertPalette.UI_TERRA_TOP,
					"base": DesertPalette.UI_TERRA_BASE,
					"fg": Color.WHITE,
					"bob": bob * 0.6,
					"cb": func():
						state.select_plot(pid_ref)
						_inspector.open_tab("power")
				})
			elif low_stk:
				var pid_ref2: String = str(p["id"])
				entries.append({
					"pos": state.plot_position(p) + Vector3(0, 3.6, 0),
					"text": "📦 RESTOCK",
					"top": DesertPalette.UI_GOLD_TOP,
					"base": DesertPalette.UI_GOLD_BASE,
					"fg": DesertPalette.UI_INK,
					"bob": bob * 0.6,
					"cb": func():
						state.select_plot(pid_ref2)
						_inspector.open_tab("stock")
				})
			elif low_h2o:
				entries.append({
					"pos": state.plot_position(p) + Vector3(0, 3.6, 0),
					"text": "💧 LOW WATER",
					"top": DesertPalette.WATER,
					"base": Color("327b8c"),
					"fg": Color.WHITE,
					"bob": bob * 0.6,
					"cb": func(): state.set_map_lens(GameCatalog.MapLens.WATER),
				})
			elif state.upgrade_lock_reason(p).is_empty():
				var cost := GameCatalog.upgrade_cost_for_level(p["type"], p["level"])
				if state.cash >= cost:
					var p_ref: Dictionary = p
					entries.append({
						"pos": state.plot_position(p) + Vector3(0, 3.8, 0),
						"text": "↑ LV%d %s" % [int(p["level"]) + 1, GameCatalog.format_cash(cost)],
						"top": DesertPalette.UI_GOLD_TOP,
						"base": DesertPalette.UI_GOLD_BASE,
						"fg": DesertPalette.UI_INK,
						"bob": bob,
						"cb": func(): state.upgrade_plot(p_ref),
					})

	var vp := get_viewport().get_visible_rect().size
	while _bubble_pool.size() < entries.size():
		var b := Button.new()
		_bubbles_layer.add_child(b)
		_bubble_pool.append(b)

	for i in range(_bubble_pool.size()):
		var b := _bubble_pool[i]
		if i >= entries.size():
			b.visible = false
			continue
		var e := entries[i]
		var wp: Vector3 = e["pos"]
		if camera.is_position_behind(wp):
			b.visible = false
			continue
		var sp := camera.unproject_position(wp)
		if sp.x < 40.0 or sp.x > vp.x - 40.0 or sp.y < 85.0 or sp.y > vp.y - 130.0:
			b.visible = false
			continue
		b.visible = true
		b.text = e["text"]
		_style_button(b, e["top"], e["base"], e["fg"], 10, 14)
		for conn in b.pressed.get_connections():
			b.pressed.disconnect(conn["callable"])
		b.pressed.connect(e["cb"])
		b.reset_size()
		b.position = Vector2(sp.x - b.size.x * 0.5, sp.y - 30.0 - float(e.get("bob", 0.0)))


func _update_floating_popups() -> void:
	while _popup_pool.size() < state.floating_cash.size():
		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_popups_layer.add_child(lbl)
		_popup_pool.append(lbl)

	for i in range(_popup_pool.size()):
		var lbl := _popup_pool[i]
		if i >= state.floating_cash.size():
			lbl.visible = false
			continue
		var fc := state.floating_cash[i]
		var prog := clampf(float(fc["age"]) / float(fc["duration"]), 0.0, 1.0)
		var wp: Vector3 = fc["pos"] + Vector3(float(fc["drift_x"]) * prog, prog * 2.35, 0.0)
		if camera.is_position_behind(wp):
			lbl.visible = false
			continue
		var sp := camera.unproject_position(wp)
		lbl.visible = true
		lbl.text = fc["text"]
		var col: Color = fc["color"]
		col.a = clampf(1.0 - prog * prog, 0.0, 1.0)
		_style_label(lbl, col, 15, true)
		lbl.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.04, col.a))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.reset_size()
		lbl.position = Vector2(sp.x - lbl.size.x * 0.5, sp.y - lbl.size.y * 0.5)
