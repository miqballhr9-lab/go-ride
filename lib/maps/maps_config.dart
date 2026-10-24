import 'package:flutter/foundation.dart';

import 'google_loader_stub.dart' if (dart.library.js_interop) 'google_loader_web.dart';

/// Google Maps ki key build ke waqt di jati hai:
///   flutter build web --dart-define=GOOGLE_MAPS_API_KEY=xxxx
/// Key na ho (ya load na ho) to app CARTO wala English map dikhata hai.
const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

class MapConfig {
  static bool _loaded = false;

  /// Key ghalat nikle (Google auth fail) to true; map CARTO pe wapas chala jata hai.
  static final googleFailed = ValueNotifier(false);

  static bool get useGoogle => _loaded && !googleFailed.value;

  /// App shuru hone se pehle Google Maps load karo (sirf web; mobile pe abhi CARTO).
  static Future<void> init() async {
    if (googleMapsApiKey.isEmpty) return;
    _loaded = await loadGoogleMaps(googleMapsApiKey, onAuthFailure: () => googleFailed.value = true);
  }
}
