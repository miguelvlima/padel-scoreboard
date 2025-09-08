import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_mode.dart';
import 'app_capabilities.dart';
import 'main.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fdyqkgprxtileyhctkgn.supabase.co', // substitui
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkeXFrZ3ByeHRpbGV5aGN0a2duIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0MzQzODMsImV4cCI6MjA3MTAxMDM4M30.PvHpyPt7Ksjpgj0xfVIK1D6PwGlmVDGbKWO4aB0mEpk',        // substitui
  );

  runApp(MyApp(
    mode: AppMode.admin,
    caps: AppCapabilities.fromMode(AppMode.admin),
  ));
}
