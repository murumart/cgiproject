#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// 4D (cell_type * 3D state array) arrays for read and write buffers
layout(set = 0, binding = 0, std430) restrict buffer ReadArray { float data[]; } read;
layout(set = 0, binding = 1, std430) restrict buffer WriteArray { float data[]; } write;
// 5D (cell_type * cell_type * 3D kernel) kernel array
layout(set = 0, binding = 2, std430) restrict buffer KernelArray { float data[]; } kernel;

layout(push_constant) uniform PushConstants {
	int grid_size; // size.x, size.y, size.z: dimensions of the 3D grid; size.w: number of cell types
	int kernel_size; // kernel_size.x, kernel_size.y, kernel_size.z: dimensions of the 3D kernel; kernel_size.w: unused
	int typecount;
} pc;


int idx4D(int type, int x, int y, int z, ivec4 size) {
	return x
	+ size.x * y
	+ size.x * size.y * z
	+ size.x * size.y * size.z * type;
}


int idx5D(int type1, int type2, int x, int y, int z, ivec4 size) {
	return x
	+ size.x * y
	+ size.x * size.y * z
	+ size.x * size.y * size.z * type1
	+ size.x * size.y * size.z * size.w * type2;
}

void main() {
    ivec3 id;
    id.x = int(gl_GlobalInvocationID.x);
    id.y = int(gl_GlobalInvocationID.y);

    uint gid_z = gl_GlobalInvocationID.z;
    int write_type = int(gid_z % pc.typecount);
    id.z = int(gid_z / pc.typecount);

    if (id.x >= pc.grid_size || id.y >= pc.grid_size || id.z >= pc.grid_size)
        return;

    ivec4 size = ivec4(pc.grid_size, pc.grid_size, pc.grid_size, pc.typecount);
    ivec3 half_k = ivec3(pc.kernel_size, pc.kernel_size, pc.kernel_size) / 2;
    // float dsigma = 2.0 * pc.sigma * pc.sigma;

    int out_i = idx4D(write_type, id.x, id.y, id.z, size);

    float sum = 0.0;

    for (int read_type = 0; read_type < pc.typecount; read_type++) {
        for (int kz = -half_k.z; kz <= half_k.z; kz++) {
            for (int ky = -half_k.y; ky <= half_k.y; ky++) {
                for (int kx = -half_k.x; kx <= half_k.x; kx++) {
                    ivec3 nb = id + ivec3(kx, ky, kz);
                    if (nb.x < 0 || nb.y < 0 || nb.z < 0 ||
                        nb.x >= pc.grid_size || nb.y >= pc.grid_size || nb.z >= pc.grid_size)
                        continue;

                    int ni = idx4D(read_type, nb.x, nb.y, nb.z, size);
                    int ki = idx5D(
                        write_type,
                        read_type,
                        kx + half_k.x,
                        ky + half_k.y,
                        kz + half_k.z,
                        size
                    );

                    sum += kernel.data[ki] * read.data[ni];
                }
            }
        }
    }

    // float growth = exp(-pow(sum - pc.mu, 2.0) / dsigma) * 2.0 - 1.0;
    // float cur = read.data[out_i];
    // write.data[out_i] = clamp(cur + pc.dt * growth, 0.0, 1.0);
    write.data[out_i] = int(clamp(sum, 0.0, 255.0));
}


