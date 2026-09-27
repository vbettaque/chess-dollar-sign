shader_type canvas_item;

uniform vec3 background_color : source_color = vec3(0.145, 0.207, 0.227);
uniform vec3 white_tile_color : source_color = vec3(1.0);
uniform vec3 black_tile_color : source_color = vec3(0.0);

void fragment() {
	
	float width = mix(0.5, 0.75, UV.y);
	
	if (2. * abs(UV.x - 0.5) > width) {
		COLOR = vec4(background_color, 1);
	} else {
		float x = (UV.x - (1. - width) / 2.) / width;
		float y = mod(0.75/width * UV.y - TIME / 8., 1.0);
		int i = int(floor(x * 8.0));
		int j = int(floor(y * 8.0));
		if ((i + j) % 2 == 0) {
			COLOR = vec4(black_tile_color, 1.0);
		} else {
			COLOR = vec4(white_tile_color, 1.0);
		}
	}
	
	float t_top = smoothstep(0, 0.5, UV.y);
	float t_bottom = 1. - smoothstep(0.5, 1.0, UV.y);
	
	COLOR = mix(vec4(background_color, 1), COLOR, t_top);
	COLOR = mix(vec4(background_color, 1), COLOR, t_bottom);
	
}