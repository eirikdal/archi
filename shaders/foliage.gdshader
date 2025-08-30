// res://shaders/foliage_ground.shader
shader_type canvas_item;

// Palette (12 colours). Adjust to your master set.
uniform vec4 COL0  : source_color = vec4(0.137,0.086,0.141,1.0); // #231624 deep indigo
uniform vec4 COL1  : source_color = vec4(0.176,0.141,0.251,1.0);
uniform vec4 COL2  : source_color = vec4(0.220,0.180,0.298,1.0);
uniform vec4 COL3  : source_color = vec4(0.282,0.247,0.329,1.0);
uniform vec4 COL4  : source_color = vec4(0.149,0.251,0.180,1.0); // moss
uniform vec4 COL5  : source_color = vec4(0.223,0.345,0.212,1.0);
uniform vec4 COL6  : source_color = vec4(0.325,0.478,0.286,1.0);
uniform vec4 COL7  : source_color = vec4(0.455,0.600,0.341,1.0);
uniform vec4 COL8  : source_color = vec4(0.576,0.690,0.447,1.0);
uniform vec4 COL9  : source_color = vec4(0.702,0.776,0.545,1.0);
uniform vec4 COL10 : source_color = vec4(0.827,0.874,0.675,1.0);
uniform vec4 COL11 : source_color = vec4(0.816,0.831,0.835,1.0); // frosty highlight #d0d4d5

// Controls
uniform float world_scale = 1.0;     // 1.0 = 1:1 world units
uniform float base_height = 32.0;    // vertical height of foliage band in px
uniform float detail_freq = 0.08;    // noise frequency
uniform float clump_freq  = 0.02;    // big shapes
uniform float parallax    = 0.0;     // set >0 to make it scroll slower than camera

// Bayer 4x4 dither
float bayer4x4(vec2 p) {
    int x = int(mod(p.x,4.0));
    int y = int(mod(p.y,4.0));
    int idx = x + y*4;
    int map[16] = int[16](
        0,  8,  2, 10,
       12,  4, 14,  6,
        3, 11,  1,  9,
       15,  7, 13,  5
    );
    return float(map[idx]) / 16.0;
}

// Hash/Noise
float hash(vec2 p){ return fract(sin(dot(p, vec2(41.0,289.0))) * 43758.5453); }
float noise(vec2 p){
    vec2 i = floor(p), f = fract(p);
    float a = hash(i);
    float b = hash(i+vec2(1,0));
    float c = hash(i+vec2(0,1));
    float d = hash(i+vec2(1,1));
    vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

// FBM
float fbm(vec2 p){
    float v=0.0, a=0.5;
    for(int i=0;i<5;i++){
        v += a*noise(p);
        p *= 2.02;
        a *= 0.5;
    }
    return v;
}

vec4 palette(float t){
    // 4-tone mossy ramp, mapped into 12-col palette
    if (t < 0.25) return COL4;
    if (t < 0.50) return COL6;
    if (t < 0.75) return COL8;
    return COL10;
}

void fragment(){
    // World-space UVs (camera-proof). Convert SCREEN_PIXEL_SIZE to world px.
    vec2 world_px = (FRAGCOORD.xy / SCREEN_PIXEL_SIZE) * world_scale;
    // Optional parallax (smaller = slower scroll)
    world_px.x *= (1.0 - parallax);

    // Grass band mask (fade to dirt below)
    float band = smoothstep(0.0, 8.0, base_height - world_px.y);

    // Clumps + detail
    float clump = fbm(world_px * clump_freq);
    float detail = fbm(world_px * detail_freq);
    float foliage = clamp(clump*0.6 + detail*0.6, 0.0, 1.0);

    // Height modulation to get tufts on top edge
    float tuft = fbm(vec2(world_px.x*0.04, 0.0));
    float top_edge = smoothstep(0.35, 0.65, foliage + tuft*0.35);

    float shade = clamp(foliage*band, 0.0, 1.0);
    vec4 col = palette(shade);

    // Dither to the fixed palette
    float d = bayer4x4(FRAGCOORD.xy);
    float t = floor(shade*4.0 + d)/4.0;
    COLOR = mix(col, COL11, 0.05*top_edge); // tiny frost highlights
}
