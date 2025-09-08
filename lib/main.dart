import 'package:flutter/material.dart';
import 'events/events_page.dart';
import 'app_mode.dart';
import 'app_capabilities.dart';
import 'theme/app_theme.dart';

class MyApp extends StatelessWidget {
  final AppMode mode;
  final AppCapabilities caps;
  const MyApp({super.key, required this.mode, required this.caps});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Padel Scoreboard',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: EventsPage(caps: caps),

    );
  }
}