/// Model representing an operational logistics rule with safety guards and audit trails.
class LogisticsRule {
  final int id;
  final String ruleKey;
  final String ruleNameAr;
  final String ruleNameEn;
  final String scopeType;
  final int? scopeId;
  final String? conservativeDefault;
  final String? verifiedValue;
  final String valueUnit;
  final String enforcementLevel;
  final String verificationStatus;
  final int? verifiedByUserId;
  final DateTime? verifiedOn;
  final String? evidenceRef;
  final String? sourceRef;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final DateTime? reviewDueOn;
  final int versionId;
  final bool isLatest;
  final bool isActive;
  final String effectiveEnforcementLevel;
  final bool safetyGuardTriggered;
  final String? guardReason;

  const LogisticsRule({
    required this.id,
    required this.ruleKey,
    required this.ruleNameAr,
    required this.ruleNameEn,
    this.scopeType = 'GLOBAL',
    this.scopeId,
    this.conservativeDefault,
    this.verifiedValue,
    required this.valueUnit,
    this.enforcementLevel = 'WARNING',
    this.verificationStatus = 'UNVERIFIED',
    this.verifiedByUserId,
    this.verifiedOn,
    this.evidenceRef,
    this.sourceRef,
    this.effectiveFrom,
    this.effectiveTo,
    this.reviewDueOn,
    this.versionId = 1,
    this.isLatest = true,
    this.isActive = true,
    this.effectiveEnforcementLevel = 'WARNING',
    this.safetyGuardTriggered = false,
    this.guardReason,
  });

  factory LogisticsRule.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    return LogisticsRule(
      id: json['id'] as int? ?? 0,
      ruleKey: json['rule_key'] as String? ?? '',
      ruleNameAr: json['rule_name_ar'] as String? ?? '',
      ruleNameEn: json['rule_name_en'] as String? ?? '',
      scopeType: json['scope_type'] as String? ?? 'GLOBAL',
      scopeId: json['scope_id'] as int?,
      conservativeDefault: json['conservative_default'] as String?,
      verifiedValue: json['verified_value'] as String?,
      valueUnit: json['value_unit'] as String? ?? 'DAYS',
      enforcementLevel: json['enforcement_level'] as String? ?? 'WARNING',
      verificationStatus: json['verification_status'] as String? ?? 'UNVERIFIED',
      verifiedByUserId: json['verified_by_user_id'] as int?,
      verifiedOn: parseDate(json['verified_on']),
      evidenceRef: json['evidence_ref'] as String?,
      sourceRef: json['source_ref'] as String?,
      effectiveFrom: parseDate(json['effective_from']),
      effectiveTo: parseDate(json['effective_to']),
      reviewDueOn: parseDate(json['review_due_on']),
      versionId: json['version_id'] as int? ?? 1,
      isLatest: json['is_latest'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      effectiveEnforcementLevel:
          json['effective_enforcement_level'] as String? ?? 'WARNING',
      safetyGuardTriggered: json['safety_guard_triggered'] as bool? ?? false,
      guardReason: json['guard_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rule_key': ruleKey,
      'rule_name_ar': ruleNameAr,
      'rule_name_en': ruleNameEn,
      'scope_type': scopeType,
      'scope_id': scopeId,
      'conservative_default': conservativeDefault,
      'verified_value': verifiedValue,
      'value_unit': valueUnit,
      'enforcement_level': enforcementLevel,
      'verification_status': verificationStatus,
      'verified_by_user_id': verifiedByUserId,
      'verified_on': verifiedOn?.toIso8601String(),
      'evidence_ref': evidenceRef,
      'source_ref': sourceRef,
      'effective_from': effectiveFrom?.toIso8601String().split('T').first,
      'effective_to': effectiveTo?.toIso8601String().split('T').first,
      'review_due_on': reviewDueOn?.toIso8601String().split('T').first,
      'version_id': versionId,
      'is_latest': isLatest,
      'is_active': isActive,
      'effective_enforcement_level': effectiveEnforcementLevel,
      'safety_guard_triggered': safetyGuardTriggered,
      'guard_reason': guardReason,
    };
  }

  bool get isVerified => verificationStatus == 'VERIFIED';
}
