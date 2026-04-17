shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 highlight_color : source_color = vec4(1.0, 0.95, 0.2, 0.85);
uniform float pulse_time : hint_range(0.0, 100000.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 4.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.15;
uniform float border_width : hint_range(0.01, 0.6) = 0.18;
uniform float edge_softness : hint_range(0.001, 0.15) = 0.04;
uniform float glow_width : hint_range(0.0, 0.4) = 0.10;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.08;

// Rounded-rectangle signed distance field.
float rounded_rect_sdf(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;

	float d_outer = rounded_rect_sdf(p, vec2(1.0, 1.0), corner_radius);
	float inner_r = max(corner_radius - border_width, 0.0);
	float d_inner = rounded_rect_sdf(p, vec2(1.0 - border_width, 1.0 - border_width), inner_r);

	// Ring mask: inside outer rect AND outside inner rect.
	float outer_mask = 1.0 - smoothstep(-edge_softness, edge_softness, d_outer);
	float inner_mask = smoothstep(-edge_softness, edge_softness, d_inner);
	float ring = outer_mask * inner_mask;

	// Soft glow extending beyond ring edges.
	float glow_outer = 1.0 - smoothstep(0.0, glow_width, d_outer);
	float glow_inner = 1.0 - smoothstep(0.0, glow_width, -d_inner);
	float glow = max(glow_outer, glow_inner) * 0.35;

	float mask = max(ring, glow);

	if (mask < 0.01) {
		discard;
	}

	float pulse = sin(pulse_time * pulse_speed) * pulse_amount;
	float alpha = clamp(highlight_color.a + pulse, 0.4, 1.0);

	ALBEDO = highlight_color.rgb;
	ALPHA = mask * alpha;
}
