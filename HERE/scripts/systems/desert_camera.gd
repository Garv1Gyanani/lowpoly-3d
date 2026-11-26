class_name DesertCamera
extends Camera3D

## Smooth free-360° orbit + tilt + zoom + pan camera for both Mobile touch & Desktop mouse/keys.

const DEFAULT_YAW := 0.14
const DEFAULT_PITCH := 0.30
const DEFAULT_DISTANCE := 34.0
const STAGE_ONE_DISTANCE := 24.0
const MIN_DISTANCE := 12.0
const MAX_DISTANCE := 110.0
const MIN_PITCH := 0.18
const MAX_PITCH := 1.30
const PITCH_PRESETS: Array[float] = [0.24, 0.52, 1.15]

var target := Vector3(0.0, 1.6, -26.0)
var yaw := DEFAULT_YAW
var pitch := DEFAULT_PITCH
var distance := STAGE_ONE_DISTANCE

var _goal_target := Vector3(0.0, 1.6, -26.0)
var _goal_yaw := DEFAULT_YAW
var _goal_pitch := DEFAULT_PITCH
var _goal_distance := STAGE_ONE_DISTANCE


func _ready() -> void:
	fov = 38.0
	near = 0.6
	far = 520.0
	_apply_transform()


func reset_immediate(new_target: Vector3, new_distance: float = DEFAULT_DISTANCE, new_pitch: float = DEFAULT_PITCH, new_yaw: float = DEFAULT_YAW) -> void:
	target = new_target
	_goal_target = new_target
	distance = clampf(new_distance, MIN_DISTANCE, MAX_DISTANCE)
	_goal_distance = distance
	pitch = clampf(new_pitch, MIN_PITCH, MAX_PITCH)
	_goal_pitch = pitch
	yaw = new_yaw
	_goal_yaw = new_yaw
	_apply_transform()


func focus_on(new_target: Vector3, new_distance: float = -1.0, new_pitch: float = -1.0, new_yaw: float = NAN) -> void:
	_goal_target = _clamp_target(new_target)
	if new_distance > 0.0:
		_goal_distance = clampf(new_distance, MIN_DISTANCE, MAX_DISTANCE)
	if new_pitch > 0.0:
		_goal_pitch = clampf(new_pitch, MIN_PITCH, MAX_PITCH)
	if not is_nan(new_yaw):
		_goal_yaw = new_yaw


func ensure_min_pitch(min_p: float) -> void:
	if _goal_pitch < min_p:
		_goal_pitch = clampf(min_p, MIN_PITCH, MAX_PITCH)


func orbit_by(delta_rad: float) -> void:
	_goal_yaw += delta_rad


func tilt_by(delta_rad: float) -> void:
	_goal_pitch = clampf(_goal_pitch + delta_rad, MIN_PITCH, MAX_PITCH)


func zoom_by_factor(scale_factor: float) -> void:
	_goal_distance = clampf(_goal_distance / maxf(0.1, scale_factor), MIN_DISTANCE, MAX_DISTANCE)


func rotate_quarter(dir: int) -> void:
	var snapped := roundf(_goal_yaw / (PI * 0.5)) * (PI * 0.5)
	_goal_yaw = snapped + float(dir) * (PI * 0.5)


func cycle_pitch_preset() -> void:
	var next_p := PITCH_PRESETS[0]
	for p in PITCH_PRESETS:
		if p > _goal_pitch + 0.08:
			next_p = p
			break
	_goal_pitch = next_p


func pan_relative(right_units: float, forward_units: float) -> void:
	var right_dir := Vector3(cos(yaw), 0.0, -sin(yaw))
	var fwd_dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
	_goal_target = _clamp_target(_goal_target + right_dir * right_units + fwd_dir * forward_units)


func pan_by_screen_delta(screen_delta: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.y < 10.0:
		return
	var scale := distance * 0.00145
	pan_relative(-screen_delta.x * scale, screen_delta.y * scale)


func update_smoothing(dt: float) -> void:
	var t := clampf(dt * 10.5, 0.0, 1.0)
	target = target.lerp(_goal_target, t)
	yaw = lerpf(yaw, _goal_yaw, t)
	pitch = lerpf(pitch, _goal_pitch, t)
	distance = lerpf(distance, _goal_distance, t)
	_apply_transform()


func _apply_transform() -> void:
	var cp := cos(pitch)
	var sp := sin(pitch)
	var offset := Vector3(
		sin(yaw) * cp * distance,
		sp * distance,
		cos(yaw) * cp * distance
	)
	global_position = target + offset
	look_at(target, Vector3.UP)


func screen_to_ground(screen_pos: Vector2, plane_y: float = 0.0) -> Vector3:
	var origin := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	if absf(dir.y) < 1e-5:
		return Vector3(target.x, plane_y, target.z)
	var t := (plane_y - origin.y) / dir.y
	if t < 0.0:
		return Vector3(target.x, plane_y, target.z)
	return origin + dir * t


func _clamp_target(p: Vector3) -> Vector3:
	return Vector3(
		clampf(p.x, OutpostLayout.WORLD_MIN_X - 8.0, OutpostLayout.WORLD_MAX_X + 8.0),
		clampf(p.y, 0.5, 5.0),
		clampf(p.z, OutpostLayout.WORLD_MIN_Z - 8.0, OutpostLayout.HIGHWAY_CENTER_Z + 12.0)
	)
