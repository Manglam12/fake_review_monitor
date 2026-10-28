import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../core/models.dart';
import '../../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.record});
  final ReviewRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record, m = AppState.I.model;
    final behaviourMissing = (r.reviewerId == null) && (r.productId == null);
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        const DemoBanner(),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.psychology_outlined, color: blue), const SizedBox(width: 8), Text('ML prediction', style: Theme.of(context).textTheme.titleMedium)]),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 500),
              builder: (_, v, child) => Opacity(opacity: v, child: child), child: VerdictChip(r.verdict)),
          const SizedBox(height: 10),
          if (r.prob != null) Text('Model score (fake-likelihood): about ${probText(r.prob!)}', style: Theme.of(context).textTheme.titleLarge),
          if (r.prob != null) const Text('A score from a statistical model, rounded to the nearest 5%. It is not a certainty.', style: TextStyle(fontSize: 12)),
          if (r.note != null) Text(r.note!, style: const TextStyle(color: amber)),
          const SizedBox(height: 6),
          Text('Likely Genuine at or below ${probText(m.lo)}, Suspicious at or above ${probText(m.hi)}, otherwise Uncertain.', style: const TextStyle(fontSize: 12)),
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.rule, color: amber), const SizedBox(width: 8), Text('Rule-based warnings', style: Theme.of(context).textTheme.titleMedium)]),
          const SizedBox(height: 4),
          const Text('Separate from the ML prediction. Warnings are hints to look closer, not proof that a review is fake.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          if (r.warnings.isEmpty) const Text('No warning indicators found.')
          else for (final w in r.warnings) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.warning_amber_rounded, color: amber),
              title: Text(w.title), subtitle: Text(w.detail)),
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Behaviour checks', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6),
          Text(behaviourMissing ? 'Insufficient metadata (no reviewer ID or product ID was given).'
              : r.reviewerId != null && !r.warnings.any((w) => const ['burst', 'copy_paste'].contains(w.code))
                  ? 'No repeat-behaviour pattern found among reviews saved on this device for this reviewer.'
                  : 'See any warnings above.'),
        ])),
        const SectionTitle('Review'),
        AppCard(child: SelectableText(r.text)),
        const SizedBox(height: 8),
        Text('Rating: ${r.rating?.toStringAsFixed(0) ?? "not given"}   Reviewer: ${r.reviewerId ?? "-"}   Product: ${r.productId ?? "-"}   Date: ${fmtTime(r.reviewTime)}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 16),
        const Text('Responsible use: predictions can be wrong. Do not use them as the only basis for accusing a person or a business.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
      ])),
    );
  }
}
