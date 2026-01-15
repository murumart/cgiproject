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
shared ivec3 brick_map_size;

void main() {
	// Initialize shared memory
	if (gl_LocalInvocationIndex == 0) {
		brick_occupied_shared = 0;
		brick_map_size = imageSize(brick_map);
	}
	// Calculate global brick ID (Workgroup ID)
	ivec3 brick_id = ivec3(gl_WorkGroupID.xyz);
	// ivec3 brick_map_size = imageSize(brick_map);
	
	// Wait for initialization
	barrier();

	// Safety: Stop if we are outside the brick map bounds
	if (any(greaterThanEqual(brick_id, brick_map_size))) return;

	int BRICK_SIZE = int(pc.brick_size);
	int BRICK_SIZE2 = BRICK_SIZE * BRICK_SIZE;
	// Total voxels in a brick
	int total_voxels = BRICK_SIZE2 * BRICK_SIZE;
	
	// Calculate the starting voxel coordinate for this brick
	ivec3 brick_start = brick_id * BRICK_SIZE;
	
	int group_size = int(gl_WorkGroupSize.x * gl_WorkGroupSize.y * gl_WorkGroupSize.z); // 512
	
	// Stride loop: Each thread checks multiple voxels to cover the whole brick
	for (int i = int(gl_LocalInvocationIndex); i < total_voxels; i += group_size) {
		memoryBarrierShared();
		if (brick_occupied_shared != 0)
			break;
		// Convert linear index i to local xyz within the brick
		int z = i / BRICK_SIZE2;
		int y = (i % BRICK_SIZE2) / BRICK_SIZE;
		int x = i % BRICK_SIZE;
		
		ivec3 voxel_pos = brick_start + ivec3(x, y, z);
		
		bool occupied = imageLoad(voxel_data, voxel_pos).r != 0;
		
		// Check occupancy (cell type > 0)
		// uint cell_type = uint(voxel.r * 255.0 + 0.5);
		// bool is_occupied = cell > 0;
		
		// If this voxel is occupied, mark the shared flag
		if (occupied) {
			atomicOr(brick_occupied_shared, 1);
			// if (gl_LocalInvocationIndex != 0) return;
			break;
		}
	}
	
	// Wait for all threads in the workgroup to finish checking their voxels
	barrier();
	
	// Thread 0 writes the result for the entire brick
	if (gl_LocalInvocationIndex == 0) {
		// uint occupancy = (brick_occupied_shared > 0) ? 1 : 0;
		imageStore(brick_map, brick_id, vec4(brick_occupied_shared, 0, 0, 0));
	}
}
