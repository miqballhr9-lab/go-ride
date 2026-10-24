import 'dart:async';
import 'dart:js_interop';

import 'package:latlong2/latlong.dart';
import 'package:web/web.dart' as web;

/// Browser se user ki jagah (user ijazat de to).
Future<LatLng?> currentLocation() {
  final done = Completer<LatLng?>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition p) {
        if (!done.isCompleted) done.complete(LatLng(p.coords.latitude, p.coords.longitude));
      }).toJS,
      ((web.GeolocationPositionError _) {
        if (!done.isCompleted) done.complete(null);
      }).toJS,
    );
  } catch (_) {
    if (!done.isCompleted) done.complete(null);
  }
  return done.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
}
