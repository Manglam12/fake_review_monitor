import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../core/models.dart';
import '../../state.dart';
import '../widgets.dart';
import 'home.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<HistoryScreen> {
  final _q = TextEditingController();
  Verdict? _filter;
  late Future<List<ReviewRecord>> _f = _load();
  Future<List<ReviewRecord>> _load() => AppState.I.db.query(search: _q.text, verdict: _filter);
  void _refresh() => setState(() => _f = _load());

  @override
  void dispose() { _q.dispose(); super.dispose(); }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Delete all history?'), content: const Text('This removes every saved review from this phone. It cannot be undone.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete all'))]));
    if (ok == true) { await AppState.I.db.clearAll(); AppState.I.bump(); _refresh(); }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: AppState.I.dataVersion,
      builder: (_, __, ___) => Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Row(children: [
          Expanded(child: TextField(controller: _q, onChanged: (_) => _refresh(), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search text, reviewer or product'))),
          IconButton(tooltip: 'Delete all', onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined))])),
        SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: const Text('All'), selected: _filter == null, onSelected: (_) { _filter = null; _refresh(); })),
          for (final v in Verdict.values) Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: Text(v.label), selected: _filter == v, onSelected: (_) { _filter = v; _refresh(); }))])),
        Expanded(child: FutureBuilder<List<ReviewRecord>>(future: _f, builder: (c, s) {
          if (s.hasError) return ErrorState('Could not load history: ${s.error}', onRetry: _refresh);
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          if (s.data!.isEmpty) return const EmptyState(Icons.history, 'No reviews found', 'Analyzed reviews are saved here.');
          return ListView.separated(padding: const EdgeInsets.all(16), itemCount: s.data!.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) { final r = s.data![i];
                return Dismissible(key: ValueKey(r.id), direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.withAlpha(120), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.delete)),
                    onDismissed: (_) async { await AppState.I.db.delete(r.id!); AppState.I.bump(); },
                    child: ReviewTile(r, onChanged: _refresh)); });
        })),
      ]));
}
