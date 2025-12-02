#[compute]
#version 450

// 8x8x8 threads per group
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Output Texture (Write Only) - RGBA32F format
layout(set = 0, binding = 0, rgba32f) uniform restrict writeonly image3D output_grid;

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
	
	// Generate color based on position
	vec3 color = vec3(
		0.5 + 0.5 * sin(pos.x * 10.0 + float(pc.seed) * 0.01),
		0.5 + 0.5 * sin(pos.y * 10.0 + float(pc.seed) * 0.01),
		0.5 + 0.5 * sin(pos.z * 10.0 + float(pc.seed) * 0.01)
	);
	
	// Alpha channel = occupancy
	float occupancy = is_filled ? 1.0 : 0.0;
	
	// Write color + occupancy
	imageStore(output_grid, coord, vec4(color * occupancy, occupancy));
}