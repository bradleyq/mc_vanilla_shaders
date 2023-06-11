# Better Environment Shaders for vanilla 1.19
<img src="images/4.png" /> 

## Overview
Shader that adds as much as possible from OptiFine shaders to the vanilla transparency shader available in "Fabulous" graphics setting. Due to limited material, light, time, and shadow information, some advanced features are not possible. A good number, however, are. I have ported them here. Most samples in credits are heavily modified to fit with the vanilla pipeline. Supports all FOV and render distances.

### Usage
See License.md for licensing. This pack requires Fabulous graphics on. For best experience, use FOV 70 with render distance 16!

### Configuration
Some basic settings can be toggled by editing `assets\minecraft\shaders\post\transparency.json` in `uniforms` for `preprocess0` pass and `postprocess2` pass. The following can be changed:
```
FOVGuess      [30.0, 110.0] 70.0 Default FOV as a fallback
FogDistance   [0.1, 10.0]   3.0  Fog distance multiplier
BloomAmount   [0.0, 1.0]    0.25 Bloom amount to apply
AutoExposure  0.0 or 1.0    1.0  Auto exposure enable
ExposurePoint [1.0, 4.0]    2.0  Target value to expose to  
Vibrance      [0.0, 2.0]    1.0  Color vibrance / saturation
```

## Features
- Water Waves
- SSAO
- Revamped Skys: Approximate Atmosphereic Scattering (Overworld), Aurora (End)
- Directional Light
- Screen Space Shadows
- Java Alpha-PBR support (Emissive, Subsurface, Waving)
- Multiplicative Transparency
- HDR Lighting
- Auto Exposure
- Bloom
- Volumetric Clouds
- Compatible with Optifine Fabulous & Dynamic Lights

### Comparisons
<div>
    <table style="width:100%">
        <tr>
            <td align="middle">
              <img src="images/0.png"/>
              <figcaption align="middle">vanilla</figcaption>
            </td>
        </tr>
        <tr>
            <td align="middle">
              <img src="images/1.png"/> 
              <figcaption align="middle">shader v1</figcaption>
            </td>
        </tr>
        <tr>
            <td align="middle">
              <img src="images/2.png"/> 
              <figcaption align="middle">shader v2</figcaption>
            </td>
        </tr>
        <tr>
            <td align="middle">
              <img src="images/5.png"/> 
              <figcaption align="middle">shader v3</figcaption>
            </td>
        </tr>
    </table>
</div>

## Credits
- **BSL shaders - capttatsu** for base SSR https://bitslablab.com/bslshaders/
- **Auroras - nimitz (twitter: @stormoid)** for base End Auroroa https://www.shadertoy.com/view/XtGGRt
- **Non physical based atmospheric scattering - robobo1221** for base sky https://www.shadertoy.com/view/Ml2cWG
- **Star Spheremap - peremoya2000** for base stars https://www.shadertoy.com/view/styXWz
- **SSAO - reinder** for base AO https://www.shadertoy.com/view/Ms33WB
