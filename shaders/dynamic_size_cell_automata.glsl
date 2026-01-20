#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0, std430) buffer ReadArray { readonly uint data[]; } read;

layout(set = 0, binding = 1, std430) buffer WriteArray { writeonly uint data[]; } write;

layout(set = 0, binding = 2, std430) buffer KernelArray { readonly float data[]; } kernel;

layout(push_constant) uniform PushConstants {
    int stride_X;
    int stride_Y;
    int stride_Z;
    int typecount;
	ivec3 grid_size;
	ivec3 kernel_size;
} pc;

void main() {
    int typecount = pc.typecount;
    // uint gid_z = gl_GlobalInvocationID.z;

    ivec3 id;
    id.x = int(gl_GlobalInvocationID.x);
    id.y = int(gl_GlobalInvocationID.y);
    id.z = int(gl_GlobalInvocationID.z / typecount);

    // if (any(greaterThanEqual(id, pc.grid_size))) {
    //     return;
    // }

    int write_type = int(gl_GlobalInvocationID.z % typecount);
    // if (write_type == 0) return;    // Don't calculate air

    int kernel_grid_volume = pc.kernel_size.x * pc.kernel_size.y * pc.kernel_size.z + 1;
    ivec3 half_k = pc.kernel_size / 2;
    int write_type_kernel_index = kernel_grid_volume * typecount * write_type;
    float sum = 0.0;
    int out_index = id.x + id.y * pc.stride_X + id.z * pc.stride_Y;
    int ni = out_index - half_k.x;
    id.x -= half_k.x;
    ivec3 miinimum = ivec3(0);


    // if not close to edge no out of bounds check in loop (branch prediction seems better)
    // if(any(lessThan(id, half_k)) || any(greaterThanEqual(id + half_k, pc.grid_size))) {
    for (int read_type = 0; read_type < typecount; read_type++) {
        int kernel_index = write_type_kernel_index + read_type * kernel_grid_volume;
        int remaining_kernel_values = int(kernel.data[kernel_index++]);
        if (remaining_kernel_values == 0) {
            ni += pc.stride_Z;
            continue;
        }
        // Loop through all kernel indexes from -halh_k to half_k
        for (int kz = -half_k.z; kz <= half_k.z && remaining_kernel_values > 0; kz++) {
            for (int ky = -half_k.y; ky <= half_k.y && remaining_kernel_values > 0; ky++) {
                for (int kx = 0; kx < pc.kernel_size.x; kx++) {    // && remaining_kernel_values > 0 made slower
                    // Skip 0 values
                    float kernel_factor = kernel.data[kernel_index++];
                    if (kernel_factor == 0.0)
                        continue;
                    // Reduce amount of remaining values
                    remaining_kernel_values--;
                    // Out of bounds check
                    ivec3 nb = id + ivec3(kx, ky, kz);
                    if (any(lessThan(nb, miinimum)) || any(greaterThanEqual(nb, pc.grid_size)))
                        continue;

                    sum +=  kernel_factor * read.data[ni + kx + ky * pc.stride_X + kz * pc.stride_Y];
                }
            }
        }
        ni += pc.stride_Z;
    }

    // int out_i = idx4D(write_type, id.x, id.y, id.z);
    write.data[out_index + pc.stride_Z * write_type] = int(clamp(sum, 0.0, 255.0));
}

