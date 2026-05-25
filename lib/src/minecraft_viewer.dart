import 'dart:convert';

import 'package:flutter/material.dart';

import '_viewer_controller_stub.dart'
    if (dart.library.html) '_viewer_controller_web.dart'
    if (dart.library.io) '_viewer_controller_mobile.dart';

class MinecraftViewer extends StatefulWidget {
  final String entityJson;
  final String? textureBase64;
  final double? scale;
  final double cameraDistance;
  final double rotationSpeed;
  final bool autoRotate;
  final int backgroundColor;
  final bool lighting;
  final double fov;
  final VoidCallback? onModelLoaded;
  final void Function(String)? onError;
  final bool debugMode;

  const MinecraftViewer({
    super.key,
    required this.entityJson,
    this.textureBase64,
    this.scale,
    this.cameraDistance = 80.0,
    this.rotationSpeed = 0.005,
    this.autoRotate = true,
    this.backgroundColor = 0x1a1a1a,
    this.lighting = true,
    this.fov = 75.0,
    this.onModelLoaded,
    this.onError,
    this.debugMode = false,
  });

  @override
  State<MinecraftViewer> createState() => MinecraftViewerState();
}

class MinecraftViewerState extends State<MinecraftViewer> {
  late ViewerController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = ViewerController();
    _controller.init(_getHtmlContent(), _handleJavaScriptMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleJavaScriptMessage(String message) {
    if (widget.debugMode) debugPrint('MinecraftViewer JS: $message');
    if (message == 'PAGE_READY') {
      _loadModel();
    } else if (message == 'MODEL_LOADED') {
      if (mounted) setState(() => _isLoading = false);
      widget.onModelLoaded?.call();
    } else if (message.startsWith('ERROR:')) {
      _handleError(message.substring(6));
    }
  }

  void _handleError(String error) {
    if (widget.debugMode) debugPrint('MinecraftViewer error: $error');
    if (mounted) {
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
    widget.onError?.call(error);
  }

  Future<void> _loadModel() async {
    if (widget.entityJson.isEmpty) return;
    try {
      final entityMap = jsonDecode(widget.entityJson) as Map<String, dynamic>;
      final options = <String, dynamic>{
        'entityJson': entityMap,
        if (widget.scale != null) 'scale': widget.scale,
        'cameraDistance': widget.cameraDistance,
        'rotationSpeed': widget.rotationSpeed,
        'autoRotate': widget.autoRotate,
        'backgroundColor': widget.backgroundColor,
        'lighting': widget.lighting,
        'fov': widget.fov,
        if (widget.textureBase64 != null)
          'textureUrl': 'data:image/png;base64,${widget.textureBase64}',
      };
      await _controller.runJS('window.loadModel(${jsonEncode(options)});');
    } catch (e) {
      _handleError(e.toString());
    }
  }

  // Public control methods — access via GlobalKey<MinecraftViewerState>

  void updateModel(String entityJson) {
    if (entityJson.isEmpty) return;
    final entityMap = jsonDecode(entityJson) as Map<String, dynamic>;
    _controller.runJS('window.updateModel(${jsonEncode(entityMap)});');
  }

  void updateTexture(String base64) {
    final dataUri = 'data:image/png;base64,$base64';
    _controller.runJS('window.updateTexture(${jsonEncode(dataUri)});');
  }

  void setScale(double scale) => _controller.runJS('window.setScale($scale);');

  void setCameraDistance(double distance) =>
      _controller.runJS('window.setCameraDistance($distance);');

  void setAutoRotate(bool autoRotate) =>
      _controller.runJS('window.setAutoRotate($autoRotate);');

  String _getHtmlContent() {
    final bgCss =
        '#${widget.backgroundColor.toRadixString(16).padLeft(6, '0')}';
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; background: $bgCss; }
    #viewer { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="viewer"></div>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script>
${_getJavaScriptContent()}
  </script>
</body>
</html>''';
  }

  String _getJavaScriptContent() => r'''
// Web iframe bridge — used when running inside Flutter Web (iframe context).
// On native mobile, MinecraftViewerBridge is injected by addJavaScriptChannel
// before this script runs, so the if-guard skips re-defining it.
if (typeof window.MinecraftViewerBridge === 'undefined') {
  window.MinecraftViewerBridge = {
    postMessage: function(msg) {
      try { window.parent.postMessage({source:'mc-viewer', data:msg}, '*'); } catch(e) {}
    }
  };
}
// Handle runJS commands sent from Flutter Web via postMessage
window.addEventListener('message', function(e) {
  if (e.data && e.data.source === 'mc-eval') {
    try { eval(e.data.code); } catch(err) {
      window.MinecraftViewerBridge.postMessage('ERROR:eval:' + err.message);
    }
  }
});

class MinecraftModelViewer {
  constructor(container, options) {
    this.container = container;
    this.options = options;
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.model = null;
    this.texture = null;
    this.isDragging = false;
    this.prevPos = { x: 0, y: 0 };
    this.prevPinchDist = null;
    this.autoRotate = options.autoRotate !== false;
    this.rotationSpeed = options.rotationSpeed || 0.005;
    this.currentEntityJson = options.entityJson || null;
    this._dirty = true;
    this.isPanning = false;
    this.prevMidPoint = null;
    this.panTargetX = 0;
    this.panTargetY = 0;
  }

  async init() {
    this.setupScene();
    this.setupCamera();
    this.setupRenderer();
    if (this.options.lighting !== false) this.setupLighting();
    this.setupControls();
    if (this.options.textureUrl) await this.loadTexture(this.options.textureUrl);
    if (this.currentEntityJson) this.buildModel(this.currentEntityJson);
    this.animate();
    window.addEventListener('resize', () => this.onWindowResize());
  }

  setupScene() {
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(this.options.backgroundColor || 0x1a1a1a);
  }

  setupCamera() {
    const w = this.container.clientWidth || window.innerWidth;
    const h = this.container.clientHeight || window.innerHeight;
    this.camera = new THREE.PerspectiveCamera(
      this.options.fov || 75, w / h, 0.01, 1000
    );
    this.camera.position.set(0, 0, (this.options.cameraDistance || 80) / 16);
    this.camera.lookAt(0, 0, 0);
  }

  setupRenderer() {
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    const w = this.container.clientWidth || window.innerWidth;
    const h = this.container.clientHeight || window.innerHeight;
    this.renderer.setSize(w, h);
    this.renderer.setPixelRatio(window.devicePixelRatio || 1);
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.container.appendChild(this.renderer.domElement);
  }

  setupLighting() {
    this.scene.add(new THREE.AmbientLight(0xffffff, 0.6));

    const dir = new THREE.DirectionalLight(0xffffff, 0.8);
    dir.position.set(5, 10, 7);
    dir.castShadow = true;
    dir.shadow.camera.near = 0.1;
    dir.shadow.camera.far = 500;
    dir.shadow.camera.left = -10;
    dir.shadow.camera.right = 10;
    dir.shadow.camera.top = 10;
    dir.shadow.camera.bottom = -10;
    this.scene.add(dir);

    const back = new THREE.DirectionalLight(0xffffff, 0.3);
    back.position.set(-5, 5, -7);
    this.scene.add(back);
  }

  setupControls() {
    const el = this.renderer.domElement;

    el.addEventListener('contextmenu', e => e.preventDefault());
    el.addEventListener('mousedown', (e) => {
      if (e.button === 1 || e.button === 2) {
        this.isPanning = true;
      } else {
        this.isDragging = true;
      }
      this.prevPos = { x: e.clientX, y: e.clientY };
    });
    document.addEventListener('mouseup', () => { this.isDragging = false; this.isPanning = false; });
    document.addEventListener('mousemove', (e) => {
      const dx = e.clientX - this.prevPos.x;
      const dy = e.clientY - this.prevPos.y;
      if (this.isPanning) {
        this._applyPan(dx, dy);
      } else if (this.isDragging && this.model) {
        this.model.rotation.y += dx * 0.01;
        this.model.rotation.x += dy * 0.01;
      } else { return; }
      this.prevPos = { x: e.clientX, y: e.clientY };
      this._dirty = true;
    });

    el.addEventListener('touchstart', (e) => {
      e.preventDefault();
      if (e.touches.length === 1) {
        this.isDragging = true;
        this.prevPinchDist = null;
        this.prevMidPoint = null;
        this.prevPos = { x: e.touches[0].clientX, y: e.touches[0].clientY };
      } else if (e.touches.length === 2) {
        this.isDragging = false;
        const dx = e.touches[0].clientX - e.touches[1].clientX;
        const dy = e.touches[0].clientY - e.touches[1].clientY;
        this.prevPinchDist = Math.sqrt(dx * dx + dy * dy);
        this.prevMidPoint = {
          x: (e.touches[0].clientX + e.touches[1].clientX) / 2,
          y: (e.touches[0].clientY + e.touches[1].clientY) / 2
        };
      }
    }, { passive: false });

    el.addEventListener('touchend', (e) => {
      e.preventDefault();
      if (e.touches.length === 0) { this.isDragging = false; this.prevPinchDist = null; this.prevMidPoint = null; }
    }, { passive: false });

    el.addEventListener('touchmove', (e) => {
      e.preventDefault();
      if (e.touches.length === 1 && this.isDragging && this.model) {
        const dx = e.touches[0].clientX - this.prevPos.x;
        const dy = e.touches[0].clientY - this.prevPos.y;
        this.model.rotation.y += dx * 0.01;
        this.model.rotation.x += dy * 0.01;
        this.prevPos = { x: e.touches[0].clientX, y: e.touches[0].clientY };
        this._dirty = true;
      } else if (e.touches.length === 2) {
        const dx = e.touches[0].clientX - e.touches[1].clientX;
        const dy = e.touches[0].clientY - e.touches[1].clientY;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (this.prevPinchDist !== null) {
          const delta = (this.prevPinchDist - dist) * 0.05;
          this.camera.position.z = Math.max(0.5, Math.min(20, this.camera.position.z + delta));
          this._dirty = true;
        }
        this.prevPinchDist = dist;
        const midX = (e.touches[0].clientX + e.touches[1].clientX) / 2;
        const midY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
        if (this.prevMidPoint !== null) {
          this._applyPan(midX - this.prevMidPoint.x, midY - this.prevMidPoint.y);
          this._dirty = true;
        }
        this.prevMidPoint = { x: midX, y: midY };
      }
    }, { passive: false });

    el.addEventListener('wheel', (e) => {
      e.preventDefault();
      this.camera.position.z += e.deltaY * 0.005;
      this.camera.position.z = Math.max(0.5, Math.min(20, this.camera.position.z));
      this._dirty = true;
    }, { passive: false });
  }

  loadTexture(url) {
    return new Promise((resolve) => {
      const loader = new THREE.TextureLoader();
      loader.crossOrigin = 'anonymous';
      loader.load(
        url,
        (tex) => {
          tex.magFilter = THREE.NearestFilter;
          tex.minFilter = THREE.NearestFilter;
          this.texture = tex;
          resolve(tex);
        },
        undefined,
        (err) => { console.warn('Texture load failed:', err); resolve(null); }
      );
    });
  }

  buildModel(entityJson) {
    if (this.model) {
      this.scene.remove(this.model);
      this._disposeGroup(this.model);
      this.model = null;
    }
    this.currentEntityJson = entityJson;
    this.model = new THREE.Group();

    if (entityJson['minecraft:geometry']) {
      this._buildBedrockModel(entityJson);
    } else if (Object.keys(entityJson).some(k => k.startsWith('geometry.'))) {
      this._buildLegacyBedrockModel(entityJson);
    } else {
      const elements = entityJson.elements || [];
      elements.forEach(el => this._addCube(el));
    }

    // Minecraft models face -Z (North); rotate to face camera at +Z
    this.model.rotation.y = Math.PI;

    // 1. Apply scale first (auto-scale uses raw geometry bounds before centering)
    const s = this.options.scale;
    if (s) {
      this.model.scale.set(s, s, s);
    } else {
      const box = new THREE.Box3().setFromObject(this.model);
      const modelH = box.max.y - box.min.y;
      if (modelH > 0.0001) {
        const fovRad = (this.options.fov || 75) * Math.PI / 180;
        const visH = 2 * this.camera.position.z * Math.tan(fovRad / 2);
        const autoS = (visH * 0.8) / modelH;
        this.model.scale.set(autoS, autoS, autoS);
      }
    }

    // 2. Center after scale so bounding box reflects final size
    this._centerModel();

    // 3. Reset camera pan to center on every model load
    this.panTargetX = 0;
    this.panTargetY = 0;
    this.camera.position.x = 0;
    this.camera.position.y = 0;
    this.camera.lookAt(0, 0, 0);

    this.scene.add(this.model);
  }

  _buildBedrockModel(entityJson) {
    const geoList = entityJson['minecraft:geometry'];
    if (!geoList || !geoList.length) return;
    const geo = geoList[0];
    const desc = geo.description || {};
    const texW = desc.texture_width || 64;
    const texH = desc.texture_height || 64;
    this._buildBoneHierarchy(geo.bones || [], texW, texH, false);
  }

  _buildLegacyBedrockModel(entityJson) {
    const geoKey = Object.keys(entityJson).find(k => k.startsWith('geometry.'));
    if (!geoKey) return;
    const geo = entityJson[geoKey];
    const texW = geo.texturewidth || 64;
    const texH = geo.textureheight || 64;
    this._buildBoneHierarchy(geo.bones || [], texW, texH, true);
  }

  // Shared bone-hierarchy builder for both Bedrock formats.
  // isLegacy=true → box UV + bone.mirror; isLegacy=false → per-face UV object
  _buildBoneHierarchy(bones, texW, texH, isLegacy) {
    const boneByName = {};
    const groupByName = {};
    bones.forEach(bone => {
      boneByName[bone.name] = bone;
      groupByName[bone.name] = new THREE.Group();
    });

    // Populate each bone group with its cube meshes
    bones.forEach(bone => {
      const group = groupByName[bone.name];
      const pivot = bone.pivot || [0, 0, 0];
      const mirror = bone.mirror || false;
      (bone.cubes || []).forEach(cube => {
        const mesh = isLegacy
          ? this._legacyCubeMesh(cube, texW, texH, mirror, pivot)
          : this._bedrockCubeMesh(cube, texW, texH, pivot);
        if (mesh) group.add(mesh);
      });
      // Static bone rotation (ZYX order matches Blockbench/Bedrock convention)
      if (bone.rotation) {
        group.rotation.order = 'ZYX';
        group.rotation.x = bone.rotation[0] * Math.PI / 180;
        group.rotation.y = bone.rotation[1] * Math.PI / 180;
        group.rotation.z = bone.rotation[2] * Math.PI / 180;
      }
    });

    // Wire up parent-child relationships and positions
    bones.forEach(bone => {
      const pivot = bone.pivot || [0, 0, 0];
      const group = groupByName[bone.name];
      if (bone.parent && groupByName[bone.parent]) {
        const parentPivot = (boneByName[bone.parent] || {}).pivot || [0, 0, 0];
        group.position.set(
          (pivot[0] - parentPivot[0]) / 16,
          (pivot[1] - parentPivot[1]) / 16,
          (pivot[2] - parentPivot[2]) / 16
        );
        groupByName[bone.parent].add(group);
      } else {
        group.position.set(pivot[0] / 16, pivot[1] / 16, pivot[2] / 16);
        this.model.add(group);
      }
    });
  }

  // Cube mesh for Bedrock 1.10.0 (box UV, bone.mirror)
  _legacyCubeMesh(cube, texW, texH, mirror, bonePivot) {
    const origin  = cube.origin  || [0, 0, 0];
    const size    = cube.size    || [1, 1, 1];
    const inflate = cube.inflate || 0;
    const fw = size[0] + inflate * 2;
    const fh = size[1] + inflate * 2;
    const fd = size[2] + inflate * 2;
    if (fw < 0.001 || fh < 0.001 || fd < 0.001) return null;

    const geometry = new THREE.BoxGeometry(fw / 16, fh / 16, fd / 16);
    const material = (this.texture && Array.isArray(cube.uv) && cube.uv.length === 2)
      ? this._boxUVMaterials(cube.uv, size, texW, texH, mirror)
      : new THREE.MeshPhongMaterial({ color: 0x7EC850, shininess: 0 });

    const mesh = new THREE.Mesh(geometry, material);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    // Position = cube world-space center minus bone pivot
    mesh.position.set(
      (origin[0] + size[0] / 2 - bonePivot[0]) / 16,
      (origin[1] + size[1] / 2 - bonePivot[1]) / 16,
      (origin[2] + size[2] / 2 - bonePivot[2]) / 16
    );
    return mesh;
  }

  // Cube mesh for Bedrock 1.12.0 (per-face UV object)
  _bedrockCubeMesh(cube, texW, texH, bonePivot) {
    const origin = cube.origin || [0, 0, 0];
    const size   = cube.size   || [1, 1, 1];
    const w = size[0] / 16, h = size[1] / 16, d = size[2] / 16;
    if (Math.abs(w) < 0.001 || Math.abs(h) < 0.001 || Math.abs(d) < 0.001) return null;

    const geometry = new THREE.BoxGeometry(Math.abs(w), Math.abs(h), Math.abs(d));
    const material = (this.texture && cube.uv)
      ? this._bedrockFaceMaterials(cube.uv, texW, texH)
      : new THREE.MeshPhongMaterial({ color: 0x7EC850, shininess: 0 });

    const mesh = new THREE.Mesh(geometry, material);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    mesh.position.set(
      (origin[0] + size[0] / 2 - bonePivot[0]) / 16,
      (origin[1] + size[1] / 2 - bonePivot[1]) / 16,
      (origin[2] + size[2] / 2 - bonePivot[2]) / 16
    );
    return mesh;
  }

  _boxUVMaterials(uv, size, texW, texH, mirror) {
    // Box UV net layout for cube [w, h, d] at [u0, v0]:
    //   Row 0: [TOP:d×w at (u0+d,v0)] [BOT:w×d at (u0+d+w,v0)]
    //   Row 1: [W:d×h] [N:w×h] [E:d×h] [S:w×h]
    // Three.js BoxGeometry face order: +x(east), -x(west), +y(up), -y(down), +z(south), -z(north)
    const u0 = uv[0], v0 = uv[1];
    const w = size[0], h = size[1], d = size[2];

    // [x1, y1, x2, y2, flipU]  — UV region in texture pixels
    // East/West/North faces need horizontal flip due to Three.js UV orientation
    const r = mirror ? [
      [u0,         v0+d, u0+d,        v0+d+h, false],  // east  → W region (swapped), no extra flip
      [u0+d+w,     v0+d, u0+d+w+d,   v0+d+h, false],  // west  → E region (swapped), no extra flip
      [u0+d,       v0,   u0+d+w,      v0+d,   true ],  // up,   mirror adds flip
      [u0+d+w,     v0,   u0+d+w+w,   v0+d,   true ],  // down, mirror adds flip
      [u0+d+w+d,   v0+d, u0+d+w+d+w, v0+d+h, true ],  // south,mirror adds flip
      [u0+d,       v0+d, u0+d+w,      v0+d+h, false],  // north,flip cancels
    ] : [
      [u0+d+w,     v0+d, u0+d+w+d,   v0+d+h, true ],  // east  (Three.js UV reversed)
      [u0,         v0+d, u0+d,        v0+d+h, true ],  // west  (Three.js UV reversed)
      [u0+d,       v0,   u0+d+w,      v0+d,   false],  // up
      [u0+d+w,     v0,   u0+d+w+w,   v0+d,   false],  // down
      [u0+d+w+d,   v0+d, u0+d+w+d+w, v0+d+h, false],  // south
      [u0+d,       v0+d, u0+d+w,      v0+d+h, true ],  // north (Three.js UV reversed)
    ];

    return r.map(function(face) {
      const x1 = face[0], y1 = face[1], x2 = face[2], y2 = face[3], fu = face[4];
      const tex = this.texture.clone();
      tex.needsUpdate = true;
      tex.wrapS = THREE.ClampToEdgeWrapping;
      tex.wrapT = THREE.ClampToEdgeWrapping;
      const u1 = x1/texW, u2 = x2/texW;
      let v1 = y1/texH,   v2 = y2/texH;
      const flipV = v2 < v1;
      if (flipV) { const tmp = v1; v1 = v2; v2 = tmp; }
      tex.offset.set(fu ? u2 : u1, 1 - v2);
      tex.repeat.set(fu ? -(u2-u1) : (u2-u1), flipV ? -(v2-v1) : (v2-v1));
      return new THREE.MeshPhongMaterial({ map: tex, shininess: 0, transparent: true, alphaTest: 0.1 });
    }.bind(this));
  }

  _bedrockFaceMaterials(faces, texW, texH) {
    // Three.js BoxGeometry face order: +x, -x, +y, -y, +z, -z
    // Minecraft Bedrock equivalents:  east,west, up,down,south,north
    const order = ['east', 'west', 'up', 'down', 'south', 'north'];
    return order.map(name => {
      const face = faces[name];
      if (!face) return new THREE.MeshPhongMaterial({ color: 0x888888, shininess: 0 });
      const tex = this.texture.clone();
      tex.needsUpdate = true;
      const uv = face.uv || [0, 0];
      const uvSize = face.uv_size || [16, 16];
      const flipU = uvSize[0] < 0;
      const flipV = uvSize[1] < 0;
      const uw = Math.abs(uvSize[0]) / texW;
      const uh = Math.abs(uvSize[1]) / texH;
      const u0 = uv[0] / texW;
      const v0 = uv[1] / texH;
      tex.wrapS = THREE.ClampToEdgeWrapping;
      tex.wrapT = THREE.ClampToEdgeWrapping;
      tex.offset.set(flipU ? u0 + uw : u0, flipV ? 1 - v0 : 1 - v0 - uh);
      tex.repeat.set(flipU ? -uw : uw, flipV ? -uh : uh);
      return new THREE.MeshPhongMaterial({ map: tex, shininess: 0, transparent: true, alphaTest: 0.1 });
    });
  }

  _addCube(element) {
    const from = element.from || [0, 0, 0];
    const to   = element.to   || [16, 16, 16];
    const w = (to[0] - from[0]) / 16;
    const h = (to[1] - from[1]) / 16;
    const d = (to[2] - from[2]) / 16;
    if (w <= 0 || h <= 0 || d <= 0) return;

    const geometry = new THREE.BoxGeometry(w, h, d);
    const material = (this.texture && element.faces)
      ? this._javaFaceMaterials(element.faces)
      : new THREE.MeshPhongMaterial({ color: 0x7EC850, shininess: 0 });

    const mesh = new THREE.Mesh(geometry, material);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    mesh.position.set(
      (from[0] + to[0]) / 2 / 16,
      (from[1] + to[1]) / 2 / 16,
      (from[2] + to[2]) / 2 / 16
    );
    if (element.rotation) {
      this.model.add(this._makePivot(mesh, element.rotation));
    } else {
      this.model.add(mesh);
    }
  }

  _javaFaceMaterials(faces) {
    // Three.js BoxGeometry face order: +x, -x, +y, -y, +z, -z
    // Minecraft Java equivalents:     east,west, up,down,south,north
    const order = ['east', 'west', 'up', 'down', 'south', 'north'];
    const iw = (this.texture.image && this.texture.image.width)  || 64;
    const ih = (this.texture.image && this.texture.image.height) || 64;
    return order.map(name => {
      const face = faces[name];
      if (!face) return new THREE.MeshPhongMaterial({ color: 0x888888, shininess: 0 });
      const tex = this.texture.clone();
      tex.needsUpdate = true;
      const uv = face.uv;
      if (uv && uv.length >= 4) {
        const u1 = uv[0] / iw, v1 = uv[1] / ih;
        const u2 = uv[2] / iw, v2 = uv[3] / ih;
        tex.offset.set(u1, 1 - v2);
        tex.repeat.set(u2 - u1, v2 - v1);
        tex.wrapS = THREE.ClampToEdgeWrapping;
        tex.wrapT = THREE.ClampToEdgeWrapping;
      }
      return new THREE.MeshPhongMaterial({ map: tex, shininess: 0, transparent: true, alphaTest: 0.1 });
    });
  }

  _makePivot(mesh, rotation) {
    const origin = rotation.origin || [8, 8, 8];
    const angle  = ((rotation.angle || 0) * Math.PI) / 180;
    const axis   = rotation.axis || 'y';

    const ox = origin[0] / 16, oy = origin[1] / 16, oz = origin[2] / 16;
    const pivot = new THREE.Group();
    pivot.position.set(ox, oy, oz);
    mesh.position.x -= ox;
    mesh.position.y -= oy;
    mesh.position.z -= oz;

    if (axis === 'x') pivot.rotation.x = angle;
    else if (axis === 'y') pivot.rotation.y = angle;
    else if (axis === 'z') pivot.rotation.z = angle;

    pivot.add(mesh);
    return pivot;
  }

  _applyPan(dx, dy) {
    const speed = this.camera.position.z * 0.002;
    this.panTargetX -= dx * speed;
    this.panTargetY += dy * speed;
    this.camera.position.x = this.panTargetX;
    this.camera.position.y = this.panTargetY;
    this.camera.lookAt(this.panTargetX, this.panTargetY, 0);
  }

  _centerModel() {
    const box = new THREE.Box3().setFromObject(this.model);
    const c = box.getCenter(new THREE.Vector3());
    this.model.position.set(-c.x, -c.y, -c.z);
  }

  _disposeGroup(group) {
    group.traverse(obj => {
      if (obj.geometry) obj.geometry.dispose();
      if (obj.material) {
        const mats = Array.isArray(obj.material) ? obj.material : [obj.material];
        mats.forEach(m => { if (m.map) m.map.dispose(); m.dispose(); });
      }
    });
  }

  animate() {
    requestAnimationFrame(() => this.animate());
    if (this.autoRotate && !this.isDragging && this.model) {
      this.model.rotation.y += this.rotationSpeed;
      this._dirty = true;
    }
    if (!this._dirty) return;
    this._dirty = false;
    try {
      this.renderer.render(this.scene, this.camera);
    } catch(e) {
      if (window.MinecraftViewerBridge) window.MinecraftViewerBridge.postMessage('ERROR:render:' + e.message);
    }
  }

  onWindowResize() {
    const w = this.container.clientWidth || window.innerWidth;
    const h = this.container.clientHeight || window.innerHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this._dirty = true;
  }

  updateModel(json)  { this.buildModel(json); this._dirty = true; }
  updateTexture(url) {
    this.loadTexture(url).then(() => {
      if (this.currentEntityJson) this.buildModel(this.currentEntityJson);
      this._dirty = true;
    });
  }
  setScale(v)          { if (this.model) { this.model.scale.set(v, v, v); } this.options.scale = v; this._dirty = true; }
  setCameraDistance(d) { this.camera.position.z = d / 16; this._dirty = true; }
  setAutoRotate(v)     { this.autoRotate = v; this._dirty = true; }
}

// ─── global API ───────────────────────────────────────────────────────────────

let _viewer = null;

window.loadModel = function(options) {
  try {
    const container = document.getElementById('viewer');
    _viewer = new MinecraftModelViewer(container, options);
    _viewer.init()
      .then(() => { if (window.MinecraftViewerBridge) window.MinecraftViewerBridge.postMessage('MODEL_LOADED'); })
      .catch(err => { if (window.MinecraftViewerBridge) window.MinecraftViewerBridge.postMessage('ERROR:' + err.message); });
  } catch (e) {
    if (window.MinecraftViewerBridge) window.MinecraftViewerBridge.postMessage('ERROR:' + e.message);
  }
};

window.updateModel        = json => { if (_viewer) _viewer.updateModel(json); };
window.updateTexture      = url  => { if (_viewer) _viewer.updateTexture(url); };
window.setScale           = v    => { if (_viewer) _viewer.setScale(v); };
window.setCameraDistance  = d    => { if (_viewer) _viewer.setCameraDistance(d); };
window.setAutoRotate      = v    => { if (_viewer) _viewer.setAutoRotate(v); };
''';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _controller.buildWidget(),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        if (_error != null)
          Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
