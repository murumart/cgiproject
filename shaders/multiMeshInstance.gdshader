shader_type spatial;

const vec3 diffuse_colors[4] = vec3[](
	vec3(1.0, 0.3, 0.8),
	vec3(0.8, 0.5, 0.3),
	vec3(0.25, 1.0, 0.2),
	vec3(0.4, 0.20, 0.15)
);

varying flat int type;

void vertex() {
	type = int(INSTANCE_CUSTOM.x);
}

void fragment() {
    if (type == 0) discard;
    ALBEDO = diffuse_colors[type];
}
