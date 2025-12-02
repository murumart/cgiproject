#[compute]
#version 450

// 8x8x8 threads per group
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Output Texture (Write Only) - R8 format (red channel, 8-bit)
layout(set = 0, binding = 0, r32f) uniform restrict writeonly image3D output_grid;

void main()
{
	ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
	ivec3 size = imageSize(output_grid);

	// Safety: Stop if we are outside the texture bounds
	if (any(greaterThan(id, size))) return;

	// --- DUMMY GENERATION LOGIC ---

	// 1. Calculate the base voxel coordinate for this thread
	// Each thread writes one uint, which represents 32 voxels along X
	int base_x = id.x * 32;
	int y = id.y;
	int z = id.z;
	
	uint packed_data = 0;
	
	// Loop 32 times to generate bits for this integer
	for (int i = 0; i < 32; i++) {
		int current_x = base_x + i;
		
		// Normalized position for generation logic
		// Note: We use the full grid size for normalization
		vec3 pos = vec3(float(current_x), float(y), float(z)) / vec3(size.x * 32.0, size.y, size.z);
		vec3 center = pos - 0.5;
		
		// Generate shape (Sphere + Noise)
		float dist = length(center);
		float radius = 0.4;
		float noise = sin(pos.x * 20.0) * sin(pos.y * 20.0) * sin(pos.z * 20.0);
		
		bool is_filled = (dist < radius && noise > -0.5);
		
		if (is_filled) {
			packed_data |= (1u << i);
		}
	}

	// Write the packed uint to the Red channel as a float
	imageStore(output_grid, id, vec4(uintBitsToFloat(packed_data), 0.0, 0.0, 0.0));
}