#ifndef CONSTANTS_GLSL
#define CONSTANTS_GLSL

const ivec2 GRID_SIZE = ivec2(1024, 705);
const int AREA_SIDE_LENGTH = int(pow(float(GRID_SIZE.x * GRID_SIZE.y / 2), 1.0 / 3.0));

#endif // CONSTANTS_GLSL