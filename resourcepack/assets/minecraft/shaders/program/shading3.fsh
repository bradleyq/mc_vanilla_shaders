#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D ShadowSampler;
uniform vec2 OutSize;

in vec2 texCoord;
in vec2 oneTexel;

out vec4 fragColor;

#define NUMCONTROLS 27
#define THRESH 0.5

int inControl(vec2 screenCoord, float screenWidth) {
    if (screenCoord.y < 2.0) {
        float index = floor(screenWidth / 2.0) + THRESH / 2.0;
        index = (screenCoord.x - index) / 2.0;
        if (fract(index) < THRESH && index < NUMCONTROLS && index >= 0) {
            return int(index);
        }
    }
    return -1;
}

void main() {
    bool inctrl = inControl(texCoord * OutSize, OutSize.x) > -1;
    vec4 outColor = vec4(0.0);
    if (inctrl) {
        outColor = (texture(DiffuseSampler, texCoord - vec2(oneTexel.x, 0.0)) + texture(DiffuseSampler, texCoord + vec2(oneTexel.x, 0.0))) / 2.0;
        outColor *= (texture(ShadowSampler, texCoord - vec2(oneTexel.x, 0.0)) + texture(ShadowSampler, texCoord + vec2(oneTexel.x, 0.0))) / 2.0;
    }
    else {
        outColor = texture(DiffuseSampler, texCoord) * texture(ShadowSampler, texCoord);
    }
    fragColor = outColor;
}
