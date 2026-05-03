import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/design_system.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import 'create_route_screen.dart';

class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({super.key});

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends State<MyRoutesScreen> {
  final RouteService _routeService = RouteService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY ROUTES'),
      ),
      body: FutureBuilder<List<RouteModel>>(
        future: _routeService.fetchRoutes(),
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateRouteScreen()),
                      );
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
              return _RouteCard(route: routes[index]);
            },
          );
        },
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final RouteModel route;

  const _RouteCard({required this.route});

  @override
  Widget build(BuildContext context) {
    // Format: "THU, OCT 24 • 06:00 AM"
    final dateStr = DateFormat('EEE, MMM d').format(route.departureTime).toUpperCase();
    final timeStr = DateFormat('hh:mm a').format(route.departureTime).toUpperCase();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateRouteScreen(initialRoute: route),
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppDesignSystem.surfaceContainer,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
          border: Border.all(color: AppDesignSystem.outline.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${route.originName} →',
                        style: AppDesignSystem.labelBold.copyWith(color: AppDesignSystem.outline, fontSize: 10),
                      ),
                      Text(
                        route.destinationName,
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
                  child: const Icon(Icons.wb_sunny_outlined, color: Colors.grey, size: 20),
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
    );
  }
}
