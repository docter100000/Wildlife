shader_type spatial;

uniform vec3 grass_color_1 : source_color = vec3(0.35, 0.65, 0.25);
uniform vec3 grass_color_2 : source_color = vec3(0.25, 0.55, 0.15);

uniform vec3 dirt_color_1 : source_color = vec3(0.4, 0.28, 0.15);
uniform vec3 dirt_color_2 : source_color = vec3(0.28, 0.18, 0.1);

uniform vec3 water_color : source_color = vec3(0.1, 0.4, 0.8);
uniform float water_height = -0.35;

uniform float transition_height = -0.1;
uniform float transition_smoothness = 0.15;

uniform float noise_scale = 1.5;

varying float local_y;
varying vec3 local_pos;

// Pseudo-random hash function
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Simple value noise
float noise(vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(p);
    float b = hash(p + vec2(1.0, 0.0));
    float c = hash(p + vec2(0.0, 1.0));
    float d = hash(p + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion
float fbm(vec2 x) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    // Rotate to reduce axial bias
    mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
    for (int i = 0; i < 4; ++i) {
        v += a * noise(x);
        x = rot * x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void vertex() {
	local_y = VERTEX.y;
	local_pos = VERTEX;
}

void fragment() {
	// Generate noise based on local XZ position
	float n_grass = fbm(local_pos.xz * noise_scale);
	
	// Grass texture variation
	vec3 grass = mix(grass_color_1, grass_color_2, n_grass);
	
	// Dirt texture variation (different scale/offset for variety)
	float n_dirt = fbm(local_pos.xz * noise_scale * 1.5 + vec2(5.2, 1.3));
	vec3 dirt = mix(dirt_color_1, dirt_color_2, n_dirt);
	
	// Add noise to the transition height so it's not perfectly flat
	float transition_noise = fbm(local_pos.xz * 3.0) * 0.15 - 0.075;
	
	// Blend between grass and dirt based on height
	float t = smoothstep(
		transition_height - transition_smoothness + transition_noise, 
		transition_height + transition_smoothness + transition_noise, 
		local_y
	);
	
	vec3 dirt_grass = mix(dirt, grass, t);
	
	// Blend between dirt_grass and water based on height
	float w = smoothstep(
		water_height - transition_smoothness + transition_noise,
		water_height + transition_smoothness + transition_noise,
		local_y
	);
	
	ALBEDO = mix(water_color, dirt_grass, w);
	
	// Dirt is rougher, grass has slight specularity, water is highly reflective
	float rough_dirt_grass = mix(0.95, 0.8, t);
	ROUGHNESS = mix(0.15, rough_dirt_grass, w);
}
