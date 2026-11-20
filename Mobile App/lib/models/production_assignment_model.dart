class ProductionAssignmentModel {
  final String assignmentId;
  final String tenantId;
  final String poId;
  final String poNumber;
  final String poItemId;
  final String itemId;
  final String itemName;
  final String supervisorUserId;
  final String supervisorName;
  final int assignedCartons;
  final int completedCartons;
  final String status;
  final String assignedByUserId;
  final String notes;
  final DateTime? completedAt;
  final DateTime? createdAt;

  ProductionAssignmentModel({
    required this.assignmentId,
    required this.tenantId,
    required this.poId,
    required this.poNumber,
    required this.poItemId,
    required this.itemId,
    required this.itemName,
    required this.supervisorUserId,
    required this.supervisorName,
    required this.assignedCartons,
    required this.completedCartons,
    required this.status,
    required this.assignedByUserId,
    this.notes = '',
    this.completedAt,
    this.createdAt,
  });

  factory ProductionAssignmentModel.fromJson(Map<String, dynamic> json) {
    return ProductionAssignmentModel(
      assignmentId: json['assignment_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      poId: json['po_id'] ?? '',
      poNumber: json['po_number'] ?? '',
      poItemId: json['po_item_id'] ?? '',
      itemId: json['item_id'] ?? '',
      itemName: json['item_name'] ?? '',
      supervisorUserId: json['supervisor_user_id'] ?? '',
      supervisorName: json['supervisor_name'] ?? '',
      assignedCartons: (json['assigned_cartons'] as num?)?.toInt() ?? 0,
      completedCartons: (json['completed_cartons'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'PENDING',
      assignedByUserId: json['assigned_by_user_id'] ?? '',
      notes: json['notes'] ?? '',
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'assignment_id': assignmentId,
        'tenant_id': tenantId,
        'po_id': poId,
        'po_number': poNumber,
        'po_item_id': poItemId,
        'item_id': itemId,
        'item_name': itemName,
        'supervisor_user_id': supervisorUserId,
        'supervisor_name': supervisorName,
        'assigned_cartons': assignedCartons,
        'completed_cartons': completedCartons,
        'status': status,
        'assigned_by_user_id': assignedByUserId,
        'notes': notes,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };
}

