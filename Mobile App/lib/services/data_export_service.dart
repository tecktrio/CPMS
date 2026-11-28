import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/production_assignment_model.dart';
import '../models/qc_report_model.dart';
import '../providers/department_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/tenant_provider.dart';

class DataExportService {
  static String _formatNum(double val) {
    if (val.truncateToDouble() == val) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }

  static String _escapeCsv(String val) {
    return '"${val.replaceAll('"', '""')}"';
  }

  static Future<Uint8List> _buildTablePdf({
    required String title,
    required String subtitle,
    required List<String> metadataLines,
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? columnWidths,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
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
                        title.toUpperCase(),
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        subtitle,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Generated: $dateStr',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              if (metadataLines.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: metadataLines
                      .map((line) => pw.Text(
                            line,
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey800,
                            ),
                          ))
                      .toList(),
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.8, color: PdfColors.grey300),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CYAN PRODUCT MANAGEMENT SYSTEM (CPMS)',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          if (rows.isEmpty) {
            return [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 24),
                child: pw.Center(
                  child: pw.Text(
                    'No records available to export.',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ),
            ];
          }

          return [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: columnWidths,
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF0F172A),
                  ),
                  children: headers
                      .map(
                        (h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 7),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 8.5,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                ...rows.asMap().entries.map((entry) {
                  final isEven = entry.key % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven
                          ? PdfColors.white
                          : const PdfColor.fromInt(0xFFF8FAFC),
                    ),
                    children: entry.value
                        .map(
                          (cell) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            child: pw.Text(
                              cell,
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                color: PdfColors.black,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static Uint8List _buildCsvBytes(
      List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCsv).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsv).join(','));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  // ==================== 1. ITEMS LIST EXPORT ====================

  static Future<Uint8List> generateItemsPdf(
    List<ItemModel> items, {
    String? filterLabel,
  }) {
    final headers = [
      'SL.',
      'Item Name',
      'Category / Type',
      'Unit',
      'Available Stock',
      'Min / Reorder',
      'Status',
    ];
    final rows = items.asMap().entries.map((e) {
      final idx = e.key + 1;
      final it = e.value;
      final status = it.isBelowReorderThreshold ? 'LOW STOCK' : 'IN STOCK';
      return [
        '$idx',
        it.itemName,
        it.itemType,
        '${_formatNum(it.quantity)} ${it.measurementUnit}'.trim(),
        _formatNum(it.totalAvailableStock),
        _formatNum(it.reorderThresholdQuantity),
        status,
      ];
    }).toList();

    return _buildTablePdf(
      title: 'Items & Materials Directory',
      subtitle: 'CYAN PRODUCT MANAGEMENT SYSTEM (CPMS)',
      metadataLines: [
        'Total Items: ${items.length}',
        if (filterLabel != null && filterLabel.isNotEmpty)
          'Filter: $filterLabel',
      ],
      headers: headers,
      rows: rows,
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(3.6),
        2: const pw.FlexColumnWidth(2.0),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.3),
        5: const pw.FlexColumnWidth(1.3),
        6: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  static Uint8List generateItemsCsvBytes(List<ItemModel> items) {
    final headers = [
      'SL',
      'Item Name',
      'Category',
      'Specification / Qty Per Unit',
      'Measurement Unit',
      'Available Stock',
      'Minimum Stock Threshold',
      'Status',
    ];
    final rows = items.asMap().entries.map((e) {
      final it = e.value;
      return [
        '${e.key + 1}',
        it.itemName,
        it.itemType,
        _formatNum(it.quantity),
        it.measurementUnit,
        _formatNum(it.totalAvailableStock),
        _formatNum(it.reorderThresholdQuantity),
        it.isBelowReorderThreshold ? 'LOW STOCK' : 'IN STOCK',
      ];
    }).toList();

    return _buildCsvBytes(headers, rows);
  }

  // ==================== 2. STORE ROOM DETAILS EXPORT ====================

  static Future<Uint8List> generateStoreRoomPdf({
    required StoreRoomModel room,
    required List<StoreRoomItemModel> roomItems,
    required List<ItemModel> allItems,
  }) {
    final headers = [
      'SL.',
      'Item Name',
      'Division / Section',
      'In-Stock Qty',
      'Min Alert Count',
      'Pkts / Carton',
    ];

    final rows = roomItems.asMap().entries.map((e) {
      final sri = e.value;
      final item = allItems.firstWhere(
        (i) => i.itemId == sri.itemId,
        orElse: () => ItemModel(
          itemId: sri.itemId,
          tenantId: room.tenantId,
          sku: '-',
          itemName: sri.itemId,
          itemType: '',
          measurementUnit: '',
          reorderThresholdQuantity: 0,
          totalAvailableStock: sri.quantity,
          isBelowReorderThreshold: false,
          reorderShortfallQuantity: 0,
          isActive: true,
        ),
      );
      final divName = room.displayDivisionName(sri);
      final pktPerCtn = item.reorderThresholdQuantity > 0
          ? item.reorderThresholdQuantity.toInt().toString()
          : '14';
      return [
        '${e.key + 1}',
        item.itemName,
        divName,
        _formatNum(sri.quantity),
        _formatNum(sri.minCount),
        pktPerCtn,
      ];
    }).toList();

    final totalUnits =
        roomItems.fold<double>(0, (sum, sri) => sum + sri.quantity);

    return _buildTablePdf(
      title: 'Store Room Inventory: ${room.roomName}',
      subtitle: 'CYAN PRODUCT MANAGEMENT SYSTEM (CPMS)',
      metadataLines: [
        'Room Code: ${room.roomCode}',
        if (room.temperature != null) 'Temperature: ${room.temperature}°C',
        'Divisions: ${room.divisions.length}',
        'Items Listed: ${roomItems.length}',
        'Total Stock Units: ${_formatNum(totalUnits)}',
      ],
      headers: headers,
      rows: rows,
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(3.6),
        2: const pw.FlexColumnWidth(2.4),
        3: const pw.FlexColumnWidth(1.3),
        4: const pw.FlexColumnWidth(1.3),
        5: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  static Uint8List generateStoreRoomCsvBytes({
    required StoreRoomModel room,
    required List<StoreRoomItemModel> roomItems,
    required List<ItemModel> allItems,
  }) {
    final headers = [
      'SL',
      'Room Name',
      'Room Code',
      'Item Name',
      'Division / Section',
      'In-Stock Qty',
      'Min Alert Count',
      'Packets Per Carton',
    ];

    final rows = roomItems.asMap().entries.map((e) {
      final sri = e.value;
      final item = allItems.firstWhere(
        (i) => i.itemId == sri.itemId,
        orElse: () => ItemModel(
          itemId: sri.itemId,
          tenantId: room.tenantId,
          sku: '',
          itemName: sri.itemId,
          itemType: '',
          measurementUnit: '',
          reorderThresholdQuantity: 0,
          totalAvailableStock: sri.quantity,
          isBelowReorderThreshold: false,
          reorderShortfallQuantity: 0,
          isActive: true,
        ),
      );
      final divName = room.displayDivisionName(sri);
      final pktPerCtn = item.reorderThresholdQuantity > 0
          ? item.reorderThresholdQuantity.toInt().toString()
          : '14';
      return [
        '${e.key + 1}',
        room.roomName,
        room.roomCode,
        item.itemName,
        divName,
        _formatNum(sri.quantity),
        _formatNum(sri.minCount),
        pktPerCtn,
      ];
    }).toList();

    return _buildCsvBytes(headers, rows);
  }

  // ==================== 3. USERS & DEPARTMENTS EXPORT ====================

  static String _resolveUserDepartments(
    TenantUserModel user,
    List<DepartmentModel> departments,
  ) {
    if (user.departmentIds.isEmpty) return 'Unassigned';
    final names = user.departmentIds.map((id) {
      final match = departments.where((d) => d.departmentId == id);
      return match.isNotEmpty ? match.first.departmentName : id;
    }).toList();
    return names.join(', ');
  }

  static Future<Uint8List> generateUsersPdf({
    required List<TenantUserModel> users,
    required List<DepartmentModel> departments,
    String? tenantName,
  }) {
    final headers = [
      'SL.',
      'Full Name',
      'Username',
      'Email Address',
      'Department(s)',
      'Status',
    ];

    final rows = users.asMap().entries.map((e) {
      final u = e.value;
      return [
        '${e.key + 1}',
        u.fullName.isNotEmpty ? u.fullName : 'Staff Member',
        u.userName.isNotEmpty ? '@${u.userName}' : '-',
        u.emailAddress,
        _resolveUserDepartments(u, departments),
        u.accountStatus.toUpperCase(),
      ];
    }).toList();

    return _buildTablePdf(
      title: 'Users & Departments Directory',
      subtitle: 'CYAN PRODUCT MANAGEMENT SYSTEM (CPMS)',
      metadataLines: [
        if (tenantName != null && tenantName.isNotEmpty)
          'Organization: $tenantName',
        'Total Users: ${users.length}',
      ],
      headers: headers,
      rows: rows,
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(2.6),
        4: const pw.FlexColumnWidth(2.4),
        5: const pw.FlexColumnWidth(1.1),
      },
    );
  }

  static Uint8List generateUsersCsvBytes({
    required List<TenantUserModel> users,
    required List<DepartmentModel> departments,
  }) {
    final headers = [
      'SL',
      'Full Name',
      'Username',
      'Email Address',
      'Departments',
      'Status',
    ];

    final rows = users.asMap().entries.map((e) {
      final u = e.value;
      return [
        '${e.key + 1}',
        u.fullName,
        u.userName,
        u.emailAddress,
        _resolveUserDepartments(u, departments),
        u.accountStatus,
      ];
    }).toList();

    return _buildCsvBytes(headers, rows);
  }

  // ==================== 4. FULL PO PRODUCTION, QA, SUPERVISORS, EXPORT & USERS REPORT ====================

  static TenantUserModel? _findUser(
      String userId, List<TenantUserModel> users) {
    if (userId.isEmpty) return null;
    for (final u in users) {
      if (u.userId == userId) return u;
    }
    return null;
  }

  static String _formatUserLabel(
      String userId, String fallbackName, List<TenantUserModel> users) {
    final u = _findUser(userId, users);
    if (u != null) {
      final name = u.fullName.isNotEmpty ? u.fullName : u.userName;
      final handle = u.userName.isNotEmpty ? ' (@${u.userName})' : '';
      return '$name$handle';
    }
    return fallbackName.isNotEmpty ? fallbackName : (userId.isNotEmpty ? userId : '-');
  }

  static pw.Widget _buildSectionTitle(String title, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 11,
          color: const PdfColor.fromInt(0xFF0F172A),
        ),
      ),
    );
  }

  static pw.Widget _buildSectionTable({
    required List<String> headers,
    required List<List<String>> rows,
    required pw.Font fontBold,
    Map<int, pw.TableColumnWidth>? columnWidths,
    String emptyMessage = 'No records recorded.',
  }) {
    if (rows.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Text(
          emptyMessage,
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: columnWidths,
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 5, vertical: 6),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final isEven = entry.key % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color:
                  isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF8FAFC),
            ),
            children: entry.value
                .map(
                  (cell) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 5),
                    child: pw.Text(
                      cell,
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.black),
                    ),
                  ),
                )
                .toList(),
          );
        }),
      ],
    );
  }

  static List<TenantUserModel> _collectInvolvedUsers({
    required List<ProductionAssignmentModel> assignments,
    required List<QcReportModel> qcReports,
    required List<TenantUserModel> tenantUsers,
    required List<DepartmentModel> departments,
  }) {
    final involvedIds = <String>{};
    for (final a in assignments) {
      if (a.supervisorUserId.isNotEmpty) involvedIds.add(a.supervisorUserId);
      if (a.assignedByUserId.isNotEmpty) involvedIds.add(a.assignedByUserId);
    }
    for (final q in qcReports) {
      if (q.inspectorUserId.isNotEmpty) involvedIds.add(q.inspectorUserId);
    }

    final prodDeptIds = departments
        .where((d) {
          final n = d.departmentName.toLowerCase();
          return n.contains('production') ||
              n.contains('supervisor') ||
              n.contains('quality') ||
              n.contains('qc') ||
              n.contains('pack') ||
              n.contains('export');
        })
        .map((d) => d.departmentId)
        .toSet();

    final result = <TenantUserModel>[];
    final seen = <String>{};
    for (final u in tenantUsers) {
      final isExplicitlyInvolved = involvedIds.contains(u.userId);
      final isInProdDept = u.departmentIds.any((id) => prodDeptIds.contains(id));
      if ((isExplicitlyInvolved || isInProdDept) && !seen.contains(u.userId)) {
        seen.add(u.userId);
        result.add(u);
      }
    }
    return result;
  }

  static Future<Uint8List> generatePoProductionPdf({
    required PurchaseOrderModel po,
    required List<ProductionAssignmentModel> assignments,
    required List<QcReportModel> qcReports,
    required List<TenantUserModel> tenantUsers,
    required List<DepartmentModel> departments,
    String? tenantName,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final dateFmt = DateFormat('dd/MM/yyyy');
    final dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');

    final totalProduced =
        po.items.fold<int>(0, (s, i) => s + i.completedCartons);
    final totalPacked = po.items.fold<int>(0, (s, i) => s + i.packedCartons);
    final totalShipped = po.items.fold<int>(0, (s, i) => s + i.shippedCartons);

    final lineRows = po.items.asMap().entries.map((e) {
      final it = e.value;
      return [
        '${e.key + 1}',
        it.itemName,
        it.specification.isNotEmpty ? it.specification : it.unit.toUpperCase(),
        '${it.packetPerCarton}',
        '${it.cartons}',
        '${it.totalPackets}',
        '${it.completedCartons}/${it.cartons}',
        it.qcPassed ? 'PASSED' : 'PENDING',
        '${it.packedCartons}/${it.cartons}',
        '${it.shippedCartons}/${it.cartons}',
      ];
    }).toList();

    final assignmentRows = assignments.asMap().entries.map((e) {
      final a = e.value;
      return [
        '${e.key + 1}',
        a.itemName,
        _formatUserLabel(a.supervisorUserId, a.supervisorName, tenantUsers),
        _formatUserLabel(a.assignedByUserId, 'Manager', tenantUsers),
        '${a.assignedCartons}',
        '${a.completedCartons}',
        a.status,
        a.createdAt != null ? dateTimeFmt.format(a.createdAt!) : '-',
        a.completedAt != null ? dateTimeFmt.format(a.completedAt!) : '-',
        a.notes.isNotEmpty ? a.notes : '-',
      ];
    }).toList();

    final qcRows = qcReports.asMap().entries.map((e) {
      final q = e.value;
      return [
        '${e.key + 1}',
        q.itemName,
        _formatUserLabel(q.inspectorUserId, q.inspectorName, tenantUsers),
        q.status,
        '${q.inspectedCartons}',
        '${q.rejectedCartons}',
        dateTimeFmt.format(q.inspectedAt),
        q.remarks.isNotEmpty ? q.remarks : '-',
      ];
    }).toList();

    final involvedUsers = _collectInvolvedUsers(
      assignments: assignments,
      qcReports: qcReports,
      tenantUsers: tenantUsers,
      departments: departments,
    );

    final userRows = involvedUsers.asMap().entries.map((e) {
      final u = e.value;
      final assignedCount =
          assignments.where((a) => a.supervisorUserId == u.userId).length;
      final managedCount =
          assignments.where((a) => a.assignedByUserId == u.userId).length;
      final qcCount =
          qcReports.where((q) => q.inspectorUserId == u.userId).length;
      final rolesInPo = <String>[
        if (managedCount > 0) 'Assigned $managedCount task(s)',
        if (assignedCount > 0) 'Supervisor ($assignedCount task(s))',
        if (qcCount > 0) 'QA Inspected ($qcCount report(s))',
      ];
      return [
        '${e.key + 1}',
        u.fullName.isNotEmpty ? u.fullName : u.userName,
        u.userName.isNotEmpty ? '@${u.userName}' : '-',
        u.emailAddress,
        _resolveUserDepartments(u, departments),
        rolesInPo.isNotEmpty ? rolesInPo.join(', ') : 'Department Staff',
        u.accountStatus.toUpperCase(),
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PRODUCTION, QA, EXPORT & STAFF REPORT — PO #${po.poNumber}',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 16, color: PdfColors.black),
                    ),
                    pw.Text(
                      '${tenantName ?? 'CYAN PRODUCT MANAGEMENT SYSTEM (CPMS)'} • Status: ${po.status}',
                      style: const pw.TextStyle(
                          fontSize: 8.5, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Text(
                  'Generated: ${dateTimeFmt.format(DateTime.now())}',
                  style: const pw.TextStyle(
                      fontSize: 8.5, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                pw.Text('Customer: ${po.customerName}',
                    style: const pw.TextStyle(fontSize: 8.5)),
                if (po.customerContact.isNotEmpty)
                  pw.Text('Contact: ${po.customerContact}',
                      style: const pw.TextStyle(fontSize: 8.5)),
                pw.Text('PO Date: ${dateFmt.format(po.poDate)}',
                    style: const pw.TextStyle(fontSize: 8.5)),
                pw.Text(
                  'Shipping: ${po.expectedShippingDate != null ? dateFmt.format(po.expectedShippingDate!) : 'N/A'}',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
                pw.Text(
                  'Totals: Produced $totalProduced/${po.totalCartons} • Packed $totalPacked/${po.totalCartons} • Shipped $totalShipped/${po.totalCartons} ctns',
                  style: pw.TextStyle(font: fontBold, fontSize: 8.5),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 0.8, color: PdfColors.grey300),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('CYAN PRODUCT MANAGEMENT SYSTEM (CPMS)',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (ctx) => [
          _buildSectionTitle(
              '1. PRODUCTION LINE ITEMS, PACKING & EXPORT SUMMARY', fontBold),
          _buildSectionTable(
            headers: [
              'SL.',
              'Item Name',
              'Spec',
              'Pkt/Ctn',
              'Ctns',
              'Total Pkts',
              'Produced',
              'QC',
              'Packed',
              'Shipped',
            ],
            rows: lineRows,
            fontBold: fontBold,
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(2.8),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(0.8),
              4: const pw.FlexColumnWidth(0.8),
              5: const pw.FlexColumnWidth(1.0),
              6: const pw.FlexColumnWidth(1.1),
              7: const pw.FlexColumnWidth(1.0),
              8: const pw.FlexColumnWidth(1.0),
              9: const pw.FlexColumnWidth(1.0),
            },
          ),
          _buildSectionTitle(
              '2. SUPERVISORS & PRODUCTION MANAGER ASSIGNMENTS', fontBold),
          _buildSectionTable(
            headers: [
              'SL.',
              'Item Name',
              'Supervisor',
              'Assigned By (PM)',
              'Assigned',
              'Completed',
              'Status',
              'Assigned At',
              'Completed At',
              'Notes',
            ],
            rows: assignmentRows,
            fontBold: fontBold,
            emptyMessage: 'No supervisor assignments recorded for this PO.',
          ),
          _buildSectionTitle(
              '3. QUALITY ASSURANCE (QC) INSPECTION REPORTS', fontBold),
          _buildSectionTable(
            headers: [
              'SL.',
              'Item Name',
              'QA Inspector',
              'Status',
              'Inspected Ctns',
              'Rejected Ctns',
              'Inspected At',
              'Remarks',
            ],
            rows: qcRows,
            fontBold: fontBold,
            emptyMessage: 'No QC inspection reports recorded for this PO.',
          ),
          _buildSectionTitle(
              '4. INVOLVED USERS (PRODUCTION MANAGERS, SUPERVISORS, QA, PACKING & EXPORT)',
              fontBold),
          _buildSectionTable(
            headers: [
              'SL.',
              'Full Name',
              'Username',
              'Email Address',
              'Department(s)',
              'Activity / Role in PO',
              'Status',
            ],
            rows: userRows,
            fontBold: fontBold,
            emptyMessage: 'No staff members found.',
          ),
        ],
      ),
    );

    return doc.save();
  }

  static Uint8List generatePoProductionCsvBytes({
    required PurchaseOrderModel po,
    required List<ProductionAssignmentModel> assignments,
    required List<QcReportModel> qcReports,
    required List<TenantUserModel> tenantUsers,
    required List<DepartmentModel> departments,
  }) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');
    final buffer = StringBuffer();

    // Section 1: Line Items + Production/Packing/Export
    buffer.writeln('SECTION: PO LINE ITEMS & EXPORT PROGRESS');
    buffer.writeln(
      [
        'SL',
        'PO Number',
        'Customer',
        'PO Date',
        'Shipping Date',
        'PO Status',
        'Item Name',
        'Spec',
        'Pkts Per Carton Box',
        'Cartons',
        'Total Packets',
        'Produced Cartons',
        'QC Status',
        'Packed Cartons',
        'Shipped / Exported Cartons',
      ].map(_escapeCsv).join(','),
    );
    for (int i = 0; i < po.items.length; i++) {
      final it = po.items[i];
      buffer.writeln(
        [
          '${i + 1}',
          po.poNumber,
          po.customerName,
          dateFmt.format(po.poDate),
          po.expectedShippingDate != null
              ? dateFmt.format(po.expectedShippingDate!)
              : '',
          po.status,
          it.itemName,
          it.specification,
          '${it.packetPerCarton}',
          '${it.cartons}',
          '${it.totalPackets}',
          '${it.completedCartons}',
          it.qcPassed ? 'PASSED' : 'PENDING',
          '${it.packedCartons}',
          '${it.shippedCartons}',
        ].map(_escapeCsv).join(','),
      );
    }

    buffer.writeln();
    // Section 2: Supervisors & Production Managers
    buffer.writeln('SECTION: SUPERVISOR & PRODUCTION MANAGER ASSIGNMENTS');
    buffer.writeln(
      [
        'SL',
        'Item Name',
        'Supervisor Name',
        'Supervisor Email',
        'Assigned By (Production Manager)',
        'PM Email',
        'Assigned Cartons',
        'Completed Cartons',
        'Status',
        'Assigned At',
        'Completed At',
        'Notes',
      ].map(_escapeCsv).join(','),
    );
    for (int i = 0; i < assignments.length; i++) {
      final a = assignments[i];
      final sup = _findUser(a.supervisorUserId, tenantUsers);
      final pm = _findUser(a.assignedByUserId, tenantUsers);
      buffer.writeln(
        [
          '${i + 1}',
          a.itemName,
          sup?.fullName.isNotEmpty == true ? sup!.fullName : a.supervisorName,
          sup?.emailAddress ?? '',
          pm?.fullName.isNotEmpty == true ? pm!.fullName : a.assignedByUserId,
          pm?.emailAddress ?? '',
          '${a.assignedCartons}',
          '${a.completedCartons}',
          a.status,
          a.createdAt != null ? dateTimeFmt.format(a.createdAt!) : '',
          a.completedAt != null ? dateTimeFmt.format(a.completedAt!) : '',
          a.notes,
        ].map(_escapeCsv).join(','),
      );
    }

    buffer.writeln();
    // Section 3: Quality Assurance
    buffer.writeln('SECTION: QUALITY ASSURANCE (QC) REPORTS');
    buffer.writeln(
      [
        'SL',
        'Item Name',
        'QA Inspector Name',
        'QA Inspector Email',
        'QC Status',
        'Inspected Cartons',
        'Rejected Cartons',
        'Inspected At',
        'Remarks',
      ].map(_escapeCsv).join(','),
    );
    for (int i = 0; i < qcReports.length; i++) {
      final q = qcReports[i];
      final insp = _findUser(q.inspectorUserId, tenantUsers);
      buffer.writeln(
        [
          '${i + 1}',
          q.itemName,
          insp?.fullName.isNotEmpty == true ? insp!.fullName : q.inspectorName,
          insp?.emailAddress ?? '',
          q.status,
          '${q.inspectedCartons}',
          '${q.rejectedCartons}',
          dateTimeFmt.format(q.inspectedAt),
          q.remarks,
        ].map(_escapeCsv).join(','),
      );
    }

    buffer.writeln();
    // Section 4: Involved Users Details
    buffer.writeln('SECTION: ALL INVOLVED USERS DETAILS');
    buffer.writeln(
      [
        'SL',
        'Full Name',
        'Username',
        'Email Address',
        'Departments',
        'Account Status',
      ].map(_escapeCsv).join(','),
    );
    final involvedUsers = _collectInvolvedUsers(
      assignments: assignments,
      qcReports: qcReports,
      tenantUsers: tenantUsers,
      departments: departments,
    );
    for (int i = 0; i < involvedUsers.length; i++) {
      final u = involvedUsers[i];
      buffer.writeln(
        [
          '${i + 1}',
          u.fullName,
          u.userName,
          u.emailAddress,
          _resolveUserDepartments(u, departments),
          u.accountStatus,
        ].map(_escapeCsv).join(','),
      );
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }
}

