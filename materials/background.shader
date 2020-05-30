shader_type canvas_item;

varying vec2 world_pos;

uniform vec4 BACKGROUND_COLOR: hint_color = vec4(vec3(0.0, 0.0, 1.0), 1.0);
uniform vec4 GRID_COLOR: hint_color = vec4(vec3(1.0), 1.0);
uniform vec2 GRID_SIZE = vec2(100.0, 100.0);

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	vec2 grid_coords = fract(world_pos.xy * GRID_SIZE);
//	distance(FRAGCOORD.xy, grid_coords);
//	(cos(TIME * 0.2) + 1.0) * 
	COLOR = vec4(fract(world_pos.xy * 200.0), 0.0, 1.0);
}
