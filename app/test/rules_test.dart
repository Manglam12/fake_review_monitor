import 'package:fake_review_monitor/core/analyzer.dart';
import 'package:fake_review_monitor/core/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool has(List<dynamic> w, String c) => w.any((x) => x.code == c);
  group('single review warnings', () {
    test('short positive 5-star review gets no warnings', () => expect(singleReviewWarnings('Great product, works well.'), isEmpty));
    test('link and contact', () {
      final w = singleReviewWarnings('Visit www.deals.com or whatsapp +91 98765 43210');
      expect(has(w, 'link'), true); expect(has(w, 'contact'), true);
    });
    test('promo needs two phrases', () {
      expect(has(singleReviewWarnings('Free shipping was nice'), 'promo'), false);
      expect(has(singleReviewWarnings('Buy now and get a discount!'), 'promo'), true);
    });
    test('repetition', () => expect(has(singleReviewWarnings('great product great product great product great product great'), 'repetition'), true));
    test('emoji / special characters do not crash', () => singleReviewWarnings('\u{1F60D}\u{1F60D} <b>x</b> \u4e2d\u6587 ;--'));
  });
  group('batch rules', () {
    test('exact and near duplicates', () {
      final r = runBatchRules([
        RuleInput(0, 'Excellent quality very satisfied with this purchase today'),
        RuleInput(1, 'excellent quality, very satisfied with this purchase today!'),
        RuleInput(2, 'Excellent quality very satisfied with this purchase today really'),
        RuleInput(3, 'Totally different sentence about a kettle that leaks water'),
      ]);
      expect(has(r.perRow[0]!, 'duplicate'), true);
      expect(has(r.perRow[2]!, 'near_duplicate'), true);
      expect(r.perRow[3], isNull);
    });
    test('burst of 5 reviews in 24h by one reviewer', () {
      final t = DateTime(2024, 1, 1);
      final r = runBatchRules([for (var i = 0; i < 5; i++) RuleInput(i, 'review number $i is unique enough', reviewer: 'A', time: t.add(Duration(hours: i)))]);
      expect(has(r.perRow[0]!, 'burst'), true); expect(r.reviewers.single.reviewer, 'A');
    });
    test('no burst when reviews are spread out', () {
      final t = DateTime(2024, 1, 1);
      final r = runBatchRules([for (var i = 0; i < 5; i++) RuleInput(i, 'review number $i is unique enough', reviewer: 'A', time: t.add(Duration(days: i * 3)))]);
      expect(r.perRow[0], isNull);
    });
    test('missing metadata: behaviour rules are skipped, nothing invented', () {
      final r = runBatchRules([for (var i = 0; i < 12; i++) RuleInput(i, 'unique review text number $i here')]);
      expect(r.reviewers, isEmpty); expect(r.products, isEmpty);
    });
    test('copy-paste across products', () {
      final r = runBatchRules([RuleInput(0, 'same words here everywhere', reviewer: 'B', product: 'P1'), RuleInput(1, 'same words here everywhere', reviewer: 'B', product: 'P2')]);
      expect(has(r.perRow[0]!, 'copy_paste'), true);
    });
    test('extreme rating pattern needs 10+ rated reviews', () {
      final few = runBatchRules([for (var i = 0; i < 9; i++) RuleInput(i, 'text $i unique words', product: 'P', rating: 5)]);
      final many = runBatchRules([for (var i = 0; i < 10; i++) RuleInput(i, 'text $i unique words', product: 'P', rating: 5)]);
      expect(few.perRow[0], isNull); expect(has(many.perRow[0]!, 'extreme_ratings'), true);
    });
  });
  group('input validation', () {
    test('empty / whitespace', () { expect(validateReviewText(''), isNotNull); expect(validateReviewText('   \n'), isNotNull); });
    test('valid / too long', () { expect(validateReviewText('ok review'), isNull); expect(validateReviewText('a' * 5001), isNotNull); });
    test('ids optional, max 64', () { expect(validateId(null), isNull); expect(validateId('x' * 65), isNotNull); });
  });
}
