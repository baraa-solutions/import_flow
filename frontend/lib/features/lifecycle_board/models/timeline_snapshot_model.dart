class TimelineSnapshotModel {
  final int id;
  final int importFileId;
  final String stageCode;
  final String stageName;
  final int phaseNumber;
  final String phaseName;
  final String? plannedStartDate;
  final String? plannedEndDate;
  final String? actualStartDate;
  final String? actualEndDate;
  final double? durationDays;
  final int? slaDays;
  final double? varianceDays;
  final String status; // PENDING, IN_PROGRESS, COMPLETED, DELAYED
  final bool isBottleneck;
  final String? delayReason;
  final Map<String, dynamic>? eventDetailsJson;
  final String? lastSyncedAt;

  TimelineSnapshotModel({
    required this.id,
    required this.importFileId,
    required this.stageCode,
    required this.stageName,
    required this.phaseNumber,
    required this.phaseName,
    this.plannedStartDate,
    this.plannedEndDate,
    this.actualStartDate,
    this.actualEndDate,
    this.durationDays,
    this.slaDays,
    this.varianceDays,
    this.status = 'PENDING',
    this.isBottleneck = false,
    this.delayReason,
    this.eventDetailsJson,
    this.lastSyncedAt,
  });

  factory TimelineSnapshotModel.fromJson(Map<String, dynamic> json) {
    return TimelineSnapshotModel(
      id: json['id'] as int? ?? 0,
      importFileId: json['import_file_id'] as int? ?? 0,
      stageCode: json['stage_code']?.toString() ?? '',
      stageName: json['stage_name']?.toString() ?? '',
      phaseNumber: json['phase_number'] as int? ?? 1,
      phaseName: json['phase_name']?.toString() ?? '',
      plannedStartDate: json['planned_start_date']?.toString(),
      plannedEndDate: json['planned_end_date']?.toString(),
      actualStartDate: json['actual_start_date']?.toString(),
      actualEndDate: json['actual_end_date']?.toString(),
      durationDays: (json['duration_days'] as num?)?.toDouble(),
      slaDays: (json['sla_days'] as num?)?.toInt(),
      varianceDays: (json['variance_days'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'PENDING',
      isBottleneck: json['is_bottleneck'] == true,
      delayReason: json['delay_reason']?.toString(),
      eventDetailsJson: json['event_details_json'] as Map<String, dynamic>?,
      lastSyncedAt: json['last_synced_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'import_file_id': importFileId,
      'stage_code': stageCode,
      'stage_name': stageName,
      'phase_number': phaseNumber,
      'phase_name': phaseName,
      'planned_start_date': plannedStartDate,
      'planned_end_date': plannedEndDate,
      'actual_start_date': actualStartDate,
      'actual_end_date': actualEndDate,
      'duration_days': durationDays,
      'sla_days': slaDays,
      'variance_days': varianceDays,
      'status': status,
      'is_bottleneck': isBottleneck,
      'delay_reason': delayReason,
      'event_details_json': eventDetailsJson,
      'last_synced_at': lastSyncedAt,
    };
  }
}

class TimelineSummaryModel {
  final int importFileId;
  final String importFileCode;
  final int totalStages;
  final int completedStages;
  final int inProgressStages;
  final int delayedStages;
  final int bottlenecksCount;
  final String? currentStageCode;
  final String? currentStageName;
  final List<TimelineSnapshotModel> snapshots;

  TimelineSummaryModel({
    required this.importFileId,
    required this.importFileCode,
    this.totalStages = 25,
    this.completedStages = 0,
    this.inProgressStages = 0,
    this.delayedStages = 0,
    this.bottlenecksCount = 0,
    this.currentStageCode,
    this.currentStageName,
    this.snapshots = const [],
  });

  factory TimelineSummaryModel.fromJson(Map<String, dynamic> json) {
    final list = json['snapshots'] as List<dynamic>? ?? [];
    return TimelineSummaryModel(
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code']?.toString() ?? '',
      totalStages: json['total_stages'] as int? ?? 25,
      completedStages: json['completed_stages'] as int? ?? 0,
      inProgressStages: json['in_progress_stages'] as int? ?? 0,
      delayedStages: json['delayed_stages'] as int? ?? 0,
      bottlenecksCount: json['bottlenecks_count'] as int? ?? 0,
      currentStageCode: json['current_stage_code']?.toString(),
      currentStageName: json['current_stage_name']?.toString(),
      snapshots: list
          .map((item) => TimelineSnapshotModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'total_stages': totalStages,
      'completed_stages': completedStages,
      'in_progress_stages': inProgressStages,
      'delayed_stages': delayedStages,
      'bottlenecks_count': bottlenecksCount,
      'current_stage_code': currentStageCode,
      'current_stage_name': currentStageName,
      'snapshots': snapshots.map((s) => s.toJson()).toList(),
    };
  }
}
