import 'dart:typed_data';

import 'package:fruit_safe/models/diagnostic_data.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// One exportable Fruit-Safe inspection certificate.
class AuditReportData {
  const AuditReportData({
    required this.batchId,
    required this.formattedDate,
    required this.fruitName,
    required this.acetylenePpm,
    required this.vocPpm,
    required this.visualAnomalyScore,
    required this.apiScore,
    required this.riskTier,
    required this.languageName,
    required this.advisoryText,
    this.inspectionUnit = defaultInspectionUnit,
  });

  static const defaultInspectionUnit = 'Field Station #04 - Kwara / Lagos Produce Hub';

  final String batchId;
  final String formattedDate;
  final String fruitName;
  final double acetylenePpm;
  final double vocPpm;
  final double visualAnomalyScore;
  final double apiScore;

  /// One of `SAFE`, `CAUTION`, or `DANGER`.
  final String riskTier;
  final String languageName;
  final String advisoryText;
  final String inspectionUnit;

  /// Builds a receipt from the scan already shown on the results screen.
  factory AuditReportData.fromDiagnostic(
    DiagnosticData diagnostic, {
    required String languageName,
    DateTime? issuedAt,
    String inspectionUnit = defaultInspectionUnit,
  }) {
    final at = issuedAt ?? DateTime.now();
    final stamp = at.millisecondsSinceEpoch.toString();
    return AuditReportData(
      batchId: 'FS-NG-${stamp.substring(6)}',
      formattedDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(at),
      fruitName: diagnostic.fruitType,
      acetylenePpm: diagnostic.acetylenePpm,
      vocPpm: diagnostic.vocLevel,
      visualAnomalyScore: diagnostic.visualScore,
      apiScore: diagnostic.apiScore,
      riskTier: tierForStatus(diagnostic.status),
      languageName: languageName,
      advisoryText: diagnostic.audioFeedbackText,
      inspectionUnit: inspectionUnit,
    );
  }

  /// Maps the on-screen Safe / Warning / Danger label onto a certificate tier.
  static String tierForStatus(String status) {
    switch (status) {
      case 'Safe':
      case 'SAFE':
        return 'SAFE';
      case 'Warning':
      case 'WARNING':
      case 'CAUTION':
        return 'CAUTION';
      case 'Danger':
      case 'DANGER':
        return 'DANGER';
      default:
        return status.toUpperCase();
    }
  }

  String get clearanceStatus {
    switch (riskTier) {
      case 'SAFE':
        return 'STATUS: CLEARED FOR TRADE & CONSUMPTION';
      case 'DANGER':
        return 'STATUS: SUSPECTED CHEMICAL ADULTERATION (CaC2)';
      default:
        return 'STATUS: RECHECK BEFORE TRADE';
    }
  }
}

/// Plain-text and PDF forms of an [AuditReportData] receipt.
class AuditReportService {
  const AuditReportService._();

  static String formatPlainTextReceipt(AuditReportData data) {
    return [
      'FRUIT-SAFE OFFICIAL INSPECTION RECEIPT',
      'Batch: ${data.batchId}',
      'Timestamp: ${data.formattedDate}',
      'Market hub: ${data.inspectionUnit}',
      'Fruit: ${data.fruitName}',
      'Acetylene Gas Level: ${data.acetylenePpm.toStringAsFixed(1)} PPM',
      'VOC Gas Level: ${data.vocPpm.toStringAsFixed(1)} PPM',
      'Visual Anomaly Index: ${data.visualAnomalyScore.toStringAsFixed(1)}%',
      'Composite API: ${data.apiScore.toStringAsFixed(1)}%',
      'Risk tier: ${data.riskTier}',
      data.clearanceStatus,
      'Advisory (${data.languageName}): ${data.advisoryText}',
    ].join('\n');
  }

  static Future<Uint8List> generatePdfBytes(AuditReportData data) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final stamp = _stampColor(data.riskTier);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey800, width: 1.4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'FRUIT-SAFE BIOCHEMICAL DIAGNOSTIC AUDIT CERTIFICATE',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  data.fruitName,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 16),
                _metaTable(data),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Chemical telemetry',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
                pw.SizedBox(height: 6),
                _telemetryTable(data),
                pw.SizedBox(height: 16),
                pw.Container(
                  color: stamp,
                  padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  child: pw.Text(
                    data.clearanceStatus,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Vernacular advisory (${data.languageName})',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
                pw.SizedBox(height: 6),
                pw.Text(data.advisoryText, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
              ],
            ),
          );
        },
      ),
    );
    return document.save();
  }

  static PdfColor _stampColor(String riskTier) {
    switch (riskTier) {
      case 'SAFE':
        return const PdfColor.fromInt(0xFF059669);
      case 'DANGER':
        return const PdfColor.fromInt(0xFFDC2626);
      default:
        return const PdfColor.fromInt(0xFFF59E0B);
    }
  }

  static pw.Widget _metaTable(AuditReportData data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(2.2),
      },
      children: [
        _pair('Batch ID', data.batchId),
        _pair('Timestamp', data.formattedDate),
        _pair('Fruit', data.fruitName),
        _pair('Language', data.languageName),
        _pair('Inspection unit', data.inspectionUnit),
      ],
    );
  }

  static pw.Widget _telemetryTable(AuditReportData data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        _pair('Acetylene (C2H2)', '${data.acetylenePpm.toStringAsFixed(1)} PPM'),
        _pair('VOC', '${data.vocPpm.toStringAsFixed(1)} PPM'),
        _pair('Visual anomaly (Sv)', '${data.visualAnomalyScore.toStringAsFixed(1)}%'),
        _pair('Adulteration Probability Index', '${data.apiScore.toStringAsFixed(1)}%'),
      ],
    );
  }

  static pw.TableRow _pair(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }
}
