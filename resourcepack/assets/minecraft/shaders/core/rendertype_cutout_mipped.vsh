#version 150

#moj_import <light.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out vec2 texCoord2;
out vec3 normal;
out vec4 glpos;
out float face;

void main() {
    face = float(int((gl_VertexID + 3) / 4));
    gl_Position = ProjMat * ModelViewMat * vec4(Position + ChunkOffset, 1.0);

    vertexDistance = length((ModelViewMat * vec4(Position + ChunkOffset, 1.0)).xyz);
    vec4 col = Color;
    if (Color.g > Color.b && Color.g > Color.r) {
        vec3 swamp = vec3(106.0 / 255.0, 112.0 / 255.0, 57.0 / 255.0); // special handling to darken swamp colors
        col = vec4(normalize(Color.rgb) * 210.0 / 255.0 * (1.0 - 0.9 * smoothstep(0.9, 1.0, swamp)), 1.0);
    } else if (Color.r == Color.g && Color.g == Color.b) {
        col = vec4(1.0);
    }
    vertexColor = col * minecraft_sample_lightmap(Sampler2, UV2);
    texCoord0 = UV0;
    texCoord2 = UV2 / 255.0;
    texCoord2.x *= 1.0 - getSun(Sampler2);
    normal = Normal;
    glpos = gl_Position;
}
