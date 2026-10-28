import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../core/models.dart';
import '../../core/rules.dart';
import '../../data/csv_io.dart';
import '../../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home.dart';

class BatchScreen extends StatefulWidget {
  const BatchScreen({super.key});
  @override
  State<BatchScreen> createState() => _BatchState();
}

class _BatchState extends State<BatchScreen> {
  String? _name, _error;
  BatchParse? _parsed;
  double _progress = 0;
  bool _running = false;
  List<ReviewRecord>? _results;
  BatchRuleResult? _rules;

  Future<void> _pick() async {
    setState(() { _error = null; _parsed = null; _results = null; _rules = null; });
    try {
      final f = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
      if (f == null || f.files.isEmpty) return;
      final file = f.files.first;
      if (file.size > maxBatchBytes) { setState(() => _error = 'File is larger than ${maxBatchBytes ~/ (1024 * 1024)} MB. Split it into smaller CSV files.'); return; }
      final parsed = parseBatchCsv(utf8.decode(file.bytes!, allowMalformed: true));
      setState(() { _name = file.name; _parsed = parsed; if (!parsed.ok) _error = parsed.problems.firstWhere((p) => p.startsWith('FATAL'), orElse: () => 'No usable reviews.').replaceFirst('FATAL: ', ''); });
    } catch (e) {
      setState(() => _error = 'Could not open the file: $e');
    }
  }

  Future<void> _run() async {
    final p = _parsed!;
    setState(() { _running = true; _progress = 0; });
    try {
      final recs = <ReviewRecord>[];
      for (var i = 0; i < p.rows.length; i++) {
        final r = p.rows[i];
        recs.add(AppState.I.analyzer.analyze(r.text, rating: r.rating, reviewerId: r.reviewer, productId: r.product, reviewTime: r.time, source: 'batch'));
        if (i % 100 == 0) { setState(() => _progress = i / p.rows.length); await Future.delayed(Duration.zero); }
      }
      final rules = runBatchRules([for (var i = 0; i < recs.length; i++)
        RuleInput(i, recs[i].text, rating: recs[i].rating, reviewer: recs[i].reviewerId, product: recs[i].productId, time: recs[i].reviewTime)]);
      for (var i = 0; i < recs.length; i++) {
        recs[i].warnings = [...recs[i].warnings, ...(rules.perRow[i] ?? []).where((w) => !recs[i].warnings.any((x) => x.code == w.code))];
      }
      await AppState.I.db.insertMany(recs);
      AppState.I.bump();
      setState(() { _results = recs; _rules = rules; });
    } catch (e) {
      setState(() => _error = 'Analysis failed: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _parsed, res = _results;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const DemoBanner(),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Import a CSV file', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Required column: review_text. Optional: rating, reviewer_id, product_id, timestamp. Max 20,000 rows / 20 MB. Everything stays on this phone.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _running ? null : _pick, icon: const Icon(Icons.folder_open), label: const Text('Choose CSV file'))])),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: AppCard(child: Row(children: [const Icon(Icons.error_outline, color: coral), const SizedBox(width: 10), Expanded(child: Text(_error!))]))),
      if (p != null && p.rows.isNotEmpty) ...[
        const SectionTitle('File check'),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_name: ${p.rows.length} usable reviews'),
          Text('Columns found: ${p.foundColumns.join(", ")}', style: const TextStyle(fontSize: 12)),
          if (!p.foundColumns.contains('reviewer_id') || !p.foundColumns.contains('timestamp'))
            const Text('Insufficient metadata for some behaviour checks (reviewer_id and timestamp are needed for burst detection). Those checks are skipped.', style: TextStyle(color: amber, fontSize: 12)),
          for (final m in p.problems.where((x) => !x.startsWith('FATAL'))) Text(m, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          if (_running) LinearProgressIndicator(value: _progress) else if (res == null) FilledButton(onPressed: _run, child: const Text('Analyze all')),
        ])),
      ],
      if (res != null && _rules != null) ...[
        const SectionTitle('Summary'),
        AppCard(child: Column(children: [
          for (final v in Verdict.values) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [VerdictChip(v), const Spacer(), Text('${res.where((r) => r.verdict == v).length}', style: const TextStyle(fontWeight: FontWeight.w700))])),
          const Divider(),
          Row(children: [const Text('Rows with duplicate text'), const Spacer(), Text('${_rules!.duplicateRows}')]),
          Row(children: [const Text('Rows with near-duplicate text'), const Spacer(), Text('${_rules!.nearDuplicateRows}')]),
          Row(children: [const Text('Reviewers with burst/copy-paste pattern'), const Spacer(), Text('${_rules!.reviewers.length}')]),
          for (final n in _rules!.notes) Text(n, style: const TextStyle(fontSize: 12, color: amber)),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => AppState.I.shareText('review_results.csv', resultsToCsv(res)), icon: const Icon(Icons.ios_share), label: const Text('Export results (CSV)')),
        ])),
        const SectionTitle('Most suspicious'),
        for (final r in (res.where((r) => r.verdict == Verdict.suspicious).toList()..sort((a, b) => (b.prob ?? 0).compareTo(a.prob ?? 0))).take(10))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: ReviewTile(r)),
        if (!res.any((r) => r.verdict == Verdict.suspicious)) const Text('No review reached the Suspicious level.'),
      ],
    ]);
  }
}
