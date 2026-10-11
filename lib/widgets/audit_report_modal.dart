import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fruit_safe/services/audit_report_service.dart';
import 'package:fruit_safe/theme/app_theme.dart';
import 'package:printing/printing.dart';

/// Opens the official inspection receipt for [data].
Future<void> showAuditReport(BuildContext context, AuditReportData data) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => AuditReportModal(data: data),
  );
}

class AuditReportModal extends StatefulWidget {
  const AuditReportModal({super.key, required this.data});

  final AuditReportData data;

  @override
  State<AuditReportModal> createState() => _AuditReportModalState();
}

class _AuditReportModalState extends State<AuditReportModal> {
  var _printing = false;

  Future<void> _copyReceipt() async {
    await Clipboard.setData(
      ClipboardData(text: AuditReportService.formatPlainTextReceipt(widget.data)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt copied to clipboard.')),
    );
  }

  Future<void> _printReceipt() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await Printing.layoutPdf(
        onLayout: (format) => AuditReportService.generatePdfBytes(widget.data),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the print dialog.')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final textTheme = Theme.of(context).textTheme;
    final bannerColor = _bannerColor(data.riskTier);
    final height = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.92),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkSlate.withValues(alpha: 0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _DashedRule(),
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.darkSlate,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'OFFICIAL INSPECTION RECEIPT',
                            style: textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        data.fruitName,
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _MetaLine(label: 'Batch ID', value: data.batchId),
                      _MetaLine(label: 'Timestamp', value: data.formattedDate),
                      _MetaLine(label: 'Market hub', value: data.inspectionUnit),
                      const SizedBox(height: 12),
                      _ReadingRow(
                        label: 'Acetylene Gas Level',
                        value: '${data.acetylenePpm.toStringAsFixed(1)} PPM',
                      ),
                      _ReadingRow(
                        label: 'VOC Gas Level',
                        value: '${data.vocPpm.toStringAsFixed(1)} PPM',
                      ),
                      _ReadingRow(
                        label: 'Visual Anomaly Index',
                        value: '${data.visualAnomalyScore.toStringAsFixed(1)}%',
                      ),
                      _ReadingRow(
                        label: 'Composite API',
                        value: '${data.apiScore.toStringAsFixed(1)}%',
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: bannerColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data.clearanceStatus,
                          textAlign: TextAlign.center,
                          style: textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Advisory (${data.languageName})',
                        style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.advisoryText,
                        style: textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      const _DashedRule(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _copyReceipt,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy Receipt'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _printing ? null : _printReceipt,
                icon: _printing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Print / Save PDF'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _bannerColor(String riskTier) {
    switch (riskTier) {
      case 'SAFE':
        return AppColors.statusVerdant;
      case 'DANGER':
        return AppColors.statusDanger;
      default:
        return AppColors.statusWarning;
    }
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: textTheme.bodyMedium?.copyWith(color: AppColors.darkSlate, height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: 8,
      child: CustomPaint(painter: _DashPainter()),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.darkSlate.withValues(alpha: 0.35)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
