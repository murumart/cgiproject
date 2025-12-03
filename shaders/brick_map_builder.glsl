#[compute]
#version 450

// Build brick occupancy map from voxel data
// Optimized using group shared memory
// Each workgroup handles ONE brick
// Each thread handles multiple voxels if brick size is large

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Input: Full voxel grid (e.g., 512^3) - R8 UNORM format (cell type)
layout(set = 0, binding = 0, r8) uniform restrict readonly image3D voxel_data;

// Output: Brick occupancy map (e.g., 64^3 for 512^3 voxels with 8^3 bricks)
layout(set = 0, binding = 1, r8) uniform restrict writeonly image3D brick_map;

// Push constant for brick size
layout(push_constant) uniform PushConstants {
	uint brick_size;
} pc;

// Shared memory to store if the brick is occupied
// Initialize to 0 (false)
shared uint brick_occupied_shared;

void main()
{
	uint BRICK_SIZE = pc.brick_size;

	// Initialize shared memory
	if (gl_LocalInvocationIndex == 0) {
		brick_occupied_shared = 0;
	}
	
	// Wait for initialization
	barrier();
	
	// Calculate global brick ID (Workgroup ID)
	ivec3 brick_id = ivec3(gl_WorkGroupID.xyz);
	ivec3 brick_map_size = imageSize(brick_map);
	
	// Safety: Stop if we are outside the brick map bounds
	if (any(greaterThanEqual(brick_id, brick_map_size))) return;
	
	// Calculate the starting voxel coordinate for this brick
	ivec3 brick_start = brick_id * int(BRICK_SIZE);
	
	// Total voxels in a brick
	uint total_voxels = BRICK_SIZE * BRICK_SIZE * BRICK_SIZE;
	uint group_size = gl_WorkGroupSize.x * gl_WorkGroupSize.y * gl_WorkGroupSize.z; // 512
	
	// Stride loop: Each thread checks multiple voxels to cover the whole brick
	for (uint i = gl_LocalInvocationIndex; i < total_voxels; i += group_size) {
		// Convert linear index i to local xyz within the brick
		int z = int(i) / (int(BRICK_SIZE) * int(BRICK_SIZE));
		int y = (int(i) % (int(BRICK_SIZE) * int(BRICK_SIZE))) / int(BRICK_SIZE);
		int x = int(i) % int(BRICK_SIZE);
		
		ivec3 voxel_pos = brick_start + ivec3(x, y, z);
		
		vec4 voxel = imageLoad(voxel_data, voxel_pos);
		
		// Check occupancy (cell type > 0)
		uint cell_type = uint(voxel.r * 255.0 + 0.5);
		bool is_occupied = cell_type > 0u;
		
		// If this voxel is occupied, mark the shared flag
		if (is_occupied) {
			atomicOr(brick_occupied_shared, 1);
		}
	}
	
	// Wait for all threads in the workgroup to finish checking their voxels
	barrier();
	
	// Thread 0 writes the result for the entire brick
	if (gl_LocalInvocationIndex == 0) {
		float occupancy = (brick_occupied_shared > 0) ? 1.0 : 0.0;
		imageStore(brick_map, brick_id, vec4(occupancy, 0.0, 0.0, 1.0));
	}
}
