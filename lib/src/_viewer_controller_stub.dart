import 'package:flutter/widgets.dart';

class ViewerController {
  Future<void> init(String html, void Function(String) onMessage) async {}
  Future<void> runJS(String js) async {}
  Widget buildWidget() => const SizedBox.shrink();
  void dispose() {}
}
