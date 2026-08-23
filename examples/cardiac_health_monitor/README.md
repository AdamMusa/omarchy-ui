# Pulse Atlas

A premium cardiac wellness visualization written entirely in Ruby. Its heart is an actual 81,881
vertex anatomical GLB scene loaded through the framework's `model_view_3d` component. The geometry
beats in three axes and acts as the interaction surface: double-click/wheel/pinch to zoom, drag to
orbit, and use the single reset control to restore the camera. The app also combines live
ECG-style charting, radial gauges, particles, a recovery heatmap, scheduled state, breathing
controls, and an image-backed insight dialog. It is a UI showcase, not medical advice.

Install the optional native 3D runtime with `sudo pacman -S qt6-quick3d assimp` before launching.

```bash
omarchy_ui launch main.rb
```
