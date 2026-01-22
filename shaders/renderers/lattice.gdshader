shader_type spatial;

render_mode unshaded, depth_prepass_alpha;

uniform sampler3D simulation_data : filter_nearest; // The texture from the compute shader
uniform int grid_size;

varying vec3 vxNormal;

const float EPSILON = 0.001;

void vertex() {
	// set because NORMAL in fragment is not in world space
	vxNormal = NORMAL;
	//if (abs(NORMAL.x) < EPSILON) POSITION.xyz = vec3(0);
}

void fragment() {

	float uvw_cell_size = 1.0 / float(grid_size + 1);
	float dadd = 0.5 * uvw_cell_size; // adding this to get center of block??

	vec3 color = vec3(0.0);

	// converting fragment coordinates to 3d texture coordinates
	float axisCoef = float(grid_size);
	ivec3 uvw = ivec3(0);
	if (abs(vxNormal.x) > EPSILON) {
		uvw.x = int(COLOR.r * axisCoef);
		uvw.z = int(UV.x * axisCoef);
		uvw.y = int(UV.y * axisCoef);
		color.r = COLOR.r;
		float cell = texelFetch(simulation_data, uvw, 0).r; // value of the voxel
		if (cell <= 0.0) {
			ALPHA = 0.0;
		}
	} else if (abs(vxNormal.z) > EPSILON) {
		uvw.z = int(COLOR.r * axisCoef);
		uvw.x = int(UV.x * axisCoef);
		uvw.y = int(UV.y * axisCoef);
		color.b = COLOR.r;
		float cell = texelFetch(simulation_data, uvw, 0).r; // value of the voxel
		if (cell <= 0.0) {
			ALPHA = 0.0;
		}
	} else if (abs(vxNormal.y) > EPSILON) {
		uvw.y = int(COLOR.r * axisCoef);
		uvw.x = int(UV.x * axisCoef);
		uvw.z = int(UV.y * axisCoef);
		color.g = COLOR.r;
		float cell = texelFetch(simulation_data, uvw, 0).r; // value of the voxel
		if (cell <= 0.0) {
			ALPHA = 0.0;
		}
	}
	//ALPHA = 1.0;
	//color = vxNormal;

	ALBEDO = color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
