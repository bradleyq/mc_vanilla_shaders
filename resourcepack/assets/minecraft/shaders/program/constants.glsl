#define CLOUD_MULT vec4(1.25, 1.25, 1.25, 0.5)

struct Layer {
    vec4 color;
    float depth;
    float op;
};