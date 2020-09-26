#version 120

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D TranslucentRSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D ItemEntitySampler;
uniform sampler2D ItemEntityDepthSampler;
uniform sampler2D ParticlesSampler;
uniform sampler2D ParticlesDepthSampler;
uniform sampler2D WeatherSampler;
uniform sampler2D WeatherDepthSampler;
uniform sampler2D CloudsSampler;
uniform sampler2D CloudsDepthSampler;

varying vec2 texCoord;

struct Layer {
    vec4 color;
    float depth;
    float op;
};

#define NUM_LAYERS 6

Layer layers[NUM_LAYERS];
int layerIndices[NUM_LAYERS];

void init_arrays() {
    layers[0] = Layer(vec4(texture2D(DiffuseSampler, texCoord).rgb, 1.0), texture2D(DiffuseDepthSampler, texCoord).r, 1.0);
    layers[1] = Layer(texture2D(TranslucentSampler, texCoord), texture2D(TranslucentDepthSampler, texCoord).r, 0.5);
    layers[2] = Layer(texture2D(ItemEntitySampler, texCoord), texture2D(ItemEntityDepthSampler, texCoord).r, 1.0);
    layers[3] = Layer(texture2D(ParticlesSampler, texCoord), texture2D(ParticlesDepthSampler, texCoord).r, 1.0);
    layers[4] = Layer(texture2D(WeatherSampler, texCoord), texture2D(WeatherDepthSampler, texCoord).r, 0.0);
    layers[5] = Layer(texture2D(CloudsSampler, texCoord), texture2D(CloudsDepthSampler, texCoord).r, 1.0);

    for (int ii = 0; ii < NUM_LAYERS; ++ii) {
        layerIndices[ii] = ii;
    }

    for (int ii = 0; ii < NUM_LAYERS; ++ii) {
        for (int jj = 0; jj < NUM_LAYERS - ii - 1; ++jj) {
            if (layers[layerIndices[jj]].depth < layers[layerIndices[jj + 1]].depth) {
                int temp = layerIndices[jj];
                layerIndices[jj] = layerIndices[jj + 1];
                layerIndices[jj + 1] = temp;
            }
        }
    }
}

void main() {
    init_arrays();

    vec3 OutTexel = vec3(0.0);
    vec4 ColorTmp = vec4(0.0);
    for (int ii = 0; ii < NUM_LAYERS; ++ii) {
        ColorTmp = layers[layerIndices[ii]].color;
        float op = layers[layerIndices[ii]].op;
        if (op < 0.1) {
            OutTexel = 0.5 * mix(OutTexel, ColorTmp.rgb, ColorTmp.a) +  0.5 * OutTexel * mix(vec3(1.0), ColorTmp.rgb / clamp(max(ColorTmp.r, max(ColorTmp.g, ColorTmp.b)), 0.1, 1.0), clamp(ColorTmp.a, 0.0, 1.0));
        } else if (op < 0.6 && ColorTmp.a > 0.0) {
            OutTexel = 0.75 * mix(OutTexel, ColorTmp.rgb, ColorTmp.a) +  0.25 * OutTexel * mix(vec3(1.0), ColorTmp.rgb / clamp(max(ColorTmp.r, max(ColorTmp.g, ColorTmp.b)), 0.1, 1.0), clamp(ColorTmp.a, 0.0, 1.0));
        } 
        else {
            OutTexel = mix(OutTexel, ColorTmp.rgb, ColorTmp.a);
        }
    }

    gl_FragColor = vec4(OutTexel, 1.0);
}
