import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/app_localizations_ar.dart';
import '../../../core/localization/app_localizations_en.dart';
import '../../../core/localization/domain_enum_labels.dart';

double _numToDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? fallback;
  return fallback;
}

int _numToInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? fallback;
  return fallback;
}

/// Where a tariff version stands against a given day (ministerial-decree validity window).
enum TariffValidity { active, expired, upcoming }

/// Validity-window fields for a tariff save payload (dates as yyyy-MM-dd text).
///
/// On create ([originalFrom] null) both fields are sent. On edit only the fields the user changed
/// are sent, so re-saving a form never re-sends the stored effective_from (the backend would read
/// that as "change the rates from the version's start" and history would be lost). A cleared
/// Effective To is sent as an explicit null, which reopens the version.
Map<String, dynamic> tariffValidityPayload({
  required String from,
  required String to,
  String? originalFrom,
  String? originalTo,
}) {
  final fromText = from.trim();
  final toText = to.trim();
  final toValue = toText.isEmpty ? null : toText;
  if (originalFrom == null) {
    return {'effective_from': fromText, 'effective_to': toValue};
  }
  return {
    if (fromText != originalFrom.trim()) 'effective_from': fromText,
    if (toText != (originalTo ?? '').trim()) 'effective_to': toValue,
  };
}

/// Whether a rate change on an edited tariff should move Effective From to [today]: only when the
/// version is already in force (started before today) and the user has not picked another start.
bool shouldDefaultEffectiveFromToToday({
  required bool rateChanged,
  required String currentFrom,
  required String originalFrom,
  required DateTime today,
}) {
  if (!rateChanged || currentFrom.trim() != originalFrom.trim()) return false;
  final start = DateTime.tryParse(originalFrom.trim());
  if (start == null) return false;
  return DateTime(start.year, start.month, start.day)
      .isBefore(DateTime(today.year, today.month, today.day));
}

class CustomsTariffModel {
  final int tariffId;
  final String hsCode;
  final String hsDescription;
  final String? customsCategory;

  final double customsDutyRate;
  final double vatRate;
  final double scheduleTaxRate;
  final double developmentFeeRate;
  final double importFeeRate;
  final double customsServiceFeeRate;

  final bool requiresCoo;
  final bool requiresInspection;
  final bool requiresAcid;
  final String? regulatoryAuthority;
  final String? priorApprovalNote;
  final bool hasAntiDumpingRisk;
  final String? antiDumpingNotes;

  final DateTime effectiveFrom;
  final DateTime? effectiveTo;

  final String? sourceUrl;
  final DateTime? lastVerifiedDate;
  final String? verifiedBy;
  final String? confidence;

  final String? notes;
  final bool isActive;
  final int totalVersions;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasMultiplePhases => totalVersions > 1;

  const CustomsTariffModel({
    required this.tariffId,
    required this.hsCode,
    required this.hsDescription,
    this.customsCategory,
    required this.customsDutyRate,
    required this.vatRate,
    required this.scheduleTaxRate,
    required this.developmentFeeRate,
    required this.importFeeRate,
    this.customsServiceFeeRate = 1.0,
    required this.requiresCoo,
    required this.requiresInspection,
    required this.requiresAcid,
    this.regulatoryAuthority,
    this.priorApprovalNote,
    this.hasAntiDumpingRisk = false,
    this.antiDumpingNotes,
    required this.effectiveFrom,
    this.effectiveTo,
    this.sourceUrl,
    this.lastVerifiedDate,
    this.verifiedBy,
    this.confidence,
    this.notes,
    required this.isActive,
    this.totalVersions = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomsTariffModel.fromJson(Map<String, dynamic> json) {
    return CustomsTariffModel(
      tariffId: _numToInt(json['tariff_id']),
      hsCode: json['hs_code']?.toString() ?? '',
      hsDescription: json['hs_description']?.toString() ?? '',
      customsCategory: json['customs_category']?.toString(),
      customsDutyRate: _numToDouble(json['customs_duty_rate']),
      vatRate: _numToDouble(json['vat_rate']),
      scheduleTaxRate: _numToDouble(json['schedule_tax_rate']),
      developmentFeeRate: _numToDouble(json['development_fee_rate']),
      importFeeRate: _numToDouble(json['import_fee_rate']),
      customsServiceFeeRate: _numToDouble(json['customs_service_fee_rate'], 1.0),
      requiresCoo: json['requires_coo'] as bool? ?? false,
      requiresInspection: json['requires_inspection'] as bool? ?? false,
      requiresAcid: json['requires_acid'] as bool? ?? false,
      regulatoryAuthority: json['regulatory_authority']?.toString(),
      priorApprovalNote: json['prior_approval_note']?.toString(),
      hasAntiDumpingRisk: json['has_anti_dumping_risk'] as bool? ?? false,
      antiDumpingNotes: json['anti_dumping_notes']?.toString(),
      effectiveFrom: json['effective_from'] != null
          ? DateTime.tryParse(json['effective_from'].toString()) ?? DateTime.now()
          : DateTime.now(),
      effectiveTo: json['effective_to'] != null
          ? DateTime.tryParse(json['effective_to'].toString())
          : null,
      sourceUrl: json['source_url']?.toString(),
      lastVerifiedDate: json['last_verified_date'] != null
          ? DateTime.tryParse(json['last_verified_date'].toString())
          : null,
      verifiedBy: json['verified_by']?.toString(),
      confidence: json['confidence']?.toString(),
      notes: json['notes']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      totalVersions: _numToInt(json['total_versions'], 1),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'hs_code': hsCode,
        'hs_description': hsDescription,
        'customs_category': customsCategory,
        'customs_duty_rate': customsDutyRate,
        'vat_rate': vatRate,
        'schedule_tax_rate': scheduleTaxRate,
        'development_fee_rate': developmentFeeRate,
        'import_fee_rate': importFeeRate,
        'customs_service_fee_rate': customsServiceFeeRate,
        'requires_coo': requiresCoo,
        'requires_inspection': requiresInspection,
        'requires_acid': requiresAcid,
        'regulatory_authority': regulatoryAuthority,
        'has_anti_dumping_risk': hasAntiDumpingRisk,
        if (antiDumpingNotes != null) 'anti_dumping_notes': antiDumpingNotes,
        'effective_from': effectiveFrom.toIso8601String().split('T').first,
        'effective_to': effectiveTo?.toIso8601String().split('T').first,
        'notes': notes,
      };

  /// The category in the language of [l10n] (CUSTOMS_CATEGORY code or legacy
  /// label; free legacy text is shown as stored); `null` when there is none.
  String? categoryLabel(AppLocalizations l10n) {
    final raw = customsCategory?.trim();
    if (raw == null || raw.isEmpty) return null;
    return DomainEnums.label(l10n, DomainEnumType.customsCategory, raw);
  }

  /// The category in Arabic (Arabic-only exports).
  String? get categoryLabelArabic => categoryLabel(const AppLocalizationsAr());

  /// Lower-case text a search box matches: the stored value plus both labels.
  String get categorySearchText {
    final raw = customsCategory?.trim();
    if (raw == null || raw.isEmpty) return '';
    final en = categoryLabel(const AppLocalizationsEn()) ?? '';
    final ar = categoryLabelArabic ?? '';
    return '$raw $en $ar'.toLowerCase();
  }

  /// Validity of this version on [day] (today by default). Both bounds are inclusive, as in the
  /// backend lookup `effective_from <= day <= effective_to` (a closed version ends the day before
  /// its successor starts).
  TariffValidity validityOn([DateTime? day]) {
    final d = _dateOnly(day ?? DateTime.now());
    if (_dateOnly(effectiveFrom).isAfter(d)) return TariffValidity.upcoming;
    final to = effectiveTo;
    if (to != null && _dateOnly(to).isBefore(d)) return TariffValidity.expired;
    return TariffValidity.active;
  }

  static DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
}

class CustomsDutyBreakdownModel {
  final String hsCode;
  final String hsDescription;
  final String? customsCategory;
  final DateTime estimateDate;

  final double cifValue;
  final double freight;
  final double packagingEgp;

  final double customsDutyRate;
  final double vatRate;
  final double scheduleTaxRate;
  final double developmentFeeRate;
  final double importFeeRate;
  final double customsServiceFeeRate;

  final double importDutyAmount;
  final double vatBase;
  final double vatAmount;
  final double scheduleTaxAmount;
  final double developmentFeeAmount;
  final double importFeeAmount;
  final double customsServiceFeeAmount;
  final double totalTaxesAndFees;

  final bool requiresCoo;
  final bool requiresInspection;
  final bool requiresAcid;
  final String? regulatoryAuthority;

  final String? conditionsNote;
  final Map<String, dynamic>? feeCodesBreakdown;

  const CustomsDutyBreakdownModel({
    required this.hsCode,
    required this.hsDescription,
    this.customsCategory,
    required this.estimateDate,
    required this.cifValue,
    required this.freight,
    this.packagingEgp = 0.0,
    required this.customsDutyRate,
    required this.vatRate,
    required this.scheduleTaxRate,
    required this.developmentFeeRate,
    required this.importFeeRate,
    this.customsServiceFeeRate = 1.0,
    required this.importDutyAmount,
    required this.vatBase,
    required this.vatAmount,
    required this.scheduleTaxAmount,
    required this.developmentFeeAmount,
    required this.importFeeAmount,
    this.customsServiceFeeAmount = 0.0,
    required this.totalTaxesAndFees,
    required this.requiresCoo,
    required this.requiresInspection,
    required this.requiresAcid,
    this.regulatoryAuthority,
    this.conditionsNote,
    this.feeCodesBreakdown,
  });

  factory CustomsDutyBreakdownModel.fromJson(Map<String, dynamic> json) {
    return CustomsDutyBreakdownModel(
      hsCode: json['hs_code'] as String,
      hsDescription: json['hs_description'] as String,
      customsCategory: json['customs_category'] as String?,
      estimateDate: DateTime.parse(json['estimate_date'] as String),
      cifValue: _numToDouble(json['cif_value']),
      freight: _numToDouble(json['freight']),
      packagingEgp: _numToDouble(json['packaging_egp']),
      customsDutyRate: _numToDouble(json['customs_duty_rate']),
      vatRate: _numToDouble(json['vat_rate']),
      scheduleTaxRate: _numToDouble(json['schedule_tax_rate']),
      developmentFeeRate: _numToDouble(json['development_fee_rate']),
      importFeeRate: _numToDouble(json['import_fee_rate']),
      customsServiceFeeRate: _numToDouble(json['customs_service_fee_rate'], 1.0),
      importDutyAmount: _numToDouble(json['import_duty_amount']),
      vatBase: _numToDouble(json['vat_base']),
      vatAmount: _numToDouble(json['vat_amount']),
      scheduleTaxAmount: _numToDouble(json['schedule_tax_amount']),
      developmentFeeAmount: _numToDouble(json['development_fee_amount']),
      importFeeAmount: _numToDouble(json['import_fee_amount']),
      customsServiceFeeAmount: _numToDouble(json['customs_service_fee_amount']),
      totalTaxesAndFees: _numToDouble(json['total_taxes_and_fees']),
      requiresCoo: json['requires_coo'] as bool? ?? false,
      requiresInspection: json['requires_inspection'] as bool? ?? false,
      requiresAcid: json['requires_acid'] as bool? ?? false,
      regulatoryAuthority: json['regulatory_authority'] as String?,
      conditionsNote: json['conditions_note']?.toString(),
      feeCodesBreakdown: json['fee_codes_breakdown'] is Map<String, dynamic>
          ? json['fee_codes_breakdown'] as Map<String, dynamic>
          : null,
    );
  }
}

