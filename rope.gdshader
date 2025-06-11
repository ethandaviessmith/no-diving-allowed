shader_type canvas_item;

uniform float pixel_size : hint_range(0.5, 8, 0.5) = 1.0; // 1 for perfect pixels if your rope is 4px
uniform float band_width : hint_range(1, 16, 1) = 4.0;    // Should match rope width in pixels (Line2D.width)
uniform vec4 color_white = vec4(1.0,1.0,1.0,1.0);
uniform vec4 color_blue = vec4(0.22,0.44,1.0,1.0);
uniform float twist_repeat = 6.0;

void fragment() {

	float snapped_x = floor(UV.x / pixel_size) * pixel_size;
    float snapped_y = floor(UV.y / pixel_size) * pixel_size;
    // snap UV to pixel grid for sharp look
    vec2 uv_px = floor(UV * vec2(twist_repeat * band_width, band_width)) / vec2(twist_repeat * band_width, band_width);
    float along = uv_px.x * twist_repeat * band_width; // pixel-wise distance along the rope
    float across = uv_px.y * band_width;               // pixel along width

    // Calculate the diagonal offset: creates a twist
    float diag = mod(along + across, band_width);

    // Strands: |W|W|B|B| = two white, two blue across width=4px
    // We'll set up as: white at 0,1; blue at 2; white at 3, then repeat

    vec4 col;
    if (band_width == 4.0) {
        if (diag < 1.0) {
            col = color_white;
        } else if (diag < 2.0) {
            col = color_white;
        } else if (diag < 3.0) {
            col = color_blue;
        } else {
            col = color_white;
        }
    } else {
        // For wider ropes, just stripe white/blue/white by proportion
        if (diag < band_width * 0.33) {
            col = color_white;
        } else if (diag < band_width * 0.66) {
            col = color_blue;
        } else {
            col = color_white;
        }
    }

    // Make edges transparent for crispy pixel width
    if (across < 0.0 || across > (band_width-1.0)) {
        col.a = 0.0;
    }

    COLOR = col;
}