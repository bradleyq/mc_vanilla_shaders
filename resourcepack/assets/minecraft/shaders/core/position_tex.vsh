#version 150

in vec3 Position;
in vec2 UV0;

uniform sampler2D Sampler0;
uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

out mat4 ProjInv;
out vec3 cscale;
out vec3 c1;
out vec3 c2;
out vec3 c3;
out vec2 texCoord0;
out float isSun;

#define SUNSIZE 60
#define SUNDIST 110
#define OVERLAYSCALE 2.0

void main() {
    vec4 candidate = ProjMat * ModelViewMat * vec4(Position, 1.0);
    ProjInv = mat4(0.0);
    cscale = vec3(0.0);
    c1 = vec3(0.0);
    c2 = vec3(0.0);
    c3 = vec3(0.0);
    isSun = 0.0;
    vec2 tsize = textureSize(Sampler0, 0);

    // test if sun or moon. Position.y limit excludes worldborder.
    if (Position.y < SUNDIST  && Position.y > -SUNDIST && (ModelViewMat * vec4(Position, 1.0)).z > -SUNDIST) {

        // only the sun has a square texture
        if (tsize.x == tsize.y) {
            isSun = 1.0;
            candidate = vec4(-2.0 * OVERLAYSCALE, -OVERLAYSCALE, 0.0, 1.0);

            // modify position of sun so that it covers the entire screen and store c1, c2, c3 so player space position of sun can be extracted in fsh.
            // this is the key to get everything working since it guarantees that we can access sun info in the control pixels in fsh.
            if (UV0.x < 0.5) {
                c1 = Position;
                cscale.x = 1.0;
            } else {
                candidate.x = OVERLAYSCALE;
                if (UV0.y < 0.5) {
                    c2 = Position;
                    cscale.y = 1.0;
                } else {
                    candidate.y = 2.0 * OVERLAYSCALE;
                    c3 = Position;
                    cscale.z = 1.0;
                }
            }
            ProjInv = inverse(ProjMat * ModelViewMat);
        } else {
            isSun = 0.5;
        }
    }

    gl_Position = candidate;
    texCoord0 = UV0;
}
