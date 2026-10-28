import 'package:flutter/material.dart';
import '../core/model.dart';
import '../state.dart';
import 'theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, margin: EdgeInsets.zero, color: Theme.of(context).brightness == Brightness.dark ? card : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Padding(padding: padding, child: child)));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)));
}

class VerdictChip extends StatelessWidget {
  const VerdictChip(this.v, {super.key});
  final Verdict v;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: verdictColor(v).withAlpha(40), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(verdictIcon(v), size: 15, color: verdictColor(v)), const SizedBox(width: 5),
        Text(v.label, style: TextStyle(color: verdictColor(v), fontWeight: FontWeight.w600, fontSize: 12))]));
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.icon, this.title, this.sub, {super.key});
  final IconData icon;
  final String title, sub;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline), const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.outline))])));
}

class ErrorState extends StatelessWidget {
  const ErrorState(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: coral), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[const SizedBox(height: 12), OutlinedButton(onPressed: onRetry, child: const Text('Try again'))]])));
}

/// Shown on every main screen when the bundled model was trained on synthetic data.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});
  @override
  Widget build(BuildContext context) => AppState.I.model.demoOnly
      ? Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: amber.withAlpha(35), borderRadius: BorderRadius.circular(12), border: Border.all(color: amber)),
          child: const Row(children: [Icon(Icons.science_outlined, color: amber, size: 18), SizedBox(width: 8),
            Expanded(child: Text('DEMO MODEL: trained on synthetic data. Do not treat results as real-world accuracy.', style: TextStyle(fontSize: 12)))]))
      : const SizedBox.shrink();
}

/// Simple horizontal bar list. Values come straight from stored data.
class BarList extends StatelessWidget {
  const BarList(this.items, {super.key, this.color = blue});
  final List<MapEntry<String, int>> items;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final mx = items.fold<int>(1, (a, e) => e.value > a ? e.value : a);
    return Column(children: [for (final e in items) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      SizedBox(width: 74, child: Text(e.key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: e.value / mx), duration: const Duration(milliseconds: 500),
          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 12, color: color, backgroundColor: color.withAlpha(30))))),
      SizedBox(width: 40, child: Text('${e.value}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)))]))]);
  }
}

String fmtTime(DateTime? t) => t == null ? '-' : t.toIso8601String().substring(0, 16).replaceFirst('T', ' ');
