class_name WorldRenderer
extends Node3D

## Manages the live Godot 4 3D Desert Outpost scene graph:
## - Dynamic ProceduralSkyMaterial + real DirectionalLight3D sun with soft shadows
## - Static backdrop (built once) & outpost static (rebuilt on layout change)
## - Modular buildings with tap-bounce & build-pop animations
## - Pooled Vehicles, Visitors, Particles, Clouds, Tumbleweeds & Build Overlays

var state: GameState

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SunLight

var _backdrop_root: Node3D
var _clouds_node: Node3D
var _static_outpost_node: Node3D
var _buildings_root: Node3D
var _utilities_root: Node3D
var _power_lines_node: Node3D
var _decos_root: Node3D
var _store_staff_root: Node3D
var _crew_root: Node3D
var _vehicles_root: Node3D
var _visitors_root: Node3D
var _particles_root: Node3D
var _overlays_root: Node3D
var _tumbleweeds: Array[Node3D] = []

var _plot_nodes: Dictionary = {}   # plot_id -> Node3D
var _plot_levels: Dictionary = {}  # plot_id -> int
var _plot_solar: Dictionary = {}   # plot_id -> bool
var _windmill_rotors: Array[Dictionary] = [] # [{"node": Node3D, "speed": float}]
var _pumpjack_beams: Array[Dictionary] = []  # [{"node": Node3D, "phase": float}]
var _crew_nodes: Dictionary = {}             # crew_id -> Node3D
var _vehicle_nodes: Dictionary = {} # vehicle_id -> {node, rev, hl}
var _visitor_nodes: Dictionary = {} # visitor_id -> Node3D
var _particle_mesh: BoxMesh
var _particle_nodes: Array[MeshInstance3D] = []
var _anim_rebuild_accum := 0.0


func setup(game_state: GameState) -> void:
	state = game_state
	_setup_environment()

	_buildings_root = Node3D.new()
	_utilities_root = Node3D.new()
	_decos_root = Node3D.new()
	_store_staff_root = Node3D.new()
	_crew_root = Node3D.new()
	_vehicles_root = Node3D.new()
	_visitors_root = Node3D.new()
	_particles_root = Node3D.new()
	_overlays_root = Node3D.new()
	for n in [_buildings_root, _utilities_root, _decos_root, _store_staff_root, _crew_root, _vehicles_root, _visitors_root, _particles_root, _overlays_root]:
		add_child(n)

	_backdrop_root = DesertTerrainBuilder.build_backdrop_node()
	add_child(_backdrop_root)
	_clouds_node = DesertTerrainBuilder.build_clouds_node()
	add_child(_clouds_node)
	_build_tumbleweeds()

	_particle_mesh = BoxMesh.new()
	_particle_mesh.size = Vector3.ONE

	state.world_layout_changed.connect(_rebuild_outpost_layout)
	state.overlay_changed.connect(_rebuild_overlays)
	_rebuild_outpost_layout()


func _setup_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6693c9")
	sky_mat.sky_horizon_color = Color("f7cca6")
	sky_mat.ground_bottom_color = DesertPalette.SAND_DARK
	sky_mat.ground_horizon_color = Color("f7cca6")
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f2d7bc")
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("f3cfa8")
	env.fog_density = 0.0018
	world_env.environment = env

	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.04
	sun_light.shadow_normal_bias = 1.5
	sun_light.directional_shadow_max_distance = 160.0
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func _build_tumbleweeds() -> void:
	for i in range(2):
		var kit := MeshKit.new()
		kit.add_frustum(0, 0.04, 0, 0.22, 0.20, 0.16, 0.15, 0.30, 5, DesertPalette.ARROYO_DARK, DesertPalette.WOOD_LIGHT)
		var tw := kit.build_node("Tumbleweed_%d" % i, true)
		add_child(tw)
		_tumbleweeds.append(tw)


func _rebuild_outpost_layout() -> void:
	if state == null:
		return
	if _static_outpost_node != null:
		_static_outpost_node.queue_free()
	_static_outpost_node = DesertTerrainBuilder.build_flora_and_roads_node(state)
	add_child(_static_outpost_node)

	_rebuild_buildings(true)
	_rebuild_utilities_and_power()
	_rebuild_decorations()
	_rebuild_store_staff()
	_rebuild_overlays()


func _rebuild_buildings(force: bool) -> void:
	for p in state.plots:
		var pid: String = p["id"]
		if not p["is_built"]:
			if _plot_nodes.has(pid):
				_plot_nodes[pid].queue_free()
				_plot_nodes.erase(pid)
				_plot_levels.erase(pid)
				_plot_solar.erase(pid)
			continue
		var lv: int = p["level"]
		var has_solar: bool = state.plot_has_rooftop_solar(p)
		if force or not _plot_nodes.has(pid) or int(_plot_levels.get(pid, -1)) != lv or bool(_plot_solar.get(pid, false)) != has_solar:
			if _plot_nodes.has(pid):
				_plot_nodes[pid].queue_free()
			var node := BuildingBuilder.build_plot_node(p["type"], lv, state.anim_time, null, has_solar)
			_buildings_root.add_child(node)
			_plot_nodes[pid] = node
			_plot_levels[pid] = lv
			_plot_solar[pid] = has_solar
		var n: Node3D = _plot_nodes[pid]
		n.visible = state.relocating_plot_id != pid
		n.position = state.plot_position(p)
		n.rotation.y = -OutpostLayout.yaw_for_quarter_turn(p["rot"])


func _rebuild_utilities_and_power() -> void:
	for c in _utilities_root.get_children():
		c.queue_free()
	_windmill_rotors.clear()
	_pumpjack_beams.clear()
	for u in state.utilities:
		if not state.relocating_utility_id.is_empty() and str(u["id"]) == state.relocating_utility_id:
			continue
		var ukind: int = int(u["kind"])
		var node := PowerBuilder.build_utility_node(ukind, u)
		node.position = state.utility_position(u)
		node.rotation.y = -OutpostLayout.yaw_for_quarter_turn(int(u.get("rot", 0)))
		_utilities_root.add_child(node)
		if ukind == GameCatalog.UtilityKind.WINDMILL:
			var rotor := node.get_node_or_null("Rotor")
			if rotor != null:
				var wind_boost := state.world_grid.cell_trait(Vector2i(int(u["grid_x"]), int(u["grid_z"]))) == GameCatalog.ParcelTrait.WIND_CORRIDOR
				_windmill_rotors.append({"node": rotor, "speed": 2.9 if wind_boost else 1.85})
		elif ukind == GameCatalog.UtilityKind.OIL_PUMPJACK:
			var beam := node.get_node_or_null("Beam")
			if beam != null:
				_pumpjack_beams.append({"node": beam, "phase": float(int(u["grid_x"]) + int(u["grid_z"])) * 0.7})

	if _power_lines_node != null:
		_power_lines_node.queue_free()
	_power_lines_node = PowerBuilder.build_power_lines_node(state)
	add_child(_power_lines_node)


func _rebuild_decorations() -> void:
	for c in _decos_root.get_children():
		c.queue_free()
	for d in state.decorations:
		if not state.relocating_deco_id.is_empty() and d["id"] == state.relocating_deco_id:
			continue
		var n := BuildingBuilder.build_decoration_node(d["kind"], state.anim_time)
		n.position = OutpostLayout.cell_center(d["grid_x"], d["grid_z"])
		n.rotation.y = -OutpostLayout.yaw_for_quarter_turn(int(d.get("rot", 0)))
		_decos_root.add_child(n)


func _rebuild_store_staff() -> void:
	for c in _store_staff_root.get_children():
		c.queue_free()
	for p in state.plots:
		if not p["is_built"] or state.relocating_plot_id == str(p["id"]):
			continue
		var hired: Array = state.plot_staff_list(p)
		if hired.is_empty():
			continue
		# Display the highest hired role's uniform standing at the store's entrance porch
		var top_role: Dictionary = GameCatalog.STAFF_ROLES[0]
		for r: Dictionary in GameCatalog.STAFF_ROLES:
			if hired.has(str(r["id"])):
				top_role = r
		var sn := EntityBuilder.build_store_staff_node(top_role)
		var step := OutpostLayout.forward_step_for_quarter_turn(int(p["rot"]))
		var side := Vector3(-float(step.y), 0.0, float(step.x))
		sn.position = state.plot_visitor_stop(p) + side * 0.85 - Vector3(float(step.x), 0.0, float(step.y)) * 0.25
		sn.rotation.y = -OutpostLayout.yaw_for_quarter_turn(int(p["rot"]))
		_store_staff_root.add_child(sn)


func _rebuild_overlays() -> void:
	for c in _overlays_root.get_children():
		c.queue_free()
	var has_tool := state.tool_mode != GameCatalog.WorldToolMode.PLAY
	var has_lens := state.active_lens != GameCatalog.MapLens.NONE
	if not has_tool and not has_lens:
		return

	var kit := MeshKit.new()
	const CS := OutpostLayout.GRID_CELL_SIZE
	const PARCEL_W := float(OutpostLayout.PARCEL_SIZE) * CS

	# 1. Active Map Lens Layer (renders even in PLAY mode!)
	if has_lens:
		_build_lens_overlay(kit, CS, PARCEL_W)

	# 2. Active Tool Mode Layer (land frames, tile grid, road preview, placement ghost)
	if has_tool:
		for p: Vector2i in state.world_grid.owned_parcels.keys():
			var c := OutpostLayout.parcel_center(p.x, p.y)
			_add_border_frame(kit, c.x, c.z, PARCEL_W - 0.25, PARCEL_W - 0.25, 0.14, Color(0.95, 0.76, 0.30, 0.85))
		if state.tool_mode == GameCatalog.WorldToolMode.BUY_LAND:
			var can_buy := state.can_buy_more_land()
			for p in state.world_grid.purchasable_parcels():
				var c := OutpostLayout.parcel_center(p.x, p.y)
				var tr_id: int = state.world_grid.parcel_trait(p)
				var tr_spec := GameCatalog.parcel_trait_spec(tr_id)
				var col: Color = (tr_spec["tint"] if tr_id != GameCatalog.ParcelTrait.NONE else Color(0.32, 0.80, 0.44, 0.42)) if can_buy else Color(0.25, 0.25, 0.25, 0.30)
				var rim: Color = (tr_spec["rim"] if tr_id != GameCatalog.ParcelTrait.NONE else Color(0.60, 1.0, 0.62, 0.90)) if can_buy else Color(0.7, 0.7, 0.7, 0.45)
				kit.add_ground_rect(c.x, 0.04, c.z, PARCEL_W - 0.5, PARCEL_W - 0.5, col)
				_add_border_frame(kit, c.x, c.z, PARCEL_W - 0.4, PARCEL_W - 0.4, 0.20, rim)
		else:
			for p: Vector2i in state.world_grid.owned_parcels.keys():
				var rect := OutpostLayout.parcel_cell_bounds(p.x, p.y)
				var min_x := (float(rect.position.x) - 0.5) * CS
				var max_x := (float(rect.position.x + rect.size.x) - 0.5) * CS
				var min_z := (float(rect.position.y) - 0.5) * CS
				var max_z := (float(rect.position.y + rect.size.y) - 0.5) * CS
				var gcol := Color(1.0, 0.96, 0.86, 0.26)
				for gx in range(rect.position.x, rect.position.x + rect.size.x + 1):
					var x := (float(gx) - 0.5) * CS
					kit.add_ground_rect(x, 0.038, (min_z + max_z) * 0.5, 0.05, max_z - min_z, gcol)
				for gz in range(rect.position.y, rect.position.y + rect.size.y + 1):
					var z := (float(gz) - 0.5) * CS
					kit.add_ground_rect((min_x + max_x) * 0.5, 0.038, z, max_x - min_x, 0.05, gcol)

		if state.tool_mode == GameCatalog.WorldToolMode.PAINT_ROAD and state.has_road_start:
			var prev := state.compute_road_line_preview()
			var ok: bool = str(prev["reason"]).is_empty() and not prev["build"].is_empty()
			var bcol := Color(0.86, 0.30, 0.22, 0.56) if state.road_erase_mode else (Color(0.28, 0.78, 0.42, 0.56) if ok else Color(0.95, 0.65, 0.24, 0.54))
			var build_set: Dictionary = {}
			for c: Vector2i in prev["build"]:
				build_set[c] = true
				var wc := OutpostLayout.cell_center_v(c)
				kit.add_ground_rect(wc.x, 0.055, wc.z, CS - 0.06, CS - 0.06, bcol)
			for c: Vector2i in prev["skip"]:
				var wc := OutpostLayout.cell_center_v(c)
				kit.add_ground_rect(wc.x, 0.052, wc.z, CS - 0.14, CS - 0.14, Color(1.0, 1.0, 1.0, 0.24))
			for c: Vector2i in prev["blocked"]:
				var wc := OutpostLayout.cell_center_v(c)
				kit.add_ground_rect(wc.x, 0.060, wc.z, CS - 0.10, CS - 0.10, Color(0.92, 0.24, 0.18, 0.72))
			if state.road_two_lane and not state.road_erase_mode:
				var dash_col := Color(0.98, 0.85, 0.36, 0.85)
				for c: Vector2i in build_set.keys():
					var wc := OutpostLayout.cell_center_v(c)
					if build_set.has(Vector2i(c.x + 1, c.y)) and not build_set.has(Vector2i(c.x - 1, c.y)) and (build_set.has(Vector2i(c.x, c.y - 1)) or build_set.has(Vector2i(c.x, c.y + 1))):
						kit.add_ground_rect(wc.x + CS * 0.5, 0.064, wc.z, 0.12, 1.05, dash_col)
					elif build_set.has(Vector2i(c.x, c.y + 1)) and not build_set.has(Vector2i(c.x, c.y - 1)) and (build_set.has(Vector2i(c.x - 1, c.y)) or build_set.has(Vector2i(c.x + 1, c.y))):
						kit.add_ground_rect(wc.x, 0.064, wc.z + CS * 0.5, 1.05, 0.12, dash_col)

		if state.tool_mode == GameCatalog.WorldToolMode.PAINT_CONDUIT and state.has_conduit_start:
			var cprev := state.compute_conduit_line_preview()
			var cok: bool = str(cprev["reason"]).is_empty() and not cprev["build"].is_empty()
			var cbcol := Color(0.86, 0.30, 0.22, 0.62) if state.conduit_erase_mode else (Color(0.28, 0.88, 0.96, 0.65) if cok else Color(0.95, 0.65, 0.24, 0.56))
			for c: Vector2i in cprev["build"]:
				var wc := OutpostLayout.cell_center_v(c)
				kit.add_ground_rect(wc.x, 0.068, wc.z, CS * 0.68, CS * 0.68, cbcol)
			for c: Vector2i in cprev["skip"]:
				var wc := OutpostLayout.cell_center_v(c)
				kit.add_ground_rect(wc.x, 0.064, wc.z, CS * 0.45, CS * 0.45, Color(1.0, 1.0, 1.0, 0.28))
			for c: Vector2i in cprev["blocked"]:
				var wc := OutpostLayout.cell_center_v(c)
				kit.add_ground_rect(wc.x, 0.070, wc.z, CS * 0.72, CS * 0.72, Color(0.92, 0.24, 0.18, 0.75))

		if state.tool_mode == GameCatalog.WorldToolMode.PAINT_WATER_PIPE and state.has_water_pipe_start:
			var wprev := state.compute_water_pipe_line_preview()
			var wok: bool = str(wprev["reason"]).is_empty() and not wprev["build"].is_empty()
			var wbcol := Color(0.86, 0.30, 0.22, 0.62) if state.water_pipe_erase_mode else (Color(0.24, 0.68, 0.98, 0.68) if wok else Color(0.95, 0.65, 0.24, 0.56))
			for c: Vector2i in wprev["build"]:
				var wc := OutpostLayout.cell_center_v(c)
				kit.add_ground_rect(wc.x, 0.068, wc.z, CS * 0.68, CS * 0.68, wbcol)
			for c: Vector2i in wprev["skip"]:
				var wc := OutpostLayout.cell_center_v(c)
				kit.add_ground_rect(wc.x, 0.064, wc.z, CS * 0.45, CS * 0.45, Color(1.0, 1.0, 1.0, 0.28))
			for c: Vector2i in wprev["blocked"]:
				var wc := OutpostLayout.cell_center_v(c)
				kit.add_ground_rect(wc.x, 0.070, wc.z, CS * 0.72, CS * 0.72, Color(0.92, 0.24, 0.18, 0.75))

		if state.tool_mode == GameCatalog.WorldToolMode.PLACE_UTILITY and state.pending_utility_kind >= 0:
			var usz := state.ghost_size()
			var ucenter := OutpostLayout.footprint_center(state.ghost_grid_x, state.ghost_grid_z, usz.x, usz.y)
			var uspec: Dictionary = GameCatalog.UTILITIES[state.pending_utility_kind]
			var w_rad := int(uspec.get("water_radius", 0))
			if w_rad > 0:
				var rw := float(usz.x + w_rad * 2) * CS
				var rd := float(usz.y + w_rad * 2) * CS
				_add_border_frame(kit, ucenter.x, ucenter.z, rw, rd, 0.16, Color(0.28, 0.76, 1.0, 0.82))
			elif float(uspec.get("base_kw", 0.0)) > 0.0 or float(uspec.get("battery_kwh", 0.0)) > 0.0:
				var link_w := float(usz.x + PowerNetwork.LOCAL_LINK_TILES * 2) * CS
				var link_d := float(usz.y + PowerNetwork.LOCAL_LINK_TILES * 2) * CS
				_add_border_frame(kit, ucenter.x, ucenter.z, link_w, link_d, 0.16, Color(0.98, 0.82, 0.28, 0.78))

		if state.tool_mode == GameCatalog.WorldToolMode.PLACE_BUILDING:
			var rep := state.ghost_access_preview()
			var route: Array = rep["route_preview"]
			if route.size() >= 2:
				var sc: float = rep["score"]
				var rcol := Color("6ef594") if sc >= 0.88 else (Color("ffb24a") if sc < 0.55 else Color("68e8de"))
				for i in range(route.size() - 1):
					var a: Vector3 = route[i]
					var b: Vector3 = route[i + 1]
					var mid := a.lerp(b, 0.5)
					var diff := b - a
					var seg_len := diff.length()
					if seg_len < 0.05:
						continue
					kit.push_tx(Vector3(mid.x, 0.08, mid.z), -atan2(diff.z, diff.x))
					kit.add_ground_rect(0, 0, 0, seg_len + 0.12, 0.34, rcol)
					kit.pop_tx()

	_overlays_root.add_child(kit.build_node("GridOverlay", false, DesertPalette.get_unlit_material()))

	if not has_tool:
		return

	# Live 3D placement ghost mesh
	var valid := state.ghost_invalid_reason().is_empty()
	var gmat := DesertPalette.get_ghost_material(valid)
	var sz := state.ghost_size()
	var gcenter := OutpostLayout.footprint_center(state.ghost_grid_x, state.ghost_grid_z, sz.x, sz.y)
	if state.tool_mode == GameCatalog.WorldToolMode.PLACE_BUILDING and state.pending_building_type >= 0:
		var gn := BuildingBuilder.build_plot_node(state.pending_building_type, 1, 0.0, gmat)
		gn.position = gcenter
		gn.rotation.y = -OutpostLayout.yaw_for_quarter_turn(state.ghost_rotation)
		_overlays_root.add_child(gn)
	elif state.tool_mode == GameCatalog.WorldToolMode.PLACE_PARKING and state.pending_parking_kind >= 0:
		var pn := BuildingBuilder.build_parking_ghost_node(state.pending_parking_kind, state.ghost_rotation, valid)
		pn.position = gcenter
		_overlays_root.add_child(pn)
	elif state.tool_mode == GameCatalog.WorldToolMode.PLACE_DECORATION and not state.pending_deco.is_empty():
		var dn := BuildingBuilder.build_decoration_node(state.pending_deco["kind"], 0.0, gmat)
		dn.position = OutpostLayout.cell_center(state.ghost_grid_x, state.ghost_grid_z)
		dn.rotation.y = -OutpostLayout.yaw_for_quarter_turn(state.ghost_rotation)
		_overlays_root.add_child(dn)
	elif state.tool_mode == GameCatalog.WorldToolMode.PLACE_UTILITY and state.pending_utility_kind >= 0:
		var un := PowerBuilder.build_utility_node(state.pending_utility_kind, {}, gmat)
		un.position = gcenter
		un.rotation.y = -OutpostLayout.yaw_for_quarter_turn(state.ghost_rotation)
		_overlays_root.add_child(un)


func _build_lens_overlay(kit: MeshKit, cs: float, parcel_w: float) -> void:
	match state.active_lens:
		GameCatalog.MapLens.LAND_TRAITS:
			for px in range(OutpostLayout.PARCEL_COUNT_X):
				for pz in range(OutpostLayout.PARCEL_COUNT_Z):
					var p := Vector2i(px, pz)
					var c := OutpostLayout.parcel_center(px, pz)
					var revealed := state.world_grid.is_parcel_trait_revealed(p)
					if revealed:
						var tr_id := state.world_grid.parcel_trait(p)
						var spec := GameCatalog.parcel_trait_spec(tr_id)
						kit.add_ground_rect(c.x, 0.041, c.z, parcel_w - 0.55, parcel_w - 0.55, spec["tint"])
						_add_border_frame(kit, c.x, c.z, parcel_w - 0.45, parcel_w - 0.45, 0.16, spec["rim"])
					else:
						_add_border_frame(kit, c.x, c.z, parcel_w - 0.55, parcel_w - 0.55, 0.09, Color(0.85, 0.78, 0.66, 0.24))
		GameCatalog.MapLens.POWER:
			for p in state.plots:
				if not p["is_built"]:
					continue
				var btype: int = int(p["type"])
				var rt: Dictionary = p.get("runtime", {})
				var dem := float(rt.get("power_demand_kw", GameCatalog.business_power_demand_kw(btype, int(p["level"]), state.sim_clock.is_night())))
				var ratio := float(rt.get("power_ratio", 1.0))
				var data: Dictionary = GameCatalog.BUSINESSES[btype]
				var sz := OutpostLayout.rotated_size(data["grid_w"], data["grid_d"], p["rot"])
				var pos := state.plot_position(p)
				var col := Color(0.32, 0.86, 0.52, 0.46) if (dem <= 0.0 or ratio >= 0.99) else (Color(0.98, 0.72, 0.24, 0.52) if ratio > PowerNetwork.BROWNOUT_FLOOR + 0.02 else Color(0.92, 0.30, 0.24, 0.56))
				kit.add_ground_rect(pos.x, 0.056, pos.z, float(sz.x) * cs + 0.4, float(sz.y) * cs + 0.4, col)
			for u in state.utilities:
				var spec: Dictionary = GameCatalog.UTILITIES[int(u["kind"])]
				var sz := OutpostLayout.rotated_size(int(spec["grid_w"]), int(spec["grid_d"]), int(u.get("rot", 0)))
				var pos := state.utility_position(u)
				kit.add_ground_rect(pos.x, 0.056, pos.z, float(sz.x) * cs + 0.4, float(sz.y) * cs + 0.4, Color(0.98, 0.86, 0.28, 0.48))
				var link_w := float(sz.x + PowerNetwork.LOCAL_LINK_TILES * 2) * cs
				var link_d := float(sz.y + PowerNetwork.LOCAL_LINK_TILES * 2) * cs
				_add_border_frame(kit, pos.x, pos.z, link_w, link_d, 0.11, Color(0.98, 0.86, 0.28, 0.36))
			for cell: Vector2i in state.world_grid.power_poles.keys():
				var wc := OutpostLayout.cell_center_v(cell)
				kit.add_ground_rect(wc.x, 0.062, wc.z, cs * 0.72, cs * 0.72, Color(1.0, 0.86, 0.28, 0.80))
			for sp in state.power_network.overhead_spans:
				var a: Vector3 = sp["a"]
				var b: Vector3 = sp["b"]
				var a2 := Vector3(a.x, 0.065, a.z)
				var b2 := Vector3(b.x, 0.065, b.z)
				var mid := a2.lerp(b2, 0.5)
				var diff := b2 - a2
				var slen := diff.length()
				if slen > 0.05:
					kit.push_tx(mid, -atan2(diff.z, diff.x))
					kit.add_ground_rect(0, 0, 0, slen, 0.16, Color(1.0, 0.84, 0.24, 0.76))
					kit.pop_tx()
			for cell: Vector2i in state.world_grid.power_underground.keys():
				var wc := OutpostLayout.cell_center_v(cell)
				kit.add_ground_rect(wc.x, 0.064, wc.z, cs * 0.46, cs * 0.46, Color(0.28, 0.92, 0.98, 0.84))
				for nb: Vector2i in [Vector2i(cell.x + 1, cell.y), Vector2i(cell.x, cell.y + 1)]:
					if state.world_grid.has_underground_power(nb):
						var nc := OutpostLayout.cell_center_v(nb)
						var mid := wc.lerp(nc, 0.5)
						var is_h: bool = nb.x != cell.x
						kit.add_ground_rect(mid.x, 0.064, mid.z, cs if is_h else 0.34, 0.34 if is_h else cs, Color(0.28, 0.92, 0.98, 0.84))
		GameCatalog.MapLens.WATER:
			for p: Vector2i in state.world_grid.parcels_with_trait(GameCatalog.ParcelTrait.AQUIFER):
				if state.world_grid.is_parcel_trait_revealed(p):
					var c := OutpostLayout.parcel_center(p.x, p.y)
					var spec := GameCatalog.parcel_trait_spec(GameCatalog.ParcelTrait.AQUIFER)
					kit.add_ground_rect(c.x, 0.042, c.z, parcel_w - 0.5, parcel_w - 0.5, spec["tint"])
					_add_border_frame(kit, c.x, c.z, parcel_w - 0.4, parcel_w - 0.4, 0.18, spec["rim"])
			for u in state.utilities:
				var uspec: Dictionary = GameCatalog.UTILITIES[int(u["kind"])]
				var wout := float(uspec.get("water_output", 0.0))
				var wneed := float(uspec.get("water_need", 0.0))
				if wout <= 0.0 and wneed <= 0.0:
					continue
				var sz := OutpostLayout.rotated_size(int(uspec["grid_w"]), int(uspec["grid_d"]), int(u.get("rot", 0)))
				var pos := state.utility_position(u)
				var ucol := Color(0.24, 0.82, 1.0, 0.54) if wout > 0.0 else (Color(0.32, 0.86, 0.52, 0.46) if float(u.get("water_ratio", 1.0)) >= 0.99 else Color(0.92, 0.34, 0.24, 0.54))
				kit.add_ground_rect(pos.x, 0.056, pos.z, float(sz.x) * cs + 0.4, float(sz.y) * cs + 0.4, ucol)
				var wrad := int(uspec.get("water_radius", 0))
				if wrad > 0:
					_add_border_frame(kit, pos.x, pos.z, float(sz.x + wrad * 2) * cs, float(sz.y + wrad * 2) * cs, 0.11, Color(0.32, 0.84, 1.0, 0.42))
			for p in state.plots:
				if not p["is_built"]:
					continue
				var btype: int = int(p["type"])
				var wneed := float(GameCatalog.BUSINESSES[btype].get("water_need", 0.0))
				if wneed <= 0.0:
					continue
				var data: Dictionary = GameCatalog.BUSINESSES[btype]
				var sz := OutpostLayout.rotated_size(data["grid_w"], data["grid_d"], p["rot"])
				var pos := state.plot_position(p)
				var wr := float(p.get("runtime", {}).get("water_ratio", 1.0))
				var col := Color(0.28, 0.78, 0.96, 0.48) if wr >= 0.99 else Color(0.92, 0.34, 0.24, 0.56)
				kit.add_ground_rect(pos.x, 0.056, pos.z, float(sz.x) * cs + 0.4, float(sz.y) * cs + 0.4, col)
			for cell: Vector2i in state.world_grid.water_pipes.keys():
				var wc := OutpostLayout.cell_center_v(cell)
				kit.add_ground_rect(wc.x, 0.064, wc.z, cs * 0.46, cs * 0.46, Color(0.22, 0.74, 1.0, 0.86))
				for nb: Vector2i in [Vector2i(cell.x + 1, cell.y), Vector2i(cell.x, cell.y + 1)]:
					if state.world_grid.has_water_pipe(nb):
						var nc := OutpostLayout.cell_center_v(nb)
						var mid := wc.lerp(nc, 0.5)
						var is_h: bool = nb.x != cell.x
						kit.add_ground_rect(mid.x, 0.064, mid.z, cs if is_h else 0.34, 0.34 if is_h else cs, Color(0.22, 0.74, 1.0, 0.86))
		GameCatalog.MapLens.SUPPLY:
			for u in state.utilities:
				if GameCatalog.utility_group(int(u["kind"])) != "supply":
					continue
				var uspec: Dictionary = GameCatalog.UTILITIES[int(u["kind"])]
				var sz := OutpostLayout.rotated_size(int(uspec["grid_w"]), int(uspec["grid_d"]), int(u.get("rot", 0)))
				var pos := state.utility_position(u)
				kit.add_ground_rect(pos.x, 0.056, pos.z, float(sz.x) * cs + 0.4, float(sz.y) * cs + 0.4, Color(0.98, 0.76, 0.28, 0.50))
			for p in state.plots:
				if not p["is_built"]:
					continue
				var btype: int = int(p["type"])
				var data: Dictionary = GameCatalog.BUSINESSES[btype]
				var sz := OutpostLayout.rotated_size(data["grid_w"], data["grid_d"], p["rot"])
				var pos := state.plot_position(p)
				var rt: Dictionary = p.get("runtime", {})
				var smax := float(rt.get("stock_max", 0.0))
				var frac := 1.0 if smax <= 0.0 else clampf(float(rt.get("stock_units", smax)) / smax, 0.0, 1.0)
				var col := Color(0.32, 0.86, 0.52, 0.46) if frac >= 0.60 else (Color(0.95, 0.72, 0.25, 0.50) if frac >= 0.25 else Color(0.90, 0.30, 0.24, 0.58))
				kit.add_ground_rect(pos.x, 0.056, pos.z, float(sz.x) * cs + 0.4, float(sz.y) * cs + 0.4, col)
			for lnk in state.supply_sim.flow_links:
				var a: Vector3 = lnk["from"]
				var b: Vector3 = lnk["to"]
				var a2 := Vector3(a.x, 0.072, a.z)
				var b2 := Vector3(b.x, 0.072, b.z)
				var mid := a2.lerp(b2, 0.5)
				var diff := b2 - a2
				var slen := diff.length()
				if slen > 0.1:
					var lcol: Color = GameCatalog.commodity_spec(int(lnk["commodity"]))["color"]
					lcol.a = 0.72
					kit.push_tx(mid, -atan2(diff.z, diff.x))
					kit.add_ground_rect(0, 0, 0, slen, 0.22, lcol)
					kit.pop_tx()


static func _add_border_frame(kit: MeshKit, cx: float, cz: float, w: float, d: float, thick: float, col: Color) -> void:
	kit.add_ground_rect(cx, 0.045, cz - d * 0.5, w, thick, col)
	kit.add_ground_rect(cx, 0.045, cz + d * 0.5, w, thick, col)
	kit.add_ground_rect(cx - w * 0.5, 0.045, cz, thick, d, col)
	kit.add_ground_rect(cx + w * 0.5, 0.045, cz, thick, d, col)


func _process(_delta: float) -> void:
	if state == null:
		return
	_update_lighting()
	_update_plot_animations()
	_update_vehicles_and_visitors()
	_update_particles()
	_update_ambient_motion()


func _update_lighting() -> void:
	var t := state.time_of_day
	var sun_angle := (t - 0.25) * TAU
	var elev := sin(sun_angle)
	var night_factor := clampf((-elev + 0.08) / 0.42, 0.0, 1.0)
	var sunset_factor := clampf(1.0 - absf(elev - 0.06) / 0.28, 0.0, 1.0) * (1.0 - night_factor * 0.5)

	DesertPalette.update_night_glow(night_factor, sunset_factor)

	var env := world_env.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	var top := Color("6693c9").lerp(Color("4b426e"), sunset_factor * 0.85).lerp(Color("0a1426"), night_factor)
	var hor := Color("f7cca6").lerp(Color("ffaf68"), sunset_factor * 0.85).lerp(Color("284060"), night_factor)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = DesertPalette.SAND_DARK.lerp(Color("1c2434"), night_factor * 0.8)
	env.fog_light_color = hor
	env.ambient_light_color = Color("f2d7bc").lerp(Color("ffbe96"), sunset_factor * 0.6).lerp(Color("3f5a82"), night_factor)
	env.ambient_light_energy = lerpf(0.58, 0.26, night_factor)

	var sun_pitch := clampf(lerpf(-0.92, -0.32, sunset_factor), -1.1, -0.25)
	var sun_yaw := lerpf(-0.65, 0.75, clampf((t - 0.25) * 2.0, 0.0, 1.0))
	sun_light.rotation = Vector3(sun_pitch, sun_yaw, 0.0)
	sun_light.light_color = Color("fff6e3").lerp(Color("ff9e5e"), sunset_factor * 0.85).lerp(Color("7ba4d8"), night_factor)
	sun_light.light_energy = lerpf(1.22, 0.34, night_factor)


func _update_plot_animations() -> void:
	for p in state.plots:
		var pid: String = p["id"]
		if not _plot_nodes.has(pid):
			continue
		var n: Node3D = _plot_nodes[pid]
		var sy := 1.0
		var sxz := 1.0
		if p["build_pop"] > 0.0:
			var prog := 1.0 - float(p["build_pop"])
			var s := clampf(prog * 1.2 + sin(prog * PI) * 0.14, 0.15, 1.08)
			sxz = s
			sy = s
		elif p["bounce"] > 0.0:
			var wave := sin((float(p["bounce"]) / 0.38) * PI)
			sy = 1.0 + wave * 0.11
			sxz = 1.0 - wave * 0.04
		n.scale = Vector3(sxz, sy, sxz)


func _update_vehicles_and_visitors() -> void:
	var t := state.time_of_day
	var elev := sin((t - 0.25) * TAU)
	var hl_on := elev < 0.15

	var active_vids: Dictionary = {}
	for v in state.vehicles:
		var vid: int = v["id"]
		active_vids[vid] = true
		var rev: bool = int(v["phase"]) == GameCatalog.VehiclePhase.BACKING_OUT
		if not _vehicle_nodes.has(vid) or _vehicle_nodes[vid]["rev"] != rev or _vehicle_nodes[vid]["hl"] != hl_on:
			if _vehicle_nodes.has(vid):
				_vehicle_nodes[vid]["node"].queue_free()
			var vn := EntityBuilder.build_vehicle_node(v["kind"], v["color"], hl_on, rev)
			_vehicles_root.add_child(vn)
			_vehicle_nodes[vid] = {"node": vn, "rev": rev, "hl": hl_on}
		var n: Node3D = _vehicle_nodes[vid]["node"]
		n.position = v["pos"]
		n.rotation.y = -float(v["yaw"])

	for vid in _vehicle_nodes.keys():
		if not active_vids.has(vid):
			_vehicle_nodes[vid]["node"].queue_free()
			_vehicle_nodes.erase(vid)

	var active_vis: Dictionary = {}
	for vis in state.visitors:
		var id: int = vis["id"]
		active_vis[id] = true
		if not _visitor_nodes.has(id):
			var vn := EntityBuilder.build_visitor_node(vis["shirt"], vis["hat"])
			_visitors_root.add_child(vn)
			_visitor_nodes[id] = vn
		var n: Node3D = _visitor_nodes[id]
		var walking: bool = vis["phase"] != GameCatalog.VisitorPhase.SHOPPING
		var bob := absf(sin(float(vis["walk_cycle"]) * 10.0)) * 0.08 if walking else 0.0
		n.position = vis["pos"] + Vector3(0, bob, 0)
		n.rotation.y = -float(vis["yaw"])

	for id in _visitor_nodes.keys():
		if not active_vis.has(id):
			_visitor_nodes[id].queue_free()
			_visitor_nodes.erase(id)

	# Roaming Outpost Crew 3D agents
	var active_crew: Dictionary = {}
	for ag in state.staff_sim.agents:
		var cid: String = str(ag["id"])
		active_crew[cid] = true
		if not _crew_nodes.has(cid):
			var cn := EntityBuilder.build_crew_node(int(ag["kind"]))
			_crew_root.add_child(cn)
			_crew_nodes[cid] = cn
		var n: Node3D = _crew_nodes[cid]
		var walking: bool = not (ag["waypoints"] as Array).is_empty()
		var bob := absf(sin(float(ag["walk_cycle"]) * 10.0)) * 0.08 if walking else absf(sin(float(ag["walk_cycle"]) * 3.0)) * 0.025
		n.position = (ag["pos"] as Vector3) + Vector3(0, bob, 0)
		n.rotation.y = -float(ag["yaw"])

	for cid in _crew_nodes.keys():
		if not active_crew.has(cid):
			_crew_nodes[cid].queue_free()
			_crew_nodes.erase(cid)


func _update_particles() -> void:
	while _particle_nodes.size() < state.particles.size():
		var mi := MeshInstance3D.new()
		mi.mesh = _particle_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		_particles_root.add_child(mi)
		_particle_nodes.append(mi)

	for i in range(_particle_nodes.size()):
		var mi := _particle_nodes[i]
		if i >= state.particles.size():
			mi.visible = false
			continue
		var pt := state.particles[i]
		mi.visible = true
		mi.position = pt["pos"]
		var prog := clampf(float(pt["age"]) / float(pt["duration"]), 0.0, 1.0)
		var sc := float(pt["size"]) * (1.0 - prog * 0.45)
		mi.scale = Vector3(sc, sc, sc)
		(mi.material_override as StandardMaterial3D).albedo_color = pt["color"]


func _update_ambient_motion() -> void:
	if _clouds_node != null:
		_clouds_node.position.x = sin(state.anim_time * 0.05) * 6.0
	for rinfo in _windmill_rotors:
		var rn: Node3D = rinfo["node"]
		if is_instance_valid(rn):
			rn.rotation.z = -state.anim_time * float(rinfo["speed"])
	for pinfo in _pumpjack_beams:
		var bn: Node3D = pinfo["node"]
		if is_instance_valid(bn):
			bn.rotation.z = sin(state.anim_time * 2.1 + float(pinfo["phase"])) * 0.26
	var tw_cfg := [[0.020, 22.5, 0.0], [0.014, -60.0, 0.45]]
	for i in range(_tumbleweeds.size()):
		var cfg: Array = tw_cfg[i]
		var cyc := fmod(state.anim_time * float(cfg[0]) + float(cfg[2]), 1.0)
		var tx := -90.0 + cyc * 180.0
		var tz := float(cfg[1]) + sin(state.anim_time * 0.3 + float(cfg[2]) * 10.0) * 2.0
		var hop := absf(sin(state.anim_time * 4.2 + float(cfg[2]) * 7.0)) * 0.22
		var gy := DesertTerrainBuilder.height_at(tx, tz)
		_tumbleweeds[i].visible = not state.is_world_point_occupied(tx, tz)
		_tumbleweeds[i].position = Vector3(tx, gy + hop, tz)
		_tumbleweeds[i].rotation.y = state.anim_time * 2.4
