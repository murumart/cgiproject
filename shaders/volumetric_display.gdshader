shader_type spatial;

// source https://www.youtube.com/watch?v=ztkh1r1ioZo

// Unshaded is faster; cull_front allows us to see "into" the box
render_mode unshaded, cull_front;

uniform sampler3D simulation_data : filter_nearest; // The texture from the compute shader (R cell type)
uniform sampler3D brick_map : filter_nearest; // Brick occupancy map
uniform vec4 color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float density : hint_range(0.1, 100) = 100;
uniform int render_setting : hint_range(0, 7) = 0; // from the controller, can change in runtime
//uniform int max_steps = 128; // Reduce this if performance is low
uniform float mesh_size : hint_range(1, 400);
uniform int brick_size; // Size of each brick (must match VolumetricController)

// lighting
uniform vec3 sun_direction = vec3(0.5, 1.0, 0.5);
uniform vec3 sun_color = vec3(1.0, 1.0, 1.0);
uniform float sun_power : hint_range(0.0, 1.0) = 1.0;
//uniform vec3 ambient_color = vec3(0.1, 0.1, 0.1);
uniform float ambient_power : hint_range(0.0, 1.0) = 1.0;
//uniform vec3 diffuse_color = vec3(1.0, 1.0, 1.0);
//uniform vec3 specular_color = vec3(1.0, 1.0, 1.0);
uniform float shininess : hint_range(1, 128) = 32;
//uniform float screenGamma : hint_range(0.1, 10) = 2.2;

uniform float exposure : hint_range(0.1, 10) = 1.0;

uniform bool rt_shadows = false;

uniform uint ground_material = 7;

varying vec3 local_pos;

struct Material {
	vec3 diffuse_color;
	vec3 specular_color;
	float roughness;
	float opacity;
};

struct RayResult {
	Material material;
	//vec3 color;
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

/*
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
}*/

Material my_material(uint cell){
	switch (cell) {
		case 0u:
			return Material(vec3(0.0), vec3(0.0), 0.0, 0.0);
		case 1u:
			return Material(vec3(0.839, 0.537, 0.255), vec3(1.0), 0.2, 1.0);
		case 2u:
			return Material(vec3(0.271, 1, 0.392), vec3(1.0), 0.2, 1.0);
		case 3u:
			return Material(vec3(0.612, 0.424, 0.196), vec3(1.0), 0.2, 1.0);
		case 4u:
			return Material(vec3(0.2, 0.2, 0.2), vec3(1.0), 0.2, 1.0);
		case 5u:
			return Material(vec3(0.2, 0.2, 0.2), vec3(1.0), 0.2, 1.0);
		case 6u:
			return Material(vec3(0.2, 0.2, 0.2), vec3(1.0), 0.2, 1.0);
		case 7u:
			return Material(vec3(0.2, 0.6, 0.2), vec3(0.1), 0.2, 1.0);
	}
}

vec3 blinn_phong(vec3 normal, vec3 view_dir, Material material) {
	// Blinn-Phong Shading
	normal = normalize(normal);
	vec3 light_dir = normalize(sun_direction);
	view_dir = normalize(view_dir);


	float lambertian = max(dot(normal, light_dir), 0.0);
	float specular = 0.0;
	if (lambertian > 0.0) {
		vec3 half_dir = normalize(light_dir + view_dir);
		specular = pow(max(dot(normal, half_dir), 0.0), shininess);
	}

	vec3 specular_color = vec3(0.0);
	if (specular > 0.0) {
		specular_color = material.specular_color * specular * sun_color * sun_power;
	}

	vec3 diffuse_color = material.diffuse_color * lambertian * sun_color * sun_power;

	vec3 ambient_color = material.diffuse_color * sun_color * ambient_power;

	vec3 lightColor = (ambient_color + (diffuse_color) + (specular_color)/exposure);
	//lightColor = pow(lightColor, vec3(1.0 / screenGamma));

	return lightColor;
}

RayResult dda_ray_march(vec3 origin, vec3 dir) {
	RayResult res;
	res.material = Material(vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 0.0), 0.0, 0.0);
	//res.color = vec3(0.0);
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
			// set ground if exited at bottom
			if (res.stepped_axis == 1 && sgn_dir.y < 0.0) {
				res.cell = ground_material;
				res.material = my_material(ground_material);
				res.alpha = 1.0;
				res.position = curr_pos + dir * t_current;
				res.normal = vec3(0.0, 1.0, 0.0);
				res.depth = t_current;
			}
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
				res.material = my_material(res.cell);
				//res.color = mix(res.color, my_color(res.cell), 0.01 * density);
				//res.depth += t[res.stepped_axis]; // OLD INCORRECT logic
				if (res.passed_through == 0.0) {
					res.depth = t_current; // Set depth to the first hit distance
					res.position = curr_pos + dir * t_current; // Exact world position (in voxel space)

					// Calculate normal
					res.normal = vec3(0.0);
					res.normal[res.stepped_axis] = -sgn_dir[res.stepped_axis];


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
			vec3 bias = sgn_dir * 1e-4;

			// Floor the biased position.
			// Because we pushed it forward, floor() is forced to snap to the next index.
			ivec3 next_coord = ivec3(floor(exit_pos + bias));

			coord = next_coord;

			// coord[res.stepped_axis] += int(sgn_dir[res.stepped_axis]);

			t = (vec3(coord) + 0.5 * (1.0 + sgn_dir) - curr_pos) * inv_dir;

			// Update t_current to the brick boundary
			t_current = t_exit;
			continue;
		}

		// Find the closest exit point (min t)
		float t_exit = min(t.x, min(t.y, t.z));

		res.stepped_axis = (t.x <= t.y && t.x <= t.z) ? 0 : (t.y <= t.z ? 1 : 2);


		// Pure integer stepping to avoid precision issues
		coord[res.stepped_axis] += int(sgn_dir[res.stepped_axis]);

		// Recalculate t for the new coordinate (to maintain precision relative to origin)
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

	vec3 sun_dir = normalize(sun_direction);

	//vec3 lighting = blinn_phong(res.normal, -dir, res.material);

	//res.color *= lighting;
	vec3 my_color = vec3(0.0);

	if (rt_shadows) {
		// Add bias to avoid self-shadowing (acne)
		// Move along the light direction to ensure we clear the current voxel boundary
		vec3 shadow_origin = res.position + sun_dir * 0.001;

		RayResult res2sun = dda_ray_march(shadow_origin, sun_dir);

		// If the shadow ray hits something, darken the color (shadow)
		if (res2sun.alpha > 0.0) {
			// gamma correct
			my_color = res.material.diffuse_color * ambient_power * sun_color;
			//my_color = pow(my_color, vec3(1.0 / screenGamma));
		} else {
			my_color = blinn_phong(res.normal, -dir, res.material);
		}
	} else {
		my_color = blinn_phong(res.normal, -dir, res.material);
	}

	//my_color = pow(my_color, vec3(1.0 / screenGamma));
	//my_color = pow(my_color, vec3(screenGamma));

	float depth = res.depth / float(max(tex_size.x, max(tex_size.y, tex_size.z)));
	switch (render_setting) {
		case 0: // color
			ALBEDO = my_color;
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
		case 6:
			ivec3 tex_size = textureSize(simulation_data, 0);
			vec4 r = texelFetch(simulation_data, ivec3(int(sin(TIME) * 0.5 + 0.5) * tex_size.x), 0);
			ALBEDO = vec3(r.r * 255.0);
			break;
	}
}