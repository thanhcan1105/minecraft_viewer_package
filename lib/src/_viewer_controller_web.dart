import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class ViewerController {
  late html.IFrameElement _iframe;
  final String _viewId;
  StreamSubscription<html.MessageEvent>? _msgSub;

  ViewerController()
      : _viewId = 'mc-viewer-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> init(String htmlContent, void Function(String) onMessage) async {
    _iframe = html.IFrameElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..srcdoc = htmlContent;

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (_) => _iframe);

    // Only handle messages from our own iframe (supports multiple instances)
    _msgSub = html.window.onMessage.listen((event) {
      if (event.source != _iframe.contentWindow) return;
      final data = event.data;
      if (data is Map && data['source'] == 'mc-viewer') {
        onMessage(data['data'] as String? ?? '');
      }
    });

    // PAGE_READY fires after Three.js CDN script has loaded and executed
    _iframe.onLoad.first.then((_) => onMessage('PAGE_READY'));
  }

  Future<void> runJS(String js) async {
    _iframe.contentWindow?.postMessage({'source': 'mc-eval', 'code': js}, '*');
  }

  Widget buildWidget() => HtmlElementView(viewType: _viewId);

  void dispose() => _msgSub?.cancel();
}
