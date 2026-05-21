## 1.0.0

### Added
- `MinecraftViewer` widget — renders BlockBench/Minecraft entity JSON via Three.js inside a WebView.
- Interactive controls: mouse drag and touch drag to rotate, scroll/pinch to zoom.
- Auto-rotation with configurable speed.
- Texture support: load PNG skin/atlas from any HTTP/HTTPS URL or data URI; UV mapping per face.
- Full Three.js lighting setup: ambient, directional, and back lights with shadow mapping.
- Public control API via `GlobalKey<MinecraftViewerState>`:
  - `updateModel(Map entityJson)`
  - `updateTexture(String url)`
  - `setScale(double scale)`
  - `setCameraDistance(double distance)`
  - `setAutoRotate(bool autoRotate)`
- Configurable parameters: `scale`, `cameraDistance`, `rotationSpeed`, `autoRotate`, `backgroundColor`, `lighting`, `fov`.
- `onModelLoaded` and `onError` callbacks.
- `debugMode` flag for verbose logging.
- Data model classes: `MinecraftEntity`, `MinecraftElement`, `MinecraftRotation`, `MinecraftFace`, `MinecraftBone`.
- `MinecraftUtils` utility class with 12 helper methods including `createSteveModel()`, `createCreeperModel()`, `mergeEntities()`, and more.
- Cross-platform: Android, iOS, Web.

## Planned

### 1.1.0
- Bone/group hierarchy support for animated models.
- Support for `.bbmodel` file format.
- Texture atlas cropping via canvas API.

### 1.2.0
- Keyframe animation playback.
- Export rendered frame as PNG.
