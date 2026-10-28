import 'dart:convert';
import 'model.dart';

class RuleWarning {
  const RuleWarning(this.code, this.title, this.detail);
  final String code, title, detail;
  Map<String, dynamic> toJson() => {'code': code, 'title': title, 'detail': detail};
  factory RuleWarning.fromJson(Map<String, dynamic> j) =>
      RuleWarning(j['code'] as String, j['title'] as String, j['detail'] as String);
}

class ReviewRecord {
  ReviewRecord({
    this.id, required this.text, this.rating, this.reviewerId, this.productId, this.reviewTime,
    this.prob, required this.verdict, this.warnings = const [], DateTime? createdAt,
    this.source = 'single', this.note,
  }) : createdAt = createdAt ?? DateTime.now();

  int? id;
  final String text;
  final double? rating;
  final String? reviewerId, productId, note;
  final DateTime? reviewTime;
  double? prob; // null when the model score is not shown (e.g. too little text)
  Verdict verdict;
  List<RuleWarning> warnings;
  final DateTime createdAt;
  final String source;

  Map<String, Object?> toRow() => {
        'text': text, 'rating': rating, 'reviewer_id': reviewerId, 'product_id': productId,
        'review_time': reviewTime?.toIso8601String(), 'prob': prob, 'verdict': verdict.name,
        'warnings': jsonEncode(warnings.map((w) => w.toJson()).toList()),
        'created_at': createdAt.toIso8601String(), 'source': source, 'note': note,
      };

  factory ReviewRecord.fromRow(Map<String, Object?> r) => ReviewRecord(
        id: r['id'] as int?, text: r['text'] as String, rating: (r['rating'] as num?)?.toDouble(),
        reviewerId: r['reviewer_id'] as String?, productId: r['product_id'] as String?,
        reviewTime: r['review_time'] == null ? null : DateTime.tryParse(r['review_time'] as String),
        prob: (r['prob'] as num?)?.toDouble(), verdict: VerdictX.parse(r['verdict'] as String),
        warnings: (jsonDecode(r['warnings'] as String) as List)
            .map((e) => RuleWarning.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(r['created_at'] as String), source: r['source'] as String,
        note: r['note'] as String?,
      );
}
