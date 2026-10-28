// Checks the Dart port gives the SAME numbers as Python (golden_vectors.json made by ml/make_golden.py).
import 'dart:convert';
import 'dart:io';
import 'package:fake_review_monitor/core/model.dart';
import 'package:fake_review_monitor/core/text_features.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final model = ReviewModel(jsonDecode(File('assets/model/model.json').readAsStringSync()) as Map<String, dynamic>);
  final golden = (jsonDecode(File('test/assets/golden_vectors.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  for (var i = 0; i < golden.length; i++) {
    final g = golden[i];
    final text = g['text'] as String;
    final rating = (g['rating'] as num?)?.toDouble();
    test('golden #$i matches Python', () {
      expect(cleanText(text), g['clean']);
      expect(tokenize(text), (g['tokens'] as List).cast<String>());
      final f = numericFeatures(text, rating);
      final pf = (g['features'] as List).cast<num>();
      for (var k = 0; k < pf.length; k++) { expect(f[k], closeTo(pf[k].toDouble(), 1e-9), reason: numericFeatureNames[k]); }
      expect(model.rawScore(text, rating), closeTo((g['raw_score'] as num).toDouble(), 1e-6));
      expect(model.probFake(text, rating), closeTo((g['prob_fake'] as num).toDouble(), 1e-6));
      expect(model.verdictFor(model.probFake(text, rating)).label, g['label']);
    });
  }
  test('probText rounds to 5%', () {
    expect(probText(0.87), '85%'); expect(probText(0.001), '<5%'); expect(probText(0.99), '>95%');
  });
}
