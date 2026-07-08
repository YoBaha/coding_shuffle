import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'screens/main_shell.dart'; // ← changed from home_screen.dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await MobileAds.instance.initialize();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Supabase.initialize(
    url:     dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const CodingShuffleDuel());
}

class CodingShuffleDuel extends StatelessWidget {
  const CodingShuffleDuel({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coding Shuffle Duel',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const MainShell(), // ← was HomeScreen
    );
  }
}