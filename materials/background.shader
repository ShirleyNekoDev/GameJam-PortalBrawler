shader_type canvas_item;

varying vec2 world_pos;

uniform vec4 BACKGROUND_COLOR: hint_color = vec4(vec3(0.0, 0.0, 1.0), 1.0);
uniform vec4 GRID_COLOR: hint_color = vec4(vec3(1.0), 1.0);
uniform vec2 GRID_SIZE = vec2(100.0, 100.0);

uniform float TIME_FACTOR = 0.6;

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	vec2 grid_coords = fract(world_pos.xy * GRID_SIZE);
//	distance(FRAGCOORD.xy, grid_coords);
//	(cos(TIME * 0.2) + 1.0) * 
//	COLOR = vec4(vec3(fract(world_pos.xy * 200.0).x * fract(world_pos.xy * 200.0).y * sin(TIME / 10.0)), 1.0);
	COLOR = vec4(vec3(sin(TIME * TIME_FACTOR) * sin(TIME * TIME_FACTOR) * sin(TIME * TIME_FACTOR)) * 0.1 + 0.1, 1.0);
}
