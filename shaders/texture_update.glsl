#[compute]
#version 450
layout(local_size_x=1, local_size_y=1, local_size_z=1) in;

layout(set=0, binding=0, r8) uniform writeonly image3D texture;

layout(push_constant) uniform Params {
    int value;
    int x;
    int y;
    int z;
} pc;

void main() {
    imageStore(texture, ivec3(pc.x, pc.y, pc.z), vec4(float(pc.value)/255.0, 0, 0, 0));
}
