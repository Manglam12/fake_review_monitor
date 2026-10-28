import 'package:flutter/material.dart';
import '../../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> {
  String? error;
  @override
  void initState() { super.initState(); _boot(); }

  Future<void> _boot() async {
    setState(() => error = null);
    try {
      await AppState.I.init();
      await Future.delayed(const Duration(milliseconds: 900)); // lets the logo animation finish
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) => const Shell(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c)));
    } catch (e) {
      setState(() => error = 'Could not start the app: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: error != null
          ? ErrorState(error!, onRetry: _boot)
          : Center(child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 700),
              builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: .8 + .2 * v, child: child)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [blue, teal]), borderRadius: BorderRadius.circular(28)),
                    child: const Icon(Icons.fact_check_outlined, size: 56, color: Colors.white)),
                const SizedBox(height: 18),
                Text('Fake Review Monitor', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6), const Text('On-device. Private. Offline.'),
                const SizedBox(height: 24), const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))]))));
}
