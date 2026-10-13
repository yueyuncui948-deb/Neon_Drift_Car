# Neon Drift Car

Godot 4 browser-oriented starter project featuring the original **ION-01** low-poly neon car. The current scene is an interactive asset showroom, not yet a driving game.

## Open and run

Validated with **Godot 4.6.3** and **Blender 4.3.2**. Open `project.godot` and press **F6/F5**, or run:

```bash
godot --editor --path . --import
godot --path .
```

Drag with the left mouse button to orbit, scroll to zoom, and press **R** to reset the view.

The renderer is explicitly `gl_compatibility` for desktop and mobile. Godot's Compatibility renderer targets WebGL 2.0 on Web exports. The model uses opaque PBR and emissive materials, with no Forward+-only glow dependency. Browser export/runtime testing has not yet been performed; install matching Godot Web export templates and create a Web export preset when adding deployment. Rendering mode alone does not guarantee every browser/device will work.

## Assets and reproduction

- `assets/cars/neon_drift_car.gltf` + `.bin`: glTF 2.0 model imported by Godot; keep both files together.
- `art/neon_drift_car.blend`: editable Blender source, excluded from Godot import using `art/.gdignore`.
- `tools/build_car.py`: original procedural `bpy` generator.
- `scenes/showroom.tscn` and `scripts/showroom.gd`: display stage, lighting, camera and UI.
- `docs/neon-drift-showroom.png`: actual Godot Compatibility viewport capture.

Regenerate from the repository root (intentionally replaces the generated car assets and Blender source):

```bash
blender --background --python tools/build_car.py
godot --headless --editor --path . --import
```

The exported car contains **1,936 triangles, 84 mesh objects and 8 materials**, approximately 200 KiB combined glTF + buffer. Blender source units are meters, front is -Y and up is +Z; glTF converts to Y-up, so the imported car faces +Z. Separate wheels and named parts are preserved for future rigging. No collision, suspension, driving controller or animation is implemented yet.

## Cloud runtime

The cloud home directory is read-only. In each shell before launching Godot:

```bash
export XDG_DATA_HOME=/workspace/.godot-runtime/data
export XDG_CONFIG_HOME=/workspace/.godot-runtime/config
export XDG_CACHE_HOME=/workspace/.godot-runtime/cache
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
```

Headless import works without a display. For viewport rendering, use an available X11 display and, on machines without a GPU, `LIBGL_ALWAYS_SOFTWARE=1`. Use `--audio-driver Dummy` on this cloud machine without an audio device. Capture an actual rendered viewport with:

```bash
godot --path . --audio-driver Dummy -- --capture=/absolute/path/showroom.png
```

The capture command requires a graphical display and exits after saving. `--headless` cannot produce this image. `docs/` is excluded from Godot asset import.
