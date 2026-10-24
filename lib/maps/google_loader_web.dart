import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Google key ghalat ho to Google yeh global function chalata hai.
@JS('gm_authFailure')
external set _gmAuthFailure(JSFunction f);

/// Google Maps JavaScript API ka script page mein daal kar uske load hone ka intezar.
/// English naam, Pakistan region (inDrive jaisa).
Future<bool> loadGoogleMaps(String key, {void Function()? onAuthFailure}) {
  final done = Completer<bool>();
  if (onAuthFailure != null) _gmAuthFailure = onAuthFailure.toJS;
  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..src = 'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeComponent(key)}&language=en&region=PK'
    ..async = true;
  script.onload = ((web.Event _) {
    if (!done.isCompleted) done.complete(true);
  }).toJS;
  script.onerror = ((web.Event _) {
    if (!done.isCompleted) done.complete(false);
  }).toJS;
  web.document.head!.append(script);
  return done.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
}
