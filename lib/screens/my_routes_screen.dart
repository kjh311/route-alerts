import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Colors, Material, Tooltip, Curves, Scrollable, WidgetsBinding;
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
  final String? focusRouteId;
  const MyRoutesScreen({super.key, this.focusRouteId});

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends State<MyRoutesScreen> {
  final RouteService _routeService = RouteService();
  final ScrollController _scrollController = ScrollController();
  final Map<String?, GlobalKey> _cardKeys = {};
  late Stream<List<RouteModel>> _routesStream;
  final ValueNotifier<List<RouteModel>> _routesNotifier = ValueNotifier([]);
  String? _lastFocusId;

  @override
  void initState() {
    super.initState();
    _routesStream = _routeService.routesStream;
    _routesStream.listen((routes) {
      _routesNotifier.value = routes;
    });
  }

  void _scrollToRoute(String routeId) {
    // Retry mechanism to ensure context is available after build
    void attemptScroll(int retries) {
      if (retries <= 0) return;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _cardKeys[routeId];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        } else {
          // If child isn't rendered yet (lazy loading), wait a bit and retry
          Future.delayed(const Duration(milliseconds: 100), () => attemptScroll(retries - 1));
        }
      });
    }

    attemptScroll(5);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            await Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const CreateRouteScreen()),
            );
          },
          child: const Icon(CupertinoIcons.add, color: Color(0xFFE67E22), size: 28),
        ),
        middle: const Text(
          'MY ROUTES',
          style: TextStyle(color: CupertinoColors.white, letterSpacing: 1.2, fontWeight: FontWeight.bold),
        ),
        trailing: const SizedBox.shrink(),
        backgroundColor: const Color(0xFF1A1A1A),
        automaticallyImplyLeading: false,
      ),
      child: SafeArea(
        bottom: true,
        child: ValueListenableBuilder<List<RouteModel>>(
          valueListenable: _routesNotifier,
          builder: (context, routes, _) {
            if (routes.isEmpty) {
              // We should check if snapshot was empty or still loading
              // For simplicity, if notifier is empty but stream hasn't emitted, show loading
              // But here we'll just handle empty state
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 100),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.bus, size: 80, color: Color(0x33FFFFFF)),
                      const SizedBox(height: 24),
                      const Text(
                        'No routes saved yet',
                        style: TextStyle(fontSize: 20, color: CupertinoColors.systemGrey, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 32),
                      CupertinoButton.filled(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const CreateRouteScreen()),
                          );
                        },
                        child: const Text('CREATE FIRST ROUTE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Auto focus on notification tap - only trigger once per new focus ID
            if (widget.focusRouteId != null && widget.focusRouteId != _lastFocusId) {
              _lastFocusId = widget.focusRouteId;
              _scrollToRoute(widget.focusRouteId!);
            }

            return ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: routes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final route = routes[index];
                final key = _cardKeys.putIfAbsent(route.id, () => GlobalKey());
                return _RouteCard(
                  key: key,
                  route: route,
                  onDelete: () {
                    // Optimistic removal
                    _routesNotifier.value = _routesNotifier.value.where((r) => r.id != route.id).toList();
                  },
                  autoExpandAiSummary: widget.focusRouteId == route.id,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RouteCard extends StatefulWidget {
  final RouteModel route;
  final bool autoExpandAiSummary;
  final VoidCallback onDelete;

  const _RouteCard({
    super.key,
    required this.route,
    required this.onDelete,
    this.autoExpandAiSummary = false,
  });

  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  final WeatherService _weatherService = WeatherService();
  bool _isAuditing = false;
  late bool _showAiSummary;

  bool get _isActiveToday {
    final now = DateTime.now();
    // Dart: 1 (Mon) - 7 (Sun)
    // Supabase: 0 (Mon) - 6 (Sun)
    final dayNum = now.weekday - 1; 
    return widget.route.drivingDays.contains(dayNum);
  }

  @override
  void initState() {
    super.initState();
    _showAiSummary = widget.autoExpandAiSummary;
  }

  @override
  void didUpdateWidget(covariant _RouteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoExpandAiSummary && !oldWidget.autoExpandAiSummary) {
      setState(() {
        _showAiSummary = true;
      });
    }
  }

  Future<void> _toggleActive(bool value) async {
    try {
      await Supabase.instance.client
          .from('routes')
          .update({'is_active': value})
          .eq('id', widget.route.id!);
      
      await NotificationService().refreshScheduledNotifications();
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('ERROR'),
            content: Text('Failed to update status: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _deleteRoute() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('DELETE ROUTE?'),
        content: const Text('Are you sure you want to delete this route? This will also cancel all scheduled alerts.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDelete(); // Trigger optimistic UI in parent
      try {
        await Supabase.instance.client
            .from('routes')
            .delete()
            .eq('id', widget.route.id!);
        
        await NotificationService().refreshScheduledNotifications();
      } catch (e) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('ERROR'),
              content: Text('Failed to delete route: $e'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
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

      try {
        final aiBriefing = await AIService().generateWeatherBriefing(audit);
        audit['ai_briefing'] = aiBriefing;

        final hasPermission = await NotificationService().requestNotificationPermission();
        if (hasPermission) {
          await NotificationService().sendImmediateSummaryNotification(
            title: 'Weather Briefing: ${widget.route.originName}',
            body: aiBriefing,
          );
        }
      } catch (e) {
        debugPrint('AI Briefing failed: $e');
      }

      await Supabase.instance.client
          .from('routes')
          .update({'weather_condition': audit})
          .eq('id', widget.route.id!);
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('AUDIT FAILED'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAuditing = false);
      }
    }
  }

  String? _parseBriefingSummary() {
    final audit = widget.route.weatherCondition;
    if (audit == null) return null;
    if (audit['ai_briefing'] != null) return audit['ai_briefing'] as String;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.route.departureTime.split(':');
    final dummyDate = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    final timeStr = DateFormat('hh:mm a').format(dummyDate).toUpperCase();
    
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final activeDaysStr = widget.route.drivingDays.map((d) => dayNames[d - 1]).join(', ');
    
    final summary = _parseBriefingSummary();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isActiveToday ? const Color(0xFFE67E22).withOpacity(0.5) : const Color(0xFF333333),
          width: _isActiveToday ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => CreateRouteScreen(initialRoute: widget.route),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CupertinoSwitch(
                            value: widget.route.isActive,
                            onChanged: (val) => _toggleActive(val),
                            activeColor: const Color(0xFFE67E22),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.route.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: TextStyle(
                              color: widget.route.isActive ? const Color(0xFFE67E22) : CupertinoColors.systemGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => CreateRouteScreen(initialRoute: widget.route),
                                ),
                              );
                            },
                            child: const Icon(CupertinoIcons.pencil, size: 20, color: CupertinoColors.systemGrey),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _deleteRoute,
                            child: const Icon(CupertinoIcons.trash, size: 20, color: CupertinoColors.systemRed),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.route.originName} →',
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.route.destinationName,
                        style: TextStyle(
                          color: widget.route.isActive ? const Color(0xFFE67E22) : const Color(0x33E67E22),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: const Color(0xFF333333)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.time, size: 16, color: CupertinoColors.systemGrey2),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$activeDaysStr • $timeStr',
                          style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: GestureDetector(
              onTap: summary != null ? () => setState(() => _showAiSummary = !_showAiSummary) : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SAFETY BRIEFING',
                      style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_isAuditing)
                      const Center(child: CupertinoActivityIndicator())
                    else if (summary != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _showAiSummary ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                                color: const Color(0xFFE67E22),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'AI SUMMARY',
                                style: TextStyle(color: Color(0xFFE67E22), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (_showAiSummary)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                summary,
                                style: const TextStyle(color: CupertinoColors.white, fontSize: 14, height: 1.4),
                              ),
                            ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
