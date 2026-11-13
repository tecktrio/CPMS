import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../providers/purchase_order_provider.dart';
import '../../services/purchase_order_export_service.dart';
import '../../utils/file_downloader/file_downloader.dart';
import '../../widgets/user_profile_avatar.dart';

enum ExportFormat { pdf, csv }

class PurchaseOrderExportScreen extends StatefulWidget {
  final PurchaseOrderModel po;

  const PurchaseOrderExportScreen({super.key, required this.po});

  @override
  State<PurchaseOrderExportScreen> createState() =>
      _PurchaseOrderExportScreenState();
}

class _PurchaseOrderExportScreenState extends State<PurchaseOrderExportScreen> {
  ExportFormat _selectedFormat = ExportFormat.pdf;
  bool _isExporting = false;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  Future<void> _handleDownload() async {
    setState(() => _isExporting = true);

    try {
      final po = widget.po;
      if (_selectedFormat == ExportFormat.pdf) {
        final bytes = await PurchaseOrderExportService.generatePdf(po);
        final filename = 'PO-${po.poNumber}.pdf';
        await FileDownloader.download(
          bytes: bytes,
          filename: filename,
          mimeType: 'application/pdf',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded "$filename" successfully!'),
              backgroundColor: Colors.black,
            ),
          );
        }
      } else {
        final bytes = PurchaseOrderExportService.generateCsvBytes(po);
        final filename = 'PO-${po.poNumber}.csv';
        await FileDownloader.download(
          bytes: bytes,
          filename: filename,
          mimeType: 'text/csv',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded "$filename" successfully!'),
              backgroundColor: Colors.black,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handlePrintDirectly() async {
    setState(() => _isExporting = true);
    try {
      final po = widget.po;
      await Printing.layoutPdf(
        name: 'PO-${po.poNumber}',
        onLayout: (format) => PurchaseOrderExportService.generatePdf(po),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize print: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final po = widget.po;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Row(
              children: const [
                Text(
                  'Export Purchase Order',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: UserProfileAvatar(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 28 : 16,
              20,
              isWide ? 28 : 16,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PO Hero Summary Card - Uber Style
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F4F5),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 18,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 10),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'PO # ',
                                      style: TextStyle(
                                        color: Color(0xFF71717A),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    TextSpan(
                                      text: po.poNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              po.status.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Consignee
                      Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            size: 16,
                            color: Color(0xFF71717A),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              po.customerName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Dates row
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Color(0xFF71717A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'PO Date: ${_dateFormat.format(po.poDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF52525B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.local_shipping_outlined,
                            size: 14,
                            color: Color(0xFF71717A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Exp. Ship: ${po.expectedShippingDate != null ? _dateFormat.format(po.expectedShippingDate!) : 'Not Specified'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF52525B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),

                      // Specs summary pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${po.items.length} Line Items',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF71717A),
                            ),
                          ),
                          Text(
                            '${po.totalPackets} Total Packets',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF71717A),
                            ),
                          ),
                          Text(
                            '${po.totalCartons} Total Cartons',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Select Export Format Section
                const Text(
                  'SELECT EXPORT FORMAT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Format Option 1: PDF Document
                _buildFormatCard(
                  format: ExportFormat.pdf,
                  icon: Icons.picture_as_pdf_outlined,
                  iconBg: const Color(0xFFFEF2F2),
                  iconColor: const Color(0xFFDC2626),
                  title: 'PDF Document (.pdf)',
                  subtitle:
                      'Official PO document with items table, consignee data, and packaging specs.',
                  badge: 'RECOMMENDED',
                ),

                const SizedBox(height: 12),

                // Format Option 2: CSV Spreadsheet
                _buildFormatCard(
                  format: ExportFormat.csv,
                  icon: Icons.table_chart_outlined,
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF047857),
                  title: 'CSV Spreadsheet (.csv)',
                  subtitle:
                      'Comma-separated spreadsheet format for Excel, Google Sheets, or ERP integration.',
                  badge: 'DATA',
                ),

                const SizedBox(height: 32),

                // 3. Actions Row
                if (_selectedFormat == ExportFormat.pdf) ...[
                  // PDF: Download or Print Directly
                  Row(
                    children: [
                      // Direct Print Button
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            onPressed: _isExporting ? null : _handlePrintDirectly,
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: const Text(
                              'Print Directly',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Download PDF Button
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            onPressed: _isExporting ? null : _handleDownload,
                            icon: _isExporting
                                ? const SizedBox.shrink()
                                : const Icon(Icons.download_outlined,
                                    size: 18, color: Colors.white),
                            label: _isExporting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Download PDF',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // CSV: Download CSV
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: _isExporting ? null : _handleDownload,
                      icon: _isExporting
                          ? const SizedBox.shrink()
                          : const Icon(Icons.download_outlined,
                              size: 18, color: Colors.white),
                      label: _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Download CSV File',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Note info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The generated document accurately formats item packaging, carton calculations, and customer consignee records for distribution.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatCard({
    required ExportFormat format,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
  }) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () => setState(() => _selectedFormat = format),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFE5E5E5),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF71717A),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? Colors.black : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}
