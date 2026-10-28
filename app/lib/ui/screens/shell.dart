import 'package:flutter/material.dart';
import 'analyze.dart';
import 'batch.dart';
import 'history.dart';
import 'home.dart';
import 'reports.dart';
import 'settings.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  int index = 0;
  void go(int i) => setState(() => index = i);
  @override
  Widget build(BuildContext context) {
    final pages = [HomeScreen(onGo: go), const AnalyzeScreen(), const HistoryScreen(), const BatchScreen(), const ReportsScreen()];
    const titles = ['Dashboard', 'Analyze Review', 'History', 'Batch Analysis', 'Reports'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[index]), actions: [
        IconButton(tooltip: 'Settings & About', icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())))]),
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(index), child: pages[index]))),
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: go, destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.rate_review_outlined), selectedIcon: Icon(Icons.rate_review), label: 'Analyze'),
        NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        NavigationDestination(icon: Icon(Icons.upload_file_outlined), selectedIcon: Icon(Icons.upload_file), label: 'Batch'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
      ]),
    );
  }
}
