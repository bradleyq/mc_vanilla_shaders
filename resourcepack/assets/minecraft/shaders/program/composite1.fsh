#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D ItemEntitySampler;
uniform sampler2D ItemEntityDepthSampler;
uniform sampler2D ParticlesSampler;
uniform sampler2D ParticlesDepthSampler;
uniform sampler2D WeatherSampler;
uniform sampler2D WeatherDepthSampler;
uniform sampler2D CloudsSampler;
uniform sampler2D CloudsDepthSampler;

in vec2 texCoord;

out vec4 fragColor;

struct Layer {
    vec4 color;
    float depth;
    float op;
};

#define CLOUD_MULT vec4(1.25, 1.25, 1.25, 0.75)
#define ALPHA_SCALE 0.2
#define NUM_LAYERS 5

Layer layers[NUM_LAYERS];
int layerIndices[NUM_LAYERS];

void init_arrays() {
    layers[0] = Layer(texture(DiffuseSampler, texCoord), texture(TranslucentDepthSampler, texCoord).r, 0.0);
    layers[1] = Layer(texture(ItemEntitySampler, texCoord), texture(ItemEntityDepthSampler, texCoord).r, 1.0);
    layers[2] = Layer(texture(ParticlesSampler, texCoord), texture(ParticlesDepthSampler, texCoord).r, 0.0);
    layers[3] = Layer(texture(WeatherSampler, texCoord), texture(WeatherDepthSampler, texCoord).r, 1.0);
    layers[4] = Layer(texture(CloudsSampler, texCoord) * CLOUD_MULT, texture(CloudsDepthSampler, texCoord).r, 1.0);

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
    vec4 outColor = vec4(0.0);
    vec4 ColorTmp = vec4(0.0);
    float op = 0.0;
    for (int ii = 0; ii < NUM_LAYERS; ++ii) {
        Layer currL = layers[layerIndices[ii]];
        if(currL.depth < diffuseDepth) {
            ColorTmp = currL.color;
            op = currL.op;
            if (op > 0.5) {
                if (ColorTmp.a > 0.0) {
                    outColor = vec4(mix(mix(ColorTmp.rgb, outColor.rgb, outColor.a), ColorTmp.rgb, ColorTmp.a), 1.0 - (1.0 - ColorTmp.a) * (1.0 - outColor.a));
                }
            } else {
                outColor = vec4(mix(outColor.rgb, ColorTmp.rgb, ColorTmp.a * ALPHA_SCALE), outColor.a) * float(ColorTmp.a < 1.0);
            }
        }
    }
    
    fragColor = outColor;
}
