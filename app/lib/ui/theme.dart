import 'package:flutter/material.dart';
import '../core/model.dart';

const navy = Color(0xFF0B1220), card = Color(0xFF131D31), teal = Color(0xFF2DD4BF), blue = Color(0xFF3B82F6);
const amber = Color(0xFFF59E0B), coral = Color(0xFFF87171);

Color verdictColor(Verdict v) => switch (v) { Verdict.likelyGenuine => teal, Verdict.uncertain => amber, Verdict.suspicious => coral };
IconData verdictIcon(Verdict v) => switch (v) {
      Verdict.likelyGenuine => Icons.verified_outlined, Verdict.uncertain => Icons.help_outline, Verdict.suspicious => Icons.flag_outlined };

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: blue, brightness: b, primary: dark ? teal : const Color(0xFF0F766E), secondary: blue);
  return ThemeData(
    useMaterial3: true, colorScheme: scheme,
    scaffoldBackgroundColor: dark ? navy : const Color(0xFFF3F6FB),
    appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: dark ? Colors.white : navy)),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: dark ? card : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: dark ? card : Colors.white, indicatorColor: teal.withAlpha(60)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
  );
}
