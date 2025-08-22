import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'events/events_page.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fdyqkgprxtileyhctkgn.supabase.co', // substitui
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkeXFrZ3ByeHRpbGV5aGN0a2duIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0MzQzODMsImV4cCI6MjA3MTAxMDM4M30.PvHpyPt7Ksjpgj0xfVIK1D6PwGlmVDGbKWO4aB0mEpk',        // substitui
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Padel Scoreboard',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const EventsPage(),

    );
  }
}