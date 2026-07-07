import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Lock portrait
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
      // Go straight to HomeScreen — no auth gate.
      // Auth is opt-in via the Sync button inside HomeScreen.
      home: const HomeScreen(),
    );
  }
}