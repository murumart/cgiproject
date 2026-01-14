#[compute]
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=8) in;

layout(set=0, binding=0, std430) buffer readonly State { uint data[]; } state;

layout(set=0, binding=1, r8) uniform writeonly image3D out_types;

layout(push_constant) uniform Params {
    ivec3 size;
    int typecount;
} pc;


int idx4D(int t, ivec3 p, ivec3 size) {
    return p.x
         + size.x * p.y
         + size.y * p.z
         + size.z * t;
}

void main() {
    int stride_x = pc.size.x;
    int stride_y = pc.size.x * pc.size.y;
    int stride_z = pc.size.x * pc.size.y * pc.size.z;
    ivec3 stride = ivec3(stride_x, stride_y, stride_z);
    ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
    if (any(greaterThanEqual(id, pc.size))) return;

    uint best_val = 0;
    int best_type = 0;

    for (int t = 0; t < pc.typecount; t++) {
        uint v = state.data[idx4D(t, id, stride)];
        if (v > best_val) {
            best_val = v;
            best_type = t;
        }
    }

    imageStore(out_types, id, vec4(float(best_type)/255.0, 0, 0, 0));
    // imageStore(out_types, id, vec4(2/255.0, 0, 0, 0));
}
