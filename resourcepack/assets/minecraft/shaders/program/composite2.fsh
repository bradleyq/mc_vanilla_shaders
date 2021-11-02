#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D TranslucentSpecSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D ParticlesSampler;
uniform sampler2D ParticlesDepthSampler;
uniform sampler2D PartialCompositeSampler;
uniform sampler2D ItemEntityDepthSampler;
uniform sampler2D WeatherDepthSampler;
uniform sampler2D CloudsDepthSampler;

in vec2 texCoord;

out vec4 fragColor;

struct Layer {
    vec4 color;
    vec4 spec;
    float depth;
    float op;
};

#define NUM_LAYERS 3

Layer layers[NUM_LAYERS];
int layerIndices[NUM_LAYERS];

void init_arrays() {
    layers[0] = Layer(texture(TranslucentSampler, texCoord), texture(TranslucentSpecSampler, texCoord), texture(TranslucentDepthSampler, texCoord).r, 0.5);
    layers[1] = Layer(texture(ParticlesSampler, texCoord), vec4(0.0), texture(ParticlesDepthSampler, texCoord).r, 1.0);
    layers[2] = Layer(texture(PartialCompositeSampler, texCoord), vec4(0.0), min(min(texture(ItemEntityDepthSampler, texCoord).r, texture(WeatherDepthSampler, texCoord).r), texture(CloudsDepthSampler, texCoord).r), 0.0);

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

    float diffuseDepth = texture(DiffuseDepthSampler, texCoord).r;
    vec3 OutTexel = texture(DiffuseSampler, texCoord).rgb;
    vec4 ColorTmp = vec4(0.0);
    vec4 SpecTmp  = vec4(0.0);
    for (int ii = 0; ii < NUM_LAYERS; ++ii) {
        Layer currL = layers[layerIndices[ii]];
        if (currL.depth < diffuseDepth) {
            ColorTmp = currL.color;
            SpecTmp  = currL.spec;
            float op = currL.op;
            if (op < 0.1) {
                OutTexel = 0.75 * mix(OutTexel, ColorTmp.rgb, ColorTmp.a) +  0.25 * OutTexel * mix(vec3(1.0), ColorTmp.rgb / clamp(max(ColorTmp.r, max(ColorTmp.g, ColorTmp.b)), 0.3, 1.0), clamp(ColorTmp.a, 0.0, 1.0));
            } else if (op < 0.6 && ColorTmp.a > 0.0) {
                OutTexel = 0.5 * mix(OutTexel, ColorTmp.rgb, ColorTmp.a) +  0.5 * OutTexel * mix(vec3(1.0), ColorTmp.rgb / clamp(max(ColorTmp.r, max(ColorTmp.g, ColorTmp.b)), 0.1, 1.0), clamp(ColorTmp.a, 0.0, 1.0));
                OutTexel = mix(OutTexel, SpecTmp.rgb, SpecTmp.a);
            } 
            else {
                OutTexel = mix(OutTexel, ColorTmp.rgb, ColorTmp.a);
            }
        }
    }

    fragColor = vec4(OutTexel, 1.0);
}
