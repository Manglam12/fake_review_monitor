import 'package:flutter/material.dart';
import '../../core/analyzer.dart';
import '../../state.dart';
import '../widgets.dart';
import 'result.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});
  @override
  State<AnalyzeScreen> createState() => _AnalyzeState();
}

class _AnalyzeState extends State<AnalyzeScreen> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController(), _reviewer = TextEditingController(), _product = TextEditingController();
  int? _rating;
  DateTime? _time;
  bool _busy = false;

  @override
  void dispose() { _text.dispose(); _reviewer.dispose(); _product.dispose(); super.dispose(); }

  Future<void> _run() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final r = await AppState.I.analyzeAndSave(_text.text,
          rating: _rating?.toDouble(), reviewerId: _reviewer.text, productId: _product.text, time: _time);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(record: r)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(16), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: [
        const DemoBanner(),
        TextFormField(controller: _text, minLines: 5, maxLines: 10, maxLength: maxReviewChars, validator: validateReviewText,
            decoration: const InputDecoration(labelText: 'Review text', hintText: 'Paste the review here', alignLabelWithHint: true)),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
            value: _rating, decoration: const InputDecoration(labelText: 'Star rating (optional)'),
            items: [const DropdownMenuItem(value: null, child: Text('Not given')), for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i star${i > 1 ? 's' : ''}'))],
            onChanged: (v) => setState(() => _rating = v)),
        const SizedBox(height: 12),
        TextFormField(controller: _reviewer, validator: validateId, decoration: const InputDecoration(labelText: 'Reviewer ID (optional)')),
        const SizedBox(height: 12),
        TextFormField(controller: _product, validator: validateId, decoration: const InputDecoration(labelText: 'Product ID (optional)')),
        const SizedBox(height: 12),
        AppCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), onTap: () async {
          final d = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDate: _time ?? DateTime.now());
          if (d != null) setState(() => _time = d);
        }, child: Row(children: [const Icon(Icons.event_outlined), const SizedBox(width: 10),
          Expanded(child: Text(_time == null ? 'Review date (optional)' : fmtTime(_time).substring(0, 10))),
          if (_time != null) IconButton(onPressed: () => setState(() => _time = null), icon: const Icon(Icons.clear))])),
        const SizedBox(height: 8),
        const Text('Reviewer ID, product ID and date let the app look for repeat behaviour among reviews you saved before. Without them it says "Insufficient metadata".',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: _busy ? null : _run, icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
            label: Text(_busy ? 'Analyzing...' : 'Analyze')),
      ]));
}
