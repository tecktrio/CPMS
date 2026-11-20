class QcReportModel {
  final String qcReportId;
  final String tenantId;
  final String poId;
  final String poNumber;
  final String poItemId;
  final String itemId;
  final String itemName;
  final String inspectorUserId;
  final String inspectorName;
  final String status; // PASSED | FAILED | CONDITIONAL_PASS
  final int inspectedCartons;
  final int rejectedCartons;
  final String remarks;
  final List<String> attachmentUrls;
  final DateTime inspectedAt;

  QcReportModel({
    required this.qcReportId,
    required this.tenantId,
    required this.poId,
    required this.poNumber,
    required this.poItemId,
    required this.itemId,
    required this.itemName,
    required this.inspectorUserId,
    required this.inspectorName,
    required this.status,
    required this.inspectedCartons,
    this.rejectedCartons = 0,
    this.remarks = '',
    this.attachmentUrls = const [],
    required this.inspectedAt,
  });

  factory QcReportModel.fromJson(Map<String, dynamic> json) {
    return QcReportModel(
      qcReportId: json['qc_report_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      poId: json['po_id'] ?? '',
      poNumber: json['po_number'] ?? '',
      poItemId: json['po_item_id'] ?? '',
      itemId: json['item_id'] ?? '',
      itemName: json['item_name'] ?? '',
      inspectorUserId: json['inspector_user_id'] ?? '',
      inspectorName: json['inspector_name'] ?? '',
      status: json['status'] ?? 'PASSED',
      inspectedCartons: (json['inspected_cartons'] as num?)?.toInt() ?? 0,
      rejectedCartons: (json['rejected_cartons'] as num?)?.toInt() ?? 0,
      remarks: json['remarks'] ?? '',
      attachmentUrls: (json['attachment_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      inspectedAt: json['inspected_at'] != null
          ? DateTime.tryParse(json['inspected_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'qc_report_id': qcReportId,
        'tenant_id': tenantId,
        'po_id': poId,
        'po_number': poNumber,
        'po_item_id': poItemId,
        'item_id': itemId,
        'item_name': itemName,
        'inspector_user_id': inspectorUserId,
        'inspector_name': inspectorName,
        'status': status,
        'inspected_cartons': inspectedCartons,
        'rejected_cartons': rejectedCartons,
        'remarks': remarks,
        'attachment_urls': attachmentUrls,
        'inspected_at': inspectedAt.toIso8601String(),
      };
}

