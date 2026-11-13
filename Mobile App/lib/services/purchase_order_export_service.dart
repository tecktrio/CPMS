import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/purchase_order_provider.dart';

class PurchaseOrderExportService {
  static String formatShortUnit(String unit) {
    switch (unit.toUpperCase().trim()) {
      case 'KILOGRAM':
        return 'KG';
      case 'GRAM':
        return 'GM';
      case 'LITRE':
        return 'LTR';
      case 'MILLILITRE':
        return 'ML';
      case 'PIECE':
        return 'PC';
      case 'UNIT':
        return 'UNT';
      case 'CARTOON_BOX':
        return 'CTN';
      default:
        if (unit.trim().isEmpty) return '';
        if (unit.length <= 4) return unit.toUpperCase();
        return unit.substring(0, 3).toUpperCase();
    }
  }

  static String formatQtyValue(double qty) {
    if (qty.truncateToDouble() == qty) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }

  static String formatQtyPerPacketShort(double qty, String unit) {
    final u = formatShortUnit(unit);
    final val = formatQtyValue(qty);
    return u.isNotEmpty ? '$val $u' : val;
  }

  /// Generate clean, official Purchase Order PDF Document
  static Future<Uint8List> generatePdf(PurchaseOrderModel po) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    final poDateStr = dateFormat.format(po.poDate);
    final expDateStr = po.expectedShippingDate != null
        ? dateFormat.format(po.expectedShippingDate!)
        : 'N/A';

    final totalCartons = po.totalCartons;
    final totalPackets = po.totalPackets;

    // Load standard font
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PURCHASE ORDER',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 22,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'CYAN PRODUCT MANAGEMENT SYSTEM (CPMS)',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: po.status.toUpperCase() == 'CONFIRMED'
                          ? PdfColors.green50
                          : (po.status.toUpperCase() == 'DRAFT'
                              ? PdfColors.grey100
                              : PdfColors.blue50),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(2)),
                      border: pw.Border.all(
                        color: po.status.toUpperCase() == 'CONFIRMED'
                            ? PdfColors.green700
                            : PdfColors.grey400,
                        width: 0.5,
                      ),
                    ),
                    child: pw.Text(
                      po.status.replaceAll('_', ' ').toUpperCase(),
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 10,
                        color: po.status.toUpperCase() == 'CONFIRMED'
                            ? PdfColors.green900
                            : PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Header Info Row: PO Details & Consignee Details
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // PO Meta Info
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(2)),
                      border: pw.Border.all(color: PdfColors.grey200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfKeyValue('PO NUMBER:', po.poNumber, fontBold),
                        pw.SizedBox(height: 4),
                        _buildPdfKeyValue('PO DATE:', poDateStr, fontBold),
                        pw.SizedBox(height: 4),
                        _buildPdfKeyValue('EXP. SHIPPING:', expDateStr, fontBold),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                // Customer / Consignee Info
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(2)),
                      border: pw.Border.all(color: PdfColors.grey200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfKeyValue('CUSTOMER / CONSIGNEE:', po.customerName, fontBold),
                        if (po.customerAddress.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          _buildPdfKeyValue('ADDRESS:', po.customerAddress, fontBold),
                        ],
                        if (po.customerContact.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          _buildPdfKeyValue('CONTACT:', po.customerContact, fontBold),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 18),

            // Items Table matching MALTA PO Document layout
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30), // SL.
                1: const pw.FlexColumnWidth(4),   // ITEMS
                2: const pw.FlexColumnWidth(2),   // QTY/PKT
                3: const pw.FlexColumnWidth(2),   // PKT/CTN
                4: const pw.FlexColumnWidth(2),   // CARTONS
              },
              children: [
                // Blue Table Header matching document
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF93C5FD)),
                  children: [
                    _buildTableCell('SL.', isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('ITEMS', isHeader: true, align: pw.TextAlign.left),
                    _buildTableCell('QTY/PKT', isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('PKT/CTN', isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('CARTONS', isHeader: true, align: pw.TextAlign.center),
                  ],
                ),
                // Table Rows
                ...po.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final isEven = idx % 2 == 0;
                  final qtyShort = formatQtyPerPacketShort(item.quantityPerPacket, item.unit);

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : const PdfColor.fromInt(0xFFFAFAFA),
                    ),
                    children: [
                      _buildTableCell('${idx + 1}', align: pw.TextAlign.center),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.itemName,
                              style: pw.TextStyle(font: fontBold, fontSize: 10),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              '${item.sku} • ${item.totalPackets} pkts',
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                            ),
                          ],
                        ),
                      ),
                      _buildTableCell(qtyShort, align: pw.TextAlign.center, isBold: true),
                      _buildTableCell('${item.packetPerCarton}', align: pw.TextAlign.center),
                      _buildTableCell('${item.cartons}', align: pw.TextAlign.center, isBold: true),
                    ],
                  );
                }),
                // Footer Total Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
                  children: [
                    _buildTableCell('', align: pw.TextAlign.center),
                    _buildTableCell('TOTAL CARTONS', isBold: true),
                    _buildTableCell('', align: pw.TextAlign.center),
                    _buildTableCell('$totalPackets pkts', align: pw.TextAlign.center, isBold: true),
                    _buildTableCell('$totalCartons', align: pw.TextAlign.center, isBold: true),
                  ],
                ),
              ],
            ),

            if (po.notes.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                  border: pw.Border.all(color: PdfColors.grey200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PACKAGING & SHIPPING INSTRUCTIONS:',
                      style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(po.notes, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],

            pw.SizedBox(height: 32),

            // Signatures block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pw.Text('Prepared By / Warehouse In-Charge', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pw.Text('Authorized Stamp & Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildPdfKeyValue(String label, String value, pw.Font fontBold) {
    return pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
        children: [
          pw.TextSpan(
            text: '$label ',
            style: pw.TextStyle(font: fontBold, color: PdfColors.grey700),
          ),
          pw.TextSpan(text: value),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 9,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }

  /// Generate CSV Spreadsheet data string
  static String generateCsv(PurchaseOrderModel po) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final poDateStr = dateFormat.format(po.poDate);
    final expDateStr = po.expectedShippingDate != null
        ? dateFormat.format(po.expectedShippingDate!)
        : '';

    final buffer = StringBuffer();
    // Headers with short, standard names
    buffer.writeln(
      'SL,Item Name,SKU,Qty Per Packet,Unit,Packets Per Carton,Cartons,Total Packets,Total Quantity,PO Number,PO Date,Exp Shipping Date,Customer Name,Customer Address,Customer Contact,Status,Notes',
    );

    for (int i = 0; i < po.items.length; i++) {
      final it = po.items[i];
      final row = [
        (i + 1).toString(),
        '"${it.itemName.replaceAll('"', '""')}"',
        '"${it.sku.replaceAll('"', '""')}"',
        formatQtyValue(it.quantityPerPacket),
        '"${formatShortUnit(it.unit)}"',
        it.packetPerCarton.toString(),
        it.cartons.toString(),
        it.totalPackets.toString(),
        formatQtyValue(it.totalQuantity),
        '"${po.poNumber}"',
        '"$poDateStr"',
        '"$expDateStr"',
        '"${po.customerName.replaceAll('"', '""')}"',
        '"${po.customerAddress.replaceAll('"', '""')}"',
        '"${po.customerContact.replaceAll('"', '""')}"',
        '"${po.status}"',
        '"${po.notes.replaceAll('"', '""')}"',
      ];
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  /// Get CSV as bytes
  static Uint8List generateCsvBytes(PurchaseOrderModel po) {
    return Uint8List.fromList(utf8.encode(generateCsv(po)));
  }
}
