#[compute]
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=8) in;

layout(set=0, binding=0, std430) buffer State { readonly uint data[]; } state;

layout(set=0, binding=1, r8) uniform writeonly image3D out_types;

layout(push_constant) uniform Params {
    ivec3 size;
    // int typecount;
} pc;


// int idx4D(int t, ivec3 p, ivec3 stride) {
//     return p.x
//          + stride.x * p.y
//          + stride.y * p.z
//          + stride.z * t;
// }

void main() {
    ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
    if (any(greaterThanEqual(id, pc.size))) return;
    // int stride_x = pc.size.x;
    // int stride_y = pc.size.x * pc.size.y;
    int stride_z = pc.size.x * pc.size.y * pc.size.z;
    // ivec3 stride = ivec3(stride_x, stride_y, stride_z);

    uint best_val = 0;
    int best_type = 0;

    int t = id.x +
        id.y * pc.size.x +
        id.z * pc.size.x * pc.size.y;

    for (int i = 0; i < 4; i++) {
        // int i = idx4D(t, id, stride);
        uint v = state.data[t];
        if (v > best_val) {
            best_val = v;
            best_type = i;
        }
        t += stride_z;
    }

    imageStore(out_types, id, vec4(float(best_type)/255.0, 0, 0, 0));
}
