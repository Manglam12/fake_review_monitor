import 'package:csv/csv.dart';
import '../core/model.dart';
import '../core/models.dart';
import '../core/text_features.dart';

const _aliases = {
  'review_text': ['review_text', 'text', 'review', 'content', 'reviewtext'],
  'rating': ['rating', 'stars', 'score', 'overall'],
  'reviewer_id': ['reviewer_id', 'user_id', 'reviewerid', 'author', 'customer_id'],
  'product_id': ['product_id', 'asin', 'item_id', 'productid'],
  'timestamp': ['timestamp', 'date', 'time', 'review_date'],
};
const maxBatchRows = 20000;
const maxBatchBytes = 20 * 1024 * 1024;

class BatchRow {
  BatchRow(this.line, this.text, {this.rating, this.reviewer, this.product, this.time});
  final int line; // line number in the CSV (header = 1)
  final String text;
  final double? rating;
  final String? reviewer, product;
  final DateTime? time;
}

class BatchParse {
  final List<BatchRow> rows = [];
  final List<String> problems = []; // fatal or skipped-row messages
  final Set<String> foundColumns = {};
  int skippedEmpty = 0, badRatings = 0, badTimes = 0;
  bool truncated = false;
  bool get ok => rows.isNotEmpty && !problems.any((p) => p.startsWith('FATAL'));
}

BatchParse parseBatchCsv(String content) {
  final res = BatchParse();
  if (content.trim().isEmpty) {
    res.problems.add('FATAL: The file is empty.');
    return res;
  }
  List<List<dynamic>> table;
  try {
    table = CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceFirst('\ufeff', ''));
  } catch (e) {
    res.problems.add('FATAL: Could not read this as a CSV file.');
    return res;
  }
  if (table.length < 2) {
    res.problems.add('FATAL: The file needs a header row and at least one review.');
    return res;
  }
  final header = table.first.map((h) => h.toString().trim().toLowerCase()).toList();
  final col = <String, int>{};
  _aliases.forEach((std, names) {
    for (final n in names) {
      final i = header.indexOf(n);
      if (i >= 0) { col[std] = i; res.foundColumns.add(std); break; }
    }
  });
  if (!col.containsKey('review_text')) {
    res.problems.add('FATAL: No review text column. Add a column named review_text (or text / review / content). Found: ${header.join(', ')}');
    return res;
  }
  String? cell(List<dynamic> r, String k) {
    final i = col[k];
    if (i == null || i >= r.length) return null;
    final s = r[i].toString().trim();
    return s.isEmpty ? null : s;
  }

  for (var i = 1; i < table.length; i++) {
    final r = table[i];
    if (r.every((c) => c.toString().trim().isEmpty)) continue;
    if (res.rows.length >= maxBatchRows) {
      res.truncated = true;
      res.problems.add('Only the first $maxBatchRows reviews were used.');
      break;
    }
    final text = cleanText(cell(r, 'review_text'));
    if (text.isEmpty) { res.skippedEmpty++; continue; }
    double? rating = double.tryParse(cell(r, 'rating') ?? '');
    if (cell(r, 'rating') != null && (rating == null || rating < 1 || rating > 5)) { res.badRatings++; rating = null; }
    final ts = cell(r, 'timestamp');
    final time = ts == null ? null : DateTime.tryParse(ts);
    if (ts != null && time == null) res.badTimes++;
    res.rows.add(BatchRow(i + 1, text, rating: rating, reviewer: cell(r, 'reviewer_id'), product: cell(r, 'product_id'), time: time));
  }
  if (res.skippedEmpty > 0) res.problems.add('${res.skippedEmpty} row(s) skipped: empty review text.');
  if (res.badRatings > 0) res.problems.add('${res.badRatings} rating(s) ignored: not a number from 1 to 5.');
  if (res.badTimes > 0) res.problems.add('${res.badTimes} timestamp(s) ignored: use format YYYY-MM-DD or YYYY-MM-DD HH:MM:SS.');
  if (res.rows.isEmpty) res.problems.add('FATAL: No usable reviews found in the file.');
  return res;
}

/// Stops spreadsheet programs from running text that starts with = + - @ as a formula.
String csvSafe(String s) => (s.isNotEmpty && '=+-@\t\r'.contains(s[0])) ? "'$s" : s;

String resultsToCsv(List<ReviewRecord> rs) {
  final rows = <List<dynamic>>[
    ['review_text', 'rating', 'reviewer_id', 'product_id', 'timestamp', 'ml_verdict', 'ml_score_about', 'rule_warnings', 'note']
  ];
  for (final r in rs) {
    rows.add([
      csvSafe(r.text), r.rating?.toStringAsFixed(0) ?? '', csvSafe(r.reviewerId ?? ''), csvSafe(r.productId ?? ''),
      r.reviewTime?.toIso8601String() ?? '', r.verdict.label,
      r.prob == null ? '' : '${((r.prob! * 100) / 5).round() * 5}%',
      r.warnings.map((w) => w.title).join(' | '), r.note ?? ''
    ]);
  }
  return ListToCsvConverter(eol: '\n').convert(rows);
}
