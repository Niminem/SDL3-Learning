#version 460

layout(location=0) in vec4 color;
layout(location=1) in vec2 uv;

// we want to access the sampler here, we'll use
// the uniform binding similar to the Uniform Buffer
// access in the vertex shader

layout(set=2, binding=0) uniform sampler2D tex_sampler; // set is according to spec for creating GPU shader (spirv)
                                                        // binding 0 because it's the only thing we've bound

layout(location=0) out vec4 frag_color;

void main() {
 frag_color = texture(tex_sampler, uv) * color; // multiplying it by the color so we can 'tint' it
                                                // texture() is how we use sampler in glsl
}