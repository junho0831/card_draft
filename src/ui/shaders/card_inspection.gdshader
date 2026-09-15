shader_type canvas_item;
render_mode unshaded;
uniform vec2 tilt = vec2(0.0);
uniform vec4 edge_color : source_color = vec4(0.8, 0.65, 0.35, 1.0);

void fragment() {
	float sx = sin(tilt.y); float cx = cos(tilt.y);
	float sy = sin(tilt.x); float cy = cos(tilt.x);
	mat3 rotation = mat3(vec3(cy, 0.0, -sy), vec3(sy*sx, cx, cy*sx), vec3(sy*cx, -sx, cy*cx));
	vec2 p = (UV - 0.5) * vec2(1.24, 1.729);
	vec3 origin = vec3(0.0, 0.0, -3.0);
	vec3 ray = vec3(p, 3.0);
	vec3 normal = rotation[2];
	vec3 hit = origin + ray * (-dot(normal, origin) / dot(normal, ray));
	vec3 local = transpose(rotation) * hit;
	vec2 uv = local.xy / vec2(1.0, 1.394) + 0.5;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec4 face = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999)));
	float rim = 1.0 - smoothstep(0.0, 0.012, min(min(uv.x, 1.0-uv.x), min(uv.y, 1.0-uv.y)));
	float shine = pow(max(0.0, 1.0 - abs(uv.x * 0.75 + uv.y * 0.25 - 0.5 - tilt.x * 1.5)), 20.0);
	float moving = clamp(length(tilt) * 3.0, 0.0, 1.0);
	face.rgb = mix(face.rgb, edge_color.rgb, rim * 0.7);
	face.rgb += vec3(0.16, 0.18, 0.20) * shine * moving;
	vec2 shadow_p = p - vec2(0.03, 0.065) - tilt * 0.07;
	vec2 distance = abs(shadow_p) - vec2(0.48, 0.68);
	float shadow = (1.0 - smoothstep(0.0, 0.085, length(max(distance, vec2(0.0))))) * 0.5;
	COLOR = vec4(mix(vec3(0.0), face.rgb, inside), max(shadow, face.a * inside));
}
