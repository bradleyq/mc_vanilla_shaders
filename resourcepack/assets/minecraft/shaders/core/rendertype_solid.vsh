#version 330
#define VSH

#moj_import <light.glsl>
#moj_import <utils.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;

out vec4 vertexColor;
out vec2 texCoord0;
out vec2 texCoord2;
out vec3 normal;
out vec4 glpos;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position + ChunkOffset, 1.0);
    
    // vec4 col = vec4(1.0);

    // if (!(Color.r == Color.g && Color.g == Color.b)) {
    //     col = vec4(normalize(Color.rgb) * 210.0 / 255.0, 1.0);
    // }
    vec4 col = Color;
    float up = 255.0;
    float down = 127.0;
    if (getDim(Sampler2) == DIM_NETHER) {
        up = 229.0;
        down = 229.0;
    }
    if (dot(Normal, vec3(0.0, -1.0, 0.0)) > 0.999) {
        col *= 255.0 / down;
    }
    else if (dot(Normal, vec3(0.0, 1.0, 0.0)) > 0.999) {
        col *= 255.0 / up;
    }
    else if (abs(dot(Normal, vec3(1.0, 0.0, 0.0))) > 0.999) {
        col *= 255.0 / 153.0;
    }
    else if (abs(dot(Normal, vec3(0.0, 0.0, 1.0))) > 0.999) {
        col *= 255.0 / 204.0;
    }
    else if (col.r == col.g && col.g == col.b){
        col = vec4(1.0);
    }
    col.rgb = min(col.rgb, 1.0);
    col.a = 1.0;
    
    vertexColor = minecraft_sample_lightmap(Sampler2, UV2) * col;
    texCoord0 = UV0;
    texCoord2 = UV2 / 255.0;
    texCoord2.x *= 1.0 - getSun(Sampler2);
    normal = Normal;
    glpos = gl_Position;
}
