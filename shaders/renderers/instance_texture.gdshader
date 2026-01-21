shader_type spatial;

uniform sampler3D cell_tex;

const vec3 diffuse_colors[4] = vec3[](
	vec3(1.0, 0.3, 0.8),
	vec3(0.8, 0.5, 0.3),
	vec3(0.25, 1.0, 0.2),
	vec3(0.4, 0.20, 0.15)
);

varying flat int type;

void vertex() {
	ivec3 coords = ivec3(INSTANCE_CUSTOM.xyz);
	type = int(texelFetch(cell_tex, coords, 0).r * 255.0);
}

void fragment() {
    if (type == 0) discard;
    ALBEDO = diffuse_colors[type];
}
