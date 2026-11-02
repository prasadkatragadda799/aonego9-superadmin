import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_store.dart';
import 'core/routing/app_router.dart';
import 'core/utils/app_links.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // /#/login style routes — reliable on Vercel static hosting.
  setUrlStrategy(const HashUrlStrategy());
  // Restore before the first frame so the console never flashes the wrong theme.
  await ThemeModeStore.restore();
  await AppLinks.restore();
  runApp(const AOneGo9AdminApp());
}

class AOneGo9AdminApp extends StatefulWidget {
  const AOneGo9AdminApp({super.key});

  @override
  State<AOneGo9AdminApp> createState() => _AOneGo9AdminAppState();
}

class _AOneGo9AdminAppState extends State<AOneGo9AdminApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Follow the OS appearance live when the admin is on "match device".
  @override
  void didChangePlatformBrightness() => setState(() {});

  Brightness? _lastBrightness;

  /// Colour tokens are static getters, so a theme switch only repaints
  /// widgets that depend on `Theme.of`. Pages that read `AppColors.*`
  /// directly kept the old palette (a dark page with light inputs) until
  /// they happened to rebuild. On a change, every element is marked dirty
  /// once — the same pass hot reload uses — so state is kept.
  void _rebuildAllOnChange(Brightness b) {
    final changed = _lastBrightness != null && _lastBrightness != b;
    _lastBrightness = b;
    if (!changed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final root = WidgetsBinding.instance.rootElement;
      if (root == null) return;
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      mark(root);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeModeStore.mode,
      builder: (context, _, __) {
        final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final brightness = ThemeModeStore.resolve(platform);
        // Colours are static getters; point them at the theme before anything reads one.
        AppColors.applyBrightness(brightness);
        _rebuildAllOnChange(brightness);
        return MaterialApp.router(
          title: 'AOneGo9 Super Admin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(brightness),
          scrollBehavior: const _AppScrollBehavior(),
          routerConfig: appRouter,
        );
      },
    );
  }
}

/// Mouse / trackpad drag for horizontal scrollers on desktop web.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
