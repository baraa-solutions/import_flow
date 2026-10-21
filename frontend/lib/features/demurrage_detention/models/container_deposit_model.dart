import 'package:flutter/foundation.dart';

enum ContainerCondition {
  soundClean,
  damageClaimed,
  cleaningFeeDeducted;

  static ContainerCondition fromString(String val) {
    switch (val.toUpperCase()) {
      case 'DAMAGE_CLAIMED':
        return ContainerCondition.damageClaimed;
      case 'CLEANING_FEE_DEDUCTED':
        return ContainerCondition.cleaningFeeDeducted;
      case 'SOUND_CLEAN':
      default:
        return ContainerCondition.soundClean;
    }
  }

  String get labelAr {
    switch (this) {
      case ContainerCondition.soundClean:
        return 'سليمة ونظيفة (Sound Clean)';
      case ContainerCondition.damageClaimed:
        return 'مطالبة بتلفيات وأضرار';
      case ContainerCondition.cleaningFeeDeducted:
        return 'خصم غسيل ونظافة';
    }
  }
}

enum DepositRefundStatus {
  pendingReturn,
  claimSubmitted,
  overdue30Days,
  refundedFull,
  refundedPartial;

  static DepositRefundStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'CLAIM_SUBMITTED':
        return DepositRefundStatus.claimSubmitted;
      case 'OVERDUE_30_DAYS':
        return DepositRefundStatus.overdue30Days;
      case 'REFUNDED_FULL':
        return DepositRefundStatus.refundedFull;
      case 'REFUNDED_PARTIAL':
        return DepositRefundStatus.refundedPartial;
      case 'PENDING_RETURN':
      default:
        return DepositRefundStatus.pendingReturn;
    }
  }

  String get labelAr {
    switch (this) {
      case DepositRefundStatus.pendingReturn:
        return 'قيد الاسترجاع الفارغ (لم تسلم)';
      case DepositRefundStatus.claimSubmitted:
        return 'تم استلام EIR ومطالبة الخط الملاحي';
      case DepositRefundStatus.overdue30Days:
        return 'تأخر استرداد التأمين (أكثر من 30 يوماً)';
      case DepositRefundStatus.refundedFull:
        return 'تم استرداد التأمين بالكامل';
      case DepositRefundStatus.refundedPartial:
        return 'استرداد جزئي مع خصم';
    }
  }
}

@immutable
class ContainerDepositModel {
  final int depositId;
  final int importFileId;
  final int? carrierId;
  final String carrierName;
  final String containerNumber;
  final String containerType;
  final double depositAmountEgp;
  final String? paymentReference;
  final String paymentDate;
  final String? eirReturnNumber;
  final String? eirReturnDate;
  final ContainerCondition containerCondition;
  final double deductionAmountEgp;
  final DepositRefundStatus refundStatus;
  final String? refundChequeOrTransferNo;
  final String? refundReceivedDate;
  final int daysOverdue;
  final String? notes;
  final List<dynamic> disputeHistory;
  final bool isActive;
  final String createdAt;

  const ContainerDepositModel({
    required this.depositId,
    required this.importFileId,
    this.carrierId,
    required this.carrierName,
    required this.containerNumber,
    required this.containerType,
    required this.depositAmountEgp,
    this.paymentReference,
    required this.paymentDate,
    this.eirReturnNumber,
    this.eirReturnDate,
    required this.containerCondition,
    required this.deductionAmountEgp,
    required this.refundStatus,
    this.refundChequeOrTransferNo,
    this.refundReceivedDate,
    required this.daysOverdue,
    this.notes,
    required this.disputeHistory,
    required this.isActive,
    required this.createdAt,
  });

  factory ContainerDepositModel.fromJson(Map<String, dynamic> json) {
    return ContainerDepositModel(
      depositId: json['deposit_id'] as int? ?? 0,
      importFileId: json['import_file_id'] as int? ?? 0,
      carrierId: json['carrier_id'] as int?,
      carrierName: json['carrier_name'] as String? ?? '',
      containerNumber: json['container_number'] as String? ?? '',
      containerType: json['container_type'] as String? ?? '',
      depositAmountEgp: (json['deposit_amount_egp'] as num?)?.toDouble() ?? 0.0,
      paymentReference: json['payment_reference'] as String?,
      paymentDate: json['payment_date'] as String? ?? '',
      eirReturnNumber: json['eir_return_number'] as String?,
      eirReturnDate: json['eir_return_date'] as String?,
      containerCondition: ContainerCondition.fromString(json['container_condition'] as String? ?? ''),
      deductionAmountEgp: (json['deduction_amount_egp'] as num?)?.toDouble() ?? 0.0,
      refundStatus: DepositRefundStatus.fromString(json['refund_status'] as String? ?? ''),
      refundChequeOrTransferNo: json['refund_cheque_or_transfer_no'] as String?,
      refundReceivedDate: json['refund_received_date'] as String?,
      daysOverdue: json['days_overdue'] as int? ?? 0,
      notes: json['notes'] as String?,
      disputeHistory: json['dispute_history'] as List<dynamic>? ?? [],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

@immutable
class ContainerDepositOverviewModel {
  final int totalActiveDeposits;
  final double totalDepositAmountEgp;
  final int pendingReturnCount;
  final int claimSubmittedCount;
  final int overdue30DaysCount;
  final double overdueDepositAmountEgp;
  final int refundedFullCount;
  final int refundedPartialCount;
  final double totalRefundedAmountEgp;
  final double totalDeductionsEgp;
  final Map<String, dynamic> carrierBreakdown;

  const ContainerDepositOverviewModel({
    required this.totalActiveDeposits,
    required this.totalDepositAmountEgp,
    required this.pendingReturnCount,
    required this.claimSubmittedCount,
    required this.overdue30DaysCount,
    required this.overdueDepositAmountEgp,
    required this.refundedFullCount,
    required this.refundedPartialCount,
    required this.totalRefundedAmountEgp,
    required this.totalDeductionsEgp,
    required this.carrierBreakdown,
  });

  factory ContainerDepositOverviewModel.fromJson(Map<String, dynamic> json) {
    return ContainerDepositOverviewModel(
      totalActiveDeposits: json['total_active_deposits'] as int? ?? 0,
      totalDepositAmountEgp: (json['total_deposit_amount_egp'] as num?)?.toDouble() ?? 0.0,
      pendingReturnCount: json['pending_return_count'] as int? ?? 0,
      claimSubmittedCount: json['claim_submitted_count'] as int? ?? 0,
      overdue30DaysCount: json['overdue_30_days_count'] as int? ?? 0,
      overdueDepositAmountEgp: (json['overdue_deposit_amount_egp'] as num?)?.toDouble() ?? 0.0,
      refundedFullCount: json['refunded_full_count'] as int? ?? 0,
      refundedPartialCount: json['refunded_partial_count'] as int? ?? 0,
      totalRefundedAmountEgp: (json['total_refunded_amount_egp'] as num?)?.toDouble() ?? 0.0,
      totalDeductionsEgp: (json['total_deductions_egp'] as num?)?.toDouble() ?? 0.0,
      carrierBreakdown: json['carrier_breakdown'] as Map<String, dynamic>? ?? {},
    );
  }
}
