# Shaders for vanilla 1.19 DEV BRANCH!!!!!
<img src="images/4.png" /> 

## TIS HOT DEV BRANCH!!! STUFF MAY NOT WORK!!!
CL:
- rebased from directional light shader
- water waves
- SSAO
- fake atmosphereic scattering
- directional light
- Screen Space Shadows
- Java Alpha-PBR support (Emissive)

Known issues:
- flat nether lighting
- flat end lighting
- rain sky during day
- optifine #moj_import bug
- grass too dark in some biomes
- shadows are wonky
- Alpha-PBR Subsurface, specular, metalness
- solid transparency invisible
- sun, moon, stars, not reflected

## Overview
Basic shader that adds as much as possible from OptiFine shaders to the vanilla transparency shader available in "Fabulous" graphics setting. Due to limited material, light, time, and shadow information, most advanced features are not possible. A good number, however, are. I have ported them here. Most samples are from the BSL shader, however much of it is heavily modified to fit with the vanilla pipeline. Supports all FOV and render distances.

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
- **BSL shaders - capttatsu** for reference code for some of the features (SSR, Tonemapping).
