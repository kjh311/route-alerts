import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/design_system.dart';
import 'services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Services
  await SubscriptionService().init();

  runApp(const RouteAlertsApp());
}

class RouteAlertsApp extends StatelessWidget {
  const RouteAlertsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Route Alerts',
      theme: AppDesignSystem.themeData,
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Route Alerts',
          style: AppDesignSystem.headlineMedium,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Rugged Utility Ready',
              style: AppDesignSystem.bodyLarge,
            ),
            const SizedBox(height: AppDesignSystem.stackGap),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Start Route Scan'),
            ),
          ],
        ),
      ),
    );
  }
}
