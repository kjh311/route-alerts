import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/design_system.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import 'create_route_screen.dart';
import '../services/weather_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_service.dart';

class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({super.key});

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends State<MyRoutesScreen> {
  final RouteService _routeService = RouteService();
  late Future<List<RouteModel>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _routeService.fetchRoutes();
  }

  void _reloadRoutes() {
    setState(() {
      _routesFuture = _routeService.fetchRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY ROUTES'),
        actions: [
          IconButton(
            onPressed: _reloadRoutes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<RouteModel>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text('Failed to load routes', style: AppDesignSystem.headlineMedium),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          final routes = snapshot.data ?? [];

          if (routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: AppDesignSystem.outline.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No routes saved yet', style: AppDesignSystem.headlineMedium.copyWith(color: AppDesignSystem.outline)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateRouteScreen()),
                      );
                      _reloadRoutes();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('CREATE FIRST ROUTE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.primary,
                      foregroundColor: AppDesignSystem.onPrimary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDesignSystem.marginEdge),
            itemCount: routes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _RouteCard(
                route: routes[index],
                onUpdate: _reloadRoutes,
              );
            },
          );
        },
      ),
    );
  }
}

class _RouteCard extends StatefulWidget {
  final RouteModel route;
  final VoidCallback onUpdate;

  const _RouteCard({required this.route, required this.onUpdate});

  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  final WeatherService _weatherService = WeatherService();
  bool _isAuditing = false;

  bool get _isActiveToday {
    final now = DateTime.now();
    final dayName = DateFormat('EEE').format(now); // Mon, Tue, etc.
    return widget.route.drivingDays.contains(dayName);
  }

  Future<void> _getRouteWeather() async {
    setState(() => _isAuditing = true);

    try {
      final audit = await _weatherService.auditRouteWeather(
        departureTime: widget.route.departureTime,
        waypoints: List<Map<String, dynamic>>.from(widget.route.waypoints),
        shiftDurationHours: widget.route.shiftDuration,
        totalDistanceMiles: widget.route.waypoints.last['distance_from_origin_miles'] ?? 0,
      );

      // Generate AI Summary
      try {
        final aiBriefing = await AIService().generateWeatherBriefing(audit);
        audit['ai_briefing'] = aiBriefing;
      } catch (aiError) {
        debugPrint('DEBUG: AI Briefing generation failed: $aiError');
      }

      // Update Supabase
      await Supabase.instance.client
          .from('routes')
          .update({'weather_condition': audit})
          .eq('id', widget.route.id!);

      widget.onUpdate(); // Refresh the list to show new data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Weather Audit Failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAuditing = false);
      }
    }
  }

  String? _parseBriefingSummary() {
    final audit = widget.route.weatherCondition;
    if (audit == null) return null;

    // Use AI briefing if available
    if (audit['ai_briefing'] != null) {
      return audit['ai_briefing'] as String;
    }

    final alerts = audit['alerts'] as List<dynamic>?;
    if (alerts == null || alerts.isEmpty) return null;

    // Find the max peak wind across all alerts
    Map<String, dynamic>? peak;
    for (var a in alerts) {
      if (peak == null || (a['peak_wind'] ?? 0) > (peak['peak_wind'] ?? 0)) {
        peak = a;
      }
    }

    if (peak == null) return 'Audit complete. No significant hazards found.';

    final peakWind = peak['peak_wind'];
    final city = peak['city'];
    final severity = audit['status'];
    final peakTime = peak['peak_time'] != null 
        ? DateFormat('h:mm a').format(DateTime.parse(peak['peak_time']))
        : 'Unknown Time';
    final date = DateFormat('MMM d').format(DateTime.now());

    return 'Weather Audit for $date: Peak wind of ${peakWind.round()} mph in $city at $peakTime. Status: $severity.';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d').format(widget.route.departureTime).toUpperCase();
    final timeStr = DateFormat('hh:mm a').format(widget.route.departureTime).toUpperCase();
    final summary = _parseBriefingSummary();

    return Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
        border: Border.all(
          color: _isActiveToday ? AppDesignSystem.primary.withOpacity(0.5) : AppDesignSystem.outline.withOpacity(0.2),
          width: _isActiveToday ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigable Area
          InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateRouteScreen(initialRoute: widget.route),
                ),
              );
              widget.onUpdate();
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDesignSystem.radiusDefault)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isActiveToday)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ACTIVE TODAY',
                          style: AppDesignSystem.labelBold.copyWith(color: AppDesignSystem.primary, fontSize: 10),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.route.originName} →',
                              style: AppDesignSystem.labelBold.copyWith(color: AppDesignSystem.outline, fontSize: 10),
                            ),
                            Text(
                              widget.route.destinationName,
                              style: AppDesignSystem.headlineLarge.copyWith(color: AppDesignSystem.primary, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          summary != null ? Icons.check_circle_outline : Icons.wb_sunny_outlined, 
                          color: summary != null ? Colors.green : Colors.grey, 
                          size: 20
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: AppDesignSystem.secondary),
                      const SizedBox(width: 8),
                      Text(
                        '$dateStr • $timeStr',
                        style: AppDesignSystem.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppDesignSystem.outline),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Safety Briefing Area (Available for all routes, highlighted for active)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isActiveToday ? AppDesignSystem.primary.withOpacity(0.05) : AppDesignSystem.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
                border: Border.all(
                  color: _isActiveToday ? AppDesignSystem.primary.withOpacity(0.2) : AppDesignSystem.outline.withOpacity(0.1)
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('SAFETY BRIEFING', style: AppDesignSystem.labelBold.copyWith(color: AppDesignSystem.outline, fontSize: 10)),
                      if (_isActiveToday) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('PRIORITY', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isAuditing)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.primary),
                      ),
                    )
                  else if (summary != null)
                    Text(
                      summary,
                      style: AppDesignSystem.bodyMedium.copyWith(
                        color: summary.contains('Critical') ? Colors.redAccent : AppDesignSystem.onSurface,
                        fontWeight: summary.contains('Critical') ? FontWeight.bold : FontWeight.normal,
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: _getRouteWeather,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.primary,
                        foregroundColor: AppDesignSystem.onPrimary,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('GET ROUTE WEATHER'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
