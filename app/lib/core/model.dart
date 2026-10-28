// Runs the exported linear model (assets/model/model.json). Port of ml/reference_infer.py.
// Pure Dart (no Flutter imports) so it can be unit-tested with `flutter test`.
import 'dart:math';
import 'text_features.dart';

enum Verdict { likelyGenuine, uncertain, suspicious }

extension VerdictX on Verdict {
  String get label => switch (this) {
        Verdict.likelyGenuine => 'Likely Genuine',
        Verdict.uncertain => 'Uncertain',
        Verdict.suspicious => 'Suspicious / Likely Fake',
      };
  static Verdict parse(String s) =>
      Verdict.values.firstWhere((v) => v.name == s, orElse: () => Verdict.uncertain);
}

class ReviewModel {
  ReviewModel(Map<String, dynamic> m)
      : name = m['model_name'] as String,
        datasetName = (m['dataset'] as Map)['name'] as String,
        demoOnly = (m['dataset'] as Map)['demo_only'] as bool,
        rowsUsed = (m['dataset'] as Map)['rows_used'] as int,
        license = (m['dataset'] as Map)['license'] as String,
        created = m['created_utc'] as String,
        vocab = ((m['tfidf'] as Map)['vocabulary'] as Map).map((k, v) => MapEntry(k as String, v as int)),
        idf = _d((m['tfidf'] as Map)['idf']),
        wt = _d(m['weights_tfidf']),
        wn = _d(m['weights_numeric']),
        bias = (m['intercept'] as num).toDouble(),
        calA = ((m['calibration'] as Map)['a'] as num).toDouble(),
        calB = ((m['calibration'] as Map)['b'] as num).toDouble(),
        lo = ((m['thresholds'] as Map)['genuine_at_or_below'] as num).toDouble(),
        hi = ((m['thresholds'] as Map)['fake_at_or_above'] as num).toDouble();

  final String name, datasetName, license, created;
  final bool demoOnly;
  final int rowsUsed;
  final Map<String, int> vocab;
  final List<double> idf, wt, wn;
  final double bias, calA, calB, lo, hi;

  static List<double> _d(dynamic l) => (l as List).map((e) => (e as num).toDouble()).toList();

  double rawScore(String text, double? rating) {
    final t = tokenize(text);
    final grams = <String>[...t, for (var i = 0; i + 1 < t.length; i++) '${t[i]} ${t[i + 1]}'];
    final tf = <int, int>{};
    for (final g in grams) {
      final idx = vocab[g];
      if (idx != null) tf[idx] = (tf[idx] ?? 0) + 1;
    }
    final vals = tf.map((i, c) => MapEntry(i, (1.0 + log(c)) * idf[i]));
    final norm = sqrt(vals.values.fold(0.0, (a, v) => a + v * v));
    var s = bias;
    if (norm > 0) vals.forEach((i, v) => s += wt[i] * v / norm);
    final f = numericFeatures(text, rating);
    for (var i = 0; i < wn.length; i++) s += wn[i] * f[i];
    return s;
  }

  double probFake(String text, double? rating) {
    final z = calA * rawScore(text, rating) + calB;
    return z < -700 ? 0.0 : 1.0 / (1.0 + exp(-z));
  }

  Verdict verdictFor(double p) =>
      p >= hi ? Verdict.suspicious : (p <= lo ? Verdict.likelyGenuine : Verdict.uncertain);
}

/// Rounded to the nearest 5% so we never show falsely precise numbers.
String probText(double p) {
  final r = ((p * 100) / 5).round() * 5;
  return r <= 0 ? '<5%' : (r >= 100 ? '>95%' : '$r%');
}
