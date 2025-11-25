#[compute]
#version 450

// 8x8x8 threads per group
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Output Texture (Write Only) - R8 format (red channel, 8-bit)
layout(set = 0, binding = 0, r8) uniform restrict writeonly image3D output_grid;

void main() {
    ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
    ivec3 size = imageSize(output_grid);

    // Safety: Stop if we are outside the texture bounds
    if (any(greaterThan(id, size))) return;

    // --- DUMMY GENERATION LOGIC ---
    
    // 1. Calculate normalized position (0.0 to 1.0)
    vec3 pos = vec3(id) / vec3(size);
    
    // 2. Center the coordinates (-0.5 to 0.5)
    vec3 center = pos - 0.5;
    
    // 3. Generate a Sphere
    float dist = length(center);
    float radius = 0.4;
    
    // 4. Add some "noise" holes (simple sine wave interference)
    float noise = sin(pos.x * 20.0) * sin(pos.y * 20.0) * sin(pos.z * 20.0);
    
    // 5. Determine state (1.0 = Filled, 0.0 = Empty)
    // We combine the sphere shape with the noise pattern
    float state = (dist < radius && noise > -0.5) ? 1.0 : 0.0;

    // Write to the Red channel
    imageStore(output_grid, id, vec4(state, 0.0, 0.0, 1.0));
}