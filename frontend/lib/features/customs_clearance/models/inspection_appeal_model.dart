import 'package:flutter/foundation.dart';

enum AppealTier {
  firstAppeal,
  secondAppeal,
  triplicateSample;

  static AppealTier fromString(String val) {
    switch (val.toUpperCase()) {
      case 'SECOND_APPEAL':
        return AppealTier.secondAppeal;
      case 'TRIPLICATE_SAMPLE':
        return AppealTier.triplicateSample;
      case 'FIRST_APPEAL':
      default:
        return AppealTier.firstAppeal;
    }
  }

  String get labelAr {
    switch (this) {
      case AppealTier.firstAppeal:
        return 'التظلم الأول (لجنة التظلمات)';
      case AppealTier.secondAppeal:
        return 'التظلم الثاني (لجنة الخبراء)';
      case AppealTier.triplicateSample:
        return 'العينة الثلاثية (التحكيم المعملي)';
    }
  }
}

enum AppealResult {
  pending,
  overturnedConforming,
  upheldRejected;

  static AppealResult fromString(String val) {
    switch (val.toUpperCase()) {
      case 'OVERTURNED_CONFORMING':
        return AppealResult.overturnedConforming;
      case 'UPHELD_REJECTED':
        return AppealResult.upheldRejected;
      case 'PENDING':
      default:
        return AppealResult.pending;
    }
  }

  String get labelAr {
    switch (this) {
      case AppealResult.pending:
        return 'قيد نظر وفحص اللجنة';
      case AppealResult.overturnedConforming:
        return 'تم قبول التظلم (مطابق للإفراج 🟢)';
      case AppealResult.upheldRejected:
        return 'تأييد الرفض (إحالة لإعادة التصدير 🔴)';
    }
  }
}

@immutable
class InspectionAppealModel {
  final int appealId;
  final String appealCode;
  final int importFileId;
  final int? clearanceId;
  final String regulatoryAuthority;
  final String? sampleNumber;
  final String? sampleDrawDate;
  final String initialTestResult;
  final String? rejectionReason;
  final AppealTier appealTier;
  final String? appealSubmissionDate;
  final String? appealCommitteeDate;
  final String? triplicateLabAssigned;
  final AppealResult appealResult;
  final String? officialLetterRef;
  final String? notes;
  final bool isActive;
  final String? createdAt;

  const InspectionAppealModel({
    required this.appealId,
    required this.appealCode,
    required this.importFileId,
    this.clearanceId,
    required this.regulatoryAuthority,
    this.sampleNumber,
    this.sampleDrawDate,
    required this.initialTestResult,
    this.rejectionReason,
    required this.appealTier,
    this.appealSubmissionDate,
    this.appealCommitteeDate,
    this.triplicateLabAssigned,
    required this.appealResult,
    this.officialLetterRef,
    this.notes,
    required this.isActive,
    this.createdAt,
  });

  factory InspectionAppealModel.fromJson(Map<String, dynamic> json) {
    return InspectionAppealModel(
      appealId: json['appeal_id'] as int? ?? 0,
      appealCode: json['appeal_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      clearanceId: json['clearance_id'] as int?,
      regulatoryAuthority: json['regulatory_authority'] as String? ?? '',
      sampleNumber: json['sample_number'] as String?,
      sampleDrawDate: json['sample_draw_date'] as String?,
      initialTestResult: json['initial_test_result'] as String? ?? '',
      rejectionReason: json['rejection_reason'] as String?,
      appealTier: AppealTier.fromString(json['appeal_tier'] as String? ?? ''),
      appealSubmissionDate: json['appeal_submission_date'] as String?,
      appealCommitteeDate: json['appeal_committee_date'] as String?,
      triplicateLabAssigned: json['triplicate_lab_assigned'] as String?,
      appealResult: AppealResult.fromString(json['appeal_result'] as String? ?? ''),
      officialLetterRef: json['official_letter_ref'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
    );
  }
}
