#[compute]
#version 450

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

// 4D (cell_type * 3D state array) arrays for read and write buffers
layout(set = 0, binding = 0, std430) restrict buffer ReadArray { float data[]; } read;
layout(set = 0, binding = 1, std430) restrict buffer WriteArray { float data[]; } write;
// 5D (cell_type * cell_type * 3D kernel) kernel array
layout(set = 0, binding = 2, std430) restrict buffer KernelArray { float data[]; } kernel;

layout(push_constant) uniform PushConstants {
	ivec3 size; // size.x, size.y, size.z: dimensions of the 3D grid; size.w: number of cell types
	ivec3 kernel_size; // kernel_size.x, kernel_size.y, kernel_size.z: dimensions of the 3D kernel; kernel_size.w: unused
	float mu; // desired average state
	float sigma; // standard deviation for growth function
	float dt; // time step
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
	ivec4 size = ivec4(pc.size, pc.typecount);
	ivec3 half_k = pc.kernel_size / 2;
	float dsigma = 2.0 * pc.sigma * pc.sigma;
	for (int write_type = 0; write_type < pc.typecount; write_type++) {
		for (int read_type = 0; read_type < pc.typecount; read_type++) {
			ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
			int out_i = idx4D(write_type, id.x, id.y, id.z, size);
			if (id.x >= size.x || id.y >= size.y || id.z >= size.z) return;

			float sum = 0.0;
			for (int kz = -half_k.z; kz <= half_k.z; kz++) {
				for (int ky = -half_k.y; ky <= half_k.y; ky++) {
					for (int kx = -half_k.x; kx <= half_k.x; kx++) {
						ivec3 nb = id + ivec3(kx, ky, kz);
						if (nb.x < 0 || nb.y < 0 || nb.z < 0 || nb.x >= size.x || nb.y >= size.y || nb.z >= size.z) {
							continue;
						}

					int ni = idx4D(read_type, nb.x, nb.y, nb.z, size);
						int ki = idx5D(write_type, read_type, kx + half_k.x, ky + half_k.y, kz + half_k.z, size);
						sum += kernel.data[ki] * read.data[ni];
					}
				}
			}

			float growth = exp(-pow(sum - pc.mu, 2.0) / dsigma) * 2.0 - 1.0;
			float next_state = clamp(read.data[idx4D(read_type, id.x, id.y, id.z, size)] + pc.dt * growth, 0.0, 1.0);
			write.data[out_i] = next_state;
		}
	}
}