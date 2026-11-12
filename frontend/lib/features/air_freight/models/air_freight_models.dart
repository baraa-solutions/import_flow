import '../utils/air_weight_calculator.dart';

DateTime? _date(dynamic v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
double? _num(dynamic v) => (v as num?)?.toDouble();

String? isoDate(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Server-configured air-freight constants (system parameters).
class AirFreightSettings {
  final double airVolumetricDivisor;
  final double courierVolumetricDivisor;
  final int freeStorageDays;
  final double weightTolerancePct;

  const AirFreightSettings({
    required this.airVolumetricDivisor,
    required this.courierVolumetricDivisor,
    required this.freeStorageDays,
    required this.weightTolerancePct,
  });

  /// IATA / courier standards, used only until the server settings load.
  static const fallback = AirFreightSettings(
    airVolumetricDivisor: 6000,
    courierVolumetricDivisor: 5000,
    freeStorageDays: 3,
    weightTolerancePct: 0.5,
  );

  double divisorFor(String mode) => mode == 'COURIER' ? courierVolumetricDivisor : airVolumetricDivisor;

  factory AirFreightSettings.fromJson(Map<String, dynamic> json) => AirFreightSettings(
        airVolumetricDivisor: _num(json['air_volumetric_divisor']) ?? fallback.airVolumetricDivisor,
        courierVolumetricDivisor: _num(json['courier_volumetric_divisor']) ?? fallback.courierVolumetricDivisor,
        freeStorageDays: (json['free_storage_days'] as num?)?.toInt() ?? fallback.freeStorageDays,
        weightTolerancePct: _num(json['weight_tolerance_pct']) ?? fallback.weightTolerancePct,
      );
}

/// Airport free-storage countdown computed by the backend.
class AirStorageStatus {
  final String status; // NOT_STARTED | FREE | LAST_DAY | CHARGEABLE
  final int freeDays;
  final DateTime? freeUntil;
  final int? daysRemaining;
  final int chargeableDays;

  const AirStorageStatus({
    required this.status,
    required this.freeDays,
    this.freeUntil,
    this.daysRemaining,
    this.chargeableDays = 0,
  });

  factory AirStorageStatus.fromJson(Map<String, dynamic> json) => AirStorageStatus(
        status: json['status'] as String? ?? 'NOT_STARTED',
        freeDays: (json['free_days'] as num?)?.toInt() ?? 0,
        freeUntil: _date(json['free_until']),
        daysRemaining: (json['days_remaining'] as num?)?.toInt(),
        chargeableDays: (json['chargeable_days'] as num?)?.toInt() ?? 0,
      );
}

class AirShipmentRecord {
  final int id;
  final String code;
  final int importFileId;
  final String shipmentMode;
  final String? shipmentSubMode;
  final String? mawbNumber;
  final String? hawbNumber;
  final int? airlineId;
  final int? originAirportId;
  final int? destinationAirportId;
  final String? flightNumber;
  final DateTime? flightDate;
  final DateTime? arrivalDate;
  final int? piecesCount;
  final double? grossWeightKg;
  final double? volumeCbm;
  final double? volumetricWeightKg;
  final double? chargeableWeightKg;
  final double? volumetricDivisor;
  final List<AirPackageInput> packageLines;
  final String? airReleaseNo;
  final DateTime? airportStorageStartDate;
  final int? freeStorageDays;
  final String? goodsDescription;
  final String? notes;
  final AirStorageStatus? storage;

  const AirShipmentRecord({
    required this.id,
    required this.code,
    required this.importFileId,
    required this.shipmentMode,
    this.shipmentSubMode,
    this.mawbNumber,
    this.hawbNumber,
    this.airlineId,
    this.originAirportId,
    this.destinationAirportId,
    this.flightNumber,
    this.flightDate,
    this.arrivalDate,
    this.piecesCount,
    this.grossWeightKg,
    this.volumeCbm,
    this.volumetricWeightKg,
    this.chargeableWeightKg,
    this.volumetricDivisor,
    this.packageLines = const [],
    this.airReleaseNo,
    this.airportStorageStartDate,
    this.freeStorageDays,
    this.goodsDescription,
    this.notes,
    this.storage,
  });

  String get displayAwb => mawbNumber == null ? '-' : AwbNumber.format(mawbNumber!);

  factory AirShipmentRecord.fromJson(Map<String, dynamic> json) => AirShipmentRecord(
        id: (json['air_record_id'] as num).toInt(),
        code: json['air_record_code'] as String? ?? '',
        importFileId: (json['import_file_id'] as num?)?.toInt() ?? 0,
        shipmentMode: json['shipment_mode'] as String? ?? 'AIR',
        shipmentSubMode: json['shipment_sub_mode'] as String?,
        mawbNumber: json['mawb_number'] as String?,
        hawbNumber: json['hawb_number'] as String?,
        airlineId: (json['airline_id'] as num?)?.toInt(),
        originAirportId: (json['origin_airport_id'] as num?)?.toInt(),
        destinationAirportId: (json['destination_airport_id'] as num?)?.toInt(),
        flightNumber: json['flight_number'] as String?,
        flightDate: _date(json['flight_date']),
        arrivalDate: _date(json['arrival_date']),
        piecesCount: (json['pieces_count'] as num?)?.toInt(),
        grossWeightKg: _num(json['gross_weight_kg']),
        volumeCbm: _num(json['volume_cbm']),
        volumetricWeightKg: _num(json['volumetric_weight_kg']),
        chargeableWeightKg: _num(json['chargeable_weight_kg']),
        volumetricDivisor: _num(json['volumetric_divisor']),
        packageLines: ((json['package_lines'] as List?) ?? const [])
            .map((e) => AirPackageInput.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        airReleaseNo: json['air_release_no'] as String?,
        airportStorageStartDate: _date(json['airport_storage_start_date']),
        freeStorageDays: (json['free_storage_days'] as num?)?.toInt(),
        goodsDescription: json['goods_description'] as String?,
        notes: json['notes'] as String?,
        storage:
            json['storage'] is Map ? AirStorageStatus.fromJson((json['storage'] as Map).cast<String, dynamic>()) : null,
      );
}

class AwbChecklistItem {
  final String check;
  final String status; // MATCH | MISMATCH | MISSING | WARNING
  final bool blocking;
  final String? draftValue;
  final String? systemValue;

  const AwbChecklistItem({
    required this.check,
    required this.status,
    required this.blocking,
    this.draftValue,
    this.systemValue,
  });

  factory AwbChecklistItem.fromJson(Map<String, dynamic> json) => AwbChecklistItem(
        check: json['check'] as String? ?? '',
        status: json['status'] as String? ?? 'WARNING',
        blocking: json['blocking'] as bool? ?? false,
        draftValue: json['draft_value']?.toString(),
        systemValue: json['system_value']?.toString(),
      );
}

class DraftAwbReview {
  final int id;
  final String code;
  final int airRecordId;
  final int versionNumber;
  final String status; // REVISION_REQUIRED | REVIEWED | APPROVED | REJECTED
  final bool hasBlockingMismatch;
  final int openDiscrepanciesCount;
  final List<AwbChecklistItem> checklist;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? approvedBy;

  const DraftAwbReview({
    required this.id,
    required this.code,
    required this.airRecordId,
    required this.versionNumber,
    required this.status,
    required this.hasBlockingMismatch,
    required this.openDiscrepanciesCount,
    this.checklist = const [],
    this.reviewedAt,
    this.reviewedBy,
    this.approvedBy,
  });

  bool get isDecided => status == 'APPROVED' || status == 'REJECTED';

  factory DraftAwbReview.fromJson(Map<String, dynamic> json) => DraftAwbReview(
        id: (json['awb_review_id'] as num).toInt(),
        code: json['awb_review_code'] as String? ?? '',
        airRecordId: (json['air_record_id'] as num?)?.toInt() ?? 0,
        versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
        status: json['status'] as String? ?? 'REVIEWED',
        hasBlockingMismatch: json['has_blocking_mismatch'] as bool? ?? false,
        openDiscrepanciesCount: (json['open_discrepancies_count'] as num?)?.toInt() ?? 0,
        checklist: ((json['checklist_data'] as List?) ?? const [])
            .map((e) => AwbChecklistItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        reviewedAt: _date(json['reviewed_at']),
        reviewedBy: json['reviewed_by'] as String?,
        approvedBy: json['approved_by'] as String?,
      );
}

/// Arabic labels of the review checklist fields.
const Map<String, String> awbCheckLabelsAr = {
  'awb_number': 'رقم البوليصة الجوية',
  'consignee_name': 'المرسل إليه',
  'shipper_name': 'الشاحن',
  'origin_airport_code': 'مطار القيام',
  'destination_airport_code': 'مطار الوصول',
  'pieces_count': 'عدد الطرود',
  'gross_weight_kg': 'الوزن القائم (كجم)',
  'chargeable_weight_kg': 'الوزن المحاسب (كجم)',
  'goods_description': 'وصف البضاعة',
};

/// Sub-modes per main mode (mirror of modules/common/shipment_modes.py).
const Map<String, List<String>> airSubModes = {
  'AIR': ['GENERAL_CARGO', 'CONSOLIDATED', 'CHARTER', 'DANGEROUS_GOODS', 'PERISHABLE'],
  'COURIER': ['EXPRESS', 'POSTAL'],
};

const Map<String, String> subModeLabelsAr = {
  'GENERAL_CARGO': 'بضائع عامة',
  'CONSOLIDATED': 'مجمّع (Consolidation)',
  'CHARTER': 'طيران عارض (Charter)',
  'DANGEROUS_GOODS': 'بضائع خطرة',
  'PERISHABLE': 'بضائع قابلة للتلف',
  'EXPRESS': 'بريد سريع',
  'POSTAL': 'طرد بريدي',
};
