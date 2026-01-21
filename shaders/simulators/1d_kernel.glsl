#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0, std430) buffer ReadArray {
    readonly uint data[];
} read;

layout(set = 0, binding = 1, std430) buffer WriteArray {
    writeonly uint data[];
} write;

layout(set = 0, binding = 2, std430) buffer Kernel {
    readonly float data[];
} kernel;

layout(push_constant) uniform PushConstants {
    int stride_X;
    int stride_Y;
    int stride_Z;
    int typecount;
    ivec3 grid_size;
    ivec3 kernel_size; // only kernel_size[AXIS] is used
} pc;

layout(constant_id = 0) const int AXIS = 0;

void main() {
    int typecount = pc.typecount;
    ivec3 id;
    id.x = int(gl_GlobalInvocationID.x);
    id.y = int(gl_GlobalInvocationID.y);
    id.z = int(gl_GlobalInvocationID.z / typecount);

    if (any(greaterThanEqual(id, pc.grid_size))) {
        return;
    }

    int write_type = int(gl_GlobalInvocationID.z % typecount);
    int kernel_grid_volume = pc.kernel_size[AXIS];
    int write_type_kernel_index = kernel_grid_volume * typecount * write_type;
    int kernel_radius = pc.kernel_size[AXIS] / 2;
    int base_index = id.x + id.y * pc.stride_X + id.z * pc.stride_Y;

    float sum = 0.0;

    for (int read_type = 0; read_type < pc.typecount; read_type++) {

        int kernel_base = write_type_kernel_index + read_type * kernel_grid_volume;

        for (int k = -kernel_radius; k <= kernel_radius; k++) {
            float w = kernel.data[kernel_base + k];

            ivec3 nb = id;
            if (AXIS == 0) nb.x += k;
            if (AXIS == 1) nb.y += k;
            if (AXIS == 2) nb.z += k;

            if (any(lessThan(nb, ivec3(0))) ||
                any(greaterThanEqual(nb, pc.grid_size)))
                continue;

            int ni = nb.x + nb.y * pc.stride_X + nb.z * pc.stride_Y
                    + read_type * pc.stride_Z;


            sum += w * float(read.data[ni]);
        }
    }

    write.data[base_index + write_type * pc.stride_Z] =
        uint(clamp(sum, 0.0, 255.0));
}
