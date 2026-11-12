/// Payment pathway milestone gates of one import file
/// (GET /api/v1/import-files/{id}/payment-pathway).
///
/// The backend owns the rules (modules/import_files/payment_milestones.py);
/// Flutter only renders completed / pending milestones and blocking gates.
class PaymentMilestoneStatus {
  final String code;
  final String labelEn;
  final String labelAr;
  final String evidenceEn;
  final String evidenceAr;
  final bool isCompleted;
  final String? requiredBeforeGate;
  final String? requiredBeforeLabelEn;
  final String? requiredBeforeLabelAr;

  const PaymentMilestoneStatus({
    required this.code,
    required this.labelEn,
    required this.labelAr,
    this.evidenceEn = '',
    this.evidenceAr = '',
    required this.isCompleted,
    this.requiredBeforeGate,
    this.requiredBeforeLabelEn,
    this.requiredBeforeLabelAr,
  });

  factory PaymentMilestoneStatus.fromJson(Map<String, dynamic> json) => PaymentMilestoneStatus(
        code: json['code']?.toString() ?? '',
        labelEn: json['label_en']?.toString() ?? '',
        labelAr: json['label_ar']?.toString() ?? '',
        evidenceEn: json['evidence_en']?.toString() ?? '',
        evidenceAr: json['evidence_ar']?.toString() ?? '',
        isCompleted: json['is_completed'] == true,
        requiredBeforeGate: json['required_before_gate']?.toString(),
        requiredBeforeLabelEn: json['required_before_label_en']?.toString(),
        requiredBeforeLabelAr: json['required_before_label_ar']?.toString(),
      );

  String label(bool isAr) => isAr && labelAr.isNotEmpty ? labelAr : labelEn;
  String evidence(bool isAr) => isAr && evidenceAr.isNotEmpty ? evidenceAr : evidenceEn;
  String? requiredBeforeLabel(bool isAr) => isAr ? (requiredBeforeLabelAr ?? requiredBeforeLabelEn) : requiredBeforeLabelEn;
}

class PaymentGateStatus {
  final String gate;
  final String labelEn;
  final String labelAr;
  final List<String> requiredMilestones;
  final List<String> missingMilestones;
  final bool isSatisfied;
  final bool isPassed;
  final bool isWaived;

  const PaymentGateStatus({
    required this.gate,
    required this.labelEn,
    required this.labelAr,
    this.requiredMilestones = const [],
    this.missingMilestones = const [],
    required this.isSatisfied,
    required this.isPassed,
    this.isWaived = false,
  });

  factory PaymentGateStatus.fromJson(Map<String, dynamic> json) => PaymentGateStatus(
        gate: json['gate']?.toString() ?? '',
        labelEn: json['label_en']?.toString() ?? '',
        labelAr: json['label_ar']?.toString() ?? '',
        requiredMilestones: _strings(json['required_milestones']),
        missingMilestones: _strings(json['missing_milestones']),
        isSatisfied: json['is_satisfied'] == true,
        isPassed: json['is_passed'] == true,
        isWaived: json['is_waived'] == true,
      );

  String label(bool isAr) => isAr && labelAr.isNotEmpty ? labelAr : labelEn;

  /// Upcoming gate whose milestones are still missing.
  bool get isBlocking => !isPassed && !isSatisfied && !isWaived;
}

class PaymentPathwayStatus {
  final int importFileId;
  final String? importFileCode;
  final String? paymentTerm;
  final bool isPathwaySet;
  final int? currentPhaseId;
  final String? currentStepCode;
  final List<PaymentMilestoneStatus> milestones;
  final List<PaymentGateStatus> gates;
  final int completedCount;
  final int totalCount;
  final String? nextBlockingGate;
  final bool isBlocked;
  final List<String> blockingReasonsEn;
  final List<String> blockingReasonsAr;

  const PaymentPathwayStatus({
    required this.importFileId,
    this.importFileCode,
    this.paymentTerm,
    required this.isPathwaySet,
    this.currentPhaseId,
    this.currentStepCode,
    this.milestones = const [],
    this.gates = const [],
    this.completedCount = 0,
    this.totalCount = 0,
    this.nextBlockingGate,
    this.isBlocked = false,
    this.blockingReasonsEn = const [],
    this.blockingReasonsAr = const [],
  });

  factory PaymentPathwayStatus.fromJson(Map<String, dynamic> json) => PaymentPathwayStatus(
        importFileId: (json['import_file_id'] as num?)?.toInt() ?? 0,
        importFileCode: json['import_file_code']?.toString(),
        paymentTerm: json['payment_term']?.toString(),
        isPathwaySet: json['is_pathway_set'] == true,
        currentPhaseId: (json['current_phase_id'] as num?)?.toInt(),
        currentStepCode: json['current_step_code']?.toString(),
        milestones: _maps(json['milestones']).map(PaymentMilestoneStatus.fromJson).toList(),
        gates: _maps(json['gates']).map(PaymentGateStatus.fromJson).toList(),
        completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
        totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
        nextBlockingGate: json['next_blocking_gate']?.toString(),
        isBlocked: json['is_blocked'] == true,
        blockingReasonsEn: _strings(json['blocking_reasons_en']),
        blockingReasonsAr: _strings(json['blocking_reasons_ar']),
      );

  /// 0..1 share of completed milestones (1 when the pathway has none).
  double get progress => totalCount == 0 ? 1.0 : completedCount / totalCount;

  List<String> blockingReasons(bool isAr) =>
      isAr && blockingReasonsAr.isNotEmpty ? blockingReasonsAr : blockingReasonsEn;

  /// True when [gate] (PHASE_n / STEP_xx / CLOSURE) is an upcoming gate still missing milestones.
  bool isGateBlocked(String gate) => gates.any((g) => g.gate == gate && g.isBlocking);

  /// True when moving the file into board phase [phaseId] is currently blocked.
  bool isPhaseBlocked(int phaseId) => isGateBlocked('PHASE_$phaseId');

  List<PaymentMilestoneStatus> get pendingMilestones => milestones.where((m) => !m.isCompleted).toList();
}

List<String> _strings(dynamic value) =>
    value is List ? value.map((e) => e.toString()).toList() : const <String>[];

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const <Map<String, dynamic>>[];
