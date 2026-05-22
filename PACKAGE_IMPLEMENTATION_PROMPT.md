# Minecraft Viewer - Flutter Package - Complete Implementation Prompt

## Overview

You are implementing a complete, production-ready Flutter package called `minecraft_viewer` for viewing and rendering Minecraft 3D entity models.

**This IS a proper Pub.dev package**, not just a widget file.

## Package Structure

```
minecraft_viewer/
├── pubspec.yaml                          # Package configuration
├── README.md                             # Documentation
├── CHANGELOG.md                          # Version history
├── LICENSE                               # MIT License
├── lib/
│   ├── minecraft_viewer.dart             # Main export
│   └── src/
│       ├── minecraft_viewer.dart         # Main widget
│       ├── models/
│       │   └── minecraft_entity.dart     # Data models
│       └── utils/
│           └── minecraft_utils.dart      # Utility functions
├── example/
│   └── main.dart                         # Example app
└── test/
    └── minecraft_viewer_test.dart        # Unit tests (optional)
```

## 1. pubspec.yaml

**Requirements:**
- Package name: `minecraft_viewer`
- Version: 1.0.0
- Dart SDK: >=3.0.0 <4.0.0
- Flutter: >=3.10.0
- Main dependency: `webview_flutter: ^4.4.0`
- Platform-specific dependencies:
  - `webview_flutter_android: ^13.0.0`
  - `webview_flutter_ios: ^13.0.0`
  - `webview_flutter_web: ^0.2.0`

## 2. lib/minecraft_viewer.dart (Main Export)

This file exports all public APIs:

```dart
library minecraft_viewer;

export 'src/minecraft_viewer.dart';
export 'src/models/minecraft_entity.dart';
export 'src/utils/minecraft_utils.dart';
```

## 3. lib/src/minecraft_viewer.dart (Main Widget)

Implement `MinecraftViewer` StatefulWidget with:

### Constructor Parameters
- `entityJson` (required): Map<String, dynamic> - BlockBench entity
- `textureUrl` (optional): String - Texture file path/URL
- `scale` (default 1.0): double - Model scale (0.1-3.0)
- `cameraDistance` (default 80.0): double - Camera distance (10-200)
- `rotationSpeed` (default 0.005): double - Auto-rotation speed
- `autoRotate` (default true): bool - Enable auto-rotation
- `backgroundColor` (default 0x1a1a1a): int - RGB hex color
- `lighting` (default true): bool - Enable Three.js lighting
- `fov` (default 75.0): double - Camera FOV
- `onModelLoaded` (optional): VoidCallback - Success callback
- `onError` (optional): Function(String) - Error callback
- `debugMode` (default false): bool - Enable logging

### State Implementation

**Key Methods:**

1. **`_initWebView()`**
   - Create WebViewController
   - Add JavaScript bridge: `MinecraftViewerBridge`
   - Load HTML with Three.js
   - Handle navigation and errors

2. **`_handleJavaScriptMessage(String message)`**
   - Listen for `'MODEL_LOADED'` message
   - Listen for `'ERROR:'` prefixed messages
   - Update UI state accordingly

3. **`_loadModel()`**
   - Serialize entity JSON
   - Execute JavaScript to load model
   - Pass all options to JavaScript

4. **`_getHtmlContent()`**
   - Return HTML string with embedded Three.js code
   - Include scene setup, model rendering, controls

5. **State Methods (expose via context)**
   - `updateModel(Map newEntityJson)` - Update entity
   - `updateTexture(String url)` - Change texture
   - `setScale(double scale)` - Update scale
   - `setCameraDistance(double distance)` - Update camera
   - `setAutoRotate(bool autoRotate)` - Toggle rotation

### HTML/JavaScript Implementation

The `_getHtmlContent()` returns an HTML page with:

**HTML Structure:**
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; }
    body { width: 100%; height: 100vh; background: #1a1a1a; }
    #viewer { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="viewer"></div>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script>
    // JavaScript implementation here
  </script>
</body>
</html>
```

**JavaScript: MinecraftModelViewer Class**

Implement class with methods:

1. **`constructor(container, options)`**
   - Create Three.js scene
   - Setup camera (PerspectiveCamera)
   - Create renderer (WebGLRenderer)
   - Store options

2. **`init()`**
   - Call setupScene, setupCamera, setupRenderer
   - Call setupLighting, setupControls
   - Load texture if provided
   - Build model if provided
   - Start animation loop
   - Add window resize listener

3. **`setupScene()`**
   - Create THREE.Scene
   - Set background color

4. **`setupCamera()`**
   - Create PerspectiveCamera with fov and aspect ratio
   - Position at [0, 0, cameraDistance]
   - Look at origin

5. **`setupRenderer()`**
   - Create WebGLRenderer with antialias
   - Set size to container dimensions
   - Set pixel ratio
   - Enable shadow mapping (PCFShadowShadowMap)
   - Append to container

6. **`setupLighting()`**
   - Add AmbientLight (0xffffff, 0.6)
   - Add DirectionalLight (0xffffff, 0.8) at [5, 10, 7]
   - Enable shadow casting and shadow camera
   - Add back light (0xffffff, 0.3) at [-5, 5, -7]

7. **`setupControls()`**
   - Add mouse events (down, up, move)
   - Add touch events (start, end, move)
   - Add wheel event (prevent default, adjust camera Z)
   - Track mouse/touch position
   - Rotation: `model.rotation.y += deltaX * 0.01`
   - Rotation: `model.rotation.x += deltaY * 0.01`
   - Zoom clamp: 20 < distance < 300

8. **`loadTexture()`**
   - Promise-based texture loading
   - Use THREE.TextureLoader
   - Set magFilter and minFilter to THREE.NearestFilter
   - Handle errors gracefully

9. **`buildModel(entityJson)`**
   - Remove existing model
   - Create THREE.Group
   - Loop through elements and call addCube
   - Center model using Box3
   - Scale model
   - Add to scene

10. **`addCube(element)`**
    - Calculate dimensions: (to[i] - from[i]) / 16
    - Create THREE.BoxGeometry
    - Create MeshPhongMaterial (with or without texture)
    - Create Mesh
    - Enable shadows
    - Set position at element center
    - Apply rotation if present
    - Add to model group

11. **`applyRotation(mesh, rotation)`**
    - Get origin, angle, axis from rotation
    - Apply rotation around origin point
    - Translate, rotate, translate back

12. **`centerModel()`**
    - Calculate bounding box
    - Get center
    - Subtract center from position

13. **`animate()`**
    - requestAnimationFrame loop
    - If autoRotate and not dragging: `model.rotation.y += rotationSpeed`
    - Render scene

14. **Global Functions**
    - `window.loadModel(options)` - Initialize viewer
    - `window.updateModel(json)` - Update model
    - `window.updateTexture(url)` - Update texture
    - `window.setScale(value)` - Set scale
    - `window.setCameraDistance(distance)` - Update camera
    - `window.setAutoRotate(bool)` - Toggle rotation

### UI Build

Return Stack with:
1. WebViewWidget with controller
2. Loading indicator if `_isLoading`
3. Error dialog if `_error` is not null

## 4. lib/src/models/minecraft_entity.dart

Implement Dart data classes for type safety:

1. **`MinecraftElement`**
   - `name`: String
   - `from`: List<double>
   - `to`: List<double>
   - `rotation`: MinecraftRotation?
   - `faces`: Map<String, MinecraftFace>?
   - `fromJson()` factory
   - `toJson()` method

2. **`MinecraftRotation`**
   - `origin`: List<double>
   - `axis`: String
   - `angle`: double
   - `fromJson()` factory
   - `toJson()` method

3. **`MinecraftFace`**
   - `uv`: List<int>
   - `texture`: String?
   - `rotation`: int?
   - `cullface`: bool?
   - `fromJson()` factory
   - `toJson()` method

4. **`MinecraftEntity`**
   - `elements`: List<MinecraftElement>
   - `textures`: Map<String, dynamic>?
   - `bones`: List<MinecraftBone>?
   - `ambientOcclusion`: String?
   - `fromJson()` factory
   - `toJson()` method

5. **`MinecraftBone`**
   - `name`: String
   - `pivot`: List<double>?
   - `rotation`: List<double>?
   - `cubes`: List<String>?
   - `children`: List<MinecraftBone>?
   - `fromJson()` factory
   - `toJson()` method

## 5. lib/src/utils/minecraft_utils.dart

Implement static utility class with methods:

1. **`parseEntity(String jsonString)`** → MinecraftEntity
2. **`parseEntityFromMap(Map json)`** → MinecraftEntity
3. **`entityToJson(MinecraftEntity entity)`** → String
4. **`createSimpleCube({String name, double size})`** → MinecraftEntity
5. **`createSteveModel()`** → MinecraftEntity (head, body, 4 limbs)
6. **`createCreeperModel()`** → MinecraftEntity (head, body, 4 legs)
7. **`getEntityBounds(entity)`** → List<double> [minX, minY, minZ, maxX, maxY, maxZ]
8. **`getEntityCenter(entity)`** → List<double> [centerX, centerY, centerZ]
9. **`scaleEntity(entity, scale)`** → MinecraftEntity
10. **`cloneEntity(entity)`** → MinecraftEntity
11. **`mergeEntities(List<MinecraftEntity> entities)`** → MinecraftEntity
12. **`isValidEntity(Map json)`** → bool

## 6. README.md

Comprehensive documentation with:
- Feature list
- Installation instructions
- Platform setup (iOS, Android, Web)
- Quick start guide
- Code examples (5+)
- Complete API reference
- Entity JSON format specification
- Controls documentation
- Texture support options
- Performance metrics
- Troubleshooting guide
- Platform support matrix
- License and credits

## 7. CHANGELOG.md

Version history documenting:
- v1.0.0 features and additions
- Future planned releases
- Known issues (if any)
- Migration guides
- Breaking changes (if any)

## 8. LICENSE

MIT License file with copyright notice.

## 9. example/main.dart (Optional but Recommended)

Complete example app showing:
- Basic usage
- Model selection dropdown
- Scale/camera sliders
- Auto-rotate toggle
- Error handling
- Loading states

## 10. test/minecraft_viewer_test.dart (Optional)

Unit tests for:
- Data model serialization/deserialization
- Utility function correctness
- Edge cases

## Key Requirements

✅ **Cross-Platform**: iOS, Android, Web
✅ **Performance**: 60 FPS with 200+ elements
✅ **Type Safety**: Full Dart type system
✅ **Error Handling**: Comprehensive error management
✅ **Documentation**: Complete API docs
✅ **Examples**: Working code examples
✅ **License**: MIT (already included)
✅ **Testable**: Proper separation of concerns

## Publishing to Pub.dev

After implementation:

1. Create GitHub repository
2. Update homepage/repository URLs in pubspec.yaml
3. Test on all platforms
4. Run: `flutter pub publish`

## File Sizes

- Main widget: ~400 lines
- Models: ~300 lines
- Utils: ~250 lines
- HTML/JS: ~600 lines (embedded)
- Total: ~1500 lines (well-organized code)

## Performance Targets

- Startup: < 1 second
- Model render: < 100ms
- FPS: 60 with < 200 elements
- Memory: 50-150MB runtime

This is a production-ready package that can be published to Pub.dev!
