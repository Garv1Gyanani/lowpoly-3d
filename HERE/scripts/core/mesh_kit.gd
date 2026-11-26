class_name MeshKit
extends RefCounted

## High-throughput procedural low-poly mesh builder for Godot 4 Mobile.
## Packs hundreds of flat-shaded boxes, frustums, awnings, wires & details into
## 1-3 GPU ArrayMesh surfaces (opaque, night-emissive, always-emissive) with
## real hardware Z-buffer depth, real directional shadows, and crisp 3D Label3D signs.

var _st_opaque: SurfaceTool
var _st_night: SurfaceTool
var _st_always: SurfaceTool
var _has_opaque := false
var _has_night := false
var _has_always := false

var _origin := Vector3.ZERO
var _rot_y := 0.0
var _basis := Basis.IDENTITY
var _stack: Array = []
var signs: Array[Dictionary] = []


func _init() -> void:
	_st_opaque = SurfaceTool.new()
	_st_opaque.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st_night = SurfaceTool.new()
	_st_night.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st_always = SurfaceTool.new()
	_st_always.begin(Mesh.PRIMITIVE_TRIANGLES)


func push_tx(local_origin: Vector3, rot_y: float = 0.0) -> void:
	_stack.append([_origin, _rot_y, _basis])
	_origin = _origin + (_basis * local_origin)
	_rot_y += rot_y
	if absf(rot_y) >= 1e-6:
		_basis = _basis * Basis(Vector3.UP, -rot_y)


## Pushes a full 3D Transform (yaw, pitch, roll) for tilted tectonic rock slabs & overhangs.
func push_tx_basis(local_origin: Vector3, local_basis: Basis) -> void:
	_stack.append([_origin, _rot_y, _basis])
	_origin = _origin + (_basis * local_origin)
	_basis = _basis * local_basis


func pop_tx() -> void:
	var prev = _stack.pop_back()
	_origin = prev[0]
	_rot_y = prev[1]
	_basis = prev[2]


static func _rot_vec(v: Vector3, rad: float) -> Vector3:
	if absf(rad) < 1e-6:
		return v
	var c := cos(rad)
	var s := sin(rad)
	return Vector3(v.x * c - v.z * s, v.y, v.x * s + v.z * c)


func _tx(v: Vector3) -> Vector3:
	return _origin + (_basis * v)


func _pick_st(emissive_mode: int) -> SurfaceTool:
	if emissive_mode == 1:
		_has_night = true
		return _st_night
	elif emissive_mode == 2:
		_has_always = true
		return _st_always
	_has_opaque = true
	return _st_opaque


## Emits a flat-shaded triangle whose outward normal follows CCW (b-a)x(c-a).
## Godot 4 uses CW front-face winding, so vertices are submitted as (a, c, b).
func add_tri(a: Vector3, b: Vector3, c: Vector3, col: Color, double_sided: bool = false, emissive_mode: int = 0) -> void:
	var wa := _tx(a)
	var wb := _tx(b)
	var wc := _tx(c)
	var n := (wb - wa).cross(wc - wa)
	var nlen := n.length()
	if nlen < 1e-7:
		return
	n /= nlen
	var st := _pick_st(emissive_mode)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(wa)
	st.set_normal(n)
	st.add_vertex(wc)
	st.set_normal(n)
	st.add_vertex(wb)
	if double_sided:
		var nb := -n
		st.set_color(col)
		st.set_normal(nb)
		st.add_vertex(wa)
		st.set_normal(nb)
		st.add_vertex(wb)
		st.set_normal(nb)
		st.add_vertex(wc)


func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, double_sided: bool = false, emissive_mode: int = 0) -> void:
	add_tri(a, b, c, col, double_sided, emissive_mode)
	add_tri(a, c, d, col, double_sided, emissive_mode)


func add_ground_poly(verts: Array[Vector3], col: Color, emissive_mode: int = 0) -> void:
	if verts.size() < 3:
		return
	for i in range(1, verts.size() - 1):
		add_tri(verts[0], verts[i], verts[i + 1], col, false, emissive_mode)


func add_ground_rect(cx: float, y: float, cz: float, w: float, d: float, col: Color, emissive_mode: int = 0) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	add_quad(
		Vector3(cx - hw, y, cz - hd),
		Vector3(cx - hw, y, cz + hd),
		Vector3(cx + hw, y, cz + hd),
		Vector3(cx + hw, y, cz - hd),
		col,
		false,
		emissive_mode
	)


func add_box(
	cx: float,
	y_bottom: float,
	cz: float,
	w: float,
	h: float,
	d: float,
	col: Color,
	top_col: Color = Color(-1, 0, 0),
	emissive_mode: int = 0,
	skip_bottom: bool = true,
	skip_top: bool = false
) -> void:
	var x0 := cx - w * 0.5
	var x1 := cx + w * 0.5
	var y0 := y_bottom
	var y1 := y_bottom + h
	var z0 := cz - d * 0.5
	var z1 := cz + d * 0.5

	var p000 := Vector3(x0, y0, z0)
	var p100 := Vector3(x1, y0, z0)
	var p101 := Vector3(x1, y0, z1)
	var p001 := Vector3(x0, y0, z1)
	var p010 := Vector3(x0, y1, z0)
	var p110 := Vector3(x1, y1, z0)
	var p111 := Vector3(x1, y1, z1)
	var p011 := Vector3(x0, y1, z1)

	var tc := col if top_col.r < 0.0 else top_col
	if not skip_top:
		add_quad(p010, p011, p111, p110, tc, false, emissive_mode)
	add_quad(p001, p101, p111, p011, col, false, emissive_mode)
	add_quad(p100, p000, p010, p110, col, false, emissive_mode)
	add_quad(p101, p100, p110, p111, col, false, emissive_mode)
	add_quad(p000, p001, p011, p010, col, false, emissive_mode)
	if not skip_bottom:
		add_quad(p001, p000, p100, p101, col, false, emissive_mode)


func add_tapered_box(
	cx: float,
	y_bottom: float,
	cz: float,
	bottom_len: float,
	bottom_wid: float,
	top_len: float,
	top_wid: float,
	height: float,
	col: Color,
	top_col: Color = Color(-1, 0, 0),
	top_shift_x: float = 0.0,
	top_shift_z: float = 0.0
) -> void:
	var bx0 := cx - bottom_len * 0.5
	var bx1 := cx + bottom_len * 0.5
	var bz0 := cz - bottom_wid * 0.5
	var bz1 := cz + bottom_wid * 0.5
	var tx0 := cx + top_shift_x - top_len * 0.5
	var tx1 := cx + top_shift_x + top_len * 0.5
	var tz0 := cz + top_shift_z - top_wid * 0.5
	var tz1 := cz + top_shift_z + top_wid * 0.5
	var y0 := y_bottom
	var y1 := y_bottom + height

	var b00 := Vector3(bx0, y0, bz0)
	var b10 := Vector3(bx1, y0, bz0)
	var b11 := Vector3(bx1, y0, bz1)
	var b01 := Vector3(bx0, y0, bz1)
	var t00 := Vector3(tx0, y1, tz0)
	var t10 := Vector3(tx1, y1, tz0)
	var t11 := Vector3(tx1, y1, tz1)
	var t01 := Vector3(tx0, y1, tz1)

	var tc := col if top_col.r < 0.0 else top_col
	add_quad(t00, t01, t11, t10, tc)
	add_quad(b11, b10, t10, t11, col)
	add_quad(b00, b01, t01, t00, col)
	add_quad(b01, b11, t11, t01, col)
	add_quad(b10, b00, t00, t10, col)


func add_cabin_windows(
	cx: float,
	y_bottom: float,
	cz: float,
	bottom_len: float,
	bottom_wid: float,
	top_len: float,
	top_wid: float,
	height: float,
	glass_col: Color,
	sheen_col: Color,
	top_shift_x: float = 0.0,
	inset_bottom: float = 0.14,
	inset_top: float = 0.14,
	side_inset: float = 0.14
) -> void:
	var bx0 := cx - bottom_len * 0.5
	var bx1 := cx + bottom_len * 0.5
	var bz0 := cz - bottom_wid * 0.5
	var bz1 := cz + bottom_wid * 0.5
	var tx0 := cx + top_shift_x - top_len * 0.5
	var tx1 := cx + top_shift_x + top_len * 0.5
	var tz0 := cz - top_wid * 0.5
	var tz1 := cz + top_wid * 0.5
	var y0 := y_bottom
	var y1 := y_bottom + height

	var b00 := Vector3(bx0, y0, bz0)
	var b10 := Vector3(bx1, y0, bz0)
	var b11 := Vector3(bx1, y0, bz1)
	var b01 := Vector3(bx0, y0, bz1)
	var t00 := Vector3(tx0, y1, tz0)
	var t10 := Vector3(tx1, y1, tz0)
	var t11 := Vector3(tx1, y1, tz1)
	var t01 := Vector3(tx0, y1, tz1)

	var faces := [
		[b11, b10, t10, t11],
		[b00, b01, t01, t00],
		[b01, b11, t11, t01],
		[b10, b00, t00, t10],
	]
	for f in faces:
		var p0: Vector3 = f[0]
		var p1: Vector3 = f[1]
		var p2: Vector3 = f[2]
		var p3: Vector3 = f[3]
		var n := (p1 - p0).cross(p2 - p0).normalized()
		var lift := n * 0.016
		var q0 := p0.lerp(p1, side_inset).lerp(p3.lerp(p2, side_inset), inset_bottom) + lift
		var q1 := p0.lerp(p1, 1.0 - side_inset).lerp(p3.lerp(p2, 1.0 - side_inset), inset_bottom) + lift
		var q2 := p0.lerp(p1, 1.0 - side_inset).lerp(p3.lerp(p2, 1.0 - side_inset), 1.0 - inset_top) + lift
		var q3 := p0.lerp(p1, side_inset).lerp(p3.lerp(p2, side_inset), 1.0 - inset_top) + lift
		add_quad(q0, q1, q2, q3, glass_col)
		var s0 := q0.lerp(q1, 0.16) + n * 0.008
		var s1 := q0.lerp(q1, 0.34) + n * 0.008
		var s2 := q3.lerp(q2, 0.56) + n * 0.008
		var s3 := q3.lerp(q2, 0.38) + n * 0.008
		add_quad(s0, s1, s2, s3, sheen_col)


func add_flush_rect_x(x_wall: float, cy: float, cz: float, width_z: float, height_y: float, col: Color, positive_x: bool, emissive_mode: int = 0) -> void:
	var hz := width_z * 0.5
	var hy := height_y * 0.5
	var x := x_wall + (0.022 if positive_x else -0.022)
	if positive_x:
		add_quad(Vector3(x, cy - hy, cz + hz), Vector3(x, cy - hy, cz - hz), Vector3(x, cy + hy, cz - hz), Vector3(x, cy + hy, cz + hz), col, false, emissive_mode)
	else:
		add_quad(Vector3(x, cy - hy, cz - hz), Vector3(x, cy - hy, cz + hz), Vector3(x, cy + hy, cz + hz), Vector3(x, cy + hy, cz - hz), col, false, emissive_mode)


func add_flush_rect_z(cx: float, cy: float, z_wall: float, width_x: float, height_y: float, col: Color, positive_z: bool, emissive_mode: int = 0) -> void:
	var hx := width_x * 0.5
	var hy := height_y * 0.5
	var z := z_wall + (0.022 if positive_z else -0.022)
	if positive_z:
		add_quad(Vector3(cx - hx, cy - hy, z), Vector3(cx + hx, cy - hy, z), Vector3(cx + hx, cy + hy, z), Vector3(cx - hx, cy + hy, z), col, false, emissive_mode)
	else:
		add_quad(Vector3(cx + hx, cy - hy, z), Vector3(cx - hx, cy - hy, z), Vector3(cx - hx, cy + hy, z), Vector3(cx + hx, cy + hy, z), col, false, emissive_mode)


func add_frustum(
	cx: float,
	y_bottom: float,
	cz: float,
	brx: float,
	brz: float,
	trx: float,
	trz: float,
	height: float,
	sides: int,
	side_col: Color,
	top_col: Color = Color(-1, 0, 0),
	phase_offset: float = 0.0,
	roughness: float = 0.0,
	seed_val: int = 1,
	emissive_mode: int = 0
) -> void:
	var bot: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in range(sides):
		var a := phase_offset + (float(i) / float(sides)) * TAU
		var jitter := 1.0 if roughness == 0.0 else (1.0 + sin(i * 3.17 + seed_val * 1.93) * roughness)
		var ca := cos(a) * jitter
		var sa := sin(a) * jitter
		bot.append(Vector3(cx + ca * brx, y_bottom, cz + sa * brz))
		top.append(Vector3(cx + ca * trx, y_bottom + height, cz + sa * trz))

	for i in range(sides):
		var nxt := (i + 1) % sides
		add_quad(bot[nxt], bot[i], top[i], top[nxt], side_col, false, emissive_mode)

	if trx > 0.01 and trz > 0.01:
		var tc := side_col if top_col.r < 0.0 else top_col
		# Reverse fan so top face normal points +Y (CCW viewed from above)
		for i in range(1, sides - 1):
			add_tri(top[0], top[sides - i], top[sides - i - 1], tc, false, emissive_mode)


func add_gable_roof(cx: float, y_base: float, cz: float, w: float, h: float, d: float, roof_col: Color, gable_col: Color) -> void:
	var x0 := cx - w * 0.5
	var x1 := cx + w * 0.5
	var z0 := cz - d * 0.5
	var z1 := cz + d * 0.5
	var y_top := y_base + h
	var fl := Vector3(x0, y_base, z1)
	var fr := Vector3(x1, y_base, z1)
	var bl := Vector3(x0, y_base, z0)
	var br := Vector3(x1, y_base, z0)
	var rl := Vector3(x0, y_top, cz)
	var rr := Vector3(x1, y_top, cz)
	add_quad(fl, fr, rr, rl, roof_col)
	add_quad(br, bl, rl, rr, roof_col)
	add_tri(fr, br, rr, gable_col)
	add_tri(bl, fl, rl, gable_col)


func add_sloped_awning(cx: float, y_back: float, y_front: float, cz: float, w: float, d: float, col: Color, stripe_col: Color = Color(-1, 0, 0), stripes: int = 1) -> void:
	var x0 := cx - w * 0.5
	var z_back := cz - d * 0.5
	var z_front := cz + d * 0.5
	var sw := w / float(stripes)
	for i in range(stripes):
		var sx0 := x0 + sw * i
		var sx1 := sx0 + sw
		var c := stripe_col if (stripe_col.r >= 0.0 and i % 2 == 1) else col
		add_quad(
			Vector3(sx0, y_back, z_back),
			Vector3(sx0, y_front, z_front),
			Vector3(sx1, y_front, z_front),
			Vector3(sx1, y_back, z_back),
			c,
			true
		)
		add_quad(
			Vector3(sx0, y_front - 0.14, z_front),
			Vector3(sx1, y_front - 0.14, z_front),
			Vector3(sx1, y_front, z_front),
			Vector3(sx0, y_front, z_front),
			c,
			true
		)


func add_front_window(cx: float, cy: float, z_wall: float, w: float, h: float, day_col: Color = DesertPalette.WINDOW_DAY) -> void:
	add_flush_rect_z(cx, cy, z_wall + 0.015, w, h, day_col, true, 1)


func add_right_window(x_wall: float, cy: float, cz: float, d: float, h: float, day_col: Color = DesertPalette.WINDOW_DAY) -> void:
	add_flush_rect_x(x_wall + 0.015, cy, cz, d, h, day_col, true, 1)


func add_left_window(x_wall: float, cy: float, cz: float, d: float, h: float, day_col: Color = DesertPalette.WINDOW_DAY) -> void:
	add_flush_rect_x(x_wall - 0.015, cy, cz, d, h, day_col, false, 1)


func add_sagging_wire(start: Vector3, end: Vector3, col: Color, sag: float = 0.28, thickness: float = 0.036, segments: int = 5, bulb_count: int = 0) -> void:
	for s in range(segments):
		var t0 := float(s) / float(segments)
		var t1 := float(s + 1) / float(segments)
		var p0 := start.lerp(end, t0) - Vector3(0, sin(t0 * PI) * sag, 0)
		var p1 := start.lerp(end, t1) - Vector3(0, sin(t1 * PI) * sag, 0)
		add_quad(p0, p1, p1 - Vector3(0, thickness, 0), p0 - Vector3(0, thickness, 0), col, true)
	if bulb_count > 0:
		for b in range(1, bulb_count + 1):
			var tb := float(b) / float(bulb_count + 1)
			var bp := start.lerp(end, tb) - Vector3(0, sin(tb * PI) * sag + 0.07, 0)
			add_box(bp.x, bp.y, bp.z, 0.09, 0.10, 0.09, DesertPalette.CREAM, Color(-1, 0, 0), 1)


func add_front_sign_text(cx: float, cy: float, z_face: float, width: float, height: float, text: String, col: Color, night_glow: bool = true) -> void:
	signs.append({
		"pos": _tx(Vector3(cx, cy, z_face + 0.048)),
		"rot_y": -_rot_y,
		"width": width,
		"height": height,
		"text": text,
		"color": col,
		"night_glow": night_glow,
	})


## Shared architectural helpers (clean, non-overlapping geometry)

func add_framed_door(cx: float, y_bottom: float, z_wall: float, width: float, height: float, frame_col: Color = DesertPalette.WOOD_DARK, door_col: Color = DesertPalette.WOOD, has_glass: bool = true) -> void:
	add_box(cx, y_bottom, z_wall + 0.03, width + 0.14, height + 0.08, 0.06, frame_col)
	add_box(cx, y_bottom, z_wall + 0.075, width, height, 0.03, door_col)
	if has_glass:
		add_front_window(cx, y_bottom + height * 0.62, z_wall + 0.085, width * 0.68, height * 0.44)


func add_framed_front_window(cx: float, cy: float, z_wall: float, width: float, height: float, frame_col: Color = DesertPalette.WOOD, sill_col: Color = DesertPalette.CREAM_DARK) -> void:
	var frame_bottom := cy - height * 0.5 - 0.05
	add_box(cx, frame_bottom, z_wall + 0.025, width + 0.14, height + 0.12, 0.05, frame_col)
	add_box(cx, frame_bottom - 0.08, z_wall + 0.07, width + 0.24, 0.08, 0.14, sill_col)
	add_front_window(cx, cy, z_wall + 0.045, width, height)
	# Non-coplanar cross mullions (vertical +0.008 behind horizontal) to prevent GPU cross Z-fighting
	add_flush_rect_z(cx, cy, z_wall + 0.082, 0.05, height, frame_col, true)
	add_flush_rect_z(cx, cy, z_wall + 0.090, width, 0.05, frame_col, true)


func add_adobe_parapet_roof(cx: float, y_base: float, cz: float, width: float, depth: float, parapet_h: float = 0.30, parapet_col: Color = DesertPalette.TERRACOTTA, deck_col: Color = DesertPalette.SAND_DARK, add_vigas: bool = true) -> void:
	var outer_w := width + 0.22
	var outer_d := depth + 0.22
	var rim := minf(0.24, minf(outer_w, outer_d) * 0.18)
	var inner_w := maxf(0.2, outer_w - rim * 2.0)
	var inner_d := maxf(0.2, outer_d - rim * 2.0)
	add_box(cx, y_base, cz, inner_w, 0.06, inner_d, deck_col)
	add_box(cx, y_base, cz - outer_d * 0.5 + rim * 0.5, outer_w, parapet_h, rim, parapet_col)
	add_box(cx, y_base, cz + outer_d * 0.5 - rim * 0.5, outer_w, parapet_h, rim, parapet_col)
	add_box(cx - outer_w * 0.5 + rim * 0.5, y_base, cz, rim, parapet_h, inner_d, parapet_col)
	add_box(cx + outer_w * 0.5 - rim * 0.5, y_base, cz, rim, parapet_h, inner_d, parapet_col)
	if add_vigas:
		var count := maxi(3, int(floor(width / 1.15)))
		for i in range(count):
			var t := 0.5 if count == 1 else float(i) / float(count - 1)
			var bx := cx - width * 0.40 + t * (width * 0.80)
			add_box(bx, y_base - 0.12, cz + depth * 0.5 + 0.12, 0.11, 0.11, 0.22, DesertPalette.WOOD_DARK)


func add_marquee_sign(cx: float, y_bottom: float, cz: float, width: float, height: float, text: String, frame_col: Color, face_col: Color = DesertPalette.CREAM, text_col: Color = DesertPalette.UI_INK, depth: float = 0.22) -> void:
	var front_z := cz + depth * 0.5
	add_box(cx, y_bottom, cz, width, height, depth, frame_col)
	add_flush_rect_z(cx, y_bottom + height * 0.5, front_z, width - 0.22, height - 0.18, face_col, true, 1)
	add_front_sign_text(cx, y_bottom + height * 0.5, front_z + 0.02, width - 0.34, height - 0.26, text, text_col, true)


func add_patio_umbrella_table(cx: float, y_bottom: float, cz: float, umbrella_col: Color, top_col: Color = DesertPalette.CREAM, s: float = 1.0) -> void:
	add_box(cx, y_bottom, cz, 0.22 * s, 0.48 * s, 0.22 * s, DesertPalette.WOOD_DARK, Color(-1, 0, 0), 0, true, true)
	add_box(cx, y_bottom + 0.48 * s, cz, 0.80 * s, 0.09 * s, 0.80 * s, DesertPalette.WOOD_LIGHT)
	for dx in [-0.54 * s, 0.54 * s]:
		add_box(cx + dx, y_bottom, cz, 0.24 * s, 0.34 * s, 0.24 * s, DesertPalette.WOOD)
	add_box(cx, y_bottom + 0.57 * s, cz, 0.08 * s, 0.97 * s, 0.08 * s, DesertPalette.WOOD_DARK)
	add_frustum(cx, y_bottom + 1.54 * s, cz, 0.86 * s, 0.86 * s, 0.07 * s, 0.07 * s, 0.32 * s, 6, umbrella_col, top_col)
	add_box(cx, y_bottom + 1.86 * s, cz, 0.11 * s, 0.12 * s, 0.11 * s, DesertPalette.CREAM)


func add_potted_cactus(cx: float, y_bottom: float, cz: float) -> void:
	add_frustum(cx, y_bottom, cz, 0.18, 0.18, 0.24, 0.24, 0.30, 6, DesertPalette.TERRACOTTA)
	add_frustum(cx, y_bottom + 0.30, cz, 0.12, 0.12, 0.10, 0.10, 0.50, 6, DesertPalette.CACTUS)


## Finalizes all accumulated geometry into a single GPU-batched Node3D with crisp Label3D signs.
func build_node(node_name: String = "MeshPart", cast_shadow: bool = true, material_override: Material = null) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var mesh := ArrayMesh.new()
	var surf_idx := 0

	if _has_opaque:
		_st_opaque.commit(mesh)
		mesh.surface_set_material(surf_idx, material_override if material_override != null else DesertPalette.get_opaque_material())
		surf_idx += 1
	if _has_night:
		_st_night.commit(mesh)
		mesh.surface_set_material(surf_idx, material_override if material_override != null else DesertPalette.get_night_emissive_material())
		surf_idx += 1
	if _has_always:
		_st_always.commit(mesh)
		mesh.surface_set_material(surf_idx, material_override if material_override != null else DesertPalette.get_always_emissive_material())
		surf_idx += 1

	if surf_idx > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)

	if material_override == null:
		var font := DesertPalette.get_display_font()
		for s in signs:
			var lbl := Label3D.new()
			lbl.text = s["text"]
			lbl.position = s["pos"]
			lbl.rotation.y = s["rot_y"]
			lbl.modulate = s["color"]
			lbl.outline_size = 0
			lbl.shaded = false
			lbl.double_sided = false
			lbl.no_depth_test = false
			lbl.font_size = 48
			if font != null:
				lbl.font = font
			var lines := str(s["text"]).split("\n")
			var max_chars := 1
			for ln in lines:
				max_chars = maxi(max_chars, ln.length())
			var px_w := float(s["width"]) / (float(max_chars) * 34.0)
			var px_h := float(s["height"]) / (float(lines.size()) * 54.0)
			lbl.pixel_size = clampf(minf(px_w, px_h), 0.002, 0.015)
			root.add_child(lbl)

	return root
