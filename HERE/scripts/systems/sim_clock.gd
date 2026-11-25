class_name SimClock
extends RefCounted

## Deterministic simulation clock for Desert Outpost:
## Tracks day counter, time_of_day (0..1), DayPhase, sim speed (0x / 1x / 2x),
## fixed-rate 1 Hz economy ticks, and solar irradiance aligned with WorldRenderer.

enum DayPhase { DAWN, DAY, DUSK, NIGHT }

const DAY_CYCLE_RATE := 0.0085
const FIXED_TICK_SECONDS := 1.0

var day_number: int = 1
var time_of_day: float = 0.37
var auto_day_night: bool = true
var sim_speed: float = 1.0
var _last_nonzero_speed: float = 1.0
var _tick_accum: float = 0.0


func reset(day: int = 1, tod: float = 0.37, auto_cycle: bool = true, speed: float = 1.0) -> void:
	day_number = maxi(1, day)
	time_of_day = fposmod(tod, 1.0)
	auto_day_night = auto_cycle
	sim_speed = clampf(speed, 0.0, 4.0)
	if sim_speed > 0.0:
		_last_nonzero_speed = sim_speed
	_tick_accum = 0.0


func is_paused() -> bool:
	return sim_speed <= 0.001


func set_speed(speed: float) -> void:
	sim_speed = clampf(speed, 0.0, 4.0)
	if sim_speed > 0.001:
		_last_nonzero_speed = sim_speed


func toggle_pause() -> void:
	if is_paused():
		sim_speed = _last_nonzero_speed if _last_nonzero_speed > 0.001 else 1.0
	else:
		_last_nonzero_speed = sim_speed
		sim_speed = 0.0


func cycle_speed() -> float:
	if is_paused():
		set_speed(1.0)
	elif sim_speed < 1.5:
		set_speed(2.0)
	else:
		set_speed(0.0)
	return sim_speed


func set_time_preset(tod: float, pause_cycle: bool = true) -> void:
	time_of_day = fposmod(tod, 1.0)
	auto_day_night = not pause_cycle


func advance(real_dt: float) -> Dictionary:
	var dt := clampf(real_dt, 0.0, 0.1)
	var sim_dt := dt * sim_speed
	var day_rolled := false
	var prev_phase := day_phase()

	if auto_day_night and sim_dt > 0.0:
		time_of_day += sim_dt * DAY_CYCLE_RATE
		while time_of_day >= 1.0:
			time_of_day -= 1.0
			day_number += 1
			day_rolled = true

	var ticks := 0
	if sim_dt > 0.0:
		_tick_accum += sim_dt
		while _tick_accum >= FIXED_TICK_SECONDS:
			_tick_accum -= FIXED_TICK_SECONDS
			ticks += 1

	var cur_phase := day_phase()
	return {
		"sim_dt": sim_dt,
		"ticks": ticks,
		"day_rolled": day_rolled,
		"phase_changed": cur_phase != prev_phase,
		"phase": cur_phase,
	}


## Matches WorldRenderer._update_lighting sun elevation curve exactly.
func sun_elevation() -> float:
	return sin((time_of_day - 0.25) * TAU)


## Smooth 0.0 (night) -> 1.0 (solar noon) irradiance factor for rooftop & farm solar.
func solar_factor() -> float:
	return clampf(sun_elevation(), 0.0, 1.0)


func is_night() -> bool:
	return sun_elevation() < -0.05


func day_phase() -> int:
	var elev := sun_elevation()
	if elev < -0.08:
		return DayPhase.NIGHT
	if elev < 0.22:
		return DayPhase.DAWN if time_of_day < 0.5 else DayPhase.DUSK
	return DayPhase.DAY


func phase_name() -> String:
	match day_phase():
		DayPhase.DAWN:
			return "DAWN"
		DayPhase.DAY:
			return "DAY"
		DayPhase.DUSK:
			return "DUSK"
		_:
			return "NIGHT"


func time_label() -> String:
	var total_mins := int(floor(fposmod(time_of_day, 1.0) * 1440.0))
	var hh := int(total_mins / 60) % 24
	var mm := total_mins % 60
	return "%02d:%02d" % [hh, mm]


func hud_label() -> String:
	var icon := "☀"
	match day_phase():
		DayPhase.DAWN:
			icon = "◐"
		DayPhase.DUSK:
			icon = "◑"
		DayPhase.NIGHT:
			icon = "☾"
	return "D%d %s %s" % [day_number, icon, phase_name()]


func speed_label() -> String:
	if is_paused():
		return "❚❚"
	if sim_speed >= 1.5:
		return "2×"
	return "1×"


func to_dict() -> Dictionary:
	return {
		"day": day_number,
		"time_of_day": time_of_day,
		"auto_day_night": auto_day_night,
		"sim_speed": sim_speed,
	}


func from_dict(d: Dictionary) -> void:
	reset(
		int(d.get("day", 1)),
		float(d.get("time_of_day", 0.37)),
		bool(d.get("auto_day_night", true)),
		float(d.get("sim_speed", 1.0))
	)
