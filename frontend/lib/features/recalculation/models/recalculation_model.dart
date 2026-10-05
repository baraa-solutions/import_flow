/// Data models for Centralized Recalculation Engine (CRE-001)
///
/// These models mirror the API schemas exactly.
/// All pages use these models — no page creates its own variance/sync model.
library;

// ── Preview Item ──────────────────────────────────────────────────────────────

class RecalculationPreviewItem {
  final String fieldName;
  final String labelAr;
  final String labelEn;
  final double oldValue;
  final double newValue;
  final double varianceAmount;
  final double variancePercentage;
  final bool isHardBlock;
  final double thresholdPercentage;
  final String sourceEntityType;
  final int dependencyId;

  const RecalculationPreviewItem({
    required this.fieldName,
    required this.labelAr,
    required this.labelEn,
    required this.oldValue,
    required this.newValue,
    required this.varianceAmount,
    required this.variancePercentage,
    required this.isHardBlock,
    required this.thresholdPercentage,
    required this.sourceEntityType,
    required this.dependencyId,
  });

  factory RecalculationPreviewItem.fromJson(Map<String, dynamic> json) {
    return RecalculationPreviewItem(
      fieldName: json['field_name'] as String? ?? '',
      labelAr: json['label_ar'] as String? ?? '',
      labelEn: json['label_en'] as String? ?? '',
      oldValue: (json['old_value'] as num?)?.toDouble() ?? 0.0,
      newValue: (json['new_value'] as num?)?.toDouble() ?? 0.0,
      varianceAmount: (json['variance_amount'] as num?)?.toDouble() ?? 0.0,
      variancePercentage: (json['variance_percentage'] as num?)?.toDouble() ?? 0.0,
      isHardBlock: json['is_hard_block'] as bool? ?? false,
      thresholdPercentage: (json['threshold_percentage'] as num?)?.toDouble() ?? 5.0,
      sourceEntityType: json['source_entity_type'] as String? ?? '',
      dependencyId: json['dependency_id'] as int? ?? 0,
    );
  }

  String get formattedVariancePct {
    return '${variancePercentage.toStringAsFixed(1)}%';
  }

  bool get hasChange => varianceAmount.abs() > 0.01;
}


// ── Preview Response ──────────────────────────────────────────────────────────

class RecalculationPreviewResponse {
  final String targetEntityType;
  final int targetEntityId;
  final List<RecalculationPreviewItem> items;
  final bool hasAnyVariance;
  final bool hasHardBlock;
  final double maxVariancePct;
  final bool blockedByStatus;
  final String currentEntityStatus;
  final bool canApply;
  final String messageAr;
  /// Additive backend contract: render from this code, `messageAr` is the legacy fallback.
  final String? messageCode;
  final Map<String, dynamic> params;

  const RecalculationPreviewResponse({
    required this.targetEntityType,
    required this.targetEntityId,
    required this.items,
    required this.hasAnyVariance,
    required this.hasHardBlock,
    required this.maxVariancePct,
    required this.blockedByStatus,
    required this.currentEntityStatus,
    required this.canApply,
    required this.messageAr,
    this.messageCode,
    this.params = const {},
  });

  factory RecalculationPreviewResponse.fromJson(Map<String, dynamic> json) {
    return RecalculationPreviewResponse(
      targetEntityType: json['target_entity_type'] as String? ?? '',
      targetEntityId: json['target_entity_id'] as int? ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => RecalculationPreviewItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hasAnyVariance: json['has_any_variance'] as bool? ?? false,
      hasHardBlock: json['has_hard_block'] as bool? ?? false,
      maxVariancePct: (json['max_variance_pct'] as num?)?.toDouble() ?? 0.0,
      blockedByStatus: json['blocked_by_status'] as bool? ?? false,
      currentEntityStatus: json['current_entity_status'] as String? ?? '',
      canApply: json['can_apply'] as bool? ?? false,
      messageAr: json['message_ar'] as String? ?? '',
      messageCode: json['message_code'] as String?,
      params: Map<String, dynamic>.from(json['params'] as Map? ?? const {}),
    );
  }

  List<RecalculationPreviewItem> get changedItems =>
      items.where((i) => i.hasChange).toList();
}


// ── Apply Result ──────────────────────────────────────────────────────────────

class RecalculationApplyResult {
  final String targetEntityType;
  final int targetEntityId;
  final String actionTaken; // 'auto_updated', 'revalidation_required', 'revision_created', 'no_op'
  final bool revisionCreated;
  final int? newEntityId;
  final String? newEntityCode;
  final int logId;
  final String messageAr;
  final String? messageCode;
  final Map<String, dynamic> params;
  /// Real list of applied changes returned by the backend (may be empty on old servers).
  final List<Map<String, dynamic>> appliedChanges;

  const RecalculationApplyResult({
    required this.targetEntityType,
    required this.targetEntityId,
    required this.actionTaken,
    required this.revisionCreated,
    this.newEntityId,
    this.newEntityCode,
    required this.logId,
    required this.messageAr,
    this.messageCode,
    this.params = const {},
    this.appliedChanges = const [],
  });

  factory RecalculationApplyResult.fromJson(Map<String, dynamic> json) {
    return RecalculationApplyResult(
      targetEntityType: json['target_entity_type'] as String? ?? '',
      targetEntityId: json['target_entity_id'] as int? ?? 0,
      actionTaken: json['action_taken'] as String? ?? 'no_op',
      revisionCreated: json['revision_created'] as bool? ?? false,
      newEntityId: json['new_entity_id'] as int?,
      newEntityCode: json['new_entity_code'] as String?,
      logId: json['log_id'] as int? ?? 0,
      messageAr: json['message_ar'] as String? ?? '',
      messageCode: json['message_code'] as String?,
      params: Map<String, dynamic>.from(json['params'] as Map? ?? const {}),
      appliedChanges: (json['applied_changes'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}


// ── Dependency Map Entry ──────────────────────────────────────────────────────

class RecalculationDependency {
  final int id;
  final String targetEntityType;
  final String targetField;
  final String sourceEntityType;
  final String sourceField;
  final String joinKey;
  final List<String> blockedStatuses;
  final String? requiredPermission;
  final String? labelAr;
  final String? labelEn;
  final bool isActive;

  const RecalculationDependency({
    required this.id,
    required this.targetEntityType,
    required this.targetField,
    required this.sourceEntityType,
    required this.sourceField,
    required this.joinKey,
    required this.blockedStatuses,
    this.requiredPermission,
    this.labelAr,
    this.labelEn,
    required this.isActive,
  });

  factory RecalculationDependency.fromJson(Map<String, dynamic> json) {
    return RecalculationDependency(
      id: json['id'] as int? ?? 0,
      targetEntityType: json['target_entity_type'] as String? ?? '',
      targetField: json['target_field'] as String? ?? '',
      sourceEntityType: json['source_entity_type'] as String? ?? '',
      sourceField: json['source_field'] as String? ?? '',
      joinKey: json['join_key'] as String? ?? 'import_file_id',
      blockedStatuses: (json['blocked_statuses'] as List<dynamic>?)?.cast<String>() ?? [],
      requiredPermission: json['required_permission'] as String?,
      labelAr: json['label_ar'] as String?,
      labelEn: json['label_en'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
