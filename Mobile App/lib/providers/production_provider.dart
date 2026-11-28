import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/production_assignment_model.dart';
import '../models/qc_report_model.dart';

class ProductionProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<ProductionAssignmentModel> _myAssignments = [];
  List<ProductionAssignmentModel> _poAssignments = [];
  List<ProductionAssignmentModel> _allAssignments = [];
  List<QcReportModel> _poQcReports = [];
  bool _isLoading = false;
  String? _errorMessage;

  ProductionProvider({required this.apiClient});

  List<ProductionAssignmentModel> get myAssignments => _myAssignments;
  List<ProductionAssignmentModel> get poAssignments => _poAssignments;
  List<ProductionAssignmentModel> get allAssignments => _allAssignments;
  List<QcReportModel> get poQcReports => _poQcReports;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ProductionAssignmentModel> assignmentsForItem(
      String poId, String itemId) {
    final source = _allAssignments.isNotEmpty ? _allAssignments : _poAssignments;
    return source
        .where((a) =>
            a.poId == poId &&
            a.itemId == itemId &&
            a.status.toUpperCase() != 'CANCELLED')
        .toList();
  }

  Future<void> loadAllAssignments() async {
    try {
      final res = await apiClient.get(ApiConstants.productionAssignments);
      if (res is List) {
        _allAssignments = res
            .map((e) =>
                ProductionAssignmentModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading all assignments: $e');
    }
  }

  Future<void> loadMyAssignments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.get(ApiConstants.productionAssignmentsMy);
      if (res is List) {
        _myAssignments = res
            .map((e) =>
                ProductionAssignmentModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading my assignments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAssignmentsByPo(String poId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.get(ApiConstants.productionAssignmentsByPo(poId));
      if (res is List) {
        _poAssignments = res
            .map((e) =>
                ProductionAssignmentModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading PO assignments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAssignment({
    required String poId,
    required String itemId,
    required String supervisorUserId,
    required int assignedCartons,
    String? notes,
    DateTime? targetDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'po_id': poId,
        'item_id': itemId,
        'supervisor_user_id': supervisorUserId,
        'assigned_cartons': assignedCartons,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (targetDate != null) 'target_date': targetDate.toUtc().toIso8601String(),
      };

      final res = await apiClient.post(
        ApiConstants.productionAssignments,
        body: body,
      );

      final newModel =
          ProductionAssignmentModel.fromJson(Map<String, dynamic>.from(res));
      _poAssignments.insert(0, newModel);
      _allAssignments.insert(0, newModel);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error creating production assignment: $e');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProgress({
    required String assignmentId,
    required int completedCartons,
    bool markDone = false,
  }) async {
    try {
      final res = await apiClient.patch(
        ApiConstants.productionAssignmentProgress(assignmentId),
        body: {
          'completed_cartons': completedCartons,
          if (markDone) 'mark_done': true,
        },
      );

      final updated = ProductionAssignmentModel.fromJson(
        Map<String, dynamic>.from(res),
      );

      final myIdx = _myAssignments.indexWhere(
        (a) => a.assignmentId == assignmentId,
      );
      if (myIdx >= 0) _myAssignments[myIdx] = updated;

      final poIdx = _poAssignments.indexWhere(
        (a) => a.assignmentId == assignmentId,
      );
      if (poIdx >= 0) _poAssignments[poIdx] = updated;

      final allIdx = _allAssignments.indexWhere(
        (a) => a.assignmentId == assignmentId,
      );
      if (allIdx >= 0) _allAssignments[allIdx] = updated;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error updating progress: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAssignment({
    required String assignmentId,
    String? supervisorUserId,
    int? assignedCartons,
    String? notes,
    DateTime? targetDate,
  }) async {
    _errorMessage = null;
    try {
      final body = <String, dynamic>{
        'supervisor_user_id': ?supervisorUserId,
        'assigned_cartons': ?assignedCartons,
        'notes': ?notes,
        if (targetDate != null) 'target_date': targetDate.toUtc().toIso8601String(),
      };
      final res = await apiClient.patch(
        ApiConstants.productionAssignmentCancel(assignmentId),
        body: body,
      );
      final updated =
          ProductionAssignmentModel.fromJson(Map<String, dynamic>.from(res));

      final myIdx =
          _myAssignments.indexWhere((a) => a.assignmentId == assignmentId);
      if (myIdx >= 0) _myAssignments[myIdx] = updated;

      final poIdx =
          _poAssignments.indexWhere((a) => a.assignmentId == assignmentId);
      if (poIdx >= 0) _poAssignments[poIdx] = updated;

      final allIdx =
          _allAssignments.indexWhere((a) => a.assignmentId == assignmentId);
      if (allIdx >= 0) _allAssignments[allIdx] = updated;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error updating assignment: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelAssignment(String assignmentId) async {
    try {
      await apiClient.delete(ApiConstants.productionAssignmentCancel(assignmentId));
      _poAssignments.removeWhere((a) => a.assignmentId == assignmentId);
      _myAssignments.removeWhere((a) => a.assignmentId == assignmentId);
      _allAssignments.removeWhere((a) => a.assignmentId == assignmentId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error cancelling assignment: $e');
      return false;
    }
  }

  // QC Reports Operations
  Future<void> loadQcReportsByPo(String poId) async {
    try {
      final res = await apiClient.get(ApiConstants.qcReportsByPo(poId));
      if (res is List) {
        _poQcReports = res
            .map((e) => QcReportModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading QC reports: $e');
    }
  }

  Future<bool> submitQcReport({
    required String poId,
    required String itemId,
    required String status,
    required int inspectedCartons,
    int rejectedCartons = 0,
    String? remarks,
    List<String>? attachmentUrls,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'po_id': poId,
        'item_id': itemId,
        'status': status,
        'inspected_cartons': inspectedCartons,
        'rejected_cartons': rejectedCartons,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        'attachment_urls': ?attachmentUrls,
      };

      final res = await apiClient.post(ApiConstants.qcReports, body: body);
      final newReport = QcReportModel.fromJson(Map<String, dynamic>.from(res));
      _poQcReports.insert(0, newReport);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error submitting QC report: $e');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
