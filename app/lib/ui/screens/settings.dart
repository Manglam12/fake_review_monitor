import 'package:flutter/material.dart';
import '../../state.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final m = AppState.I.model;
    Widget row(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: Text(v))]));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & About')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        const DemoBanner(),
        AppCard(child: ValueListenableBuilder<ThemeMode>(valueListenable: AppState.I.themeMode, builder: (_, mode, __) =>
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Light theme'), value: mode == ThemeMode.light, onChanged: AppState.I.setLight))),
        const SectionTitle('Model'),
        AppCard(child: Column(children: [
          row('Type', m.name), row('Trained', m.created), row('Dataset', m.datasetName), row('Rows used', '${m.rowsUsed}'), row('License', m.license),
          row('Output', 'Likely Genuine / Uncertain / Suspicious. Probability rounded to 5%.'),
          row('Training report', 'ml/artifacts/training_report.md in the project folder.')])),
        const SectionTitle('Limitations'),
        const AppCard(child: Text('- The model learns patterns from its training data. On other websites, languages or writing styles it can be wrong.\n'
            '- Only English-style ASCII words are used; other scripts and emojis add little signal.\n'
            '- Rating-vs-text mismatch uses a small word list, so it is rough.\n'
            '- Rule-based warnings are hints. Plain, short or 5-star reviews are normal and are not treated as fake.\n'
            '- Behaviour checks need reviewer IDs / timestamps and only see reviews saved on this phone.')),
        const SectionTitle('Privacy'),
        const AppCard(child: Text('Everything runs on this phone. Reviews are never uploaded. No login, no API key, no internet permission.')),
        const SectionTitle('Responsible use'),
        const AppCard(child: Text('Predictions can be wrong. Do not use them as the only basis for accusing a person or a business. Check the evidence yourself.')),
        const SectionTitle('Project'),
        const AppCard(child: Text('Fake Product Review Monitoring System - final-year B.Tech CSE project.\nFlutter + SQLite app; model trained with Python / scikit-learn and exported as JSON.\n(Add your name, guide and college here.)')),
      ])),
    );
  }
}
