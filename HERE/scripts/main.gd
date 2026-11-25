extends Node3D

## Root Desert Outpost scene controller: wires GameState, WorldRenderer, DesertCamera,
## DesertHud, and full Mobile touch + Desktop mouse/keyboard input controls.

@onready var state: GameState = $GameState
@onready var camera: DesertCamera = $DesertCamera
@onready var world_renderer: WorldRenderer = $WorldRenderer
@onready var hud: DesertHud = $DesertHud

const HOLD_MOVE_SECONDS := 0.34

var _left_down := false
var _right_down := false
var _drag_moved := false
var _press_pos := Vector2.ZERO
var _touches: Dictionary = {} # finger_idx -> Vector2
var _prev_pinch_dist := 0.0
var _prev_twist_angle := 0.0
var _prev_mid := Vector2.ZERO

var _hold_pending := false
var _hold_elapsed := 0.0
var _hold_dragging := false
var _hold_pos := Vector2.ZERO
var _hold_touch_idx := -1


func _ready() -> void:
	state.attach_camera(camera)
	world_renderer.setup(state)
	hud.setup(state, camera)


func _process(delta: float) -> void:
	if not _hold_pending:
		return
	if hud.is_modal_open() or state.tool_mode != GameCatalog.WorldToolMode.PLAY:
		_cancel_hold()
		return
	_hold_elapsed += delta
	var prog := clampf((_hold_elapsed - 0.06) / (HOLD_MOVE_SECONDS - 0.06), 0.0, 1.0)
	if prog > 0.0:
		hud.set_hold_indicator(_hold_pos, prog)
	if _hold_elapsed >= HOLD_MOVE_SECONDS:
		_hold_pending = false
		hud.clear_hold_indicator()
		if state.try_start_hold_move_at(_hold_pos):
			_hold_dragging = true
			_drag_moved = true
			hud.close_tray_if_open()


func _cancel_hold() -> void:
	_hold_pending = false
	_hold_elapsed = 0.0
	hud.clear_hold_indicator()


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_modal_open():
		_cancel_hold()
		return

	# --- Mobile Multi-Touch (1-finger pan/tap/hold-move, 2-finger pinch zoom + twist orbit + vertical tilt) ---
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			_touches[te.index] = te.position
			if _touches.size() == 1:
				_press_pos = te.position
				_drag_moved = false
				if state.tool_mode == GameCatalog.WorldToolMode.PLAY and state.has_movable_object_at(te.position):
					_hold_pending = true
					_hold_elapsed = 0.0
					_hold_pos = te.position
					_hold_touch_idx = te.index
			elif _touches.size() == 2:
				_cancel_hold()
				if _hold_dragging:
					_hold_dragging = false
					state.finish_hold_move()
				_capture_two_finger_state()
		else:
			if _hold_dragging and te.index == _hold_touch_idx:
				_hold_dragging = false
				_hold_touch_idx = -1
				_touches.erase(te.index)
				_cancel_hold()
				state.finish_hold_move()
				return
			var was_single := _touches.size() == 1 and not _drag_moved
			_touches.erase(te.index)
			_cancel_hold()
			if was_single and te.position.distance_to(_press_pos) < 16.0:
				hud.close_tray_if_open()
				state.handle_world_tap(te.position)
		return

	if event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		_touches[de.index] = de.position
		if _hold_dragging and de.index == _hold_touch_idx:
			state.drag_ghost_to_screen(de.position)
			return
		if _touches.size() == 1:
			if de.position.distance_to(_press_pos) > 12.0:
				_drag_moved = true
				_cancel_hold()
			if _drag_moved:
				camera.pan_by_screen_delta(de.relative)
		elif _touches.size() >= 2:
			_drag_moved = true
			_cancel_hold()
			var keys := _touches.keys()
			var p0: Vector2 = _touches[keys[0]]
			var p1: Vector2 = _touches[keys[1]]
			var dist := p0.distance_to(p1)
			var angle := (p1 - p0).angle()
			var mid := (p0 + p1) * 0.5
			if _prev_pinch_dist > 10.0 and dist > 10.0:
				camera.zoom_by_factor(dist / _prev_pinch_dist)
			var ang_d := fposmod(angle - _prev_twist_angle + PI, TAU) - PI
			if absf(ang_d) > 0.002 and absf(ang_d) < 0.5:
				camera.orbit_by(-ang_d)
			var mid_dy := mid.y - _prev_mid.y
			if absf(dist - _prev_pinch_dist) < 8.0:
				camera.tilt_by(mid_dy * 0.005)
			_prev_pinch_dist = dist
			_prev_twist_angle = angle
			_prev_mid = mid
		return

	# --- Desktop Mouse & Trackpad ---
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_left_down = true
				_drag_moved = false
				_press_pos = mb.position
				if state.tool_mode == GameCatalog.WorldToolMode.PLAY and state.has_movable_object_at(mb.position):
					_hold_pending = true
					_hold_elapsed = 0.0
					_hold_pos = mb.position
			else:
				_cancel_hold()
				if _hold_dragging:
					_hold_dragging = false
					_left_down = false
					state.finish_hold_move()
					return
				if _left_down and not _drag_moved and mb.position.distance_to(_press_pos) < 12.0:
					hud.close_tray_if_open()
					state.handle_world_tap(mb.position)
				_left_down = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_right_down = mb.pressed
			if mb.pressed:
				_cancel_hold()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera.zoom_by_factor(1.10)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera.zoom_by_factor(0.91)
		return

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _hold_dragging and _left_down:
			state.drag_ghost_to_screen(mm.position)
			return
		if _right_down or (_left_down and Input.is_key_pressed(KEY_SHIFT)):
			_drag_moved = true
			_cancel_hold()
			camera.orbit_by(-mm.relative.x * 0.006)
			camera.tilt_by(mm.relative.y * 0.004)
		elif _left_down:
			if mm.position.distance_to(_press_pos) > 9.0:
				_drag_moved = true
				_cancel_hold()
			if _drag_moved:
				camera.pan_by_screen_delta(mm.relative)
		return

	# --- Keyboard Shortcuts ---
	if event is InputEventKey and event.pressed:
		var ke := event as InputEventKey
		var step := camera.distance * 0.06
		match ke.keycode:
			KEY_W, KEY_UP: camera.pan_relative(0.0, step)
			KEY_S, KEY_DOWN: camera.pan_relative(0.0, -step)
			KEY_A, KEY_LEFT: camera.pan_relative(-step, 0.0)
			KEY_D, KEY_RIGHT: camera.pan_relative(step, 0.0)
			KEY_Q: camera.orbit_by(-0.08)
			KEY_E: camera.orbit_by(0.08)
			KEY_T, KEY_PAGEUP: camera.tilt_by(0.05)
			KEY_G, KEY_PAGEDOWN: camera.tilt_by(-0.05)
			KEY_EQUAL, KEY_KP_ADD: camera.zoom_by_factor(1.08)
			KEY_MINUS, KEY_KP_SUBTRACT: camera.zoom_by_factor(0.92)
			KEY_R: state.rotate_ghost()
			KEY_SPACE: state.toggle_pause()
			KEY_1: state.set_map_lens(GameCatalog.MapLens.NONE)
			KEY_2: state.set_map_lens(GameCatalog.MapLens.LAND_TRAITS)
			KEY_3: state.set_map_lens(GameCatalog.MapLens.POWER)
			KEY_4: state.set_map_lens(GameCatalog.MapLens.WATER)
			KEY_5: state.set_map_lens(GameCatalog.MapLens.SUPPLY)
			KEY_ESCAPE:
				if state.tool_mode != GameCatalog.WorldToolMode.PLAY:
					state.cancel_tool_mode()
				elif not state.selected_entity_id.is_empty():
					state.clear_selected_plot()
				elif state.active_lens != GameCatalog.MapLens.NONE:
					state.set_map_lens(GameCatalog.MapLens.NONE)
			KEY_ENTER, KEY_KP_ENTER:
				if state.tool_mode == GameCatalog.WorldToolMode.PAINT_ROAD:
					state.confirm_road_line()
				elif state.tool_mode == GameCatalog.WorldToolMode.PAINT_CONDUIT:
					state.confirm_conduit_line()
				elif state.tool_mode == GameCatalog.WorldToolMode.PAINT_WATER_PIPE:
					state.confirm_water_pipe_line()
				elif state.tool_mode != GameCatalog.WorldToolMode.PLAY:
					state.confirm_placement()


func _capture_two_finger_state() -> void:
	var keys := _touches.keys()
	if keys.size() < 2:
		return
	var p0: Vector2 = _touches[keys[0]]
	var p1: Vector2 = _touches[keys[1]]
	_prev_pinch_dist = p0.distance_to(p1)
	_prev_twist_angle = (p1 - p0).angle()
	_prev_mid = (p0 + p1) * 0.5
