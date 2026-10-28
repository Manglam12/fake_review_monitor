import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../core/models.dart';
import '../../data/db.dart';
import '../../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'result.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onGo});
  final void Function(int) onGo;
  Future<(ReportData, List<ReviewRecord>)> _load() async => (await AppState.I.db.report(), await AppState.I.db.query(limit: 5));
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: AppState.I.dataVersion,
        builder: (_, __, ___) => FutureBuilder<(ReportData, List<ReviewRecord>)>(
          future: _load(),
          builder: (c, s) {
            if (s.hasError) return ErrorState('Could not load data: ${s.error}');
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final (d, recent) = s.data!;
            return ListView(padding: const EdgeInsets.all(16), children: [
              const DemoBanner(),
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reviews analysed', style: TextStyle(fontSize: 13)),
                Text('${d.total}', style: Theme.of(c).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(children: [for (final v in Verdict.values) Expanded(child: Column(children: [
                  Text('${d.verdicts[v]}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: verdictColor(v))),
                  Text(v == Verdict.suspicious ? 'Suspicious' : v == Verdict.uncertain ? 'Uncertain' : 'Genuine', style: const TextStyle(fontSize: 12))]))])])),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Action(Icons.rate_review_outlined, 'Analyze a review', () => onGo(1))),
                const SizedBox(width: 12),
                Expanded(child: _Action(Icons.upload_file_outlined, 'Batch (CSV)', () => onGo(3)))]),
              const SectionTitle('Recent'),
              if (recent.isEmpty) const AppCard(child: EmptyState(Icons.inbox_outlined, 'Nothing yet', 'Analyze your first review to see it here.'))
              else for (final r in recent) Padding(padding: const EdgeInsets.only(bottom: 8), child: ReviewTile(r)),
            ]);
          }),
      );
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(onTap: onTap, child: Column(children: [Icon(icon, color: teal, size: 30), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center)]));
}

class ReviewTile extends StatelessWidget {
  const ReviewTile(this.r, {super.key, this.onChanged});
  final ReviewRecord r;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) => AppCard(
      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(record: r))); onChanged?.call(); },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(children: [VerdictChip(r.verdict), const Spacer(),
          if (r.warnings.isNotEmpty) Text('${r.warnings.length} warning${r.warnings.length > 1 ? 's' : ''}', style: const TextStyle(color: amber, fontSize: 12))])]));
}
