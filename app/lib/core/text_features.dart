// Dart port of ml/features.py. Keep both files in sync; test/golden_test.dart checks they agree.
import 'dart:math';

const numericFeatureNames = [
  'length', 'words', 'ttr', 'top_word_share', 'exclaim', 'caps', 'has_url',
  'has_contact', 'promo', 'rating_norm', 'rating_known', 'sentiment01', 'mismatch'
];

final _tokenRe = RegExp(r"[a-z0-9']+");
final _urlRe = RegExp(r"(?:https?://|www\.)\S+|[a-z0-9-]+\.(?:com|net|org|in|io|shop|store)\b", caseSensitive: false);
final _emailRe = RegExp(r"[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}", caseSensitive: false);
final _phoneRe = RegExp(r"\+?\d[\d\s().-]{8,}\d");
final _ctrlRe = RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f\u200b-\u200d\ufeff]');
final _spaceRe = RegExp(r'[ \t\r\n\f\v\u00a0]+');
const _contactWords = ['whatsapp', 'telegram', 'contact me', 'call me', 'dm me'];
const _promoPhrases = [
  'buy now', 'order now', 'discount', 'free', 'click', 'limited offer', 'best price', 'cheap',
  'guaranteed', 'must buy', '100%', 'coupon', 'promo', 'use code', 'visit'
];
const _positive = {
  'good', 'great', 'excellent', 'love', 'loved', 'perfect', 'amazing', 'awesome', 'best', 'nice',
  'happy', 'fantastic', 'wonderful', 'recommend', 'works', 'smooth', 'comfortable', 'sturdy', 'fast'
};
const _negative = {
  'bad', 'poor', 'terrible', 'awful', 'hate', 'hated', 'worst', 'broken', 'broke', 'useless', 'waste',
  'disappointed', 'disappointing', 'slow', 'cheap', 'defective', 'faulty', 'refund', 'return'
};

String cleanText(String? text) {
  if (text == null) return '';
  var t = text.replaceAll(_ctrlRe, '');
  t = t.replaceAll('\u2018', "'").replaceAll('\u2019', "'").replaceAll('\u201c', '"').replaceAll('\u201d', '"');
  return t.replaceAll(_spaceRe, ' ').trim();
}

List<String> tokenize(String? text) =>
    _tokenRe.allMatches(cleanText(text).toLowerCase()).map((m) => m.group(0)!).toList();

int _count(String s, String p) {
  var c = 0, i = 0;
  while (true) {
    i = s.indexOf(p, i);
    if (i < 0) break;
    c++;
    i += p.length;
  }
  return c;
}

bool hasUrl(String t) => _urlRe.hasMatch(cleanText(t));
bool hasContact(String t) {
  final c = cleanText(t);
  final low = c.toLowerCase();
  return _emailRe.hasMatch(c) || _phoneRe.hasMatch(c) || _contactWords.any(low.contains);
}

int promoCount(String t) {
  final low = cleanText(t).toLowerCase();
  return _promoPhrases.fold(0, (a, p) => a + _count(low, p));
}

List<double> numericFeatures(String? text, double? rating) {
  final t = cleanText(text);
  final low = t.toLowerCase();
  final toks = _tokenRe.allMatches(low).map((m) => m.group(0)!).toList();
  final n = toks.length;
  final uniq = toks.toSet().length;
  final ttr = n > 0 ? uniq / n : 0.0;
  var top = 0.0;
  final counts = <String, int>{};
  for (final w in toks) {
    if (w.length >= 4) counts[w] = (counts[w] ?? 0) + 1;
  }
  if (counts.isNotEmpty && n > 0) top = counts.values.reduce(max) / n;
  var upper = 0, letters = 0;
  for (final u in t.codeUnits) {
    if (u >= 65 && u <= 90) { upper++; letters++; }
    else if (u >= 97 && u <= 122) { letters++; }
  }
  final caps = letters > 0 ? upper / letters : 0.0;
  final known = rating != null && !rating.isNaN;
  final pos = toks.where(_positive.contains).length;
  final neg = toks.where(_negative.contains).length;
  final sent = (pos + neg) > 0 ? (pos - neg) / (pos + neg) : 0.0;
  final mismatch = (known && pos + neg > 0) ? ((sent - (rating - 3.0) / 2.0).abs() / 2.0) : 0.0;
  return [
    min(t.length / 1000.0, 1.0), min(n / 200.0, 1.0), ttr, top,
    min(_count(t, '!') / 10.0, 1.0), caps,
    _urlRe.hasMatch(t) ? 1.0 : 0.0,
    hasContact(t) ? 1.0 : 0.0,
    min(promoCount(t) / 3.0, 1.0),
    known ? (rating - 1.0) / 4.0 : 0.0,
    known ? 1.0 : 0.0,
    (sent + 1.0) / 2.0,
    mismatch,
  ];
}
