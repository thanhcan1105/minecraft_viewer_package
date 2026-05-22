import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ViewerController {
  late WebViewController _ctrl;

  Future<void> init(String html, void Function(String) onMessage) async {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'MinecraftViewerBridge',
        onMessageReceived: (msg) => onMessage(msg.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => onMessage('PAGE_READY'),
        onWebResourceError: (e) => onMessage('ERROR:WebView: ${e.description}'),
      ))
      ..loadHtmlString(html);
  }

  Future<void> runJS(String js) => _ctrl.runJavaScript(js);
  Widget buildWidget() => WebViewWidget(controller: _ctrl);
  void dispose() {}
}
