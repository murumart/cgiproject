#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0, std430) buffer ReadArray { readonly uint data[]; } read;

layout(set = 0, binding = 1, std430) buffer WriteArray { writeonly uint data[]; } write;

layout(set = 0, binding = 2, std430) buffer KernelArray { readonly float data[]; } kernel;

layout(set = 0, binding = 3, std430) buffer OffsetArray { readonly int data[]; } offset;

layout(push_constant) uniform PushConstants {
	ivec3 grid_size; // size.x, size.y, size.z: dimensions of the 3D grid;
	ivec4 kernel_size;
} pc;


void main() {
    int typecount = pc.kernel_size.w;
    uint gid_z = gl_GlobalInvocationID.z;
    int write_type = int(gid_z % typecount);
    // if (write_type == 0) return;    // Don't calculate air

    ivec3 id;
    id.x = int(gl_GlobalInvocationID.x);
    id.y = int(gl_GlobalInvocationID.y);
    id.z = int(gid_z / typecount);

    // if (any(greaterThanEqual(id, pc.grid_size))) {
    //     return;
    // }

    int kernel_grid_volume = pc.kernel_size.x * pc.kernel_size.y * pc.kernel_size.z + 1;
    ivec3 half_k = pc.kernel_size.xyz / 2;
    int write_type_kernel_index = kernel_grid_volume * pc.kernel_size.w * write_type;
    float sum = 0.0;
    // int ni = 0;
    int stride_Y = pc.grid_size.x * pc.grid_size.y;


    // if not close to edge no out of bounds check in loop
    if(any(lessThan(id, half_k)) || any(greaterThanEqual(id + half_k, pc.grid_size))) {
        // ivec3 tmpId = id - half_k;
        for (int read_type = 0; read_type < typecount; read_type++) {
            int kernel_index = write_type_kernel_index + read_type * kernel_grid_volume;
            int remaining_kernel_values = int(kernel.data[kernel_index++]);
            if (remaining_kernel_values == 0) {
                continue;
            }
            int ni = stride_Y * read_type;
            // Loop through all kernel indexes from -halh_k to half_k
            for (int kz = -half_k.z; kz <= half_k.z && remaining_kernel_values > 0; kz++) {
                for (int ky = -half_k.y; ky <= half_k.y && remaining_kernel_values > 0; ky++) {
                    for (int kx = -half_k.x; kx <= half_k.x && remaining_kernel_values > 0; kx++) {
                        // Skip 0 values
                        float kernel_factor = kernel.data[kernel_index++];
                        if (kernel_factor == 0.0)
                            continue;
                        // Reduce amount of remaining values
                        remaining_kernel_values--;
                        // Out of bounds check
                        ivec3 nb = id + ivec3(kx, ky, kz);
                        if (any(lessThan(nb, ivec3(0))) || any(greaterThanEqual(nb, pc.grid_size)))
                            continue;

                        sum +=  kernel_factor * read.data[ni + offset.data[kernel_index-1]];
                    }
                }
            }
            // ni += pc.stride.z;
        }
    } else {
        int baseIndex = id.x + pc.grid_size.x * (id.y + pc.grid_size.y * id.z);
        for (int read_type = 0; read_type < typecount; read_type++) {
            int kernel_index = write_type_kernel_index + read_type * kernel_grid_volume;
            int remaining_kernel_values = int(kernel.data[kernel_index++]);
            if (remaining_kernel_values == 0) {
                continue;
            }
            int ni = baseIndex + stride_Y * read_type;
            for (int i = 1; i < kernel_grid_volume && remaining_kernel_values > 0; i++) {
                // Skip 0 values
                float kernel_factor = kernel.data[kernel_index++];
                if (kernel_factor == 0.0)
                    continue;
                // Reduce amount of remaining values
                remaining_kernel_values--;
                sum += kernel_factor * read.data[ni + offset.data[i]];
            }
        }
    }

    // int out_i = idx4D(write_type, id.x, id.y, id.z);
    write.data[id.x + pc.grid_size.x * id.y + stride_Y * (id.z + pc.grid_size.z  * write_type)] = int(clamp(sum, 0.0, 255.0));
}
