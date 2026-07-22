import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Registers `dart_bclibc`'s web platform with Flutter's plugin registry.
///
/// This package doesn't use platform channels on web — `AsyncCalculator`
/// talks to the wasm engine directly via `dart:js_interop` — so there's
/// nothing to wire up here. This class exists only so the `web:` entry in
/// `pubspec.yaml`'s `flutter.plugin.platforms` resolves to a real
/// `pluginClass`, which is what makes pub.dev list Web as a supported
/// platform for this plugin.
class BclibcWebPlugin {
  static void registerWith(Registrar registrar) {}
}
