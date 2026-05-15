import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/design_system.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import 'create_route_screen.dart';
import '../services/weather_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';

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

  void _reloadRoutes() async {
    setState(() {
      _routesFuture = _routeService.fetchRoutes();
    });
    // Ensure background alarms are synced with latest weather audits
    await NotificationService().refreshScheduledNotifications();
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
      body: SafeArea(
        child: FutureBuilder<List<RouteModel>>(
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
    ));
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
  bool _showAiSummary = false;

  bool get _isActiveToday {
    final now = DateTime.now();
    // Dart: 1 (Mon) - 7 (Sun)
    // Supabase: 0 (Mon) - 6 (Sun)
    final dayNum = now.weekday - 1; 
    return widget.route.drivingDays.contains(dayNum);
  }

  Future<void> _toggleActive(bool value) async {
    try {
      await Supabase.instance.client
          .from('routes')
          .update({'is_active': value})
          .eq('id', widget.route.id!);
      
      // Force refresh of all background alarms
      await NotificationService().refreshScheduledNotifications();
      
      widget.onUpdate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteRoute() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppDesignSystem.surfaceContainer,
        title: Text('DELETE ROUTE?', style: AppDesignSystem.headlineMedium),
        content: const Text('Are you sure you want to delete this route? This will also cancel all scheduled alerts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AppDesignSystem.outline)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('routes')
            .delete()
            .eq('id', widget.route.id!);
        
        // Refresh notifications to remove deleted route alarms
        await NotificationService().refreshScheduledNotifications();
        
        widget.onUpdate();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete route: $e')),
          );
        }
      }
    }
  }

  Future<void> _getRouteWeather() async {
    setState(() => _isAuditing = true);

    try {
      final parts = widget.route.departureTime.split(':');
      final departureDateTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      
      final audit = await _weatherService.auditRouteWeather(
        departureTime: departureDateTime,
        waypoints: List<Map<String, dynamic>>.from(widget.route.waypoints),
        shiftDurationHours: widget.route.shiftDuration,
        totalDistanceMiles: widget.route.waypoints.last['distance_from_origin_miles'] ?? 0,
      );

      // Generate AI Summary
      try {
        final aiBriefing = await AIService().generateWeatherBriefing(audit);
        audit['ai_briefing'] = aiBriefing;

        // NEW: Trigger Immediate Notification
        final String title = 'Weather Briefing: ${widget.route.originName} to ${widget.route.destinationName}';
        
        // Ensure permissions
        final hasPermission = await NotificationService().requestNotificationPermission();
        if (hasPermission) {
          await NotificationService().sendImmediateSummaryNotification(
            title: title,
            body: aiBriefing,
          );
        } else {
          // Fallback UI if permission denied
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications are disabled. Weather briefing saved to route detail.')),
            );
          }
        }
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

    final peakWind = (peak['peak_wind'] as num?)?.toDouble() ?? 0.0;
    final city = peak['city'] ?? 'Unknown City';
    final severity = audit['status'] ?? 'Unknown Status';
    final peakTime = peak['peak_time'] != null 
        ? DateFormat('h:mm a').format(DateTime.parse(peak['peak_time']))
        : 'Unknown Time';
    final date = DateFormat('MMM d').format(DateTime.now());

    return 'Weather Audit for $date: Peak wind of ${peakWind.round()} mph in $city at $peakTime. Status: $severity.';
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.route.departureTime.split(':');
    final dummyDate = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    final timeStr = DateFormat('hh:mm a').format(dummyDate).toUpperCase();
    
    // Format driving days nicely
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final activeDaysStr = widget.route.drivingDays.map((d) => dayNames[d - 1]).join(', ');
    
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
                  // Top Action/Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: widget.route.isActive,
                            onChanged: (val) => _toggleActive(val ?? false),
                            activeColor: AppDesignSystem.primary,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          Text(
                            widget.route.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: AppDesignSystem.labelBold.copyWith(
                              color: widget.route.isActive ? AppDesignSystem.primary : AppDesignSystem.outline,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: AppDesignSystem.secondary),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreateRouteScreen(initialRoute: widget.route),
                                  ),
                                );
                                widget.onUpdate();
                              },
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _deleteRoute,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Trip Names Row
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.route.originName} →',
                        style: AppDesignSystem.headlineMedium.copyWith(
                          color: widget.route.isActive ? AppDesignSystem.onSurfaceVariant : AppDesignSystem.onSurfaceVariant.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.route.destinationName,
                        style: AppDesignSystem.headlineLarge.copyWith(
                          color: widget.route.isActive ? AppDesignSystem.primary : AppDesignSystem.primary.withOpacity(0.3),
                          decoration: widget.route.isActive ? null : TextDecoration.lineThrough,
                          height: 1.1,
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
                      Expanded(
                        child: Text(
                          '$activeDaysStr • $timeStr',
                          style: AppDesignSystem.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                     InkWell(
                       onTap: () => setState(() => _showAiSummary = !_showAiSummary),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             children: [
                               Icon(_showAiSummary ? Icons.expand_less : Icons.expand_more, color: AppDesignSystem.primary, size: 20),
                               const SizedBox(width: 4),
                               Text(
                                 'AI SUMMARY',
                                 style: AppDesignSystem.labelBold.copyWith(color: AppDesignSystem.primary, fontSize: 12),
                               ),
                             ],
                           ),
                           if (_showAiSummary)
                             Padding(
                               padding: const EdgeInsets.only(top: 8.0),
                               child: Text(
                                 (widget.route.weatherCondition?['ai_briefing'] as String?) ?? 'AI summary not available.',
                                 style: AppDesignSystem.bodyMedium.copyWith(color: AppDesignSystem.onSurfaceVariant),
                               ),
                             ),
                         ],
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
