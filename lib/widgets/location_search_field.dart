import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:haul_alerts/services/js_stub.dart' if (dart.library.js) 'dart:js' as js;
import '../theme/design_system.dart';
import '../core/constants.dart';
import '../services/google_maps_loader.dart';

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
        await GoogleMapsLoader.ensureLoaded();
        await _searchWeb(query);
      } else {
        await _getSuggestions(query);
      }
    } catch (e) {
      debugPrint('DEBUG: Search Error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _searchWeb(String query) async {
    final completer = Completer<void>();
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
        if (data['status'] == 'OK') {
          setState(() {
            _predictions.clear();
            _predictions.addAll(data['predictions']);
          });
          _showOverlay();
        }
      }
    } catch (e) {
      debugPrint('Mobile Search API Error: $e');
    }
  }

  void _handlePredictionClick(dynamic prediction) async {
    final description = prediction['description'];
    final placeId = prediction['place_id'];
    
    widget.controller.text = description;
    _removeOverlay();

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
          if (data['status'] == 'OK' && data['result'] != null && data['result']['geometry'] != null) {
            final loc = data['result']['geometry']['location'];
            lat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
            lng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      widget.onSelected(description, lat, lng);
    } catch (e) {
      debugPrint('Details Error: $e');
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
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333333)),
              boxShadow: [
                BoxShadow(color: CupertinoColors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _predictions.length,
                separatorBuilder: (_, __) => Container(height: 1, color: const Color(0xFF333333)),
                itemBuilder: (context, index) {
                  final p = _predictions[index];
                  return CupertinoListTile(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: const Icon(CupertinoIcons.location, color: CupertinoColors.systemGrey, size: 20),
                    title: Text(
                      p['description'],
                      style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
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
          child: CupertinoTextField(
            controller: widget.controller,
            onChanged: _onChanged,
            placeholder: widget.hintText,
            placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey),
            style: const TextStyle(color: CupertinoColors.white),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(widget.icon, color: widget.iconColor, size: 20),
            ),
            suffix: _isSearching 
              ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: CupertinoActivityIndicator(radius: 8),
                )
              : null,
          ),
        ),
      ],
    );
  }
}
