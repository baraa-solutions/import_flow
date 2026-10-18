class ClearanceFollowupLogModel {
  final int logId;
  final int customsClearanceId;
  final int importFileId;
  final int followupSeq;
  final String followupDate;
  final String authorityType;
  final String? officialContact;
  final String statusSummary;
  final String? actionRequired;
  final String? nextVisitDate;
  final bool isCompleted;
  final String createdAt;
  final String? createdBy;

  ClearanceFollowupLogModel({
    required this.logId,
    required this.customsClearanceId,
    required this.importFileId,
    required this.followupSeq,
    required this.followupDate,
    required this.authorityType,
    this.officialContact,
    required this.statusSummary,
    this.actionRequired,
    this.nextVisitDate,
    this.isCompleted = false,
    required this.createdAt,
    this.createdBy,
  });

  factory ClearanceFollowupLogModel.fromJson(Map<String, dynamic> json) {
    return ClearanceFollowupLogModel(
      logId: json['log_id'] ?? 0,
      customsClearanceId: json['customs_clearance_id'] ?? 0,
      importFileId: json['import_file_id'] ?? 0,
      followupSeq: json['followup_seq'] ?? 1,
      followupDate: json['followup_date'] ?? '',
      authorityType: json['authority_type'] ?? '',
      officialContact: json['official_contact'],
      statusSummary: json['status_summary'] ?? '',
      actionRequired: json['action_required'],
      nextVisitDate: json['next_visit_date'],
      isCompleted: json['is_completed'] ?? false,
      createdAt: json['created_at'] ?? '',
      createdBy: json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_id': logId,
      'customs_clearance_id': customsClearanceId,
      'import_file_id': importFileId,
      'followup_seq': followupSeq,
      'followup_date': followupDate,
      'authority_type': authorityType,
      'official_contact': officialContact,
      'status_summary': statusSummary,
      'action_required': actionRequired,
      'next_visit_date': nextVisitDate,
      'is_completed': isCompleted,
      'created_at': createdAt,
      'created_by': createdBy,
    };
  }
}
