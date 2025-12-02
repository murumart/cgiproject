#[compute]
#version 450

// Build brick occupancy map from voxel data
// Optimized using group shared memory
// Each workgroup handles ONE brick (8x8x8 voxels)
// Each thread handles ONE voxel

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Input: Full voxel grid (e.g., 512^3)
layout(set = 0, binding = 0, r8) uniform restrict readonly image3D voxel_data;

// Output: Brick occupancy map (e.g., 64^3 for 512^3 voxels with 8^3 bricks)
layout(set = 0, binding = 1, r8) uniform restrict writeonly image3D brick_map;

// Brick size (8x8x8 voxels per brick)
const int BRICK_SIZE = 8;

// Shared memory to store if the brick is occupied
// Initialize to 0 (false)
shared uint brick_occupied_shared;

void main()
{
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
	
	// Calculate the voxel coordinate for this thread
	// Global ID = Brick Start + Local ID
	ivec3 voxel_pos = ivec3(gl_GlobalInvocationID.xyz);
	
	// Sample the voxel
	// Note: We don't need bounds check for voxel_pos because the dispatch size matches the grid size
	// (assuming grid size is a multiple of 8, which it is: 512)
	float voxel_value = imageLoad(voxel_data, voxel_pos).r;
	
	// If this voxel is occupied, mark the shared flag
	if (voxel_value > 0.5) {
		// Atomic OR to set the flag safely
		atomicOr(brick_occupied_shared, 1);
	}
	
	// Wait for all threads in the workgroup to finish checking their voxels
	barrier();
	
	// Thread 0 writes the result for the entire brick
	if (gl_LocalInvocationIndex == 0) {
		float occupancy = (brick_occupied_shared > 0) ? 1.0 : 0.0;
		imageStore(brick_map, brick_id, vec4(occupancy, 0.0, 0.0, 1.0));
	}
}
