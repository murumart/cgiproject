shader_type spatial;

// source https://www.youtube.com/watch?v=ztkh1r1ioZo

// Unshaded is faster; cull_back allows us to see "into" the box
render_mode unshaded, cull_disabled;

uniform sampler3D simulation_data : filter_nearest; // The texture from the compute shader
uniform vec4 color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float density : hint_range(0.1, 100) = 100;
uniform int render_setting : hint_range(0, 2) = 0;
//uniform int max_steps = 128; // Reduce this if performance is low


// Standard AABB Intersection
vec2 intersect_box(vec3 orig, vec3 dir, vec3 box_min, vec3 box_max) {
	vec3 inv_dir = 1.0 / dir;
	vec3 tmin_tmp = (box_min - orig) * inv_dir;
	vec3 tmax_tmp = (box_max - orig) * inv_dir;
	vec3 tmin = min(tmin_tmp, tmax_tmp);
	vec3 tmax = max(tmin_tmp, tmax_tmp);
	float t0 = max(tmin.x, max(tmin.y, tmin.z));
	float t1 = min(tmax.x, min(tmax.y, tmax.z));
	return vec2(t0, t1); // t0 is the start, t1 is the end
}

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Transform camera ray to object local space
	vec3 local_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz; // position of the camera in object space
	vec3 local_frag = local_pos; // position of the fragment in object space
	vec3 dir = normalize(local_frag - local_cam); // direction to the fragment from the camera

	// Get texture dimensions
	ivec3 tex_size = textureSize(simulation_data, 0);
	//int max_steps = tex_size.x * 2; // should this be * 2?
	vec3 voxel_resolution = vec3(tex_size);
	
	// Convert to voxel space (0 to voxel_resolution)
	vec3 origin = (local_cam + 0.5) * voxel_resolution;
	
	// DDA setup
	const float FLT_MAX = 3.4028235e+38;
	vec3 inv_dir = 1.0 / dir;
	vec3 sgn_dir = sign(inv_dir);
	inv_dir = clamp(inv_dir, vec3(-FLT_MAX), vec3(FLT_MAX));
	
	// Calculate intersection with voxel grid bounds
	vec3 t1 = -origin * inv_dir;
	vec3 t2 = (voxel_resolution - origin) * inv_dir;
	
	vec3 tmins = min(t1, t2);
	vec3 tmaxs = max(t1, t2);
	
	// Don't clamp tmin to 0 - if camera is inside the volume, tmin will be negative
	float tmin = max(tmins.x, max(tmins.y, tmins.z));
	float tmax = min(tmaxs.x, min(tmaxs.y, tmaxs.z));
	
	// Discard if ray misses the volume
	if (tmin > tmax) discard;
	
	// Move origin to entry point (or keep at camera position if inside)
	origin += dir * max(tmin, 0.0);
	
	// Get starting voxel coordinate
	ivec3 coord = ivec3(clamp(floor(origin), vec3(0), voxel_resolution - 1.0));
	
	// Calculate t values for each axis
	// t is the distance to the next voxel boundary
	vec3 t = (vec3(coord) + 0.5 * (1.0 + sgn_dir) - origin) * inv_dir;
	

	ivec3 istep = ivec3(sgn_dir); // step direction
	vec3 delta = inv_dir * sgn_dir; // delta t per step
	
	float alpha_acc = 0.0; // accumulated alpha
	uint steps = 0u; // the number of steps we have taken
	int stepped_axis = 0; // the axis we are stepping on (0 = x, 1 = y, 2 = z)


	float depth = 0.0;
	
	// DDA traversal
	// move the ray through the voxel grid until we reach the end or alpha is 1 (find the next occupied voxel)
	while (true) { // can make faster using max steps
		//steps++;
		
		// Sample current voxel
		vec3 uvw = (vec3(coord) + 0.5) / voxel_resolution; // uvw coordinates of the voxel
		float cell = texture(simulation_data, uvw).r; // value of the voxel
		
		// if the voxel is occupied
		if (cell > 0.5) { 
			depth += t[stepped_axis];
			alpha_acc += 0.01 * density; // we add the density to the alpha
			if (alpha_acc >= 1.0) break; // if the alpha is 1, we break
		}
		
		// Step to next voxel boundary
		if (t.x < t.y) { // x is the smallest
			if (t.x < t.z) { // x is the smallest
				coord.x += istep.x;
				t.x += delta.x;
				stepped_axis = 0;
			} else { // z is the smallest
				coord.z += istep.z;
				t.z += delta.z;
				stepped_axis = 2;
			}
		} else { // y is the smallest
			if (t.y < t.z) { // y is the smallest
				coord.y += istep.y;
				t.y += delta.y;
				stepped_axis = 1;
			} else { // z is the smallest
				coord.z += istep.z;
				t.z += delta.z;
				stepped_axis = 2;
			}
		}
		
		// Check if we exited the volume
		if (any(lessThan(coord, ivec3(0))) || any(greaterThanEqual(coord, ivec3(voxel_resolution)))) {
			break;
		}
	}

	if (alpha_acc < 0.01) discard;

	depth = depth / 255.0;
	switch (render_setting) {
		case 0: // color
			ALBEDO = color.rgb;
			ALPHA = alpha_acc;
			break;
		case 1: // depth
			ALBEDO = vec3(depth, depth, depth);
			ALPHA = alpha_acc;
			break;
		case 2: // axis
			switch (stepped_axis) {
				case 0:
					ALBEDO = vec3(depth, 0.0, 0.0);
					ALPHA = alpha_acc;
					break;
				case 1:
					ALBEDO = vec3(0.0, depth, 0.0);
					ALPHA = alpha_acc;
					break;
				case 2:
					ALBEDO = vec3(0.0, 0.0, depth);
					ALPHA = alpha_acc;
					break;
				}
			break;
	}
}