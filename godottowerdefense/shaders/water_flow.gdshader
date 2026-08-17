shader_type canvas_item;

// Makes the painted water move without repainting the board.
//
// The board is a single image, so the lake and the waterfall are pixels, not objects. This
// walks a wave DOWN the board and displaces where the texture is sampled, so the painted
// streaks of the fall stretch and compress in sequence — which the eye reads as water
// running — while the lake gets the same motion at a fraction of the strength and reads as
// a surface breathing.
//
// It DISPLACES rather than scrolls on purpose. Scrolling the water region would drag the
// rocks above the fall down into it and need a seam to hide; a standing displacement can
// never pull in anything that is not already inside the mask, so the shore stays put no
// matter how long the game runs.
//
// `water_mask` is generated from the painting by tools/water_mask.py — white where the
// water is, black everywhere else, blurred at the edges so the motion fades out over the
// last few pixels of shore instead of stopping along a straight line. Everything the mask
// calls black samples at exactly UV, so grass, road and buildings are bit-for-bit still.

uniform sampler2D water_mask : filter_linear, repeat_disable;
uniform float ripple = 0.009;      // displacement in UV, at full mask strength (~8px)
uniform float wave_length = 180.0; // radians of wave per UV unit down the board
uniform float flow_speed = 6.0;    // radians per second; positive travels downward

void fragment() {
	float m = texture(water_mask, UV).r;
	vec2 uv = UV;
	if (m > 0.004) {
		float phase = UV.y * wave_length - TIME * flow_speed;
		float amp = ripple * m;
		uv.y += sin(phase) * amp;
		// A slower, sideways wobble across the fall, so the flow is not a single column of
		// pistons. Half the strength: water slides down more than it wanders.
		uv.x += sin(phase * 0.55 + UV.x * 40.0) * amp * 0.5;
	}
	COLOR *= texture(TEXTURE, uv);
}
