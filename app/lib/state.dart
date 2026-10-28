import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/analyzer.dart';
import 'core/model.dart';
import 'core/models.dart';
import 'core/rules.dart';
import 'data/db.dart';

class AppState {
  AppState._();
  static final AppState I = AppState._();
  late ReviewModel model;
  late AppDb db;
  late Analyzer analyzer;
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
  final dataVersion = ValueNotifier<int>(0); // screens reload when this changes
  void bump() => dataVersion.value++;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode.value = (prefs.getBool('light') ?? false) ? ThemeMode.light : ThemeMode.dark;
    model = ReviewModel(jsonDecode(await rootBundle.loadString('assets/model/model.json')) as Map<String, dynamic>);
    analyzer = Analyzer(model);
    db = await AppDb.open();
  }

  Future<void> setLight(bool light) async {
    themeMode.value = light ? ThemeMode.light : ThemeMode.dark;
    (await SharedPreferences.getInstance()).setBool('light', light);
  }

  /// Analyse one review, add behaviour warnings from reviews already stored on THIS device, save it.
  Future<ReviewRecord> analyzeAndSave(String text,
      {double? rating, String? reviewerId, String? productId, DateTime? time}) async {
    final rid = (reviewerId ?? '').trim().isEmpty ? null : reviewerId!.trim();
    final pid = (productId ?? '').trim().isEmpty ? null : productId!.trim();
    final r = analyzer.analyze(text, rating: rating, reviewerId: rid, productId: pid, reviewTime: time);
    if (rid != null) {
      final past = await db.byReviewer(rid);
      if (past.isNotEmpty) {
        final inputs = <RuleInput>[
          for (var i = 0; i < past.length; i++)
            RuleInput(i, past[i].text, rating: past[i].rating, reviewer: rid, product: past[i].productId, time: past[i].reviewTime),
          RuleInput(past.length, r.text, rating: rating, reviewer: rid, product: pid, time: time),
        ];
        final extra = runBatchRules(inputs).perRow[past.length] ?? [];
        r.warnings = [...r.warnings, ...extra.where((w) => !r.warnings.any((x) => x.code == w.code))];
      }
    }
    await db.insert(r);
    bump();
    return r;
  }

  Future<void> shareText(String filename, String content, {String mime = 'text/csv'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$filename');
    await f.writeAsString(content);
    await Share.shareXFiles([XFile(f.path, mimeType: mime)]);
  }

  Future<void> shareBytes(String filename, List<int> bytes, String mime) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$filename');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path, mimeType: mime)]);
  }
}
