#version 110

uniform sampler2D DiffuseSampler;
uniform sampler2D ExposureSampler;

varying vec2 texCoord;
varying vec2 oneTexel;
varying float aspectRatio;

float luminance(vec3 rgb) {
    return max(max(rgb.r, rgb.g), rgb.b);
}

void main() {
    vec3 color = texture2D(DiffuseSampler, texCoord).rgb;
    float elast = texture2D(ExposureSampler, texCoord).r;
    float enew = luminance(color);

    gl_FragColor = vec4(vec3(mix(elast, enew, 0.01)), 1.0);
}
