#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0, std430) buffer ReadArray { readonly uint data[]; } read;

layout(set = 0, binding = 1, std430) buffer WriteArray { writeonly uint data[]; } write;

layout(set = 0, binding = 2, std430) buffer KernelArray { readonly float data[]; } kernel;

layout(push_constant) uniform PushConstants {
	ivec3 grid_size; // size.x, size.y, size.z: dimensions of the 3D grid;
	ivec4 kernel_size;
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
    int typecount = pc.kernel_size.w;
    ivec3 id;
    id.x = int(gl_GlobalInvocationID.x);
    id.y = int(gl_GlobalInvocationID.y);

    uint gid_z = gl_GlobalInvocationID.z;
    int write_type = int(gid_z % typecount);
    id.z = int(gid_z / typecount);

    if (any(greaterThanEqual(id, pc.grid_size))) {
        return;
    }

    ivec4 size = ivec4(pc.grid_size, typecount);
    ivec3 half_k = pc.kernel_size.xyz / 2;
    // float dsigma = 2.0 * pc.sigma * pc.sigma;

    int out_i = idx4D(write_type, id.x, id.y, id.z, size);

    float sum = 0.0;

    for (int read_type = 0; read_type < typecount; read_type++) {
        for (int kz = -half_k.z; kz <= half_k.z; kz++) {
            for (int ky = -half_k.y; ky <= half_k.y; ky++) {
                for (int kx = -half_k.x; kx <= half_k.x; kx++) {
                    ivec3 nb = id + ivec3(kx, ky, kz);
                    if (any(lessThan(nb, ivec3(0))) || any(greaterThanEqual(nb, pc.grid_size)))
                        continue;

                    int ni = idx4D(read_type, nb.x, nb.y, nb.z, size);
                    int ki = idx5D(
                        write_type,
                        read_type,
                        kx + half_k.x,
                        ky + half_k.y,
                        kz + half_k.z,
                        pc.kernel_size
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


