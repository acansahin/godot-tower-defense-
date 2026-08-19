shader_type canvas_item;

// Makes the painted water move without repainting the board. The lake and waterfall need
// different motion: layered, low-amplitude diagonal currents on flat water; narrow, faster
// vertical streaks on the fall. A single large sine made the whole lake pulse like rubber.
//
// `water_mask` is generated from the painting by tools/water_mask.py — white where the
// water is, black everywhere else, blurred at the edges so the motion fades out over the
// last few pixels of shore instead of stopping along a straight line. Everything the mask
// calls black samples at exactly UV, so grass, road and buildings are bit-for-bit still.

uniform sampler2D water_mask : filter_linear, repeat_disable;
uniform float lake_strength = 0.00135; // subtle surface motion, roughly two source pixels
uniform float fall_strength = 0.0028;  // stronger motion inside the waterfall only
uniform float motion_speed = 1.0;

void fragment() {
	float m = texture(water_mask, UV).r;
	if (m > 0.004) {
		float t = TIME * motion_speed;

		// The painted waterfall occupies this small part of the board. Smooth bounds prevent
		// a rectangular transition; the water mask still decides the exact silhouette.
		float fall_x = 1.0 - smoothstep(0.025, 0.075, abs(UV.x - 0.095));
		float fall_y = smoothstep(0.49, 0.55, UV.y)
				* (1.0 - smoothstep(0.70, 0.77, UV.y));
		float waterfall = fall_x * fall_y;
		float lake = 1.0 - waterfall;

		// Two oblique waves with unrelated periods keep the lake from moving as one sheet.
		float current_a = sin(dot(UV, vec2(92.0, 47.0)) + t * 0.82);
		float current_b = sin(dot(UV, vec2(-61.0, 83.0)) - t * 0.57 + 1.7);
		float current_c = sin(dot(UV, vec2(151.0, -36.0)) + t * 1.21 + 0.4);
		vec2 lake_offset = vec2(
				current_a * 0.58 + current_b * 0.30,
				current_b * 0.48 - current_a * 0.20 + current_c * 0.16
		) * lake_strength;

		// Closely spaced bands travel down the waterfall. The second band and the gentle
		// side drift break the synchronized accordion motion of the old single sine.
		float fall_a = sin(UV.y * 235.0 - t * 8.2 + sin(UV.x * 71.0) * 0.7);
		float fall_b = sin(UV.y * 137.0 - t * 5.1 + UV.x * 43.0 + 1.2);
		float fall_side = sin(UV.y * 58.0 - t * 1.7 + UV.x * 119.0);
		vec2 fall_offset = vec2(fall_side * 0.22, fall_a * 0.72 + fall_b * 0.28)
				* fall_strength;

		// Fade displacement before the shoreline. Checking the displaced mask as well keeps
		// a water pixel from pulling grass or rock across the edge of the pool.
		float interior = smoothstep(0.06, 0.72, m);
		vec2 offset = (lake_offset * lake + fall_offset * waterfall) * interior;
		float source_water = texture(water_mask, clamp(UV + offset, vec2(0.0), vec2(1.0))).r;
		offset *= smoothstep(0.03, 0.35, source_water);

		vec4 water = texture(TEXTURE, UV + offset);
		// Small moving highlights sell direction without repainting or brightening the shore.
		float lake_glint = max(0.0, current_a * 0.55 + current_c * 0.45);
		float fall_glint = max(0.0, fall_a * 0.65 + fall_b * 0.35);
		float glint = (lake_glint * lake * 0.018 + fall_glint * waterfall * 0.055)
				* interior;
		water.rgb += vec3(0.28, 0.65, 0.78) * glint;
		COLOR = water;
	}
}
