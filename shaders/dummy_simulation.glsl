#[compute]
#version 450

// 8x8x8 threads per group
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Output Texture (Write Only) - R8 UNORM format
layout(set = 0, binding = 0, r8) uniform restrict writeonly image3D output_grid;

layout(push_constant) uniform PushConstants {
	uint seed;
} pc;

void main()
{
	ivec3 coord = ivec3(gl_GlobalInvocationID.xyz);
	ivec3 size = imageSize(output_grid);

	// Safety: Stop if we are outside the texture bounds
	if (any(greaterThanEqual(coord, size))) return;

	// Normalized position for generation logic
	vec3 pos = (vec3(coord) + 0.5) / vec3(size);
	vec3 center = pos - 0.5;
	
	// Generate shape (Sphere + Noise)
	float dist = length(center);
	float radius = 0.4 * abs(sin(float(pc.seed) * 0.002));
	float noise = abs(sin(float(pc.seed) * 0.02)) * sin(sin(float(pc.seed) * 0.02) * pos.x * 20.0) * sin(sin(float(pc.seed) * 0.02) * pos.y * 20.0) * sin(sin(float(pc.seed) * 0.02) * pos.z * 20.0);
	
	bool is_filled = (dist < radius && noise > -0.5);
	
	// Alpha channel = occupancy
	//float occupancy = is_filled ? 1.0 : 0.0;

	// cell type
	// 0 = air
	// 1 = stone
	// 2 = grass
	// 3 = tree
	// 4 = snow
	// 5 = ice
	// 6 = lava
	// 7 = bedrock

	uint cell_type;
	if (is_filled)
	{
		cell_type = 1;
		if (sin(pos.x * 10.0 + pos.y * 10.0 + pos.z * 10.0) > 0.5)
		{
			cell_type = 2;
		}
	}
	else
	{
		cell_type = 0;
	}

	if (coord.x % 16 == 0 && coord.y % 16 == 0 && coord.z % 16 == 0 && dist < radius * 1.1)
	{
		cell_type = 3;
	}
	
	
	
	
	// Write occupancy
	// Write occupancy (normalized float)
	imageStore(output_grid, coord, vec4(float(cell_type) / 255.0, 0.0, 0.0, 0.0));
}