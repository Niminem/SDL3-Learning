#version 460

layout(location=0) in vec4 color;
layout(location=1) in vec2 uv;

layout(set=2, binding=0) uniform sampler2D tex_sampler; // set is according to spec for creating GPU shader (spirv).
                                                        // binding 0 because it's the only thing we've bound.

layout(location=0) out vec4 frag_color;

void main() {
 frag_color = texture(tex_sampler, uv) * color;
}