shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    vec2 offset = (SCREEN_UV - vec2(0.5)) * vec2(aspect, 1.0);
    float radius = progress * length(vec2(aspect, 1.0)) * 0.501;
    float outside = step(radius, length(offset));
    COLOR = vec4(0.0, 0.0, 0.0, outside);
}
