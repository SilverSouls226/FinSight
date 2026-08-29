import 'package:flutter/material.dart';

import 'screens/root/root_shell.dart';
import 'theme/app_theme.dart';

class FinSentinelApp extends StatelessWidget {
  const FinSentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinSentinel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const RootShell(),
    );
  }
}
