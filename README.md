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

Known issues:
- optifine #moj_import bug
- shadows are ... ok
- Alpha-PBR specular, metalness
- some translucents visible over fog (slime entities)
- poor fps: AO pass, SSR pass, Shadow blur pass
- blindness fog underwater in some biomes (swamp, warm ocean)
- particles are not emissive
- no cloud shading
- glow item frame items are lit as if outdoors

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
- **BSL shaders - capttatsu** for reference code for some of the features (SSR).
- **Auroras - nimitz (twitter: @stormoid)** for base implementation of End Auroroa.
- **Non physical based atmospheric scattering - robobo1221** Site: http://www.robobo1221.net/shaders.
