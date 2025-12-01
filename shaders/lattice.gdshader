shader_type spatial;

render_mode depth_prepass_alpha;

uniform sampler3D simulation_data : filter_nearest; // The texture from the compute shader

varying vec3 vxNormal;

void vertex() {
	// Called for every vertex the material is visible on.
	vxNormal = NORMAL;
}

void fragment() {

	// Get texture dimensions
	ivec3 tex_size = textureSize(simulation_data, 0);
	int voxel_resolution = tex_size.x;
	float div_by_resolution = 1.0 / float(voxel_resolution);
	float dadd = 0.5 * div_by_resolution; // adding this because reasons??

	vec3 color = vec3(0.0);

	/* if (COLOR.r > 1.0 || COLOR.g > 1.0 || COLOR.b > 1.0) {
		ALBEDO = vec3(0);
		ALPHA = sin(TIME) * 0.5 + 0.5;
	} */

	
	// converting fragment coordinates to 3d texture coordinates
	vec3 uvw = vec3(0);
	// these probably have mistakes in many places...
	if (vxNormal.x != 0.0) {
		uvw.x = COLOR.r + dadd;
		uvw.y = 1.0 - UV.y + dadd;
		uvw.z = 1.0 - UV.x + dadd;
		color.r += COLOR.r * 0.75;
	} else if (vxNormal.z != 0.0) {
		uvw.x = UV.x + dadd;
		uvw.y = 1.0 - UV.y + dadd;
		uvw.z = COLOR.r + dadd;
		color.b += COLOR.r * 0.75;
	} else if (vxNormal.y != 0.0) {
		uvw.x = 1.0 - UV.y + dadd;
		uvw.y = COLOR.r + dadd;
		uvw.z = 1.0 - UV.x + dadd;
		color.g += COLOR.r * 0.75;
	}

	float cell = texture(simulation_data, uvw).r; // value of the voxel
	if (cell <= 0.0) {
		ALPHA = 0.0;
	}
	color += vxNormal * 0.25;

	ALBEDO = color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
