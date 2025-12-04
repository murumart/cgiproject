shader_type spatial;

// source https://www.youtube.com/watch?v=ztkh1r1ioZo

// Unshaded is faster; cull_front allows us to see "into" the box
render_mode unshaded, cull_front;

uniform sampler3D simulation_data : filter_nearest; // The texture from the compute shader (R cell type)
uniform sampler3D brick_map : filter_nearest; // Brick occupancy map
uniform vec4 color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float density : hint_range(0.1, 100) = 100;
uniform int render_setting : hint_range(0, 5) = 0; // from the controller, can change in runtime
//uniform int max_steps = 128; // Reduce this if performance is low
uniform float mesh_size : hint_range(1, 400);
uniform int brick_size; // Size of each brick (must match VolumetricController)


varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX / mesh_size;
}

vec3 my_color(uint cell) {
	switch (cell) {
		case 0u:
			return vec3(1.0, 1.0, 1.0);
		case 1u:
			return vec3(0.2, 0.2, 0.2);
		case 2u:
			return vec3(0.2, 0.8, 1.0);
		case 3u:
			return vec3(0.2, 0.2, 0.2);
		case 4u:
			return vec3(0.2, 0.2, 0.2);
		case 5u:
			return vec3(0.2, 0.2, 0.2);
		case 6u:
			return vec3(0.2, 0.2, 0.2);
		case 7u:
			return vec3(0.2, 0.2, 0.2);
	}
}


void fragment() {
	vec3 local_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz / mesh_size; // position of the camera in object space
	vec3 local_frag = local_pos; // position of the fragment in object space
	vec3 dir = normalize(local_frag - local_cam); // direction to the fragment from the camera

	ivec3 tex_size = textureSize(simulation_data, 0);
	vec3 voxel_resolution = vec3(tex_size);
	
	// Convert to voxel space (0 to voxel_resolution)
	vec3 origin = (local_cam + 0.5) * voxel_resolution;
	
	// DDA setup
	const float FLT_MAX = 3.4028235e+38;
	vec3 inv_dir = 1.0 / dir;
	vec3 sgn_dir = sign(inv_dir); // the sign of the direction
	inv_dir = clamp(inv_dir, vec3(-FLT_MAX), vec3(FLT_MAX));
	
	// Calculate intersection with voxel grid bounds
	vec3 t1 = -origin * inv_dir; // t1 is the distance to the first intersection with the voxel grid
	vec3 t2 = (voxel_resolution - origin) * inv_dir; // t2 is the distance to the second intersection with the voxel grid
	
	vec3 tmins = min(t1, t2); 
	vec3 tmaxs = max(t1, t2); 
	
	// Don't clamp tmin to 0 - if camera is inside the volume, tmin will be negative
	float tmin = max(tmins.x, max(tmins.y, tmins.z)); 
	float tmax = min(tmaxs.x, min(tmaxs.y, tmaxs.z)); 
	
	// discard if the ray doesn't hit the volume
	if (tmin > tmax){
		discard;
	}
	
	// Move origin to entry point (or keep at camera position if inside)
	origin += dir * max(tmin, 0.0);
	
	// Get starting voxel coordinate
	ivec3 coord = ivec3(clamp(floor(origin), vec3(0), voxel_resolution - 1.0));

	// Calculate t values for each axis
	// t is the distance to the next voxel boundary
	vec3 t = (vec3(coord) + 0.5 * (1.0 + sgn_dir) - origin) * inv_dir;
	

	//ivec3 istep = ivec3(sgn_dir); // step direction (1 or -1)
	//vec3 delta = inv_dir * sgn_dir; // delta t per step
	
	float alpha_acc = 0.0; // accumulated alpha
	vec3 color_acc = vec3(0.0); // accumulated color


    // debug variables
	uint steps = 0u; // the number of steps we have taken
	int stepped_axis = 0; // the axis we are stepping on (0 = x, 1 = y, 2 = z)
	float depth = 0.0;
	float exited = 0.0;

 	float passed_through = 0.0;

	uint cell = 0u; // cell type
	
	
	// DDA traversal with brick map acceleration
	// move the ray through the voxel grid until we reach the end or alpha is 1 (find the next occupied voxel)
	uint max_steps = uint(voxel_resolution.x * 3.0); // Safety limit
	while (steps < max_steps) { // can make faster using max steps

		steps++;

		// Check if we exited the volume
		if (any(lessThan(coord, ivec3(0))) || any(greaterThanEqual(coord, ivec3(voxel_resolution)))) {
			exited = 1.0;
			break;
		}

		ivec3 brick_coord = ivec3(coord / brick_size); // brick coordinate

		// Safety check for array bounds before texture fetch
		if (any(lessThan(brick_coord, ivec3(0))) || any(greaterThanEqual(brick_coord, textureSize(brick_map, 0)))) {
			break;
		}

		vec3 brick_uvw = (vec3(brick_coord) + 0.5) / vec3(textureSize(brick_map, 0)); // uvw coordinates of the brick
		float brick_occupied = texture(brick_map, brick_uvw).r; // if the brick is occupied
		//brick_occupied = 1.0;

		if (brick_occupied > 0.5) {
			vec4 voxel_data_u = texelFetch(simulation_data, coord, 0);
			cell = uint(voxel_data_u.r * 255.0); // cell type

			

			// if the voxel is occupied
			if (cell > 0u) { 
				depth += t[stepped_axis];
				


				//color_acc += my_color(cell) * 0.01 * density;
				color_acc = mix(color_acc, my_color(cell), 0.01 * density);

				if (passed_through == 0.0) {
					switch (stepped_axis) {
						case 0: color_acc *= vec3(0.6); break;
						case 1: if (sgn_dir.y > 0.0) color_acc *= vec3(0.4); break;
						case 2: color_acc *= vec3(0.7); break;
					}
				}
				
				alpha_acc += 0.01 * density; // we add the density to the alpha
				if (alpha_acc >= 1.0) {
					alpha_acc = 1.0;
					break; // if the alpha is 1, we break
				}
				passed_through += 1.0;
			} else if (cell == 0u) {
				passed_through = 0.0;
			}
		} else {
			// If brick is empty, skip to next brick boundary
			// Calculate the position of the next brick boundaries for ALL axes
			vec3 brick_boundary_planes;
			ivec3 b_idx = coord / brick_size;

			brick_boundary_planes = (vec3(b_idx) + 0.5 * (1.0 + sgn_dir)) * float(brick_size);

			// Calculate distance (t) to these boundaries
			// Formula: (boundary - origin) / dir
			vec3 t_brick = (brick_boundary_planes - origin) * inv_dir; // find the distance to the next brick boundary

			// Find the closest exit point (min t)
			float t_exit = min(t_brick.x, min(t_brick.y, t_brick.z)); // find the closest exit point

			stepped_axis = (t_brick.x <= t_brick.y && t_brick.x <= t_brick.z) ? 0 : (t_brick.y <= t_brick.z ? 1 : 2); // find the axis we hit

			// Calculate the exact world position at the boundary
			vec3 exit_pos = origin + (dir * t_exit);
			
			// Add a bias vector in the direction of travel. 
			// This pushes the point physically INTO the next voxel.
			vec3 bias = sgn_dir * 1e-3;
			
			// Floor the biased position. 
			// Because we pushed it forward, floor() is forced to snap to the next index.
			ivec3 next_coord = ivec3(floor(exit_pos + bias));
			
			coord = next_coord;	
			t = (vec3(coord) + 0.5 * (1.0 + sgn_dir) - origin) * inv_dir;

			continue; 
		}
		

		// Find the closest exit point (min t)
		float t_exit = min(t.x, min(t.y, t.z));

		stepped_axis = (t.x <= t.y && t.x <= t.z) ? 0 : (t.y <= t.z ? 1 : 2);


		vec3 exit_pos = origin + (dir * t_exit);

		// Add a bias vector in the direction of travel. 
		// This pushes the point physically INTO the next voxel.
		vec3 bias = sgn_dir * 1e-3;
		
		// Floor the biased position. 
		// Because we pushed it forward, floor() is forced to snap to the next index.
		ivec3 next_coord = ivec3(floor(exit_pos + bias));
		
		coord = next_coord; 	
		t = (vec3(coord) + 0.5 * (1.0 + sgn_dir) - origin) * inv_dir;


		

/*
		
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
		}*/
		
	}

	//if (alpha_acc < 0.01 && render_setting != 3) discard;

	depth = depth / float(max(tex_size.x, max(tex_size.y, tex_size.z)));
	switch (render_setting) {
		case 0: // color
			ALBEDO = color_acc;
			
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
		case 3: // steps
			ALBEDO = vec3(float(steps)) / vec3(tex_size);
			ALPHA = 1.0;
			break;
		case 4: 
			ALBEDO = vec3(passed_through);
			ALPHA = 1.0;
			break;
		case 5: // exited
			ALBEDO = vec3(exited);
			ALPHA = 1.0;
			break;
	}
}