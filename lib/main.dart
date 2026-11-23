import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/desert_palette.dart';
import 'ui/outpost_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DesertOutpostApp());
}

class DesertOutpostApp extends StatelessWidget {
  const DesertOutpostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desert Outpost',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: DesertPalette.terracotta,
          surface: DesertPalette.uiSurface,
        ),
        scaffoldBackgroundColor: DesertPalette.sky,
      ),
      home: const OutpostScreen(),
    );
  }
}
