# minecraft_viewer

[![Pub Version](https://img.shields.io/pub/v/minecraft_viewer)](https://pub.dev/packages/minecraft_viewer)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Cross-platform Flutter package for viewing and rendering Minecraft 3D entity models using **Three.js** inside a WebView. Supports interactive drag-to-rotate, pinch-to-zoom, and auto-rotation on Android, iOS, and Web.

---

## Features

- Render any **BlockBench / Minecraft entity JSON** as a 3D model
- Per-face **UV texture mapping** from an HTTP URL or data URI
- **Mouse and touch controls**: drag to rotate, scroll/pinch to zoom
- **Auto-rotation** with configurable speed
- **Three.js lighting**: ambient + directional shadows
- Runtime controls via `GlobalKey<MinecraftViewerState>`: update model, texture, scale, camera, rotation
- `onModelLoaded` / `onError` callbacks
- Fully typed Dart data models (`MinecraftEntity`, `MinecraftElement`, …)
- 12-method `MinecraftUtils` helper class
- Cross-platform: **Android**, **iOS**, **Web**

---

## Platform Setup

### Android

In `android/app/src/main/AndroidManifest.xml` add internet permission:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS

In `ios/Runner/Info.plist` allow arbitrary loads (needed to fetch the Three.js CDN):

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

### Web

No extra setup required.

---

## Installation

```yaml
dependencies:
  minecraft_viewer: ^1.0.0
```

Then run `flutter pub get`.

---

## Quick Start

```dart
import 'package:minecraft_viewer/minecraft_viewer.dart';

// Build a Steve model from the built-in helper
final entityJson = MinecraftUtils.createSteveModel().toJson();

MinecraftViewer(
  entityJson: entityJson,
  autoRotate: true,
  backgroundColor: 0x1a1a2e,
)
```

---

## Examples

### 1. Minimal usage

```dart
MinecraftViewer(
  entityJson: MinecraftUtils.createSteveModel().toJson(),
)
```

### 2. With texture URL

```dart
MinecraftViewer(
  entityJson: myEntityJson,
  textureUrl: 'https://example.com/steve_skin.png',
  scale: 1.2,
  cameraDistance: 60,
)
```

### 3. Runtime control via GlobalKey

```dart
final _key = GlobalKey<MinecraftViewerState>();

// In your widget tree
MinecraftViewer(key: _key, entityJson: myEntityJson)

// Elsewhere
_key.currentState?.setScale(2.0);
_key.currentState?.setAutoRotate(false);
_key.currentState?.updateModel(newEntityJson);
_key.currentState?.updateTexture('https://example.com/new_skin.png');
_key.currentState?.setCameraDistance(100);
```

### 4. Callbacks + loading state

```dart
MinecraftViewer(
  entityJson: myEntityJson,
  onModelLoaded: () => print('Ready!'),
  onError: (err) => print('Error: $err'),
  debugMode: true,
)
```

### 5. Using MinecraftUtils

```dart
// Parse from JSON string
final entity = MinecraftUtils.parseEntity(jsonString);

// Create built-in models
final steve   = MinecraftUtils.createSteveModel();
final creeper = MinecraftUtils.createCreeperModel();
final cube    = MinecraftUtils.createSimpleCube(size: 8);

// Scale and merge
final big    = MinecraftUtils.scaleEntity(steve, 2.0);
final merged = MinecraftUtils.mergeEntities([steve, creeper]);

// Inspect bounds
final center = MinecraftUtils.getEntityCenter(entity);
final bounds = MinecraftUtils.getEntityBounds(entity);

// Validate unknown JSON
if (MinecraftUtils.isValidEntity(rawMap)) { ... }
```

---

## API Reference

### `MinecraftViewer`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `entityJson` | `Map<String, dynamic>` | required | BlockBench entity JSON |
| `textureUrl` | `String?` | `null` | Texture URL (HTTP/HTTPS or data URI) |
| `scale` | `double` | `1.0` | Model scale (0.1–3.0) |
| `cameraDistance` | `double` | `80.0` | Camera Z distance in Minecraft units |
| `rotationSpeed` | `double` | `0.005` | Auto-rotation speed (rad/frame) |
| `autoRotate` | `bool` | `true` | Enable auto-rotation |
| `backgroundColor` | `int` | `0x1a1a1a` | RGB background color |
| `lighting` | `bool` | `true` | Enable Three.js lighting |
| `fov` | `double` | `75.0` | Camera field-of-view (degrees) |
| `onModelLoaded` | `VoidCallback?` | `null` | Called when model renders |
| `onError` | `Function(String)?` | `null` | Called on error |
| `debugMode` | `bool` | `false` | Print JS bridge messages |

### `MinecraftViewerState` (via GlobalKey)

| Method | Description |
|--------|-------------|
| `updateModel(Map json)` | Replace the current model |
| `updateTexture(String url)` | Load a new texture and rebuild |
| `setScale(double scale)` | Change model scale |
| `setCameraDistance(double d)` | Move camera closer/farther |
| `setAutoRotate(bool v)` | Toggle auto-rotation |

### `MinecraftUtils`

| Method | Returns | Description |
|--------|---------|-------------|
| `parseEntity(String)` | `MinecraftEntity` | Parse JSON string |
| `parseEntityFromMap(Map)` | `MinecraftEntity` | Parse from map |
| `entityToJson(entity)` | `String` | Serialize to JSON string |
| `createSimpleCube({name, size})` | `MinecraftEntity` | Single cube |
| `createSteveModel()` | `MinecraftEntity` | 6-element Steve |
| `createCreeperModel()` | `MinecraftEntity` | 6-element Creeper |
| `getEntityBounds(entity)` | `List<double>` | `[minX,minY,minZ,maxX,maxY,maxZ]` |
| `getEntityCenter(entity)` | `List<double>` | `[cx,cy,cz]` |
| `scaleEntity(entity, scale)` | `MinecraftEntity` | Scale all coordinates |
| `cloneEntity(entity)` | `MinecraftEntity` | Deep copy |
| `mergeEntities(list)` | `MinecraftEntity` | Combine element lists |
| `isValidEntity(Map)` | `bool` | Validate JSON structure |

---

## Entity JSON Format

The widget accepts any `elements`-based BlockBench export:

```json
{
  "elements": [
    {
      "name": "head",
      "from": [4, 24, 4],
      "to":   [12, 32, 12],
      "rotation": {
        "origin": [8, 24, 8],
        "axis": "y",
        "angle": 0
      },
      "faces": {
        "north": { "uv": [8, 8, 16, 16], "texture": "#0" },
        "south": { "uv": [24, 8, 32, 16], "texture": "#0" },
        "east":  { "uv": [0, 8, 8, 16],  "texture": "#0" },
        "west":  { "uv": [16, 8, 24, 16], "texture": "#0" },
        "up":    { "uv": [8, 0, 16, 8],  "texture": "#0" },
        "down":  { "uv": [16, 0, 24, 8], "texture": "#0" }
      }
    }
  ],
  "textures": { "0": "skin.png" }
}
```

Coordinates are in **pixel units** (16 px = 1 block). UV values are in texture pixels (default atlas 64×64).

---

## Controls

| Action | Effect |
|--------|--------|
| Mouse drag / single touch drag | Rotate model |
| Scroll wheel | Zoom in/out |
| Pinch (two-finger) | Zoom in/out |

---

## Performance

| Metric | Target |
|--------|--------|
| First render | < 1 s |
| Model rebuild | < 100 ms |
| FPS (< 200 elements) | 60 FPS |
| Memory (runtime) | 50–150 MB |

---

## Troubleshooting

**Model not showing on iOS** — Add `NSAllowsArbitraryLoads` to `Info.plist` (see Platform Setup).

**Blank WebView on Android** — Ensure `INTERNET` permission is in `AndroidManifest.xml`.

**Texture not loading** — Only HTTP/HTTPS URLs and data URIs are supported. Local file paths require extra WebView configuration.

**`onError` fires immediately** — Check that `entityJson` has an `elements` key that is a non-empty list.

---

## Platform Support

| Platform | Status |
|----------|--------|
| Android  | ✅ |
| iOS      | ✅ |
| Web      | ✅ |
| macOS    | ⚠️ Requires `webview_flutter_macos` |
| Windows  | ⚠️ Requires `webview_flutter_windows` |
| Linux    | ❌ Not supported |

---

## License

MIT — see [LICENSE](LICENSE).

Three.js is used under the [MIT License](https://github.com/mrdoob/three.js/blob/dev/LICENSE).
# minecraft_viewer_package
