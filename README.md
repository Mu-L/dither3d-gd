# Surface-Stable Fractal Dithering for Godot

This is a port of [Dither3D](https://github.com/runevision/Dither3D) to Godot Engine, packaged as a plugin.

## Features

- **Surface-Stable Fractal Dithering**: Dots stick to surfaces and maintain constant screen size.
- **Multiple Shaders**:
  - `Dither3DOpaque.gdshader`: Standard opaque material.
  - `Dither3DCutout.gdshader`: Alpha cutout support.
  - `Dither3DParticleAdd.gdshader`: Additive particles.
  - `Dither3DSkybox.gdshader`: Skybox shader (6-sided texture support).
- **Global Properties**: Control dither settings globally using `Dither3DGlobalProperties` node.
- **Texture Generator**: Generate required 3D textures within the editor.

## Setup

1. **Enable Plugin**:

   - Go to **Project Settings -> Plugins** and enable **Dither3D**.

2. **Generate Textures**:

   - The shader requires special 3D textures.
   - Create a new Scene or use an existing one.
   - Add a node and attach `addons/dither3d/scripts/Dither3DTextureGenerator.gd`.
   - In the Inspector, click **Generate Textures**.
   - Textures will be saved in `addons/dither3d/textures/` (or `res://addons/dither3d_textures` if using the old script path, check the script).
   - _Note: The script has been moved to `addons/dither3d/scripts/` and updated to output to `addons/dither3d/textures/` if you modify the path constant, otherwise it defaults to `res://addons/dither3d_textures`._

3. **Use Shaders**:

   - **Example Materials**: You can use the ready-to-use materials in `addons/dither3d/materials/` directly.
   - **Manual Setup**:
     - Create a `ShaderMaterial`.
     - Assign one of the shaders from `addons/dither3d/shaders/`.
     - Assign the generated `dither_tex` and `dither_ramp_tex`.

4. **Global Control (Optional)**:
   - Add a `Dither3DGlobalProperties` node to your scene.
   - Adjust settings in the Inspector.
   - Enable **Apply Overrides** to force settings on all materials in the scene.
   - Enable **Scale With Screen** to keep dot size constant relative to screen height.

## Notes

- **Skybox**: The skybox shader approximates the original behavior. It requires 6 textures (Front, Back, Left, Right, Up, Down).
- **Particles**: The particle shader is additive and unshaded.
- **Global Properties**: This script iterates over the scene tree to find materials. It might be expensive on large scenes if updated frequently. It is recommended to use it for setup or occasional updates.

## License

This project (the Godot plugin port) is licensed under the **GNU General Public License v3.0 (GPLv3)**.

However, the core Dither3D implementation (shaders and algorithm logic) is ported from [Dither3D](https://github.com/runevision/Dither3D) by Rune Skovbo Johansen, which is licensed under the **Mozilla Public License v2.0 (MPL-2.0)**.

- The original MPL-2.0 licensed files retain their original license.
- The new files created for this Godot plugin structure are licensed under GPLv3.
- The combined work is distributed under GPLv3 in accordance with MPL-2.0 Section 3.3.
