import 'model.dart';
import 'models.dart';
import 'rules.dart';
import 'text_features.dart';

const maxReviewChars = 5000;
const minWordsForPrediction = 3;

String? validateReviewText(String? v) {
  final t = cleanText(v);
  if (t.isEmpty) return 'Please enter or paste a review.';
  if ((v ?? '').length > maxReviewChars) return 'Too long (max $maxReviewChars characters).';
  return null;
}

String? validateId(String? v) {
  if (v == null || v.trim().isEmpty) return null; // optional
  if (v.trim().length > 64) return 'Max 64 characters.';
  return null;
}

class Analyzer {
  Analyzer(this.model);
  final ReviewModel model;

  /// ML prediction + single-review rule warnings. Behaviour rules (history) are added by the caller.
  ReviewRecord analyze(String text,
      {double? rating, String? reviewerId, String? productId, DateTime? reviewTime, String source = 'single'}) {
    final clean = cleanText(text);
    final words = tokenize(clean).length;
    final warnings = singleReviewWarnings(clean);
    if (words < minWordsForPrediction) {
      return ReviewRecord(text: clean, rating: rating, reviewerId: reviewerId, productId: productId,
          reviewTime: reviewTime, prob: null, verdict: Verdict.uncertain, warnings: warnings, source: source,
          note: 'Too little text (fewer than $minWordsForPrediction words) for a reliable prediction.');
    }
    final p = model.probFake(clean, rating);
    return ReviewRecord(text: clean, rating: rating, reviewerId: reviewerId, productId: productId,
        reviewTime: reviewTime, prob: p, verdict: model.verdictFor(p), warnings: warnings, source: source);
  }
}
