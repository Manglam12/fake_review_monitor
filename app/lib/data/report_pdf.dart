import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/model.dart';
import 'db.dart';

Future<List<int>> buildReportPdf(ReportData d, {required bool demoModel}) async {
  final doc = pw.Document();
  pw.Widget table(List<List<String>> rows) => pw.TableHelper.fromTextArray(data: rows, cellStyle: const pw.TextStyle(fontSize: 10));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    build: (c) => [
      pw.Text('Fake Review Monitoring - Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.Text('Generated ${DateTime.now().toIso8601String().substring(0, 16)}'),
      if (demoModel) pw.Text('DEMO MODEL: trained on synthetic data. Results are not real-world performance.',
          style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.Text('Totals (${d.total} reviews analysed)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      table([for (final v in Verdict.values) [v.label, '${d.verdicts[v]}']]),
      pw.SizedBox(height: 10),
      pw.Text('Rating distribution', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      table([for (var i = 1; i <= 5; i++) ['$i star', '${d.ratings[i]}'], ['No rating', '${d.ratings[0]}']]),
      pw.SizedBox(height: 10),
      pw.Text('Rule-based indicators (warnings, not proof)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      table(d.indicators.isEmpty ? [['None recorded', '']] : [for (final e in d.indicators.entries) [e.key, '${e.value}']]),
      pw.SizedBox(height: 10),
      pw.Text('Per product', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      table([['Product', 'Reviews', 'Suspicious'], for (final p in d.products) ['${p['product_id']}', '${p['n']}', '${p['s']}']]),
      pw.SizedBox(height: 10),
      pw.Text('Per day', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      table([['Date', 'Genuine', 'Uncertain', 'Suspicious'],
        for (final e in d.perDay) [e.key, '${e.value[Verdict.likelyGenuine]}', '${e.value[Verdict.uncertain]}', '${e.value[Verdict.suspicious]}']]),
      pw.SizedBox(height: 14),
      pw.Text('Predictions can be wrong. Do not use them as the only basis for accusing a person or business.',
          style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
    ],
  ));
  return doc.save();
}
