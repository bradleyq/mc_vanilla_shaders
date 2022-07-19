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

#moj_import <fog.glsl>
#moj_import <utils.glsl>
#moj_import <voxelization.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform float GameTime;
uniform vec3 ChunkOffset;

in float vertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in vec4 normal;
in float dataFace;
in vec4 glpos;
flat in ivec2 cell;

out vec4 fragColor;

void main() {
    ivec2 screenSize = getScreenSize(gl_FragCoord.xy, glpos);
    discardControl(gl_FragCoord.xy, float(screenSize.x));
    if (dataFace < 0.5) {
        vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
        if (color.a < 0.5) {
            discard;
        }
        fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
    } else if (dataFace < 1.5) {
        fragColor = vertexColor;
        ivec2 pixel = cellToPixel(cell, screenSize);
        if (ivec2(gl_FragCoord.xy) != pixel)
            discard;
    } else {
        if (gl_FragCoord.y > 1.0 || gl_FragCoord.x > 3.0) {
            discard;
        }
        vec3 storedChunkOffset = mod(ChunkOffset, vec3(16)) / 16.0;
        fragColor = vec4(encodeFloat(storedChunkOffset[int(gl_FragCoord.x)]), 1);
    }
}
