import 'cpms_form_page.dart';
import 'cpms_page_route.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../utils/file_downloader/file_downloader.dart';

class ExportOptionsDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String baseFileName,
    required Future<Uint8List> Function() onGeneratePdf,
    required Future<Uint8List> Function() onGenerateCsv,
  }) {
    bool isBusy = false;

    return openCpmsPage(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          Future<void> runExport(Future<void> Function() action) async {
            setDlgState(() => isBusy = true);
            try {
              await action();
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Export failed: $e'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            } finally {
              if (ctx.mounted) setDlgState(() => isBusy = false);
            }
          }

          return CpmsFormPage(
            title: Row(
              children: [
                const Icon(Icons.file_download_outlined, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                _ExportOptionTile(
                  icon: Icons.picture_as_pdf_outlined,
                  iconColor: const Color(0xFFDC2626),
                  title: 'Download PDF',
                  description: 'Formatted report ready for sharing or archiving',
                  disabled: isBusy,
                  onTap: () => runExport(() async {
                    final bytes = await onGeneratePdf();
                    final filename = '$baseFileName.pdf';
                    await FileDownloader.download(
                      bytes: bytes,
                      filename: filename,
                      mimeType: 'application/pdf',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Downloaded "$filename"'),
                          backgroundColor: Colors.black,
                        ),
                      );
                    }
                  }),
                ),
                const SizedBox(height: 10),
                _ExportOptionTile(
                  icon: Icons.table_chart_outlined,
                  iconColor: const Color(0xFF16A34A),
                  title: 'Download CSV (Excel)',
                  description: 'Spreadsheet-compatible tabular data',
                  disabled: isBusy,
                  onTap: () => runExport(() async {
                    final bytes = await onGenerateCsv();
                    final filename = '$baseFileName.csv';
                    await FileDownloader.download(
                      bytes: bytes,
                      filename: filename,
                      mimeType: 'text/csv',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Downloaded "$filename"'),
                          backgroundColor: Colors.black,
                        ),
                      );
                    }
                  }),
                ),
                const SizedBox(height: 10),
                _ExportOptionTile(
                  icon: Icons.print_outlined,
                  iconColor: const Color(0xFF0F172A),
                  title: 'Print Document',
                  description: 'Send directly to printer or Save as PDF',
                  disabled: isBusy,
                  onTap: () => runExport(() async {
                    await Printing.layoutPdf(
                      name: baseFileName,
                      onLayout: (_) => onGeneratePdf(),
                    );
                  }),
                ),
                if (isBusy) ...[
                  const SizedBox(height: 14),
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isBusy ? null : () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool disabled;
  final VoidCallback onTap;

  const _ExportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

