shader_type spatial;
render_mode cull_back, depth_prepass_alpha, blend_mix;

// Shared Kenney colormap atlas for hex tiles (and overlays). All hex
// meshes UV into this same texture, so one sampler works for both
// overworld and mine MMI tiles.
uniform sampler2D colormap : source_color, filter_linear;

// Per-player state. xyz = world position, w = active flag (0/1).
uniform vec4 player_p1 = vec4(0.0);
uniform vec4 player_p2 = vec4(0.0);

// Horizontal radius of the occlusion cutout (world units).
uniform float occlusion_radius : hint_range(0.1, 5.0) = 1.4;
// Alpha at the center of the cutout (fully-occluding fragments).
uniform float occlusion_min_alpha : hint_range(0.0, 1.0) = 0.30;
// How far above the player we still apply the cutout.
uniform float occlusion_vertical_reach : hint_range(0.1, 20.0) = 6.0;
// Max distance from camera to a player for that player's cutout to
// apply. Iso cam sits ~17 units from its target; 25 keeps only the
// player this camera is following.
uniform float occlusion_camera_attach_dist : hint_range(1.0, 100.0) = 25.0;

varying vec3 v_world;
varying vec4 v_color;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_color = COLOR;
}

float cutout_for(vec3 frag, vec3 player, vec3 cam) {
	vec2 d = frag.xz - player.xz;
	float dxz = length(d);
	// Offset high enough that overlay meshes at the player's layer
	// (buildings, mine entrance, etc.) are NOT occluded. Only tiles
	// well above the player's feet trigger the cutout.
	float dy = frag.y - (player.y + 0.4);
	if (dy < 0.0 || dy > occlusion_vertical_reach) {
		return 1.0;
	}
	if (dxz > occlusion_radius) {
		return 1.0;
	}
	// Only fade tiles between the camera and the player. Project the
	// fragment onto the camera->player ray; if it's past the player,
	// it's behind them from the camera's point of view and should
	// render normally.
	vec3 cp = player - cam;
	float cp_len = length(cp);
	if (cp_len > 0.0001) {
		vec3 cp_dir = cp / cp_len;
		float frag_along = dot(frag - cam, cp_dir);
		if (frag_along >= cp_len) {
			return 1.0;
		}
	}
	float t = smoothstep(occlusion_radius * 0.45, occlusion_radius, dxz);
	return mix(occlusion_min_alpha, 1.0, t);
}

void fragment() {
	vec4 tex = texture(colormap, UV);
	ALBEDO = tex.rgb * v_color.rgb;
	// Each camera's cutout should follow only its own player. Pick the
	// player closer to CAMERA_POSITION_WORLD — the iso cam sits at
	// `target + offset(10,10,10)`, so its own target is always the
	// nearest active player. Inactive slots are pushed far away so
	// they lose the contest.
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 p1 = player_p1.xyz;
	vec3 p2 = player_p2.xyz;
	float d1 = (player_p1.w < 0.5) ? 1e9 : distance(cam, p1);
	float d2 = (player_p2.w < 0.5) ? 1e9 : distance(cam, p2);
	vec3 chosen = (d1 <= d2) ? p1 : p2;
	float active = (min(d1, d2) < 1e8) ? 1.0 : 0.0;
	// Also gate by camera attach distance so a distant cam (e.g. editor
	// preview) never cuts anything.
	if (min(d1, d2) > occlusion_camera_attach_dist) {
		active = 0.0;
	}
	float a = (active > 0.5) ? cutout_for(v_world, chosen, cam) : 1.0;
	ALPHA = tex.a * a;
}
