import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:js' as js;
import '../core/constants.dart';

class GoogleMapsLoader {
  static Future<void>? _loadFuture;

  static Future<void> ensureLoaded() async {
    if (!kIsWeb) return;
    
    // Check if google.maps is already defined
    final bool isLoaded = js.context.hasProperty('google') && 
                         (js.context['google'] as js.JsObject).hasProperty('maps');
    
    if (isLoaded) return;

    if (_loadFuture != null) return _loadFuture;

    final completer = Completer<void>();
    _loadFuture = completer.future;

    final key = AppConstants.googleMapsApiKey;
    
    js.context.callMethod('eval', ["""
      (function(key) {
        if (window.google && window.google.maps) return;
        var script = document.createElement('script');
        script.src = 'https://maps.googleapis.com/maps/api/js?key=' + key + '&libraries=places';
        script.async = true;
        script.defer = true;
        script.onload = function() { if (window.onMapsLoaded) window.onMapsLoaded(); };
        document.head.appendChild(script);
      })('$key')
    """]);

    js.context['onMapsLoaded'] = () {
      completer.complete();
    };

    return _loadFuture!.timeout(const Duration(seconds: 15), onTimeout: () {
      _loadFuture = null; // Allow retry on timeout
      throw TimeoutException('Google Maps SDK load timed out');
    });
  }
}
