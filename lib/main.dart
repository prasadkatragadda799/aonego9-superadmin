import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';

void main() {
  setUrlStrategy(const HashUrlStrategy());
  runApp(const AOneGo9AdminApp());
}

class AOneGo9AdminApp extends StatelessWidget {
  const AOneGo9AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AOneGo9 Super Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
