// Rule-based WARNING indicators. Separate from the ML model. They are hints, never proof.
import 'models.dart';
import 'text_features.dart';

List<RuleWarning> singleReviewWarnings(String text) {
  final w = <RuleWarning>[];
  final f = numericFeatures(text, null);
  final n = tokenize(text).length;
  if (hasUrl(text)) w.add(const RuleWarning('link', 'Contains a link', 'Reviews with web links are sometimes advertising.'));
  if (hasContact(text)) w.add(const RuleWarning('contact', 'Contact details', 'Phone, email or messaging-app details appear in the text.'));
  if (promoCount(text) >= 2) w.add(const RuleWarning('promo', 'Promotional wording', 'Several sales-style phrases (e.g. "buy now", "discount").'));
  final sentences = text.split(RegExp(r'[.!?]+')).map((s) => tokenize(s).join(' ')).where((s) => s.split(' ').length >= 3).toList();
  final repeatedSentence = sentences.length != sentences.toSet().length;
  if ((n >= 8 && f[3] >= 0.25) || repeatedSentence) {
    w.add(const RuleWarning('repetition', 'Repetitive text', 'The same words or sentences repeat a lot.'));
  }
  final letters = text.codeUnits.where((u) => (u >= 65 && u <= 90) || (u >= 97 && u <= 122)).length;
  if ('!'.allMatches(text).length >= 4 || (letters >= 15 && f[5] >= 0.6)) {
    w.add(const RuleWarning('shouting', 'Excessive capitals or exclamation marks', 'Very loud, spam-like style.'));
  }
  return w;
}

class RuleInput {
  RuleInput(this.idx, this.text, {this.rating, this.reviewer, this.product, this.time});
  final int idx;
  final String text;
  final double? rating;
  final String? reviewer, product;
  final DateTime? time;
}

class ProductSummary {
  ProductSummary(this.product, this.count, this.avgRating, this.extremeRatings, this.burst);
  final String product;
  final int count;
  final double? avgRating;
  final bool extremeRatings, burst;
}

class ReviewerFlag {
  ReviewerFlag(this.reviewer, this.count, this.reasons);
  final String reviewer;
  final int count;
  final Set<String> reasons;
}

class BatchRuleResult {
  final Map<int, List<RuleWarning>> perRow = {};
  final List<ProductSummary> products = [];
  final List<ReviewerFlag> reviewers = [];
  final List<String> notes = [];
  int duplicateRows = 0, nearDuplicateRows = 0;
}

String _norm(String t) => tokenize(t).join(' ');
bool _has(String? s) => s != null && s.trim().isNotEmpty;

/// Looks across many reviews. Needs reviewer/product/time columns for the behaviour rules;
/// without them those rules are simply skipped (nothing is invented).
BatchRuleResult runBatchRules(List<RuleInput> rows,
    {int nearDupPairBudget = 300000, int burstCount = 5, Duration burstWindow = const Duration(hours: 24)}) {
  final res = BatchRuleResult();
  void add(int i, RuleWarning w) {
    final l = res.perRow.putIfAbsent(i, () => []);
    if (!l.any((x) => x.code == w.code)) l.add(w);
  }

  final norm = {for (final r in rows) r.idx: _norm(r.text)};
  final byNorm = <String, List<int>>{};
  norm.forEach((i, n) { if (n.isNotEmpty) byNorm.putIfAbsent(n, () => []).add(i); });
  final dupIdx = <int>{};
  byNorm.forEach((_, v) {
    if (v.length >= 2) {
      for (final i in v) {
        add(i, RuleWarning('duplicate', 'Duplicate text', 'The same wording appears in ${v.length} reviews in this data.'));
        dupIdx.add(i);
      }
    }
  });
  res.duplicateRows = dupIdx.length;

  // near-duplicates: Jaccard >= 0.8 on word sets, only for reviews with >= 6 distinct words
  final sets = {for (final r in rows) r.idx: norm[r.idx]!.isEmpty ? <String>{} : norm[r.idx]!.split(' ').toSet()};
  final cand = rows.where((r) => sets[r.idx]!.length >= 6).map((r) => r.idx).toList()
    ..sort((a, b) => sets[a]!.length.compareTo(sets[b]!.length));
  var pairs = 0;
  final nearIdx = <int>{};
  outer:
  for (var a = 0; a < cand.length; a++) {
    final sa = sets[cand[a]]!;
    for (var b = a + 1; b < cand.length; b++) {
      final sb = sets[cand[b]]!;
      if (sa.length < 0.8 * sb.length) break;
      if (norm[cand[a]] == norm[cand[b]]) continue;
      if (++pairs > nearDupPairBudget) {
        res.notes.add('Near-duplicate check stopped early (too many reviews to compare).');
        break outer;
      }
      final inter = sa.intersection(sb).length;
      if (inter / (sa.length + sb.length - inter) >= 0.8) {
        nearIdx..add(cand[a])..add(cand[b]);
      }
    }
  }
  for (final i in nearIdx) {
    add(i, const RuleWarning('near_duplicate', 'Near-duplicate text', 'Almost the same wording as another review in this data.'));
  }
  res.nearDuplicateRows = nearIdx.length;

  // reviewer behaviour (needs reviewer id; burst also needs time)
  final byReviewer = <String, List<RuleInput>>{};
  for (final r in rows) { if (_has(r.reviewer)) byReviewer.putIfAbsent(r.reviewer!.trim(), () => []).add(r); }
  byReviewer.forEach((rev, list) {
    final reasons = <String>{};
    final timed = list.where((r) => r.time != null).toList()..sort((a, b) => a.time!.compareTo(b.time!));
    for (var i = 0; i < timed.length; i++) {
      var j = i;
      while (j + 1 < timed.length && timed[j + 1].time!.difference(timed[i].time!) <= burstWindow) { j++; }
      if (j - i + 1 >= burstCount) {
        for (var k = i; k <= j; k++) {
          add(timed[k].idx, RuleWarning('burst', 'Burst of reviews', 'This reviewer posted ${j - i + 1}+ reviews within 24 hours.'));
        }
        reasons.add('burst');
      }
    }
    final byText = <String, List<RuleInput>>{};
    for (final r in list) { if (norm[r.idx]!.isNotEmpty) byText.putIfAbsent(norm[r.idx]!, () => []).add(r); }
    byText.forEach((_, same) {
      final prods = same.where((r) => _has(r.product)).map((r) => r.product!.trim()).toSet();
      if (prods.length >= 2) {
        for (final r in same) { add(r.idx, const RuleWarning('copy_paste', 'Same text on several products', 'This reviewer used identical text for different products.')); }
        reasons.add('copy_paste');
      }
    });
    if (reasons.isNotEmpty) res.reviewers.add(ReviewerFlag(rev, list.length, reasons));
  });

  // product-level patterns (need >= 10 reviews; warnings describe the product, not this review)
  final byProduct = <String, List<RuleInput>>{};
  for (final r in rows) { if (_has(r.product)) byProduct.putIfAbsent(r.product!.trim(), () => []).add(r); }
  byProduct.forEach((p, list) {
    final rated = list.where((r) => r.rating != null).toList();
    final avg = rated.isEmpty ? null : rated.fold(0.0, (a, r) => a + r.rating!) / rated.length;
    var extreme = false, burst = false;
    if (rated.length >= 10) {
      final five = rated.where((r) => r.rating! >= 4.5).length / rated.length;
      final one = rated.where((r) => r.rating! <= 1.5).length / rated.length;
      extreme = five >= 0.9 || one >= 0.9;
    }
    final timed = list.where((r) => r.time != null).toList()..sort((a, b) => a.time!.compareTo(b.time!));
    final burstIdx = <int>{};
    for (var i = 0; i < timed.length; i++) {
      var j = i;
      while (j + 1 < timed.length && timed[j + 1].time!.difference(timed[i].time!) <= burstWindow) { j++; }
      if (j - i + 1 >= 10) { burst = true; for (var k = i; k <= j; k++) { burstIdx.add(timed[k].idx); } }
    }
    for (final r in list) {
      if (extreme) add(r.idx, const RuleWarning('extreme_ratings', 'Unusual rating pattern for this product', 'Nearly all ratings for this product are the same extreme value. This describes the product, not this single review.'));
      if (burstIdx.contains(r.idx)) add(r.idx, const RuleWarning('product_burst', 'Burst of reviews on this product', '10+ reviews for this product within 24 hours.'));
    }
    res.products.add(ProductSummary(p, list.length, avg, extreme, burst));
  });
  return res;
}
