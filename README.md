# Shaders for vanilla 1.19 DEV BRANCH!!!!!
<img src="images/4.png" /> 

## TIS HOT DEV BRANCH!!! STUFF MAY NOT WORK!!!
CL:
- Water Waves
- SSAO
- Approximate Atmosphereic Scattering (Overworld)
- Directional Light
- Screen Space Shadows
- Java Alpha-PBR support (Emissive, Subsurface, Waving)
- Multiplicative Transparency
- HDR buffers
- Aurora (End)
- Auto Exposure
- Parametric Rolloff Tonemap
- Bloom
- Volumetric Clouds

Known issues:
- optifine #moj_import bug
- shadow jank
- Alpha-PBR specular, metalness
- some translucents visible over fog (slime entities)
- particles are not lit
- glow item frame items are lit as if outdoors
- hand item shading is flat
- shader unused uniform warnings
- support translucent text in text display

## Overview
Basic shader that adds as much as possible from OptiFine shaders to the vanilla transparency shader available in "Fabulous" graphics setting. Due to limited material, light, time, and shadow information, most advanced features are not possible. A good number, however, are. I have ported them here. Most samples in credits are heavily modified to fit with the vanilla pipeline. Supports all FOV and render distances.

### Features
- TBD

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
              <figcaption align="middle">shader v3 (alpha)</figcaption>
            </td>
        </tr>
    </table>
</div>

## Usage
See License.md for licensing. This pack requires Fabulous graphics on. Supports FOV 30-140, distance 12-32. For best experience, use FOV 70 with render distance 16!

## Credits
- **BSL shaders - capttatsu** for base SSR https://bitslablab.com/bslshaders/
- **Auroras - nimitz (twitter: @stormoid)** for base End Auroroa https://www.shadertoy.com/view/XtGGRt
- **Non physical based atmospheric scattering - robobo1221** for base sky https://www.shadertoy.com/view/Ml2cWG
- **Star Spheremap - peremoya2000** for base stars https://www.shadertoy.com/user/peremoya2000
