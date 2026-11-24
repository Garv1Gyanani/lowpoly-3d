import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'theme/desert_palette.dart';
import 'ui/outpost_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DesertOutpostApp());
}

/// Pure `WidgetsApp` shell (zero `material.dart` dependency & zero 1.6 MB icon-font bloat).
class DesertOutpostApp extends StatelessWidget {
  const DesertOutpostApp({
    super.key,
    this.home = const OutpostScreen(),
  });

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Desert Outpost',
      color: DesertPalette.terracotta,
      debugShowCheckedModeBanner: false,
      textStyle: DesertTypography.ui(size: 13, color: DesertPalette.uiInk),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
            opacity: animation,
            child: builder(context),
          ),
        );
      },
      home: home,
    );
  }
}
