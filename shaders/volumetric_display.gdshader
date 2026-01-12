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
uniform vec3 sun_direction = vec3(0.5, 1.0, 0.5);
uniform bool rt_shading = false;

varying vec3 local_pos;

struct RayResult {
	vec3 color;
	float alpha;
	float depth;
	int stepped_axis;
	uint steps;
	float passed_through;
	float exited;
	uint cell;
	vec3 normal;
	vec3 position;
};

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

RayResult dda_ray_march(vec3 origin, vec3 dir) {
	RayResult res;
	res.color = vec3(0.0);
	res.alpha = 0.0;
	res.depth = 0.0;
	res.stepped_axis = 0;
	res.steps = 0u;
	res.passed_through = 0.0;
	res.exited = 0.0;
	res.cell = 0u;
	res.position = vec3(0.0);
	res.normal = vec3(0.0);

	ivec3 tex_size = textureSize(simulation_data, 0);
	vec3 voxel_resolution = vec3(tex_size);

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
		return res;
	}
	
	vec3 curr_pos = origin + dir * max(tmin, 0.0);
	
	// Get starting voxel coordinate
	ivec3 coord = ivec3(clamp(floor(curr_pos), vec3(0), voxel_resolution - 1.0));

	// Calculate t values for each axis
	// t is the distance to the next voxel boundary from curr_pos (entry point, relative t=0)
	vec3 t = (vec3(coord) + 0.5 * (1.0 + sgn_dir) - curr_pos) * inv_dir;

	vec3 exit_pos = vec3(0.0);
	float t_current = 0.0; // Track the current distance along the ray from curr_pos
	
    // DDA traversal with brick map acceleration
	// move the ray through the voxel grid until we reach the end or alpha is 1 (find the next occupied voxel)
	uint max_steps = uint(voxel_resolution.x * 3.0); // Safety limit
	while (res.steps < max_steps) { // can make faster using max steps
		res.steps++;

		// Check if we exited the volume
		if (any(lessThan(coord, ivec3(0))) || any(greaterThanEqual(coord, ivec3(voxel_resolution)))) {
			res.exited = 1.0;
			break;
		}

		ivec3 brick_coord = ivec3(coord / brick_size); // brick coordinate

		// Safety check for array bounds before texture fetch
		if (any(lessThan(brick_coord, ivec3(0))) || any(greaterThanEqual(brick_coord, textureSize(brick_map, 0)))) {
			break;
		}

		vec3 brick_uvw = (vec3(brick_coord) + 0.5) / vec3(textureSize(brick_map, 0)); // uvw coordinates of the brick
		float brick_occupied = textureLod(brick_map, brick_uvw, 0.0).r; // if the brick is occupied

		if (brick_occupied > 0.5) {
			vec4 voxel_data_u = texelFetch(simulation_data, coord, 0);
			res.cell = uint(voxel_data_u.r * 255.0); // cell type

			// if the voxel is occupied
			if (res.cell > 0u) { 
				//res.depth += t[res.stepped_axis]; // OLD INCORRECT logic
				if (res.passed_through == 0.0) {
					res.depth = t_current; // Set depth to the first hit distance
					res.position = curr_pos + dir * t_current; // Exact world position (in voxel space)
					
					// Calculate normal
					res.normal = vec3(0.0);
					res.normal[res.stepped_axis] = -sgn_dir[res.stepped_axis];
				}

				res.color = mix(res.color, my_color(res.cell), 0.01 * density);

				if (res.passed_through == 0.0) {
					// Blinn-Phong Shading
					vec3 N = normalize(res.normal);
					vec3 L = normalize(sun_direction);
					vec3 V = -dir; // View direction is opposite to ray direction
					vec3 H = normalize(L + V);

					float diff = max(dot(N, L), 0.0);
					float spec = pow(max(dot(N, H), 0.0), 32.0); // Shininess 32
					
					vec3 ambient = vec3(0.3); // Ambient light
					vec3 lightColor = vec3(1.0); // Sun color

					// Apply lighting
					vec3 lighting = ambient + lightColor * (diff * 0.8 + spec * 0.5);
					res.color *= lighting;
				}
				
				res.alpha += 0.01 * density; // we add the density to the alpha
				if (res.alpha >= 1.0) {
					res.alpha = 1.0;
					// Position already set on first hit
					break; // if the alpha is 1, we break
				}
				res.passed_through += 1.0;
			} else if (res.cell == 0u) {
				res.passed_through = 0.0;
			}
		} else {
			// If brick is empty, skip to next brick boundary
			// Calculate the position of the next brick boundaries for ALL axes
			vec3 brick_boundary_planes;
			ivec3 b_idx = coord / brick_size;

			brick_boundary_planes = (vec3(b_idx) + 0.5 * (1.0 + sgn_dir)) * float(brick_size);

			// Calculate distance (t) to these boundaries
			vec3 t_brick = (brick_boundary_planes - curr_pos) * inv_dir; // find the distance to the next brick boundary

			// Find the closest exit point (min t)
			float t_exit = min(t_brick.x, min(t_brick.y, t_brick.z)); // find the closest exit point

			res.stepped_axis = (t_brick.x <= t_brick.y && t_brick.x <= t_brick.z) ? 0 : (t_brick.y <= t_brick.z ? 1 : 2); // find the axis we hit

			// Calculate the exact world position at the boundary
			exit_pos = curr_pos + (dir * t_exit);
			
			// Add a bias vector in the direction of travel. 
			// This pushes the point physically INTO the next voxel.
			vec3 bias = sgn_dir * 1e-3;
			
			// Floor the biased position. 
			// Because we pushed it forward, floor() is forced to snap to the next index.
			ivec3 next_coord = ivec3(floor(exit_pos + bias));
			
			coord = next_coord;	
			t = (vec3(coord) + 0.5 * (1.0 + sgn_dir) - curr_pos) * inv_dir;
			
			// Update t_current to the brick boundary
			t_current = t_exit; 
			continue; 
		}
		
		// Find the closest exit point (min t)
		float t_exit = min(t.x, min(t.y, t.z));

		res.stepped_axis = (t.x <= t.y && t.x <= t.z) ? 0 : (t.y <= t.z ? 1 : 2);

		exit_pos = curr_pos + (dir * t_exit);

		// Add a bias vector in the direction of travel. 
		// This pushes the point physically INTO the next voxel.
		vec3 bias = sgn_dir * 1e-3;
		
		// Floor the biased position. 
		// Because we pushed it forward, floor() is forced to snap to the next index.
		ivec3 next_coord = ivec3(floor(exit_pos + bias));
		
		coord = next_coord;
		t = (vec3(coord) + 0.5 * (1.0 + sgn_dir) - curr_pos) * inv_dir;
		
		// Update t_current to the voxel boundary
		t_current = t_exit;
	}
	return res;
}


void fragment() {
	vec3 local_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz / mesh_size; // position of the camera in object space
	vec3 local_frag = local_pos; // position of the fragment in object space
	vec3 dir = normalize(local_frag - local_cam); // direction to the fragment from the camera

	ivec3 tex_size = textureSize(simulation_data, 0);
	vec3 voxel_resolution = vec3(tex_size);
	
	// Convert to voxel space (0 to voxel_resolution)
	vec3 origin = (local_cam + 0.5) * voxel_resolution;
	
	RayResult res = dda_ray_march(origin, dir);
	//if (alpha_acc < 0.01 && render_setting != 3) discard;

	if (rt_shading) {
		// Add bias to avoid self-shadowing (acne)
		// Move along the light direction to ensure we clear the current voxel boundary
		vec3 sun_dir = normalize(sun_direction);
		vec3 shadow_origin = res.position + sun_dir * 0.01;
		RayResult res2sun = dda_ray_march(shadow_origin, sun_dir);
		
		// If the shadow ray hits something, darken the color (shadow)
		if (res2sun.alpha > 0.0) {
			res.color *= 0.5;
		}
	}

	float depth = res.depth / float(max(tex_size.x, max(tex_size.y, tex_size.z)));
	switch (render_setting) {
		case 0: // color
			ALBEDO = res.color;
			
			ALPHA = res.alpha;
			break;
		case 1: // depth
			ALBEDO = vec3(depth, depth, depth);
			ALPHA = res.alpha;
			break;
		case 2: // axis
			switch (res.stepped_axis) {
				case 0:
					ALBEDO = vec3(res.depth, 0.0, 0.0);
					ALPHA = res.alpha;
					break;
				case 1:
					ALBEDO = vec3(0.0, res.depth, 0.0);
					ALPHA = res.alpha;
					break;
				case 2:
					ALBEDO = vec3(0.0, 0.0, res.depth);
					ALPHA = res.alpha;
					break;
				}
			break;
		case 3: // steps
			ALBEDO = vec3(float(res.steps)) / vec3(tex_size);
			ALPHA = 1.0;
			break;
		case 4: 
			ALBEDO = vec3(res.passed_through);
			ALPHA = 1.0;
			break;
		case 5: // exited
			ALBEDO = vec3(res.exited);
			ALPHA = 1.0;
			break;
	}
}