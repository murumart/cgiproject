#[compute]
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=8) in;

layout(set=0, binding=0, std430) buffer State { uint data[]; } state;

layout(set=0, binding=1, r8ui) uniform restrict writeonly uimage3D out_types;

layout(push_constant) uniform Params {
    int size;
    int typecount;
} pc;

int idx4D(int t, ivec3 p) {
    return p.x
         + pc.size * p.y
         + pc.size * pc.size * p.z
         + pc.size * pc.size * pc.size * t;
}

void main() {
    ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
    // if (any(greaterThanEqual(id, ivec3(pc.size)))) {
    //     return;
    // }

    // uint best_val = 0u;
    // uint best_type = 0u;

    // for (uint t = 0u; t < uint(pc.typecount); t++) {
    //     uint v = state.data[idx4D(int(t), id)];
    //     if (v > best_val) {
    //         best_val = v;
    //         best_type = t;
    //     }
    // }

    imageStore(out_types, id, uvec4(3, 0, 0, 0));
}
