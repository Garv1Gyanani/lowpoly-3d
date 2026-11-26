shader_type sky;

// Natural Route 163 / Monument Valley atmospheric desert sky for Godot 4 Mobile:
// Pale misty silver-blue upper sky melting softly into warm champagne-ivory desert haze,
// whisper-subtle high cirrus veil, and clean starry desert night (zero harsh bands or cartoon discs).

uniform vec3 sky_top_color : source_color = vec3(0.76, 0.83, 0.87);
uniform vec3 sky_mid_color : source_color = vec3(0.88, 0.88, 0.86);
uniform vec3 sky_horizon_color : source_color = vec3(0.93, 0.87, 0.80);
uniform vec3 ground_color : source_color = vec3(0.80, 0.67, 0.50);
uniform vec3 sun_dir = vec3(-0.55, 0.42, -0.72);
uniform vec3 sun_scatter_color : source_color = vec3(1.00, 0.93, 0.83);
uniform float sun_scatter_strength : hint_range(0.0, 1.0) = 0.18;
uniform float cirrus_opacity : hint_range(0.0, 1.0) = 0.22;
uniform float cirrus_drift = 0.0;
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;

	// 1. Crisp Monument Valley sky: warm ivory-apricot horizon haze melting smoothly
	// into airy powder-blue and rich clear Southwest cerulean-turquoise overhead!
	float h_up = max(up + 0.032, 0.0);
	float t_mid = smoothstep(0.0, 0.065, h_up);
	float t_top = smoothstep(0.045, 0.28, h_up);
	vec3 sky_col = mix(sky_horizon_color, sky_mid_color, t_mid);
	sky_col = mix(sky_col, sky_top_color, t_top);

	// 2. Soft, diffused off-axis atmospheric sun scatter (no cartoon sun ball)
	float cos_sun = max(dot(dir, normalize(sun_dir)), 0.0);
	float scatter = pow(cos_sun, 5.0) * 0.65 + exp(-abs(h_up) * 8.0) * pow(cos_sun, 2.0) * 0.35;
	sky_col = mix(sky_col, sun_scatter_color, clamp(scatter * sun_scatter_strength, 0.0, 0.35));

	// 3. Whisper-subtle high-altitude desert cirrus veil (like the Route 163 photo)
	if (up > 0.02 && cirrus_opacity > 0.01) {
		vec2 cuv = dir.xz / (up + 0.18);
		cuv.x = cuv.x * 0.55 + cirrus_drift;
		cuv.y *= 1.85;
		float n1 = value_noise(cuv * 2.2);
		float n2 = value_noise(cuv * 4.7 + vec2(3.1, -1.7));
		float wisp = smoothstep(0.54, 0.86, n1 * 0.68 + n2 * 0.32);
		float mask = smoothstep(0.02, 0.14, up) * (1.0 - smoothstep(0.45, 0.85, up));
		sky_col = mix(sky_col, vec3(0.98, 0.96, 0.93), wisp * mask * cirrus_opacity);
	}

	// 4. Clean desert twilight/night stars
	if (night_factor > 0.02 && up > 0.02) {
		vec2 star_uv = vec2(atan(dir.x, dir.z) * 34.0, asin(clamp(up, 0.0, 1.0)) * 34.0);
		vec2 cell = floor(star_uv);
		vec2 f = fract(star_uv) - 0.5;
		float h = hash21(cell);
		if (h > 0.935) {
			float dist = length(f - (vec2(hash21(cell + 7.1), hash21(cell + 13.7)) - 0.5) * 0.58);
			float twinkle = 0.70 + 0.30 * sin(TIME * (1.8 + h * 3.5) + h * 40.0);
			float star = smoothstep(0.10, 0.018, dist) * twinkle;
			sky_col += vec3(0.95, 0.96, 1.0) * star * night_factor * smoothstep(0.02, 0.14, up);
		}
	}

	float ground_blend = smoothstep(-0.09, -0.045, up);
	COLOR = mix(ground_color, sky_col, ground_blend);
}
