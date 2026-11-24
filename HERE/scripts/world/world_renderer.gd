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
var _decos_root: Node3D
var _vehicles_root: Node3D
var _visitors_root: Node3D
var _particles_root: Node3D
var _overlays_root: Node3D
var _tumbleweeds: Array[Node3D] = []

var _plot_nodes: Dictionary = {}   # plot_id -> Node3D
var _plot_levels: Dictionary = {}  # plot_id -> int
var _vehicle_nodes: Dictionary = {} # vehicle_id -> {node, rev, hl}
var _visitor_nodes: Dictionary = {} # visitor_id -> Node3D
var _particle_mesh: BoxMesh
var _particle_nodes: Array[MeshInstance3D] = []
var _anim_rebuild_accum := 0.0


func setup(game_state: GameState) -> void:
	state = game_state
	_setup_environment()

	_buildings_root = Node3D.new()
	_decos_root = Node3D.new()
	_vehicles_root = Node3D.new()
	_visitors_root = Node3D.new()
	_particles_root = Node3D.new()
	_overlays_root = Node3D.new()
	for n in [_buildings_root, _decos_root, _vehicles_root, _visitors_root, _particles_root, _overlays_root]:
		add_child(n)

	_backdrop_root = DesertTerrainBuilder.build_backdrop_node()
	add_child(_backdrop_root)
	_clouds_node = DesertTerrainBuilder.build_clouds_node()
	add_child(_clouds_node)
	_build_tumbleweeds()

	_particle_mesh = BoxMesh.new()
	_particle_mesh.size = Vector3.ONE

	state.world_layout_changed.connect(_rebuild_outpost_layout)
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
	_rebuild_decorations()
	_rebuild_overlays()


func _rebuild_buildings(force: bool) -> void:
	for p in state.plots:
		var pid: String = p["id"]
		if not p["is_built"]:
			if _plot_nodes.has(pid):
				_plot_nodes[pid].queue_free()
				_plot_nodes.erase(pid)
				_plot_levels.erase(pid)
			continue
		var lv: int = p["level"]
		if force or not _plot_nodes.has(pid) or int(_plot_levels.get(pid, -1)) != lv:
			if _plot_nodes.has(pid):
				_plot_nodes[pid].queue_free()
			var node := BuildingBuilder.build_plot_node(p["type"], lv, state.anim_time)
			_buildings_root.add_child(node)
			_plot_nodes[pid] = node
			_plot_levels[pid] = lv
		var n: Node3D = _plot_nodes[pid]
		n.position = state.plot_position(p)
		n.rotation.y = -OutpostLayout.yaw_for_quarter_turn(p["rot"])


func _rebuild_decorations() -> void:
	for c in _decos_root.get_children():
		c.queue_free()
	for d in state.decorations:
		var n := BuildingBuilder.build_decoration_node(d["kind"], state.anim_time)
		n.position = OutpostLayout.cell_center(d["grid_x"], d["grid_z"])
		_decos_root.add_child(n)


func _rebuild_overlays() -> void:
	for c in _overlays_root.get_children():
		c.queue_free()
	if state.tool_mode == GameCatalog.WorldToolMode.PLAY:
		return

	var kit := MeshKit.new()
	const CS := OutpostLayout.GRID_CELL_SIZE
	const PARCEL_W := float(OutpostLayout.PARCEL_SIZE) * CS

	# Land parcel frames
	for p: Vector2i in state.world_grid.owned_parcels.keys():
		var c := OutpostLayout.parcel_center(p.x, p.y)
		_add_border_frame(kit, c.x, c.z, PARCEL_W - 0.25, PARCEL_W - 0.25, 0.14, Color(0.95, 0.76, 0.30, 0.85))
	if state.tool_mode == GameCatalog.WorldToolMode.BUY_LAND:
		var can_buy := state.can_buy_more_land()
		var col := Color(0.32, 0.80, 0.44, 0.42) if can_buy else Color(0.25, 0.25, 0.25, 0.30)
		var rim := Color(0.60, 1.0, 0.62, 0.90) if can_buy else Color(0.7, 0.7, 0.7, 0.45)
		for p in state.world_grid.purchasable_parcels():
			var c := OutpostLayout.parcel_center(p.x, p.y)
			kit.add_ground_rect(c.x, 0.04, c.z, PARCEL_W - 0.5, PARCEL_W - 0.5, col)
			_add_border_frame(kit, c.x, c.z, PARCEL_W - 0.4, PARCEL_W - 0.4, 0.18, rim)
	else:
		# Tile grid lines inside owned parcels
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

	# Road line preview highlights
	if state.tool_mode == GameCatalog.WorldToolMode.PAINT_ROAD and state.has_road_start:
		var prev := state.compute_road_line_preview()
		var ok: bool = str(prev["reason"]).is_empty() and not prev["build"].is_empty()
		var bcol := Color(0.86, 0.30, 0.22, 0.55) if state.road_erase_mode else (Color(0.30, 0.78, 0.42, 0.55) if ok else Color(0.95, 0.65, 0.24, 0.52))
		for c: Vector2i in prev["build"]:
			var wc := OutpostLayout.cell_center_v(c)
			kit.add_ground_rect(wc.x, 0.055, wc.z, CS - 0.16, CS - 0.16, bcol)
		for c: Vector2i in prev["skip"]:
			var wc := OutpostLayout.cell_center_v(c)
			kit.add_ground_rect(wc.x, 0.052, wc.z, CS - 0.24, CS - 0.24, Color(1.0, 1.0, 1.0, 0.22))
		for c: Vector2i in prev["blocked"]:
			var wc := OutpostLayout.cell_center_v(c)
			kit.add_ground_rect(wc.x, 0.06, wc.z, CS - 0.14, CS - 0.14, Color(0.92, 0.24, 0.18, 0.68))

	# Route preview ribbon when placing a building
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
		_overlays_root.add_child(dn)


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
