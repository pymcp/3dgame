shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 highlight_color : source_color = vec4(1.0, 0.95, 0.2, 0.85);
uniform float pulse_time : hint_range(0.0, 100000.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 4.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.15;
uniform float hex_radius : hint_range(0.0, 1.0) = 0.80;
uniform float ring_width : hint_range(0.01, 0.5) = 0.08;
uniform float edge_softness : hint_range(0.001, 0.1) = 0.025;
uniform float glow_width : hint_range(0.0, 0.3) = 0.06;

// Pointy-top hexagon signed distance field.
// IQ's SDF is flat-top; swapping p.xy → p.yx rotates it to pointy-top
// so vertices point along the V axis (world Z on PlaneMesh).
float hex_sdf(vec2 p, float r) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p = abs(p.yx);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;

	float d_outer = hex_sdf(p, hex_radius);
	float d_inner = hex_sdf(p, hex_radius - ring_width);

	// Ring mask: inside outer hex AND outside inner hex.
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
