shader_type canvas_item;

uniform float flash = 0.0;                 // 0..1
uniform vec4  flash_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    c.rgb = mix(c.rgb, flash_color.rgb, clamp(flash, 0.0, 1.0));
    COLOR = c; // simple sprite tint, preserves alpha
}
