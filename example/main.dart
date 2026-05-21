import 'package:flutter/material.dart';
import 'package:minecraft_viewer/minecraft_viewer.dart';

void main() => runApp(const MinecraftViewerExampleApp());

class MinecraftViewerExampleApp extends StatelessWidget {
  const MinecraftViewerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minecraft Viewer Example',
      theme: ThemeData.dark(),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _viewerKey = GlobalKey<MinecraftViewerState>();

  String _selectedModel = 'steve';
  double _scale = 1.0;
  double _cameraDistance = 80.0;
  bool _autoRotate = true;
  String? _statusMessage;

  Map<String, dynamic> get _currentModelJson {
    switch (_selectedModel) {
      case 'creeper':
        return MinecraftUtils.createCreeperModel().toJson();
      case 'cube':
        return MinecraftUtils.createSimpleCube(size: 12).toJson();
      default:
        return MinecraftUtils.createSteveModel().toJson();
    }
  }

  void _onModelSelected(String? val) {
    if (val == null) return;
    setState(() => _selectedModel = val);
    _viewerKey.currentState?.updateModel(_currentModelJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Minecraft Viewer'),
        backgroundColor: const Color(0xFF1a1a1a),
        actions: [
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(_statusMessage!,
                    style: const TextStyle(color: Colors.greenAccent)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MinecraftViewer(
              key: _viewerKey,
              entityJson: _currentModelJson,
              scale: _scale,
              cameraDistance: _cameraDistance,
              autoRotate: _autoRotate,
              backgroundColor: 0x1a1a2e,
              lighting: true,
              debugMode: true,
              onModelLoaded: () {
                if (mounted) {
                  setState(() => _statusMessage = 'Model loaded ✓');
                  Future.delayed(const Duration(seconds: 2),
                      () { if (mounted) setState(() => _statusMessage = null); });
                }
              },
              onError: (err) {
                if (mounted) setState(() => _statusMessage = 'Error: $err');
              },
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: const Color(0xFF222222),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Model selector + auto-rotate toggle
          Row(
            children: [
              const Text('Model:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedModel,
                dropdownColor: const Color(0xFF333333),
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'steve', child: Text('Steve')),
                  DropdownMenuItem(value: 'creeper', child: Text('Creeper')),
                  DropdownMenuItem(value: 'cube', child: Text('Cube')),
                ],
                onChanged: _onModelSelected,
              ),
              const Spacer(),
              const Text('Auto-rotate',
                  style: TextStyle(color: Colors.white70)),
              Switch(
                value: _autoRotate,
                activeColor: Colors.greenAccent,
                onChanged: (val) {
                  setState(() => _autoRotate = val);
                  _viewerKey.currentState?.setAutoRotate(val);
                },
              ),
            ],
          ),
          // Scale slider
          Row(
            children: [
              const SizedBox(
                  width: 70,
                  child: Text('Scale',
                      style: TextStyle(color: Colors.white70))),
              Expanded(
                child: Slider(
                  value: _scale,
                  min: 0.1,
                  max: 3.0,
                  divisions: 29,
                  activeColor: Colors.greenAccent,
                  onChanged: (val) {
                    setState(() => _scale = val);
                    _viewerKey.currentState?.setScale(val);
                  },
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  _scale.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          // Camera distance slider
          Row(
            children: [
              const SizedBox(
                  width: 70,
                  child: Text('Camera',
                      style: TextStyle(color: Colors.white70))),
              Expanded(
                child: Slider(
                  value: _cameraDistance,
                  min: 10,
                  max: 200,
                  divisions: 19,
                  activeColor: Colors.greenAccent,
                  onChanged: (val) {
                    setState(() => _cameraDistance = val);
                    _viewerKey.currentState?.setCameraDistance(val);
                  },
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  _cameraDistance.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
