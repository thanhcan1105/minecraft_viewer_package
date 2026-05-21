import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MinecraftViewer extends StatefulWidget {
  final String entityJson;
  final String? textureBase64;
  final double scale;
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
    this.scale = 1.0,
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
  late WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'MinecraftViewerBridge',
        onMessageReceived: (message) =>
            _handleJavaScriptMessage(message.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _loadModel(),
        onWebResourceError: (error) =>
            _handleError('WebView error: ${error.description}'),
      ))
      ..loadHtmlString(_getHtmlContent());
  }

  void _handleJavaScriptMessage(String message) {
    if (widget.debugMode) debugPrint('MinecraftViewer JS: $message');
    if (message == 'MODEL_LOADED') {
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
    try {
      final entityMap = jsonDecode(widget.entityJson) as Map<String, dynamic>;
      final options = <String, dynamic>{
        'entityJson': entityMap,
        'scale': widget.scale,
        'cameraDistance': widget.cameraDistance,
        'rotationSpeed': widget.rotationSpeed,
        'autoRotate': widget.autoRotate,
        'backgroundColor': widget.backgroundColor,
        'lighting': widget.lighting,
        'fov': widget.fov,
        if (widget.textureBase64 != null)
          'textureUrl': 'data:image/png;base64,${widget.textureBase64}',
      };
      await _controller
          .runJavaScript('window.loadModel(${jsonEncode(options)});');
    } catch (e) {
      _handleError(e.toString());
    }
  }

  // Public control methods — access via GlobalKey<MinecraftViewerState>

  void updateModel(String entityJson) {
    final entityMap = jsonDecode(entityJson) as Map<String, dynamic>;
    _controller.runJavaScript('window.updateModel(${jsonEncode(entityMap)});');
  }

  void updateTexture(String base64) {
    final dataUri = 'data:image/png;base64,$base64';
    _controller.runJavaScript('window.updateTexture(${jsonEncode(dataUri)});');
  }

  void setScale(double scale) {
    _controller.runJavaScript('window.setScale($scale);');
  }

  void setCameraDistance(double distance) {
    _controller.runJavaScript('window.setCameraDistance($distance);');
  }

  void setAutoRotate(bool autoRotate) {
    _controller.runJavaScript('window.setAutoRotate($autoRotate);');
  }

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

    el.addEventListener('mousedown', (e) => {
      this.isDragging = true;
      this.prevPos = { x: e.clientX, y: e.clientY };
    });
    document.addEventListener('mouseup', () => { this.isDragging = false; });
    document.addEventListener('mousemove', (e) => {
      if (!this.isDragging || !this.model) return;
      const dx = e.clientX - this.prevPos.x;
      const dy = e.clientY - this.prevPos.y;
      this.model.rotation.y += dx * 0.01;
      this.model.rotation.x += dy * 0.01;
      this.prevPos = { x: e.clientX, y: e.clientY };
    });

    el.addEventListener('touchstart', (e) => {
      e.preventDefault();
      if (e.touches.length === 1) {
        this.isDragging = true;
        this.prevPinchDist = null;
        this.prevPos = { x: e.touches[0].clientX, y: e.touches[0].clientY };
      } else if (e.touches.length === 2) {
        this.isDragging = false;
        const dx = e.touches[0].clientX - e.touches[1].clientX;
        const dy = e.touches[0].clientY - e.touches[1].clientY;
        this.prevPinchDist = Math.sqrt(dx * dx + dy * dy);
      }
    }, { passive: false });

    el.addEventListener('touchend', (e) => {
      e.preventDefault();
      if (e.touches.length === 0) { this.isDragging = false; this.prevPinchDist = null; }
    }, { passive: false });

    el.addEventListener('touchmove', (e) => {
      e.preventDefault();
      if (e.touches.length === 1 && this.isDragging && this.model) {
        const dx = e.touches[0].clientX - this.prevPos.x;
        const dy = e.touches[0].clientY - this.prevPos.y;
        this.model.rotation.y += dx * 0.01;
        this.model.rotation.x += dy * 0.01;
        this.prevPos = { x: e.touches[0].clientX, y: e.touches[0].clientY };
      } else if (e.touches.length === 2) {
        const dx = e.touches[0].clientX - e.touches[1].clientX;
        const dy = e.touches[0].clientY - e.touches[1].clientY;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (this.prevPinchDist !== null) {
          const delta = (this.prevPinchDist - dist) * 0.05;
          this.camera.position.z = Math.max(0.5, Math.min(20, this.camera.position.z + delta));
        }
        this.prevPinchDist = dist;
      }
    }, { passive: false });

    el.addEventListener('wheel', (e) => {
      e.preventDefault();
      this.camera.position.z += e.deltaY * 0.005;
      this.camera.position.z = Math.max(0.5, Math.min(20, this.camera.position.z));
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

    const elements = entityJson.elements || [];
    elements.forEach(el => this._addCube(el));

    this._centerModel();
    const s = this.options.scale || 1.0;
    this.model.scale.set(s, s, s);
    this.scene.add(this.model);
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
      ? this._faceMaterials(element.faces)
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

  _faceMaterials(faces) {
    // Three.js BoxGeometry face order: +x, -x, +y, -y, +z, -z
    // Minecraft equivalents:          east,west, up,down,south,north
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
      return new THREE.MeshPhongMaterial({
        map: tex, shininess: 0, transparent: true, alphaTest: 0.1
      });
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
    }
    this.renderer.render(this.scene, this.camera);
  }

  onWindowResize() {
    const w = this.container.clientWidth || window.innerWidth;
    const h = this.container.clientHeight || window.innerHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
  }

  updateModel(json)  { this.buildModel(json); }
  updateTexture(url) {
    this.loadTexture(url).then(() => {
      if (this.currentEntityJson) this.buildModel(this.currentEntityJson);
    });
  }
  setScale(v)            { if (this.model) this.model.scale.set(v, v, v); this.options.scale = v; }
  setCameraDistance(d)   { this.camera.position.z = d / 16; }
  setAutoRotate(v)       { this.autoRotate = v; }
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
        WebViewWidget(controller: _controller),
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
