import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:haul_alerts/services/js_stub.dart' if (dart.library.js) 'dart:js' as js;
import '../theme/design_system.dart';
import '../core/constants.dart';
import '../services/google_maps_loader.dart';

/// A custom Location Search field that handles Web CORS by using the Native 
/// Google Maps JS SDK and Mobile by making direct API calls.
class LocationSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color iconColor;
  final String hintText;
  final Function(String description, double? lat, double? lng) onSelected;

  const LocationSearchField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.hintText,
    required this.onSelected,
  });

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  final List<dynamic> _predictions = [];
  Timer? _debounce;
  bool _isSearching = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (value.isNotEmpty) {
        _search(value);
      } else {
        setState(() => _predictions.clear());
        _removeOverlay();
      }
    });
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    
    try {
      if (kIsWeb) {
        await _ensureMapsLoaded();
        await _searchWeb(query);
      } else {
        // Native Dart implementation for mobile
        await _getSuggestions(query);
      }
    } catch (e) {
      debugPrint('DEBUG: Search Error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _ensureMapsLoaded() async {
    await GoogleMapsLoader.ensureLoaded();
  }

  /// Web Search using Native Google Maps JS SDK (Bypasses CORS entirely)
  Future<void> _searchWeb(String query) async {
    final completer = Completer<void>();
    
    // Call the JS Autocomplete Service
    try {
       js.context.callMethod('eval', ["""
        (function(query) {
          var service = new google.maps.places.AutocompleteService();
          service.getPlacePredictions({ input: query }, function(predictions, status) {
            if (status !== google.maps.places.PlacesServiceStatus.OK) {
              window.onGooglePredictions([]);
              return;
            }
            window.onGooglePredictions(predictions);
          });
        })('$query')
      """]);

      js.context['onGooglePredictions'] = js.allowInterop((results) {
        setState(() {
          _predictions.clear();
          if (results != null) {
            _predictions.addAll(results as List<dynamic>);
          }
        });
        _showOverlay();
        completer.complete();
      });
    } catch (e) {
      completer.completeError(e);
    }
    
    return completer.future;
  }

  /// Native Dart implementation for Mobile (Google Places Autocomplete API)
  Future<void> _getSuggestions(String query) async {
    try {
      final String apiKey = dotenv.env['ANDROID_MAPS_KEY'] ?? AppConstants.googleMapsApiKey;
      final String url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&types=(cities)'
          '&key=$apiKey';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Android-Package': 'com.jh311.haul_alerts',
          'X-Android-Cert': '86A5EF10AE192D3097FBFD6478648A862CC9E909',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('DEBUG: API Predictions Found: ${data['predictions']?.length ?? 0}');
        
        if (data['status'] == 'OK') {
          setState(() {
            _predictions.clear();
            _predictions.addAll(data['predictions']);
          });
          _showOverlay();
        } else {
          debugPrint('DEBUG: API Error Status: ${data['status']}');
          print('DEBUG: Raw Response Body: ${response.body}');
        }
      } else {
        print('DEBUG: HTTP Error Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('DEBUG: Mobile Search API Error: $e');
    }
  }

  void _handlePredictionClick(dynamic prediction) async {
    final description = prediction['description'];
    final placeId = prediction['place_id'];
    
    widget.controller.text = description;
    _removeOverlay();

    // Fetch Details for Lat/Lng
    try {
      double? lat;
      double? lng;

      if (kIsWeb) {
        final completer = Completer<void>();
        js.context.callMethod('eval', ["""
          (function(placeId) {
            var service = new google.maps.places.PlacesService(document.createElement('div'));
            service.getDetails({ placeId: placeId, fields: ['geometry'] }, function(place, status) {
              if (status === google.maps.places.PlacesServiceStatus.OK) {
                window.onGooglePlaceDetails(place.geometry.location.lat(), place.geometry.location.lng());
              }
            });
          })('$placeId')
        """]);

        js.context['onGooglePlaceDetails'] = js.allowInterop((pLat, pLng) {
          lat = (pLat as num).toDouble();
          lng = (pLng as num).toDouble();
          completer.complete();
        });
        await completer.future;
      } else {
        // Native Dart implementation for Mobile (Google Places Details API)
        final String apiKey = dotenv.env['ANDROID_MAPS_KEY'] ?? AppConstants.googleMapsApiKey;
        final String url = 'https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=$placeId'
            '&fields=geometry'
            '&key=$apiKey';

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'X-Android-Package': 'com.jh311.haul_alerts',
            'X-Android-Cert': '86A5EF10AE192D3097FBFD6478648A862CC9E909',
          },
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('DEBUG: Details Data being parsed: $data');
          if (data['status'] == 'OK' && data['result'] != null && data['result']['geometry'] != null) {
            final loc = data['result']['geometry']['location'];
            lat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
            lng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
          }
        } else {
          print('DEBUG: Details HTTP Error Body: ${response.body}');
        }
      }

      widget.onSelected(description, lat, lng);
    } catch (e) {
      debugPrint('DEBUG: Details Error: $e');
      widget.onSelected(description, null, null);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    if (_predictions.isEmpty) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            color: AppDesignSystem.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _predictions.length,
                separatorBuilder: (_, __) => Divider(color: AppDesignSystem.outline.withOpacity(0.1), height: 1),
                itemBuilder: (context, index) {
                  final p = _predictions[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: AppDesignSystem.outline, size: 20),
                    title: Text(
                      p['description'],
                      style: AppDesignSystem.bodyMedium.copyWith(color: AppDesignSystem.onSurface),
                    ),
                    onTap: () => _handlePredictionClick(p),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: TextFormField(
            controller: widget.controller,
            onChanged: _onChanged,
            style: AppDesignSystem.bodyLarge,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(widget.icon, color: widget.iconColor),
              suffixIcon: _isSearching 
                ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
            ),
          ),
        ),
      ],
    );
  }
}
