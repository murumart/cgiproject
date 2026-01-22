shader_type spatial;

render_mode unshaded, depth_prepass_alpha;

uniform sampler3D simulation_data : filter_nearest; // The texture from the compute shader
uniform int grid_size;
uniform vec3 cell_colors[3] : source_color;
uniform sampler2D cell_texture : source_color, filter_nearest;
uniform float cell_texture_size = 16;
uniform float tiles_in_atlas = 4;
uniform float cell_specs[3];
uniform float cell_shines[3];
uniform vec3 sun_direction = vec3(0.3535533906, 0.7071067812, 0.3535533906);

varying vec3 vxNormal;
varying vec3 local_cam;
varying vec3 view_dir;

const float EPSILON = 0.001;


void vertex() {
	// set because NORMAL in fragment is not in world space
	vxNormal = NORMAL;
	local_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz; // position of the camera in object space
	view_dir = local_cam - VERTEX;
	//if (abs(NORMAL.x) < EPSILON) POSITION.xyz = vec3(0);
}

vec3 bf(vec3 normal, vec3 viewdir, vec3 lightdir, vec3 amb, vec3 diff, float specamt, float shininess) {
	vec3 color = amb;
	
	float lambert = max(0.0, dot(lightdir, normal));
	float specular = 0.0;
	
	vec3 halfangle = normalize(viewdir + lightdir);
	float hndot = max(0.0, dot(halfangle, normal));
	specular = pow(hndot, shininess) * lambert * specamt;
	
	color += diff * lambert;
	color += vec3(0.5) * specular;
	
	color = min(max(color, amb * 0.5), vec3(1.0));
	//color = ;
	
	return color;
}

void fragment() {

	float uvw_cell_size = 1.0 / float(grid_size + 1);
	float dadd = 0.5 * uvw_cell_size; // adding this to get center of block??

	vec3 color = vec3(0.0);

	// converting fragment coordinates to 3d texture coordinates
	float axisCoef = float(grid_size);
	int mainAxis = int(COLOR.r * axisCoef);
	ivec2 UVAxis = ivec2(UV * axisCoef);
	ivec3 uvw = ivec3(0);
	if (abs(vxNormal.x) > EPSILON) {
		uvw.x = mainAxis;
		uvw.y = UVAxis.y;
		uvw.z = UVAxis.x;
	} else if (abs(vxNormal.z) > EPSILON) {
		uvw.x = UVAxis.x;
		uvw.y = UVAxis.y;
		uvw.z = mainAxis;
	} else /*if (abs(vxNormal.y) > EPSILON)*/ {
		uvw.x = UVAxis.x;
		uvw.y = mainAxis;
		uvw.z = UVAxis.y;
	}
	float cellF = texelFetch(simulation_data, uvw, 0).r;
	if (cellF <= 0.0) {
		ALPHA = 0.0001;
	}
	int cell = int(cellF * 255.0); // cell type of the voxel
	
	vec2 tileuv = mod((vec2(1) - UV) * axisCoef, vec2(1));
	tileuv /= tiles_in_atlas;
	tileuv.x += (1.0 / tiles_in_atlas) * float(cell - 1);
	
	color = texture(cell_texture, tileuv).rgb;
	
	color = bf(
		normalize(vxNormal),
		view_dir,
		sun_direction,
		color * 0.05,
		color,
		cell_specs[cell - 1],
		cell_shines[cell - 1]
	);

	ALBEDO = color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
