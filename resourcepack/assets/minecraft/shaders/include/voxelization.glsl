#moj_import <constants.glsl>

ivec2 positionToCell(vec3 position, out bool inside) {
    ivec3 sides = ivec3(AREA_SIDE_LENGTH);

    ivec3 iPosition = ivec3(floor(position));
    iPosition += sides / 2;

    inside = true;
    if (clamp(iPosition, ivec3(0), sides - 1) != iPosition) {
        inside = false;
        return ivec2(-1);
    }

    int index = (iPosition.y * sides.z + iPosition.z) * sides.x + iPosition.x;
    
    int halfWidth = GRID_SIZE.x / 2;
    ivec2 result = ivec2(
        (index % halfWidth) * 2,
        index / halfWidth + 1
    );
    result.x += result.y % 2;

    return result;
}

ivec2 cellToPixel(ivec2 cell, ivec2 screenSize) {
    return ivec2(round(vec2(cell) / GRID_SIZE * screenSize));
}