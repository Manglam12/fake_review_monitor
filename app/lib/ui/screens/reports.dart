import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../data/csv_io.dart';
import '../../data/db.dart';
import '../../data/report_pdf.dart';
import '../../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: AppState.I.dataVersion,
      builder: (_, __, ___) => FutureBuilder<ReportData>(future: AppState.I.db.report(), builder: (c, s) {
        if (s.hasError) return ErrorState('Could not build report: ${s.error}');
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final d = s.data!;
        if (d.total == 0) return const EmptyState(Icons.bar_chart, 'No data yet', 'Reports are built from reviews you analyze. Analyze some reviews first.');
        return ListView(padding: const EdgeInsets.all(16), children: [
          const DemoBanner(),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d.total} reviews', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 10),
            BarList([for (final v in Verdict.values) MapEntry(v == Verdict.suspicious ? 'Suspicious' : v == Verdict.uncertain ? 'Uncertain' : 'Genuine', d.verdicts[v]!)], color: teal)])),
          const SectionTitle('Rating distribution'),
          AppCard(child: BarList([for (var i = 5; i >= 1; i--) MapEntry('$i star', d.ratings[i]!), MapEntry('None', d.ratings[0]!)])),
          const SectionTitle('Rule-based indicators (warnings, not proof)'),
          AppCard(child: d.indicators.isEmpty ? const Text('No warnings recorded.') : BarList(d.indicators.entries.toList(), color: amber)),
          const SectionTitle('Per day (analysis date)'),
          AppCard(child: BarList([for (final e in d.perDay.take(14)) MapEntry(e.key.substring(5), e.value.values.fold(0, (a, b) => a + b))])),
          const SectionTitle('Products with suspicious reviews'),
          AppCard(child: d.products.isEmpty ? const Text('Insufficient metadata: no product IDs stored.') : Column(children: [
            for (final p in d.products.take(10)) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('${p['product_id']}'), subtitle: Text('${p['n']} reviews'),
                trailing: Text('${p['s'] ?? 0} suspicious', style: const TextStyle(color: coral)))])),
          const SectionTitle('Flagged reviewers'),
          AppCard(child: d.reviewers.isEmpty ? const Text('None. (Needs reviewer IDs plus a burst or copy-paste pattern.)') : Column(children: [
            for (final r in d.reviewers.take(10)) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('${r['reviewer_id']}'), trailing: Text('${r['n']} reviews'))])),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.table_chart_outlined), label: const Text('CSV'), onPressed: () async {
              final all = await AppState.I.db.query(limit: 100000);
              await AppState.I.shareText('all_reviews.csv', resultsToCsv(all));
            })),
            const SizedBox(width: 12),
            Expanded(child: FilledButton.icon(icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF'), onPressed: () async {
              final bytes = await buildReportPdf(d, demoModel: AppState.I.model.demoOnly);
              await AppState.I.shareBytes('fake_review_report.pdf', bytes, 'application/pdf');
            }))]),
        ]);
      }));
}
