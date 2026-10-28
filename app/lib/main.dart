import 'package:flutter/material.dart';
import 'state.dart';
import 'ui/screens/splash.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReviewApp());
}

class ReviewApp extends StatelessWidget {
  const ReviewApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppState.I.themeMode,
        builder: (_, mode, __) => MaterialApp(
          title: 'Fake Review Monitor', debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: mode,
          home: const SplashScreen()),
      );
}
