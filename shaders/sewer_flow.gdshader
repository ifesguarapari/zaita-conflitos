shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 sewer_color : source_color = vec4(0.01, 0.009, 0.006, 0.44);
uniform float speed = 0.018;
uniform float frequency = 5.5;
uniform float highlight_strength = 0.13;

varying vec2 flow_uv;

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash2(vec2 value) {
	return vec2(
		hash(value + vec2(19.19, 47.77)),
		hash(value + vec2(83.13, 11.57))
	);
}

float piece_layer(vec2 uv, float scale, float seed, float density) {
	vec2 moving_uv = uv * scale + vec2(TIME * speed * 4.5, -TIME * speed * 8.0);
	vec2 cell = floor(moving_uv);
	vec2 local = fract(moving_uv);
	float value = 0.0;

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 id = cell + neighbor;
			float chance = hash(id + vec2(seed, seed * 1.37));
			float enabled = step(1.0 - density, chance);
			vec2 center = hash2(id + vec2(seed * 2.1, seed * 0.7)) + neighbor;
			vec2 delta = local - center;
			float radius = mix(0.12, 0.34, hash(id + vec2(seed * 3.3, 9.2)));
			float irregular_edge = sin(delta.x * 17.0 + delta.y * 11.0 + seed) * 0.035;
			float piece = 1.0 - smoothstep(radius + irregular_edge, radius + irregular_edge + 0.08, length(delta));
			value = max(value, piece * enabled);
		}
	}

	return value;
}

void vertex() {
	flow_uv = VERTEX * 0.012;
}

void fragment() {
	float small_pieces = piece_layer(flow_uv, 4.4, 2.0, 0.34);
	float tiny_pieces = piece_layer(flow_uv + vec2(0.27, 0.11), 7.2, 8.0, 0.24) * 0.62;
	float organic_pieces = max(small_pieces, tiny_pieces);
	float slow_water = sin(flow_uv.y * frequency + flow_uv.x * 0.95 - TIME * speed * 6.0) * 0.5 + 0.5;
	float soft_visibility = 0.72 + slow_water * 0.28;
	float sheen = smoothstep(0.88, 1.0, slow_water) * highlight_strength * 0.08;
	float alpha = sewer_color.a * (0.03 + organic_pieces * soft_visibility * 0.78 + sheen);
	vec3 color = mix(sewer_color.rgb, vec3(0.0, 0.0, 0.0), organic_pieces * 0.28);
	COLOR = vec4(color, alpha);
}
