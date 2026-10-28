import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../core/model.dart';
import '../core/models.dart';

class ReportData {
  ReportData(this.total, this.verdicts, this.ratings, this.perDay, this.indicators, this.products, this.reviewers);
  final int total;
  final Map<Verdict, int> verdicts;
  final Map<int, int> ratings; // 0 = no rating given
  final List<MapEntry<String, Map<Verdict, int>>> perDay;
  final Map<String, int> indicators;
  final List<Map<String, Object?>> products; // product_id, n, suspicious
  final List<Map<String, Object?>> reviewers; // reviewer_id, n
}

class AppDb {
  AppDb(this.db);
  final Database db;

  /// [path] / [factory] are only overridden by automated tests.
  static Future<AppDb> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final p = path ?? join(await f.getDatabasesPath(), 'reviews.db');
    final db = await f.openDatabase(p,
        options: OpenDatabaseOptions(version: 1, onCreate: (d, v) async {
          await d.execute('''CREATE TABLE reviews(
            id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, rating REAL, reviewer_id TEXT,
            product_id TEXT, review_time TEXT, prob REAL, verdict TEXT NOT NULL, warnings TEXT NOT NULL,
            created_at TEXT NOT NULL, source TEXT NOT NULL, note TEXT)''');
          await d.execute('CREATE INDEX idx_verdict ON reviews(verdict)');
          await d.execute('CREATE INDEX idx_reviewer ON reviews(reviewer_id)');
          await d.execute('CREATE INDEX idx_product ON reviews(product_id)');
        }));
    return AppDb(db);
  }

  Future<void> close() => db.close();

  Future<int> insert(ReviewRecord r) async => r.id = await db.insert('reviews', r.toRow());

  Future<void> insertMany(List<ReviewRecord> rs) async {
    await db.transaction((txn) async {
      final b = txn.batch();
      for (final r in rs) { b.insert('reviews', r.toRow()); }
      await b.commit(noResult: true);
    });
  }

  Future<List<ReviewRecord>> query({String? search, Verdict? verdict, String? product, int limit = 500}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
      where.add(r"(text LIKE ? ESCAPE '\' OR reviewer_id LIKE ? ESCAPE '\' OR product_id LIKE ? ESCAPE '\')");
      args.addAll(['%$s%', '%$s%', '%$s%']);
    }
    if (verdict != null) { where.add('verdict = ?'); args.add(verdict.name); }
    if (product != null) { where.add('product_id = ?'); args.add(product); }
    final rows = await db.query('reviews',
        where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'id DESC', limit: limit);
    return rows.map(ReviewRecord.fromRow).toList();
  }

  Future<ReviewRecord?> get(int id) async {
    final r = await db.query('reviews', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : ReviewRecord.fromRow(r.first);
  }

  Future<List<ReviewRecord>> byReviewer(String id) async =>
      (await db.query('reviews', where: 'reviewer_id = ?', whereArgs: [id], limit: 500)).map(ReviewRecord.fromRow).toList();

  Future<int> delete(int id) => db.delete('reviews', where: 'id = ?', whereArgs: [id]);
  Future<int> clearAll() => db.delete('reviews');
  Future<int> count() async => Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reviews')) ?? 0;

  Future<ReportData> report() async {
    final v = <Verdict, int>{for (final x in Verdict.values) x: 0};
    for (final r in await db.rawQuery('SELECT verdict, COUNT(*) c FROM reviews GROUP BY verdict')) {
      v[VerdictX.parse(r['verdict'] as String)] = r['c'] as int;
    }
    final ratings = <int, int>{for (var i = 0; i <= 5; i++) i: 0};
    for (final r in await db.rawQuery('SELECT CAST(ROUND(COALESCE(rating,0)) AS INTEGER) k, COUNT(*) c FROM reviews GROUP BY k')) {
      ratings[r['k'] as int] = r['c'] as int;
    }
    final days = <String, Map<Verdict, int>>{};
    for (final r in await db.rawQuery(
        'SELECT substr(created_at,1,10) d, verdict, COUNT(*) c FROM reviews GROUP BY d, verdict ORDER BY d DESC LIMIT 60')) {
      (days[r['d'] as String] ??= {for (final x in Verdict.values) x: 0})[VerdictX.parse(r['verdict'] as String)] = r['c'] as int;
    }
    final ind = <String, int>{};
    for (final r in await db.rawQuery("SELECT warnings FROM reviews WHERE warnings != '[]'")) {
      for (final w in jsonDecode(r['warnings'] as String) as List) {
        final t = (w as Map)['title'] as String;
        ind[t] = (ind[t] ?? 0) + 1;
      }
    }
    final products = await db.rawQuery(
        "SELECT product_id, COUNT(*) n, SUM(verdict='suspicious') s FROM reviews WHERE product_id IS NOT NULL AND product_id != '' "
        'GROUP BY product_id ORDER BY s DESC, n DESC LIMIT 50');
    final reviewers = await db.rawQuery(
        "SELECT reviewer_id, COUNT(*) n FROM reviews WHERE reviewer_id IS NOT NULL AND reviewer_id != '' "
        """AND (warnings LIKE '%"code":"burst"%' OR warnings LIKE '%"code":"copy_paste"%') GROUP BY reviewer_id ORDER BY n DESC LIMIT 50""");
    return ReportData(v.values.fold(0, (a, b) => a + b), v, ratings, days.entries.toList(), ind, products, reviewers);
  }
}
