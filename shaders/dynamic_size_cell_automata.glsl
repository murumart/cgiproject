#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0, std430) buffer ReadArray { readonly uint data[]; } read;

layout(set = 0, binding = 1, std430) buffer WriteArray { writeonly uint data[]; } write;

layout(set = 0, binding = 2, std430) buffer KernelArray { readonly float data[]; } kernel;

layout(push_constant) uniform PushConstants {
	ivec3 grid_size; // size.x, size.y, size.z: dimensions of the 3D grid;
    ivec3 stride;
	ivec4 kernel_size;
} pc;


int idx4D(int type, int x, int y, int z) {
	return x
	+ pc.stride.x * y
	+ pc.stride.y * z
	+ pc.stride.z * type;
}


void main() {
    int typecount = pc.kernel_size.w;
    uint gid_z = gl_GlobalInvocationID.z;
    int write_type = int(gid_z % typecount);
    // if (write_type == 0) return;    // Don't calculate air

    ivec3 id;
    id.x = int(gl_GlobalInvocationID.x);
    id.y = int(gl_GlobalInvocationID.y);
    id.z = int(gid_z / typecount);

    if (any(greaterThanEqual(id, pc.grid_size))) {
        return;
    }

    // ivec3 size = pc.grid_size;
    ivec3 half_k = pc.kernel_size.xyz / 2;
    // float dsigma = 2.0 * pc.sigma * pc.sigma;

    int out_i = idx4D(write_type, id.x, id.y, id.z);

    float sum = 0.0;
    int ki = pc.kernel_size.x * pc.kernel_size.y * pc.kernel_size.z * pc.kernel_size.w * write_type;


    // if not close to edge no out of bounds check in loop
    if(any(lessThan(id - half_k, ivec3(0))) || any(greaterThanEqual(id + half_k, pc.grid_size))) {
        for (int read_type = 0; read_type < typecount; read_type++) {
            for (int kz = -half_k.z; kz <= half_k.z; kz++) {
                for (int ky = -half_k.y; ky <= half_k.y; ky++) {
                    for (int kx = -half_k.x; kx <= half_k.x; kx++) {
                        float kernel_factor = kernel.data[ki++];
                        if (kernel_factor == 0.0) { continue; }
                        ivec3 nb = id + ivec3(kx, ky, kz);
                        if (any(lessThan(nb, ivec3(0))) || any(greaterThanEqual(nb, pc.grid_size)))
                            continue;

                        int ni = idx4D(read_type, nb.x, nb.y, nb.z);

                        sum +=  kernel_factor * read.data[ni];
                    }
                }
            }
        }
    } else {
        int ni = id.x
            + pc.stride.x * id.y
            + pc.stride.y * id.z;
        for (int read_type = 0; read_type < typecount*pc.stride.z; read_type += pc.stride.z) {
            for (int kz = -half_k.z*pc.stride.y; kz <= half_k.z*pc.stride.y; kz += pc.stride.y) {
                for (int ky = -half_k.y*pc.stride.x; ky <= half_k.y*pc.stride.x; ky += pc.stride.x) {
                    // #pragma unroll
                    for (int kx = -half_k.x; kx <= half_k.x; kx++) {
                        float kernel_factor = kernel.data[ki++];
                        if (kernel_factor == 0.0) { continue; }
                        // ivec3 nb = id + ivec3(kx, ky, kz);

                        sum += kernel_factor * read.data[ni + read_type + kz + ky + kx];
                    }
                }
            }
        }
    }

    // float growth = exp(-pow(sum - pc.mu, 2.0) / dsigma) * 2.0 - 1.0;
    // float cur = read.data[out_i];
    // write.data[out_i] = clamp(cur + pc.dt * growth, 0.0, 1.0);
    write.data[out_i] = int(clamp(sum, 0.0, 255.0));
}

