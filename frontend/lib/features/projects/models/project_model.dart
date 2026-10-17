double? _numToNullableDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val);
  return null;
}

int _numToInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? fallback;
  return fallback;
}

bool _parseBool(dynamic val, {bool defaultValue = false}) {
  if (val == null) return defaultValue;
  if (val is bool) return val;
  if (val is num) return val != 0;
  if (val is String) {
    final s = val.toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes' || s == 't';
  }
  return defaultValue;
}

class ProjectModel {
  final int? projectId;
  final String projectCode;
  final String projectName;
  final String projectOwner;
  final int companyId;
  final List<int> companyIds;
  final int supplierId;
  final int incotermId;
  final String importType;
  final String priority;
  final String shipmentCategory;
  final bool allowMultiShipment;
  final bool allowMultiCompany;
  final double? totalBudgetUsd;
  final String? targetEndDate;
  final String status;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? companyName;
  final String? supplierName;
  final String? incotermCode;
  final double? totalCommittedUsd;
  final int? poCount;
  final double? remainingBudgetUsd;
  final double? budgetUtilizationPercent;
  final List<String> missingRateCurrencies;
  final Map<String, double> committedByCurrency;

  ProjectModel({
    this.projectId,
    required this.projectCode,
    required this.projectName,
    required this.projectOwner,
    required this.companyId,
    this.companyIds = const [],
    required this.supplierId,
    required this.incotermId,
    this.importType = 'Direct Commercial',
    this.priority = 'Medium',
    this.shipmentCategory = 'FCL Container',
    this.allowMultiShipment = true,
    this.allowMultiCompany = true,
    this.totalBudgetUsd,
    this.targetEndDate,
    this.status = 'Open',
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.companyName,
    this.supplierName,
    this.incotermCode,
    this.totalCommittedUsd,
    this.poCount,
    this.remainingBudgetUsd,
    this.budgetUtilizationPercent,
    this.missingRateCurrencies = const [],
    this.committedByCurrency = const {},
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    List<int> cIds = [];
    if (json['company_ids'] != null && json['company_ids'] is List) {
      cIds = (json['company_ids'] as List).map((e) => _numToInt(e)).toList();
    } else if (json['company_id'] != null) {
      cIds = [_numToInt(json['company_id'])];
    }

    return ProjectModel(
      projectId: json['project_id'] != null ? _numToInt(json['project_id']) : null,
      projectCode: json['project_code']?.toString() ?? '',
      projectName: json['project_name']?.toString() ?? '',
      projectOwner: json['project_owner']?.toString() ?? '',
      companyId: _numToInt(json['company_id']),
      companyIds: cIds,
      supplierId: _numToInt(json['supplier_id']),
      incotermId: _numToInt(json['incoterm_id']),
      importType: json['import_type']?.toString() ?? 'Direct Commercial',
      priority: json['priority']?.toString() ?? 'Medium',
      shipmentCategory: json['shipment_category']?.toString() ?? 'FCL Container',
      allowMultiShipment: _parseBool(json['allow_multi_shipment'], defaultValue: true),
      allowMultiCompany: _parseBool(json['allow_multi_company'], defaultValue: true),
      totalBudgetUsd: _numToNullableDouble(json['total_budget_usd']),
      targetEndDate: json['target_end_date']?.toString(),
      status: json['status']?.toString() ?? 'Open',
      notes: json['notes']?.toString(),
      isActive: _parseBool(json['is_active'], defaultValue: true),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      companyName: json['company_name']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      incotermCode: json['incoterm_code']?.toString(),
      totalCommittedUsd: _numToNullableDouble(json['total_committed_usd']),
      poCount: json['po_count'] != null ? _numToInt(json['po_count']) : null,
      remainingBudgetUsd: _numToNullableDouble(json['remaining_budget_usd']),
      budgetUtilizationPercent: _numToNullableDouble(json['budget_utilization_percent']),
      missingRateCurrencies: json['missing_rate_currencies'] != null && json['missing_rate_currencies'] is List
          ? (json['missing_rate_currencies'] as List).map((e) => e.toString()).toList()
          : const [],
      committedByCurrency: json['committed_by_currency'] != null && json['committed_by_currency'] is Map
          ? Map<String, double>.from(
              (json['committed_by_currency'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
            )
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (projectId != null) 'project_id': projectId,
      'project_code': projectCode,
      'project_name': projectName,
      'project_owner': projectOwner,
      'company_id': companyId,
      'company_ids': companyIds,
      'supplier_id': supplierId,
      'incoterm_id': incotermId,
      'import_type': importType,
      'priority': priority,
      'shipment_category': shipmentCategory,
      'allow_multi_shipment': allowMultiShipment,
      'allow_multi_company': allowMultiCompany,
      'total_budget_usd': totalBudgetUsd,
      if (targetEndDate != null) 'target_end_date': targetEndDate,
      'status': status,
      'notes': notes,
      'is_active': isActive,
    };
  }
}
