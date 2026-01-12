#[compute]
#version 450
layout(local_size_x=4, local_size_y=4, local_size_z=4) in;

layout(set=0, binding=0, std430) restrict buffer State {
    uint data[];
} state;

layout(set=0, binding=1, r8ui) uniform restrict uimage3D out_types;

layout(push_constant) uniform Params {
    ivec3 size;
    int typecount;
} pc;

int idx4D(int t, ivec3 p) {
    return p.x
         + pc.size.x * p.y
         + pc.size.x * pc.size.y * p.z
         + pc.size.x * pc.size.y * pc.size.z * t;
}

void main() {
    ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
    if (any(greaterThanEqual(id, pc.size))) return;

    uint best_val = 0u;
    uint best_type = 0u;

    for (uint t = 0u; t < uint(pc.typecount); t++) {
        uint v = state.data[idx4D(int(t), id)];
        if (v > best_val) {
            best_val = v;
            best_type = t;
        }
    }

    imageStore(out_types, id, uvec4(best_type, 0, 0, 0));
}
