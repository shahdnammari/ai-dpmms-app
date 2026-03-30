import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/report_models.dart';

class ReportExportService {
  Future<Uint8List> buildPdf({
    required ReportResult report,
    required String periodLabel,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Medication Report',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            periodLabel,
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 20),

          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _metric(
                  title: 'Adherence',
                  value: '${report.summary.adherencePercent}%',
                ),
                _metric(
                  title: 'Taken',
                  value: '${report.summary.taken}',
                ),
                _metric(
                  title: 'Missed',
                  value: '${report.summary.missed}',
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          pw.Text(
            'Overview',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Label', bold: true),
                  _cell('Taken', bold: true),
                  _cell('Missed', bold: true),
                  _cell('Adherence', bold: true),
                ],
              ),
              ...report.bars.map(
                (bar) => pw.TableRow(
                  children: [
                    _cell(bar.label),
                    _cell('${bar.taken}'),
                    _cell('${bar.missed}'),
                    _cell('${bar.adherencePercent}%'),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          pw.Text(
            'Insights',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Bullet(text: 'Best: ${report.insights.bestLabel}'),
          pw.Bullet(
            text: 'Most Missed: ${report.insights.mostMissedMedication}',
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<File> savePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> sharePdf({
    required ReportResult report,
    required String periodLabel,
    required String fileName,
  }) async {
    final bytes = await buildPdf(
      report: report,
      periodLabel: periodLabel,
    );

    final file = await savePdf(
      bytes: bytes,
      fileName: fileName,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Medication report - $periodLabel',
    );
  }

  Future<void> printPdf({
    required ReportResult report,
    required String periodLabel,
  }) async {
    final bytes = await buildPdf(
      report: report,
      periodLabel: periodLabel,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
    );
  }

  Future<void> previewPdf({
    required ReportResult report,
    required String periodLabel,
  }) async {
    final bytes = await buildPdf(
      report: report,
      periodLabel: periodLabel,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'medication_report.pdf',
    );
  }

  pw.Widget _metric({
    required String title,
    required String value,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(title),
      ],
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 11,
        ),
      ),
    );
  }
}