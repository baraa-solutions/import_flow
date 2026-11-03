import 'package:flutter/foundation.dart';

enum ReexportStatus {
  mandated,
  bookingConfirmed,
  customsInspected,
  ladenOnBoard,
  completedClosed;

  static ReexportStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'BOOKING_CONFIRMED':
        return ReexportStatus.bookingConfirmed;
      case 'CUSTOMS_INSPECTED':
        return ReexportStatus.customsInspected;
      case 'LADEN_ON_BOARD':
        return ReexportStatus.ladenOnBoard;
      case 'COMPLETED_CLOSED':
        return ReexportStatus.completedClosed;
      case 'MANDATED':
      default:
        return ReexportStatus.mandated;
    }
  }

  String toApiValue() {
    switch (this) {
      case ReexportStatus.mandated:
        return 'MANDATED';
      case ReexportStatus.bookingConfirmed:
        return 'BOOKING_CONFIRMED';
      case ReexportStatus.customsInspected:
        return 'CUSTOMS_INSPECTED';
      case ReexportStatus.ladenOnBoard:
        return 'LADEN_ON_BOARD';
      case ReexportStatus.completedClosed:
        return 'COMPLETED_CLOSED';
    }
  }

  String get labelAr {
    switch (this) {
      case ReexportStatus.mandated:
        return 'صدر قرار إعادة التصدير';
      case ReexportStatus.bookingConfirmed:
        return 'تم تأكيد حجز الشحن العكسي';
      case ReexportStatus.customsInspected:
        return 'تمت معاينة لجنة الإشراف الجمركي';
      case ReexportStatus.ladenOnBoard:
        return 'تم الشحن الفعلي على ظهر السفينة';
      case ReexportStatus.completedClosed:
        return 'مكتمل ومغلق رسمياً';
    }
  }
}

enum DutyDrawbackStatus {
  pendingApplication,
  approvedRefunded,
  exemptionSuspended;

  static DutyDrawbackStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'APPROVED_REFUNDED':
        return DutyDrawbackStatus.approvedRefunded;
      case 'EXEMPTION_SUSPENDED':
        return DutyDrawbackStatus.exemptionSuspended;
      case 'PENDING_APPLICATION':
      default:
        return DutyDrawbackStatus.pendingApplication;
    }
  }

  String get labelAr {
    switch (this) {
      case DutyDrawbackStatus.pendingApplication:
        return 'قيد تقديم طلب الاسترداد';
      case DutyDrawbackStatus.approvedRefunded:
        return 'تمت الموافقة ورد الرسوم';
      case DutyDrawbackStatus.exemptionSuspended:
        return 'معلق وموقوف الإعفاء';
    }
  }
}

enum SupplierCreditNoteStatus {
  requested,
  received,
  arbitration;

  static SupplierCreditNoteStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'RECEIVED':
        return SupplierCreditNoteStatus.received;
      case 'ARBITRATION':
        return SupplierCreditNoteStatus.arbitration;
      case 'REQUESTED':
      default:
        return SupplierCreditNoteStatus.requested;
    }
  }

  String get labelAr {
    switch (this) {
      case SupplierCreditNoteStatus.requested:
        return 'تمت مطالبة المورد بالخصم';
      case SupplierCreditNoteStatus.received:
        return 'تم استلام إشعار الخصم الدائن';
      case SupplierCreditNoteStatus.arbitration:
        return 'نزاع وتحكيم تجاري مع المورد';
    }
  }
}

@immutable
class ReexportDossierModel {
  final int reexportId;
  final int importFileId;
  final String importFileCode;
  final String rejectionAuthority;
  final String rejectionDecreeNumber;
  final String rejectionDate;
  final String legalReexportDeadline;
  final int daysRemainingToDestruction;
  final String reexportReason;
  final String? customsOutboundDeclarationNo;
  final bool supervisionCommitteeFormed;
  final String? customsOfficerInCharge;
  final int? returnCarrierId;
  final String? returnBookingNumber;
  final String? outboundBlNumber;
  final List<String> containerNumbers;
  final String? returnPortOfDischarge;
  final DutyDrawbackStatus dutyDrawbackStatus;
  final double dutyAmountRefundableEgp;
  final SupplierCreditNoteStatus supplierCreditNoteStatus;
  final double creditNoteAmountUsd;
  final ReexportStatus status;
  final String? notes;
  final bool isActive;
  final String createdAt;

  const ReexportDossierModel({
    required this.reexportId,
    required this.importFileId,
    required this.importFileCode,
    required this.rejectionAuthority,
    required this.rejectionDecreeNumber,
    required this.rejectionDate,
    required this.legalReexportDeadline,
    required this.daysRemainingToDestruction,
    required this.reexportReason,
    this.customsOutboundDeclarationNo,
    required this.supervisionCommitteeFormed,
    this.customsOfficerInCharge,
    this.returnCarrierId,
    this.returnBookingNumber,
    this.outboundBlNumber,
    required this.containerNumbers,
    this.returnPortOfDischarge,
    required this.dutyDrawbackStatus,
    required this.dutyAmountRefundableEgp,
    required this.supplierCreditNoteStatus,
    required this.creditNoteAmountUsd,
    required this.status,
    this.notes,
    required this.isActive,
    required this.createdAt,
  });

  factory ReexportDossierModel.fromJson(Map<String, dynamic> json) {
    return ReexportDossierModel(
      reexportId: json['reexport_id'] as int? ?? 0,
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] as String? ?? '',
      rejectionAuthority: json['rejection_authority'] as String? ?? '',
      rejectionDecreeNumber: json['rejection_decree_number'] as String? ?? '',
      rejectionDate: json['rejection_date'] as String? ?? '',
      legalReexportDeadline: json['legal_reexport_deadline'] as String? ?? '',
      daysRemainingToDestruction: json['days_remaining_to_destruction'] as int? ?? 0,
      reexportReason: json['reexport_reason'] as String? ?? '',
      customsOutboundDeclarationNo: json['customs_outbound_declaration_no'] as String?,
      supervisionCommitteeFormed: json['supervision_committee_formed'] as bool? ?? false,
      customsOfficerInCharge: json['customs_officer_in_charge'] as String?,
      returnCarrierId: json['return_carrier_id'] as int?,
      returnBookingNumber: json['return_booking_number'] as String?,
      outboundBlNumber: json['outbound_bl_number'] as String?,
      containerNumbers: (json['container_numbers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      returnPortOfDischarge: json['return_port_of_discharge'] as String?,
      dutyDrawbackStatus: DutyDrawbackStatus.fromString(json['duty_drawback_status'] as String? ?? ''),
      dutyAmountRefundableEgp: (json['duty_amount_refundable_egp'] as num?)?.toDouble() ?? 0.0,
      supplierCreditNoteStatus: SupplierCreditNoteStatus.fromString(json['supplier_credit_note_status'] as String? ?? ''),
      creditNoteAmountUsd: (json['credit_note_amount_usd'] as num?)?.toDouble() ?? 0.0,
      status: ReexportStatus.fromString(json['status'] as String? ?? ''),
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

@immutable
class DestructionAlertSummaryModel {
  final int reexportId;
  final int importFileId;
  final String importFileCode;
  final String rejectionDecreeNumber;
  final String rejectionAuthority;
  final String rejectionDate;
  final String legalReexportDeadline;
  final int daysRemainingToDestruction;
  final String alertLevel; // CRITICAL, URGENT, WARNING, NORMAL
  final String status;

  const DestructionAlertSummaryModel({
    required this.reexportId,
    required this.importFileId,
    required this.importFileCode,
    required this.rejectionDecreeNumber,
    required this.rejectionAuthority,
    required this.rejectionDate,
    required this.legalReexportDeadline,
    required this.daysRemainingToDestruction,
    required this.alertLevel,
    required this.status,
  });

  factory DestructionAlertSummaryModel.fromJson(Map<String, dynamic> json) {
    return DestructionAlertSummaryModel(
      reexportId: json['reexport_id'] as int? ?? 0,
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] as String? ?? '',
      rejectionDecreeNumber: json['rejection_decree_number'] as String? ?? '',
      rejectionAuthority: json['rejection_authority'] as String? ?? '',
      rejectionDate: json['rejection_date'] as String? ?? '',
      legalReexportDeadline: json['legal_reexport_deadline'] as String? ?? '',
      daysRemainingToDestruction: json['days_remaining_to_destruction'] as int? ?? 0,
      alertLevel: json['alert_level'] as String? ?? 'NORMAL',
      status: json['status'] as String? ?? '',
    );
  }
}

@immutable
class DestructionAlertOverviewModel {
  final int totalActiveDossiers;
  final int criticalCount;
  final int urgentCount;
  final int warningCount;
  final int normalCount;
  final List<DestructionAlertSummaryModel> alerts;

  const DestructionAlertOverviewModel({
    required this.totalActiveDossiers,
    required this.criticalCount,
    required this.urgentCount,
    required this.warningCount,
    required this.normalCount,
    required this.alerts,
  });

  factory DestructionAlertOverviewModel.fromJson(Map<String, dynamic> json) {
    final list = (json['alerts'] as List<dynamic>?)
            ?.map((e) => DestructionAlertSummaryModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return DestructionAlertOverviewModel(
      totalActiveDossiers: json['total_active_dossiers'] as int? ?? 0,
      criticalCount: json['critical_count'] as int? ?? 0,
      urgentCount: json['urgent_count'] as int? ?? 0,
      warningCount: json['warning_count'] as int? ?? 0,
      normalCount: json['normal_count'] as int? ?? 0,
      alerts: list,
    );
  }
}
