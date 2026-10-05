import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/system_messages/system_message_renderer.dart';

class GuideScopeModel {
  final int? scopeId;
  final int? guideEntryId;
  final String scopeType;
  final String scopeValue;

  GuideScopeModel({
    this.scopeId,
    this.guideEntryId,
    required this.scopeType,
    required this.scopeValue,
  });

  factory GuideScopeModel.fromJson(Map<String, dynamic> json) {
    return GuideScopeModel(
      scopeId: json['scope_id'],
      guideEntryId: json['guide_entry_id'],
      scopeType: json['scope_type'] ?? 'hs_code',
      scopeValue: json['scope_value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (scopeId != null) 'scope_id': scopeId,
      if (guideEntryId != null) 'guide_entry_id': guideEntryId,
      'scope_type': scopeType,
      'scope_value': scopeValue,
    };
  }

  String get scopeTypeAr {
    switch (scopeType) {
      case 'supplier':
        return 'المورد';
      case 'country_of_origin':
        return 'بلد المنشأ';
      case 'hs_code':
        return 'البند الجمركي (HS Code)';
      case 'product_category':
        return 'فئة المنتج';
      case 'port_of_loading':
        return 'ميناء الشحن';
      case 'port_of_discharge':
      case 'destination_port':
        return 'ميناء الوصول';
      case 'shipping_line':
        return 'الخط الملاحي';
      case 'incoterm':
        return 'شرط الشحن (Incoterm)';
      case 'payment_method':
        return 'طريقة الدفع';
      case 'certificate_type':
        return 'نوع الشهادة';
      case 'customs_broker':
        return 'المخلص الجمركي';
      case 'season_timing':
        return 'الموسم / التوقيت';
      case 'import_file_reference':
        return 'ملف الاستيراد';
      case 'pattern_key':
        return 'معرف النمط الذاتي';
      default:
        return scopeType;
    }
  }
}

class GuideEntryModel {
  final int entryId;
  final String title;
  final String content;
  final String entryType;
  final String severity;
  final String department;
  final String? expiresAt;
  final int upvotes;
  final bool isExpired;
  final int matchScore;
  final List<String> matchedDimensions;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isActive;
  final List<GuideScopeModel> scopes;

  // Section 5A: Autonomous Learning Engine Fields
  final String sourceType;
  final String status;
  final String? patternCategory;
  final double? confidenceScore;
  final String? confidenceLevel;
  final int? sampleSize;
  final String? evidenceSummary;
  final String? contributingFilesJson;
  final String? reasonWhy;
  final String? firstDetectedAt;
  final String? lastRecalculatedAt;
  final String? confirmedBy;
  final String? confirmedAt;
  final String? rejectedBy;
  final String? rejectedAt;
  final String? rejectionReason;
  /// System message code of title/content/evidence/reason (null for human-authored and legacy entries).
  final String? msgCode;
  final Map<String, dynamic>? msgParams;

  GuideEntryModel({
    required this.entryId,
    required this.title,
    required this.content,
    this.entryType = 'alert',
    this.severity = 'info',
    this.department = 'Logistics',
    this.expiresAt,
    this.upvotes = 0,
    this.isExpired = false,
    this.matchScore = 0,
    this.matchedDimensions = const [],
    this.createdBy = 'System',
    this.createdAt = '',
    this.updatedAt = '',
    this.isActive = true,
    this.scopes = const [],
    this.sourceType = 'HUMAN_AUTHORED',
    this.status = 'ACTIVE',
    this.patternCategory,
    this.confidenceScore,
    this.confidenceLevel,
    this.sampleSize,
    this.evidenceSummary,
    this.contributingFilesJson,
    this.reasonWhy,
    this.firstDetectedAt,
    this.lastRecalculatedAt,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionReason,
    this.msgCode,
    this.msgParams,
  });

  String _render(AppLocalizations l10n, String part, String fallback) => SystemMessageRenderer.render(
      code: msgCode, params: msgParams, part: part, l10n: l10n, fallback: fallback);

  /// [title] in the user's language (system-inferred entries carry a message code).
  String localizedTitle(AppLocalizations l10n) => _render(l10n, SystemMessagePart.title, title);
  String localizedContent(AppLocalizations l10n) => _render(l10n, SystemMessagePart.body, content);
  /// Null when there is neither a renderable evidence part nor a stored text.
  String? localizedEvidence(AppLocalizations l10n) =>
      SystemMessageRenderer.tryRender(code: msgCode, params: msgParams, part: SystemMessagePart.evidence, l10n: l10n) ??
      evidenceSummary;
  String? localizedReason(AppLocalizations l10n) =>
      SystemMessageRenderer.tryRender(code: msgCode, params: msgParams, part: SystemMessagePart.reason, l10n: l10n) ??
      reasonWhy;

  bool get isCritical => severity.toLowerCase() == 'critical';
  bool get isWarning => severity.toLowerCase() == 'warning';
  bool get isInfo => severity.toLowerCase() == 'info';
  bool get isPositive => severity.toLowerCase() == 'positive';

  // Section 5A Helper Getters
  bool get isSystemInferred => sourceType.toUpperCase() == 'SYSTEM_INFERRED';
  bool get isHumanAuthored => sourceType.toUpperCase() == 'HUMAN_AUTHORED';
  bool get isConfirmed => status.toUpperCase() == 'CONFIRMED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isArchived => status.toUpperCase() == 'ARCHIVED';

  String get confidencePercentString =>
      confidenceScore != null ? '${(confidenceScore! * 100).toInt()}%' : '';

  String get confidenceLevelAr {
    switch (confidenceLevel?.toUpperCase()) {
      case 'HIGH':
        return 'عالية (High)';
      case 'MEDIUM':
        return 'متوسطة (Medium)';
      case 'LOW':
        return 'منخفضة (Low)';
      default:
        return confidenceLevel ?? '';
    }
  }

  List<Map<String, dynamic>> get contributingFiles {
    if (contributingFilesJson == null || contributingFilesJson!.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(contributingFilesJson!);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppTheme.crimson;
      case 'warning':
        return AppTheme.orange;
      case 'positive':
        return AppTheme.emerald;
      case 'info':
      default:
        return AppTheme.cobalt;
    }
  }

  IconData get severityIcon {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.dangerous_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'positive':
        return Icons.verified_rounded;
      case 'info':
      default:
        return Icons.info_outline_rounded;
    }
  }

  String get severityLabelAr {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'حرج / مانع للخطأ (Critical)';
      case 'warning':
        return 'تحذير تشغيلي (Warning)';
      case 'positive':
        return 'أفضل ممارسة / نجاح (Best Practice)';
      case 'info':
      default:
        return 'معلومة إرشادية (Info)';
    }
  }

  factory GuideEntryModel.fromJson(Map<String, dynamic> json) {
    var rawScopes = json['scopes'] as List<dynamic>? ?? [];
    var rawMatched = json['matched_dimensions'] as List<dynamic>? ?? [];
    return GuideEntryModel(
      entryId: json['entry_id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      entryType: json['entry_type'] ?? 'alert',
      severity: json['severity'] ?? 'info',
      department: json['department'] ?? 'Logistics',
      expiresAt: json['expires_at'],
      upvotes: json['upvotes'] ?? 0,
      isExpired: json['is_expired'] ?? false,
      matchScore: json['match_score'] ?? 0,
      matchedDimensions: rawMatched.map((m) => m.toString()).toList(),
      createdBy: json['created_by'] ?? 'System',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      isActive: json['is_active'] ?? true,
      scopes: rawScopes.map((s) => GuideScopeModel.fromJson(s as Map<String, dynamic>)).toList(),
      sourceType: json['source_type'] ?? 'HUMAN_AUTHORED',
      status: json['status'] ?? 'ACTIVE',
      patternCategory: json['pattern_category'],
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      confidenceLevel: json['confidence_level'],
      sampleSize: json['sample_size'],
      evidenceSummary: json['evidence_summary'],
      contributingFilesJson: json['contributing_files_json'],
      reasonWhy: json['reason_why'],
      firstDetectedAt: json['first_detected_at'],
      lastRecalculatedAt: json['last_recalculated_at'],
      confirmedBy: json['confirmed_by'],
      confirmedAt: json['confirmed_at'],
      rejectedBy: json['rejected_by'],
      rejectedAt: json['rejected_at'],
      rejectionReason: json['rejection_reason'],
      msgCode: SystemMessageRenderer.parseCode(json['msg_code']),
      msgParams: SystemMessageRenderer.parseParams(json['msg_params']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry_id': entryId,
      'title': title,
      'content': content,
      'entry_type': entryType,
      'severity': severity,
      'department': department,
      if (expiresAt != null) 'expires_at': expiresAt,
      'upvotes': upvotes,
      'created_by': createdBy,
      'is_active': isActive,
      'scopes': scopes.map((s) => s.toJson()).toList(),
      'source_type': sourceType,
      'status': status,
      if (patternCategory != null) 'pattern_category': patternCategory,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (confidenceLevel != null) 'confidence_level': confidenceLevel,
      if (sampleSize != null) 'sample_size': sampleSize,
      if (evidenceSummary != null) 'evidence_summary': evidenceSummary,
      if (contributingFilesJson != null) 'contributing_files_json': contributingFilesJson,
      if (reasonWhy != null) 'reason_why': reasonWhy,
    };
  }
}

class GuideMatchResultModel {
  final List<GuideEntryModel> matchedEntries;
  final bool hasCriticalAlert;
  final bool hasWarningAlert;
  final List<String> mandatoryPorts;
  final List<String> requiredDocuments;
  final List<String> suggestedNotes;

  GuideMatchResultModel({
    this.matchedEntries = const [],
    this.hasCriticalAlert = false,
    this.hasWarningAlert = false,
    this.mandatoryPorts = const [],
    this.requiredDocuments = const [],
    this.suggestedNotes = const [],
  });

  factory GuideMatchResultModel.fromJson(Map<String, dynamic> json) {
    var rawEntries = json['matched_entries'] as List<dynamic>? ?? [];
    var rawPorts = json['mandatory_ports'] as List<dynamic>? ?? [];
    var rawDocs = json['required_documents'] as List<dynamic>? ?? [];
    var rawNotes = json['suggested_notes'] as List<dynamic>? ?? [];

    return GuideMatchResultModel(
      matchedEntries: rawEntries.map((e) => GuideEntryModel.fromJson(e as Map<String, dynamic>)).toList(),
      hasCriticalAlert: json['has_critical_alert'] ?? false,
      hasWarningAlert: json['has_warning_alert'] ?? false,
      mandatoryPorts: rawPorts.map((p) => p.toString()).toList(),
      requiredDocuments: rawDocs.map((d) => d.toString()).toList(),
      suggestedNotes: rawNotes.map((n) => n.toString()).toList(),
    );
  }
}

class ProvenanceModel {
  final int entryId;
  final String title;
  final String content;
  final String sourceType;
  final String status;
  final String? patternCategory;
  final double? confidenceScore;
  final String? confidenceLevel;
  final int? sampleSize;
  final String? evidenceSummary;
  final List<Map<String, dynamic>> contributingFiles;
  final String? reasonWhy;
  final String? firstDetectedAt;
  final String? lastRecalculatedAt;
  final bool isConfirmed;
  final String? confirmedBy;
  final bool isRejected;
  final String? rejectedBy;
  final String? rejectionReason;

  ProvenanceModel({
    required this.entryId,
    required this.title,
    required this.content,
    required this.sourceType,
    required this.status,
    this.patternCategory,
    this.confidenceScore,
    this.confidenceLevel,
    this.sampleSize,
    this.evidenceSummary,
    this.contributingFiles = const [],
    this.reasonWhy,
    this.firstDetectedAt,
    this.lastRecalculatedAt,
    this.isConfirmed = false,
    this.confirmedBy,
    this.isRejected = false,
    this.rejectedBy,
    this.rejectionReason,
  });

  factory ProvenanceModel.fromJson(Map<String, dynamic> json) {
    var rawContributing = json['contributing_files'] as List<dynamic>? ?? [];
    return ProvenanceModel(
      entryId: json['entry_id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      sourceType: json['source_type'] ?? 'SYSTEM_INFERRED',
      status: json['status'] ?? 'ACTIVE',
      patternCategory: json['pattern_category'],
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      confidenceLevel: json['confidence_level'],
      sampleSize: json['sample_size'],
      evidenceSummary: json['evidence_summary'],
      contributingFiles: rawContributing.cast<Map<String, dynamic>>(),
      reasonWhy: json['reason_why'],
      firstDetectedAt: json['first_detected_at'],
      lastRecalculatedAt: json['last_recalculated_at'],
      isConfirmed: json['is_confirmed'] ?? false,
      confirmedBy: json['confirmed_by'],
      isRejected: json['is_rejected'] ?? false,
      rejectedBy: json['rejected_by'],
      rejectionReason: json['rejection_reason'],
    );
  }
}
