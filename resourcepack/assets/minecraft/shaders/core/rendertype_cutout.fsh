#version 330
#define FSH

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;

in vec4 vertexColor;
in vec4 baseColor;
in vec2 texCoord0;
in vec2 texCoord2;
in vec3 normal;
in vec4 glpos;

out vec4 fragColor;

int xorshift(int value) {
    // Xorshift*32
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value;
}

float PRNG(int seed) {
    seed = xorshift(seed);
    return abs(fract(float(seed) / 3141.592653));
}

void main() {
    discardControlGLPos(gl_FragCoord.xy, glpos);
    vec4 outColor = textureLod(Sampler0, texCoord0, -4);

    if (outColor.a < ALPHACUTOFF) {
        discard;
    }

    vec4 baseColorDeband = baseColor;
    baseColorDeband.rgb += 5.0 * vec3(PRNG(int(gl_FragCoord.x * 1.123) + int(gl_FragCoord.y * 1.661) * int(1337))) / 255.0;
    vec4 vertexColorDeband = vertexColor;
    vertexColorDeband.rgb += 2.0 * vec3(PRNG(int(gl_FragCoord.x * 1.77) * int(1337) + int(gl_FragCoord.y * 1.123))) / 255.0;
    
    outColor.rgb *= (baseColorDeband * ColorModulator).rgb;
    outColor = getOutColor(outColor, vertexColorDeband, texCoord2, gl_FragCoord.xy, getDirB(normal));
    fragColor = outColor;
}
