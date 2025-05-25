shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.19, 0.47, 0.88, 0.85);
uniform sampler2D normal_map : hint_normal;
uniform sampler2D screen_texture : hint_screen_texture;

uniform float wave_speed : hint_range(0.01,2.0) = 0.44;
uniform float wave_strength : hint_range(0.0,1.0) = 0.055;
uniform float refraction : hint_range(0.0,0.2) = 0.06;
uniform float shimmer : hint_range(0.0,1.0) = 0.19;
uniform float sun_orbit_speed : hint_range(0.01, 0.3) = 0.03;

const float POOL_ASPECT = 800.0/500.0;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float bulk_ripple(vec2 uv, float t) {
    uv.x *= POOL_ASPECT;
    return 0.5 + 0.5*sin(uv.x*2.5 + t*0.4) * cos(uv.y*4.0 - t*0.6);
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * wave_speed;

    // --- Bulk Ripple ---
    float bulk = bulk_ripple(uv, t);

    // --- Splotchy Random Ripple Circles ---
    float ripple_sum = 0.0;
    float ripple_count = 6.0;
    for (int i = 0; i < int(ripple_count); ++i) {
        float di = float(i);
        vec2 center = vec2(
            hash(vec2(di, 1.53)) * 1.09 + 0.01,
            hash(vec2(di, 5.21)) * 0.87 + 0.07
        );
        float period = 1.4 + hash(vec2(di, 91.7)) * 1.7;
        float phase = hash(vec2(di, 13.7)) * 6.28;
        float radius = mod(t * (0.45 + hash(vec2(di, 20.1))) + phase, period);
        float dist = length((uv - center) * 1.31);
        float ring = smoothstep(0.032 * (1.0 + wave_strength), 0.0, abs(dist - radius));
        ripple_sum += ring;
    }
    ripple_sum /= ripple_count;

    // --- Shimmer ---
    float shimmer_fx = shimmer * sin(uv.x * 38.0 + t*6.1) * cos(uv.y * 26.0 + t*4.1);

    // --- Animated Normal Map ---
    vec2 waved_uv = uv +
        (texture(normal_map, uv + vec2(t,-t)*0.14).xy - 0.5)*wave_strength +
        ripple_sum * wave_strength * 0.4 +
        shimmer_fx * 0.03 +
        0.03*bulk;

    // --- Sunspot ROUND, with faded and ripply top/bottom ---
	float sun_radius = 0.13 + shimmer*0.07;
	float margin_x = sun_radius * 1.15;
	float margin_y = sun_radius * 1.12;

	// Elliptical/orbit position
	float cycle = fract(TIME * sun_orbit_speed); // user controls speed!
	float angle = cycle * TAU;
	vec2 sun_center = vec2(0.5, 0.35);
	float rx = 0.78 - margin_x;
	float ry = 0.61 - margin_y;
	vec2 sun_pos = sun_center + vec2(cos(angle) * rx, sin(angle) * ry);

	// Spot core
	vec2 delta = uv - sun_pos;
	float dist_sun = length(delta);

	// Fade top and bottom quarters softly
	float quarter = 0.25 * sun_radius;
	float fade_top = smoothstep(sun_radius, sun_radius - quarter, delta.y);      // fade top
	float fade_bot = smoothstep(-sun_radius, -sun_radius + quarter, delta.y);   // fade bottom
	float fade = fade_top * fade_bot;

	// Ripple (gentle, soft-edge only on outer top/bottom, not edge)
	float ripple_strength = 0.055;
	float ripple_freq = 13.0;

	// Soft mask: strongest ripple at tip, gently fades near core/edge
	float edge_dist = abs(delta.y);
	float ripple_zone = smoothstep(0.10 * sun_radius, quarter, edge_dist) * (1.0 - smoothstep(quarter, sun_radius, edge_dist));

	// Ripple only where near top/bottom quarter, fading at very edge and core
	float edge_wave = sin(delta.x * ripple_freq + angle * 1.2) * ripple_strength * ripple_zone;

	// Offset sunspot vertically by this ripple
	float offset_y = delta.y + edge_wave;

	// Compute final (ripply) distance
	float ripply_dist = length(vec2(delta.x, offset_y));

	// Sunspot, with gentle edge and softened ripple
	float sun = smoothstep(sun_radius, sun_radius * 0.36, ripply_dist) * fade * 2.7;

    // --- Water Color & Highlights ---
    vec4 col = water_color;
    col.rgb += (ripple_sum * 0.13) + (shimmer_fx * 0.05) + (bulk * 0.05);
    col.a = water_color.a;

    // --- Fake Refraction ---
    vec2 refract_uv = SCREEN_UV +
        (texture(normal_map, waved_uv).xy - 0.5) * refraction +
        ripple_sum * 0.008 +
        bulk * 0.009;
    vec4 refr = texture(screen_texture, refract_uv);
    vec4 surface = mix(col, refr, 0.42 + ripple_sum * 0.22 + 0.1*bulk);

    // --- Sun Specular ("sparkle") ---
    surface.rgb += vec3(1.0, 0.98, 0.85) * sun * 0.67;

    COLOR = surface;
}