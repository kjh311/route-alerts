import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'screens/auth_wrapper.dart';
import 'screens/splash_screen.dart';
import 'theme/design_system.dart';
import 'services/subscription_service.dart';
import 'services/auth_service.dart';
import 'services/ai_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const HaulAlertsApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HaulAlertsApp extends StatelessWidget {
  const HaulAlertsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Haul Alerts',
      theme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFFE67E22), // Signature Safety Orange
        scaffoldBackgroundColor: Color(0xFF000000), // Pure Midnight Black
        barBackgroundColor: Color(0xFF1A1A1A), // Deep Slate for bars
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.white,
          textStyle: TextStyle(
            color: CupertinoColors.white,
            fontFamily: 'Roboto',
          ),
        ),
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), 
      ],
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const AuthWrapper(),
      },
    );
  }
}
