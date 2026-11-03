import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';

class RefundableDepositModel {
  final int id;
  final String depositCode;
  final int? importFileId;
  final String depositType;
  final String beneficiaryType;
  final String beneficiaryName;
  final String? containerNumber;
  final String? eirNumber;
  final String? eirReturnDate;
  final double depositAmount;
  final String currency;
  final String? paidDate;
  final String? paymentReference;
  final String? bankLgNumber;
  final String? bankLgIssuingBank;
  final String? bankLgExpiryDate;
  final String recoveryStatus;
  final double refundedAmount;
  final String? refundDate;
  final String? refundReference;
  final double deductionAmount;
  final String? deductionReason;
  final String? notes;
  final String createdAt;

  const RefundableDepositModel({
    required this.id,
    required this.depositCode,
    this.importFileId,
    required this.depositType,
    required this.beneficiaryType,
    required this.beneficiaryName,
    this.containerNumber,
    this.eirNumber,
    this.eirReturnDate,
    required this.depositAmount,
    required this.currency,
    this.paidDate,
    this.paymentReference,
    this.bankLgNumber,
    this.bankLgIssuingBank,
    this.bankLgExpiryDate,
    required this.recoveryStatus,
    required this.refundedAmount,
    this.refundDate,
    this.refundReference,
    required this.deductionAmount,
    this.deductionReason,
    this.notes,
    required this.createdAt,
  });

  factory RefundableDepositModel.fromJson(Map<String, dynamic> json) {
    return RefundableDepositModel(
      id: json['id'] as int,
      depositCode: json['deposit_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int?,
      depositType: json['deposit_type'] as String? ?? 'SHIPPING_LINE_CONTAINER',
      beneficiaryType: json['beneficiary_type'] as String? ?? 'CARRIER',
      beneficiaryName: json['beneficiary_name'] as String? ?? '',
      containerNumber: json['container_number'] as String?,
      eirNumber: json['eir_number'] as String?,
      eirReturnDate: json['eir_return_date'] as String?,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'EGP',
      paidDate: json['paid_date'] as String?,
      paymentReference: json['payment_reference'] as String?,
      bankLgNumber: json['bank_lg_number'] as String?,
      bankLgIssuingBank: json['bank_lg_issuing_bank'] as String?,
      bankLgExpiryDate: json['bank_lg_expiry_date'] as String?,
      recoveryStatus: json['recovery_status'] as String? ?? 'PENDING',
      refundedAmount: (json['refunded_amount'] as num?)?.toDouble() ?? 0.0,
      refundDate: json['refund_date'] as String?,
      refundReference: json['refund_reference'] as String?,
      deductionAmount: (json['deduction_amount'] as num?)?.toDouble() ?? 0.0,
      deductionReason: json['deduction_reason'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'import_file_id': importFileId,
    'deposit_type': depositType,
    'beneficiary_type': beneficiaryType,
    'beneficiary_name': beneficiaryName,
    'container_number': containerNumber,
    'eir_number': eirNumber,
    'eir_return_date': eirReturnDate,
    'deposit_amount': depositAmount,
    'currency': currency,
    'paid_date': paidDate,
    'payment_reference': paymentReference,
    'bank_lg_number': bankLgNumber,
    'bank_lg_issuing_bank': bankLgIssuingBank,
    'bank_lg_expiry_date': bankLgExpiryDate,
    'notes': notes,
  };
}

class DepositRecoveryMetricsModel {
  final int totalDepositsCount;
  final int pendingRecoveryCount;
  final double pendingRecoveryAmountEgp;
  final double recoveredAmountEgp;
  final double totalDeductionsEgp;
  final int activeBankLgCount;
  final int carrierDepositsCount;

  const DepositRecoveryMetricsModel({
    required this.totalDepositsCount,
    required this.pendingRecoveryCount,
    required this.pendingRecoveryAmountEgp,
    required this.recoveredAmountEgp,
    required this.totalDeductionsEgp,
    required this.activeBankLgCount,
    required this.carrierDepositsCount,
  });

  factory DepositRecoveryMetricsModel.fromJson(Map<String, dynamic> json) {
    return DepositRecoveryMetricsModel(
      totalDepositsCount: json['total_deposits_count'] as int? ?? 0,
      pendingRecoveryCount: json['pending_recovery_count'] as int? ?? 0,
      pendingRecoveryAmountEgp: (json['pending_recovery_amount_egp'] as num?)?.toDouble() ?? 0.0,
      recoveredAmountEgp: (json['recovered_amount_egp'] as num?)?.toDouble() ?? 0.0,
      totalDeductionsEgp: (json['total_deductions_egp'] as num?)?.toDouble() ?? 0.0,
      activeBankLgCount: json['active_bank_lg_count'] as int? ?? 0,
      carrierDepositsCount: json['carrier_deposits_count'] as int? ?? 0,
    );
  }

  static const empty = DepositRecoveryMetricsModel(
    totalDepositsCount: 0,
    pendingRecoveryCount: 0,
    pendingRecoveryAmountEgp: 0.0,
    recoveredAmountEgp: 0.0,
    totalDeductionsEgp: 0.0,
    activeBankLgCount: 0,
    carrierDepositsCount: 0,
  );
}

final depositsRecoveryProvider = FutureProvider.autoDispose<List<RefundableDepositModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiConstants.baseUrl}/api/v1/deposits-recovery?size=100');
  final data = response.data as Map<String, dynamic>;
  final items = (data['items'] as List<dynamic>?) ?? [];
  return items.map((e) => RefundableDepositModel.fromJson(e as Map<String, dynamic>)).toList();
});

final depositRecoveryMetricsProvider = FutureProvider.autoDispose<DepositRecoveryMetricsModel>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiConstants.baseUrl}/api/v1/deposits-recovery/metrics');
  return DepositRecoveryMetricsModel.fromJson(response.data as Map<String, dynamic>);
});

class DepositsRecoveryActions {
  final Ref ref;
  DepositsRecoveryActions(this.ref);

  Future<void> createDeposit(Map<String, dynamic> payload) async {
    final dio = ref.read(dioProvider);
    await dio.post('${ApiConstants.baseUrl}/api/v1/deposits-recovery', data: payload);
    ref.invalidate(depositsRecoveryProvider);
    ref.invalidate(depositRecoveryMetricsProvider);
  }

  Future<void> linkEir(int id, String containerNo, String eirNo, String returnDate, String? notes) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '${ApiConstants.baseUrl}/api/v1/deposits-recovery/$id/link-eir',
      data: {
        'container_number': containerNo,
        'eir_number': eirNo,
        'eir_return_date': returnDate,
        'notes': notes,
      },
    );
    ref.invalidate(depositsRecoveryProvider);
    ref.invalidate(depositRecoveryMetricsProvider);
  }

  Future<void> submitClaim(int id, String submissionDate, String? refCode, String? notes) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '${ApiConstants.baseUrl}/api/v1/deposits-recovery/$id/submit-claim',
      data: {
        'claim_submission_date': submissionDate,
        'submission_reference': refCode,
        'notes': notes,
      },
    );
    ref.invalidate(depositsRecoveryProvider);
    ref.invalidate(depositRecoveryMetricsProvider);
  }

  Future<void> settleRefund(int id, Map<String, dynamic> payload) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '${ApiConstants.baseUrl}/api/v1/deposits-recovery/$id/settle',
      data: payload,
    );
    ref.invalidate(depositsRecoveryProvider);
    ref.invalidate(depositRecoveryMetricsProvider);
  }

  Future<void> releaseBankLg(int id, String letterRef, String releaseDate, String? notes) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '${ApiConstants.baseUrl}/api/v1/deposits-recovery/$id/release-lg',
      data: {
        'release_letter_reference': letterRef,
        'release_date': releaseDate,
        'notes': notes,
      },
    );
    ref.invalidate(depositsRecoveryProvider);
    ref.invalidate(depositRecoveryMetricsProvider);
  }
}

final depositsRecoveryActionsProvider = Provider((ref) => DepositsRecoveryActions(ref));
