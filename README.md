# Basic Shaders for Vanilla 1.17
<img src="images/5.png" /> 

## Overview
Basic shader that adds as much as possible from OptiFine shaders to the vanilla transparency shader available in "Fabulous" graphics setting. Due to limited material, light, time, and shadow information, most advanced features are not possible. A good number, however, are. I have ported them here. Most samples are from the BSL shader, however much of it is heavily modified to fit with the vanilla pipeline. Shadows use Bálint's voxelizer. Supports FOV <140, distance 12-32. For best experience, use FOV 70 with render distance 16!

### Features
- FXAA
- Bloom
- Adaptive exposure
- Adaptive FOV
- Voxel shadows + SSS
- SSR + approximate
- Water waves
- Inferred surface normals
- Tonemapping
- Multiplicative transparency blending

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
    </table>
</div>

## Usage
See License.md for licensing. This pack requires Fabulous graphics on. Supports FOV 30-140, distance 12-32. For best experience, use FOV 70 with render distance 16!

## Credits
- **BSL shaders - capttatsu** for reference code for some of the features (SSR, Tonemapping).
- **VanillaVoxellizationTemplate - Bálint** for voxelization: https://github.com/BalintCsala/VanillaVoxellizationTemplate
