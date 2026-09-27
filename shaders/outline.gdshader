//THIS SHADER MUST BE APPLIED TO A QUAD (MeshInstance) WITH A SIZE OF (2, 2)
//Extra Cull Margin on the quad should be turned up all the way!

shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D depth_texture : hint_depth_texture;

uniform float outline_intensity : hint_range(0, 5) = 1;
uniform bool _round = false;
uniform float outline_bias : hint_range(-10, 10) = 0;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	ALBEDO = outline_color.rgb;
	
	vec2 screen_size = vec2(textureSize(screen_texture, 1));
	
	float px = 0.5/screen_size.x;
	float py = 0.5/screen_size.y;
	
	float d = texture(depth_texture, SCREEN_UV).x;
	float du = texture(depth_texture, SCREEN_UV+vec2(0.0, py)).x;
	float dd = texture(depth_texture, SCREEN_UV+vec2(0.0, -py)).x;
	float dr = texture(depth_texture, SCREEN_UV+vec2(px, 0.0)).x;
	float dl = texture(depth_texture, SCREEN_UV+vec2(-px, 0.0)).x;
	
	float inv_d = 1.0 / max(d, 0.001);
	
	float depth_diff = 0.0;
	float neg_depth_diff = .5;
	
	depth_diff = clamp((du - d) * inv_d, 0., 1.)
		+ clamp((dd - d) * inv_d, 0., 1.)
		+ clamp((dl - d) * inv_d, 0., 1.)
		+ clamp((dr - d) * inv_d, 0., 1.);
			
	neg_depth_diff = (d - du) * inv_d
		+ (d - dd) * inv_d
		+ (d - dr) * inv_d
		+ (d - dl) * inv_d;

	depth_diff = smoothstep(0.0, 0.8, depth_diff);
	
	ALPHA = depth_diff;
	ALPHA *= 10000.0 * outline_intensity;
	
	ALPHA += outline_bias;
	
	if (_round) {
		ALPHA = round(ALPHA);
	}
	
	ALPHA *= outline_color.a;
}
