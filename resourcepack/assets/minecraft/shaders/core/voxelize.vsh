/*
MIT License
Copyright (c) 2022 Bálint Csala
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
documentation files (the "Software"), to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, 
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of 
the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.
*/

#version 150

#moj_import <light.glsl>
#moj_import <voxelization.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;


out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out vec4 normal;
out float dataFace;
out vec4 glpos;
flat out ivec2 cell;

const vec2[] OFFSETS = vec2[](
    vec2(0, 0),
    vec2(1, 0),
    vec2(1, 1),
    vec2(0, 1)
);

void main() {
    
    vec4 pos = vec4(Position + ChunkOffset, 1.0);
    vec4 textureColor = texture(Sampler0, UV0);
    if (distance(textureColor.rgb, vec3(1, 0, 1)) < 0.01) {

        bool inside;
        cell = positionToCell(floor(Position + floor(ChunkOffset)), inside);
        if (!inside) {
            gl_Position = vec4(5, 5, 0, 1);
            return;
        }

        if (Normal.y > 0) {
            // Data face used for voxelization
            dataFace = 1.0;
            gl_Position = vec4(
                (vec2(cell) + OFFSETS[gl_VertexID % 4]) / GRID_SIZE * 2.0 - 1.0,
                -1,
                1
            );
            //gl_Position = ProjMat * ModelViewMat * (pos + vec4(0, 0.2, 0, 0));
            vertexColor = vec4(floor(Position.xz) / 16, 0, 1);
            texCoord0 = OFFSETS[gl_VertexID % 4];
        } else {
            // Data face used for chunk offset storage
            gl_Position = vec4(
                OFFSETS[gl_VertexID % 4] * vec2(3, 1) / GRID_SIZE * 2.0 - 1.0,
                -1,
                1
            );
            dataFace = 2.0;
        }
    } else {
        dataFace = 0.0;
        gl_Position = ProjMat * ModelViewMat * pos;

        vertexDistance = length((ModelViewMat * vec4(Position + ChunkOffset, 1.0)).xyz);
        vertexColor = Color * minecraft_sample_lightmap(Sampler2, UV2);
        texCoord0 = UV0;
        normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);
    }
    glpos = gl_Position;
}
