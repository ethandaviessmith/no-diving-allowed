shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.19, 0.47, 0.88, 0.85);
uniform sampler2D normal_map : hint_normal;
uniform sampler2D screen_texture : hint_screen_texture; // for refraction

uniform float wave_speed : hint_range(0.01,2.0) = 0.45;
uniform float wave_strength : hint_range(0.0,1.0) = 0.07;
uniform float refraction : hint_range(0.0,0.2) = 0.06;
uniform float shimmer : hint_range(0.0,1.0) = 0.15;

// Splotchy random ripples (random seed based on position)
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * wave_speed;

    // ========= Randomized Ripple Circles =========
    float ripple_sum = 0.0;
    float ripple_count = 6.0; // How many independent ripples per tile
    for (int i = 0; i < int(ripple_count); i++) {
        float di = float(i);
        // Offset for each pseudo-random ripple center
        vec2 center = vec2(
            hash(vec2(di, 1.51)) * 1.2 - 0.1,
            hash(vec2(di, 5.19)) * 1.2 - 0.1
        );
        float period = 1.2 + hash(vec2(di, 91.2)) * 1.7;
        float phase = hash(vec2(di, 13.5)) * 6.28;
        float radius = mod(t * (0.6 + hash(vec2(di, 19.3))) + phase, period);
        float dist = length((uv - center) * 1.2);

        // Ripple band: tight ring using smoothstep falloff
        float ring = smoothstep(0.03 * (1.0 + wave_strength), 0.0, abs(dist - radius));
        ripple_sum += ring;
    }
    ripple_sum /= ripple_count;

    // Additional “shimmer” via high-frequency sine noise
    float shimmer_fx = shimmer * sin(uv.x * 34.0 + t * 5.0) * cos(uv.y * 38.0 + t * 3.5);

    // Animated normal map distortion (seamless looping if desired)
    vec2 waved_uv = uv +
        (texture(normal_map, uv + vec2(t, -t) * 0.14).xy - 0.5) * wave_strength +
        ripple_sum * wave_strength * 0.4 +
        shimmer_fx * 0.03;

    // Sun spot (“specular” highlight): moving with time, always on water
    vec2 sun_pos = vec2(0.4 + 0.3 * sin(t * 0.25), 0.2 + 0.4 * cos(t * 0.18));
    float sun_radius = 0.11 + shimmer * 0.09;
    float sun = smoothstep(sun_radius, sun_radius * 0.7, distance(uv, sun_pos)) * 4.6;
    // Sun fade along the bottom (optional)
    sun *= smoothstep(0.2, 0.0, uv.y);

    // Base color, modulated by ripples and shimmer
    vec4 col = water_color;
    col.rgb += ripple_sum * 0.10 + shimmer_fx * 0.05; // blue highlights
    col.a = water_color.a;

    // Fake refraction by distorting the screen texture
    vec2 refract_uv = SCREEN_UV + (texture(normal_map, waved_uv).xy - 0.5) * refraction + ripple_sum * 0.01;
    vec4 refr = texture(screen_texture, refract_uv);
    vec4 surface = mix(col, refr, 0.4 + ripple_sum * 0.27);

    // Add the sun spot reflection (white or tint)
    surface.rgb += vec3(1.0, 0.98, 0.85) * sun * 0.67;

    COLOR = surface;
}