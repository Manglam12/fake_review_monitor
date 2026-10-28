import 'dart:io';
import 'package:fake_review_monitor/core/model.dart';
import 'package:fake_review_monitor/core/models.dart';
import 'package:fake_review_monitor/data/csv_io.dart';
import 'package:fake_review_monitor/data/db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ReviewRecord rec(String t, Verdict v, {String? rev, String? prod, double? rating}) =>
    ReviewRecord(text: t, verdict: v, prob: 0.5, reviewerId: rev, productId: prod, rating: rating);

void main() {
  sqfliteFfiInit();
  group('CSV', () {
    test('valid with optional columns missing', () {
      final p = parseBatchCsv('review_text\nGood one\n"Nice, really \u{1F60D}"\n');
      expect(p.ok, true); expect(p.rows.length, 2); expect(p.foundColumns, {'review_text'});
    });
    test('missing review column is a clear fatal error', () {
      final p = parseBatchCsv('foo,bar\n1,2\n');
      expect(p.ok, false); expect(p.problems.first, contains('FATAL'));
    });
    test('empty file / header only', () { expect(parseBatchCsv('').ok, false); expect(parseBatchCsv('review_text\n').ok, false); });
    test('bad rating and empty text handled', () {
      final p = parseBatchCsv('review_text,rating\nfine text,9\n,5\nok again,4\n');
      expect(p.rows.length, 2); expect(p.badRatings, 1); expect(p.skippedEmpty, 1); expect(p.rows.first.rating, isNull);
    });
    test('windows line endings', () => expect(parseBatchCsv('review_text,rating\r\nhello there,5\r\n').rows.length, 1));
    test('csv export neutralises formulas', () => expect(resultsToCsv([rec('=HYPERLINK("x")', Verdict.uncertain)]), contains("'=HYPERLINK")));
  });
  group('Database', () {
    late AppDb db;
    setUp(() async => db = await AppDb.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi));
    tearDown(() => db.close());
    test('save, search, filter, delete, clear', () async {
      await db.insert(rec('cheap blender broke', Verdict.likelyGenuine, rev: 'u1', prod: 'P1'));
      await db.insert(rec('BUY NOW 100% free', Verdict.suspicious, rev: 'u2', prod: 'P1'));
      expect((await db.query()).length, 2);
      expect((await db.query(search: 'blender')).single.reviewerId, 'u1');
      expect((await db.query(verdict: Verdict.suspicious)).single.text, contains('BUY'));
      expect((await db.query(search: '%')).length, 1); // only the text with a real '%', so % is not a wildcard
      final id = (await db.query(search: 'blender')).single.id!;
      await db.delete(id);
      expect(await db.count(), 1);
      await db.clearAll();
      expect(await db.count(), 0);
    });
    test('report built from stored rows', () async {
      await db.insert(rec('a b c', Verdict.suspicious, prod: 'P9', rating: 5));
      final r = await db.report();
      expect(r.total, 1); expect(r.verdicts[Verdict.suspicious], 1); expect(r.ratings[5], 1); expect(r.products.first['product_id'], 'P9');
    });
  });
  test('data persists after closing and reopening', () async {
    final path = '${Directory.systemTemp.path}/frm_test_${DateTime.now().microsecondsSinceEpoch}.db';
    var db = await AppDb.open(path: path, factory: databaseFactoryFfi);
    await db.insert(rec('persist me', Verdict.uncertain));
    await db.close();
    db = await AppDb.open(path: path, factory: databaseFactoryFfi);
    expect((await db.query()).single.text, 'persist me');
    await db.close();
    File(path).deleteSync();
  });
}
