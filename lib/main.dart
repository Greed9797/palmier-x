import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'editor_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Required once before any Player is created (sets up libmpv).
  MediaKit.ensureInitialized();
  runApp(const PalmierXApp());
}

const brand = Color(0xFFF55900); // W3 orange — matches the Swift reskin.

class PalmierXApp extends StatelessWidget {
  const PalmierXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palmier X',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.dark,
        ).copyWith(primary: brand),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const EditorScreen(),
    );
  }
}
