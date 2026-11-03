import '../../../core/localization/app_localizations.dart';
import '../../currencies/models/currency_model.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../freight_booking/models/freight_booking_model.dart';
import '../../import_files/models/import_file_model.dart';
import '../services/customs_declaration46_calculator.dart';

/// Assessment variance severity level between comparison columns.
///
/// Thresholds:
/// - Safe / Normal: `< 2.0%`
/// - Warning: `2.0% - 10.0%`
/// - Danger: `> 10.0%`
enum AssessmentVarianceSeverity {
  safe,
  warning,
  danger;

  String get labelAr {
    switch (this) {
      case AssessmentVarianceSeverity.safe:
        return 'آمن / عادي';
      case AssessmentVarianceSeverity.warning:
        return 'تحذيري';
      case AssessmentVarianceSeverity.danger:
        return 'خطر';
    }
  }

  String get labelEn {
    switch (this) {
      case AssessmentVarianceSeverity.safe:
        return 'Safe';
      case AssessmentVarianceSeverity.warning:
        return 'Warning';
      case AssessmentVarianceSeverity.danger:
        return 'Danger';
    }
  }
}

/// Structured result of a 2-point variance calculation (delta, percentage, severity).
class AssessmentVarianceResult {
  final double? baseValue;
  final double? compareValue;
  final double? difference;
  final double? percentage;
  final AssessmentVarianceSeverity severity;

  const AssessmentVarianceResult({
    required this.baseValue,
    required this.compareValue,
    required this.difference,
    required this.percentage,
    required this.severity,
  });

  bool get hasVariance => difference != null && difference != 0.0;
  bool get isSafe => severity == AssessmentVarianceSeverity.safe;
  bool get isWarning => severity == AssessmentVarianceSeverity.warning;
  bool get isDanger => severity == AssessmentVarianceSeverity.danger;
}

/// Customs Declaration Assessment with full 3-column comparison support:
/// - Column A: Initial Study Estimate (بيانات الدراسة الأصلية)
/// - Column B: Revised Estimate with Booking Freight & Rates (بيانات التقدير المحدّث)
/// - Column C: Actual Nafeza Claim Figures (بيانات نافذة الفعلية)
class CustomsDeclarationAssessment {
  // --- Common & Header Metadata ---
  final String declarationNo;
  final String importFileCode;
  final String primaryNameWithCode;
  final String supplierName;
  final String companyName;
  final String acidNumber;
  final String form4Number;
  final String blNumber;
  final String hsCode;
  final String hsDescription;
  final String currency;
  final bool hasExemption;
  final String exemptionTitle;
  final String registrationDate;
  final String status;
  final List<String> missing;

  // --- Column A: Initial Study Assessment (بيانات الدراسة الأصلية) ---
  final double? fobForeign;
  final double? exchangeRate;
  final double? fobEgp;
  final double? freightEgp;
  final double? insuranceEgp;
  final double? cifEgp;
  final double? dutyRate;
  final double? importDutyEgp;
  final double? devRate;
  final double? devFeeEgp;
  final double? serviceRate;
  final double? serviceFeeEgp;
  final double? otherFeesEgp;
  final double? vatRate;
  final double? scheduleTaxEgp;
  final double? importFeeEgp;
  final double? vatBaseEgp;
  final double? vatEgp;
  final double? totalDutiesEgp;

  // --- Column B: Revised Figures (بيانات التقدير المحدّث) ---
  final double? revisedExchangeRate;
  final double? revisedFreightUsd;
  final double? revisedFreightEgp;
  final double? revisedInsuranceEgp;
  final double? revisedUnloadingEgp;
  final double? revisedDutyRate;
  final double? revisedExtraFeesEgp;
  final double? revisedCifEgp;
  final double? revisedImportDutyEgp;
  final double? revisedVatEgp;
  final double? revisedDevFeeEgp; // أ.ت.ص (1%)
  final double? revisedTotalDutiesEgp;
  final String? revisedEstimateDate;
  final String? revisedEstimateNotes;

  // --- Column C: Actual Nafeza Figures (بيانات نافذة الفعلية) ---
  final double? actualDutyTotal;
  final double? actualCifEgp;
  final double? actualExchangeRate;
  final String? nafezaClaimNumber;
  final String? nafezaClaimDate;
  final String? dutyVarianceReason;

  const CustomsDeclarationAssessment({
    required this.declarationNo,
    required this.importFileCode,
    required this.primaryNameWithCode,
    required this.supplierName,
    required this.companyName,
    required this.acidNumber,
    required this.form4Number,
    required this.blNumber,
    required this.hsCode,
    required this.hsDescription,
    this.fobForeign,
    required this.currency,
    this.exchangeRate,
    this.fobEgp,
    this.freightEgp,
    this.insuranceEgp,
    this.cifEgp,
    this.dutyRate,
    this.importDutyEgp,
    this.devRate,
    this.devFeeEgp,
    this.serviceRate,
    this.serviceFeeEgp,
    this.otherFeesEgp,
    this.vatRate,
    this.scheduleTaxEgp,
    this.importFeeEgp,
    this.vatBaseEgp,
    this.vatEgp,
    this.totalDutiesEgp,
    required this.hasExemption,
    required this.exemptionTitle,
    required this.registrationDate,
    required this.status,
    this.missing = const [],
    // Column B
    this.revisedExchangeRate,
    this.revisedFreightUsd,
    this.revisedFreightEgp,
    this.revisedInsuranceEgp,
    this.revisedUnloadingEgp,
    this.revisedDutyRate,
    this.revisedExtraFeesEgp,
    this.revisedCifEgp,
    this.revisedImportDutyEgp,
    this.revisedVatEgp,
    this.revisedDevFeeEgp,
    this.revisedTotalDutiesEgp,
    this.revisedEstimateDate,
    this.revisedEstimateNotes,
    // Column C
    this.actualDutyTotal,
    this.actualCifEgp,
    this.actualExchangeRate,
    this.nafezaClaimNumber,
    this.nafezaClaimDate,
    this.dutyVarianceReason,
  });

  bool get isComplete => missing.isEmpty;

  // --- Column A Aliases ---
  double? get originalTotalDutiesEgp => totalDutiesEgp;
  double? get originalCifEgp => cifEgp;
  double? get originalExchangeRate => exchangeRate;
  double? get originalDutyRate => dutyRate;
  double? get revisedAtsEgp => revisedDevFeeEgp;

  // --- Core Calculation & Evaluation Methods ---

  /// Evaluates severity based on percentage variance absolute value:
  /// - `< 2.0%` -> Safe / Normal (آمن / عادي)
  /// - `2.0% - 10.0%` -> Warning (تحذيري)
  /// - `> 10.0%` -> Danger (خطر)
  static AssessmentVarianceSeverity evaluateVarianceSeverity(double? percent) {
    if (percent == null) return AssessmentVarianceSeverity.safe;
    final absVal = percent.abs();
    if (absVal < 2.0) {
      return AssessmentVarianceSeverity.safe;
    } else if (absVal <= 10.0) {
      return AssessmentVarianceSeverity.warning;
    } else {
      return AssessmentVarianceSeverity.danger;
    }
  }

  /// Calculates the difference, percentage change, and severity between [compareValue] and [baseValue].
  static AssessmentVarianceResult calculateVariance(double? compareValue, double? baseValue) {
    if (baseValue == null || compareValue == null) {
      return const AssessmentVarianceResult(
        baseValue: null,
        compareValue: null,
        difference: null,
        percentage: null,
        severity: AssessmentVarianceSeverity.safe,
      );
    }
    final diff = ((compareValue - baseValue) * 100).roundToDouble() / 100;
    final pct = baseValue != 0.0
        ? (((compareValue - baseValue) / baseValue) * 10000).roundToDouble() / 100
        : 0.0;
    return AssessmentVarianceResult(
      baseValue: baseValue,
      compareValue: compareValue,
      difference: diff,
      percentage: pct,
      severity: evaluateVarianceSeverity(pct),
    );
  }

  // --- Total Duties Comparison (B vs A, C vs A, C vs B) ---
  AssessmentVarianceResult get dutyVarianceBvsA => calculateVariance(revisedTotalDutiesEgp, totalDutiesEgp);
  AssessmentVarianceResult get dutyVarianceCvsA => calculateVariance(actualDutyTotal, totalDutiesEgp);
  AssessmentVarianceResult get dutyVarianceCvsB => calculateVariance(actualDutyTotal, revisedTotalDutiesEgp);

  double? get dutyDiffBvsA => dutyVarianceBvsA.difference;
  double? get dutyDiffPctBvsA => dutyVarianceBvsA.percentage;
  AssessmentVarianceSeverity get dutyVarianceLevelBvsA => dutyVarianceBvsA.severity;

  double? get dutyDiffCvsA => dutyVarianceCvsA.difference;
  double? get dutyDiffPctCvsA => dutyVarianceCvsA.percentage;
  AssessmentVarianceSeverity get dutyVarianceLevelCvsA => dutyVarianceCvsA.severity;

  double? get dutyDiffCvsB => dutyVarianceCvsB.difference;
  double? get dutyDiffPctCvsB => dutyVarianceCvsB.percentage;
  AssessmentVarianceSeverity get dutyVarianceLevelCvsB => dutyVarianceCvsB.severity;

  // --- CIF Comparison (B vs A, C vs A, C vs B) ---
  AssessmentVarianceResult get cifVarianceBvsA => calculateVariance(revisedCifEgp, cifEgp);
  AssessmentVarianceResult get cifVarianceCvsA => calculateVariance(actualCifEgp, cifEgp);
  AssessmentVarianceResult get cifVarianceCvsB => calculateVariance(actualCifEgp, revisedCifEgp);

  double? get cifDiffBvsA => cifVarianceBvsA.difference;
  double? get cifDiffPctBvsA => cifVarianceBvsA.percentage;
  AssessmentVarianceSeverity get cifVarianceLevelBvsA => cifVarianceBvsA.severity;

  double? get cifDiffCvsA => cifVarianceCvsA.difference;
  double? get cifDiffPctCvsA => cifVarianceCvsA.percentage;
  AssessmentVarianceSeverity get cifVarianceLevelCvsA => cifVarianceCvsA.severity;

  double? get cifDiffCvsB => cifVarianceCvsB.difference;
  double? get cifDiffPctCvsB => cifVarianceCvsB.percentage;
  AssessmentVarianceSeverity get cifVarianceLevelCvsB => cifVarianceCvsB.severity;

  // --- Exchange Rate Comparison (B vs A, C vs A, C vs B) ---
  AssessmentVarianceResult get fxVarianceBvsA => calculateVariance(revisedExchangeRate, exchangeRate);
  AssessmentVarianceResult get fxVarianceCvsA => calculateVariance(actualExchangeRate, exchangeRate);
  AssessmentVarianceResult get fxVarianceCvsB => calculateVariance(actualExchangeRate, revisedExchangeRate);

  double? get fxDiffBvsA => fxVarianceBvsA.difference;
  double? get fxDiffPctBvsA => fxVarianceBvsA.percentage;
  AssessmentVarianceSeverity get fxVarianceLevelBvsA => fxVarianceBvsA.severity;

  double? get fxDiffCvsA => fxVarianceCvsA.difference;
  double? get fxDiffPctCvsA => fxVarianceCvsA.percentage;
  AssessmentVarianceSeverity get fxVarianceLevelCvsA => fxVarianceCvsA.severity;

  double? get fxDiffCvsB => fxVarianceCvsB.difference;
  double? get fxDiffPctCvsB => fxVarianceCvsB.percentage;
  AssessmentVarianceSeverity get fxVarianceLevelCvsB => fxVarianceCvsB.severity;

  /// Copy with updated values across any column.
  CustomsDeclarationAssessment copyWith({
    String? declarationNo,
    String? importFileCode,
    String? primaryNameWithCode,
    String? supplierName,
    String? companyName,
    String? acidNumber,
    String? form4Number,
    String? blNumber,
    String? hsCode,
    String? hsDescription,
    double? fobForeign,
    String? currency,
    double? exchangeRate,
    double? fobEgp,
    double? freightEgp,
    double? insuranceEgp,
    double? cifEgp,
    double? dutyRate,
    double? importDutyEgp,
    double? devRate,
    double? devFeeEgp,
    double? serviceRate,
    double? serviceFeeEgp,
    double? otherFeesEgp,
    double? vatRate,
    double? scheduleTaxEgp,
    double? importFeeEgp,
    double? vatBaseEgp,
    double? vatEgp,
    double? totalDutiesEgp,
    bool? hasExemption,
    String? exemptionTitle,
    String? registrationDate,
    String? status,
    List<String>? missing,
    // Column B
    double? revisedExchangeRate,
    double? revisedFreightUsd,
    double? revisedFreightEgp,
    double? revisedInsuranceEgp,
    double? revisedUnloadingEgp,
    double? revisedDutyRate,
    double? revisedExtraFeesEgp,
    double? revisedCifEgp,
    double? revisedImportDutyEgp,
    double? revisedVatEgp,
    double? revisedDevFeeEgp,
    double? revisedTotalDutiesEgp,
    String? revisedEstimateDate,
    String? revisedEstimateNotes,
    // Column C
    double? actualDutyTotal,
    double? actualCifEgp,
    double? actualExchangeRate,
    String? nafezaClaimNumber,
    String? nafezaClaimDate,
    String? dutyVarianceReason,
  }) {
    return CustomsDeclarationAssessment(
      declarationNo: declarationNo ?? this.declarationNo,
      importFileCode: importFileCode ?? this.importFileCode,
      primaryNameWithCode: primaryNameWithCode ?? this.primaryNameWithCode,
      supplierName: supplierName ?? this.supplierName,
      companyName: companyName ?? this.companyName,
      acidNumber: acidNumber ?? this.acidNumber,
      form4Number: form4Number ?? this.form4Number,
      blNumber: blNumber ?? this.blNumber,
      hsCode: hsCode ?? this.hsCode,
      hsDescription: hsDescription ?? this.hsDescription,
      fobForeign: fobForeign ?? this.fobForeign,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      fobEgp: fobEgp ?? this.fobEgp,
      freightEgp: freightEgp ?? this.freightEgp,
      insuranceEgp: insuranceEgp ?? this.insuranceEgp,
      cifEgp: cifEgp ?? this.cifEgp,
      dutyRate: dutyRate ?? this.dutyRate,
      importDutyEgp: importDutyEgp ?? this.importDutyEgp,
      devRate: devRate ?? this.devRate,
      devFeeEgp: devFeeEgp ?? this.devFeeEgp,
      serviceRate: serviceRate ?? this.serviceRate,
      serviceFeeEgp: serviceFeeEgp ?? this.serviceFeeEgp,
      otherFeesEgp: otherFeesEgp ?? this.otherFeesEgp,
      vatRate: vatRate ?? this.vatRate,
      scheduleTaxEgp: scheduleTaxEgp ?? this.scheduleTaxEgp,
      importFeeEgp: importFeeEgp ?? this.importFeeEgp,
      vatBaseEgp: vatBaseEgp ?? this.vatBaseEgp,
      vatEgp: vatEgp ?? this.vatEgp,
      totalDutiesEgp: totalDutiesEgp ?? this.totalDutiesEgp,
      hasExemption: hasExemption ?? this.hasExemption,
      exemptionTitle: exemptionTitle ?? this.exemptionTitle,
      registrationDate: registrationDate ?? this.registrationDate,
      status: status ?? this.status,
      missing: missing ?? this.missing,
      // Column B
      revisedExchangeRate: revisedExchangeRate ?? this.revisedExchangeRate,
      revisedFreightUsd: revisedFreightUsd ?? this.revisedFreightUsd,
      revisedFreightEgp: revisedFreightEgp ?? this.revisedFreightEgp,
      revisedInsuranceEgp: revisedInsuranceEgp ?? this.revisedInsuranceEgp,
      revisedUnloadingEgp: revisedUnloadingEgp ?? this.revisedUnloadingEgp,
      revisedDutyRate: revisedDutyRate ?? this.revisedDutyRate,
      revisedExtraFeesEgp: revisedExtraFeesEgp ?? this.revisedExtraFeesEgp,
      revisedCifEgp: revisedCifEgp ?? this.revisedCifEgp,
      revisedImportDutyEgp: revisedImportDutyEgp ?? this.revisedImportDutyEgp,
      revisedVatEgp: revisedVatEgp ?? this.revisedVatEgp,
      revisedDevFeeEgp: revisedDevFeeEgp ?? this.revisedDevFeeEgp,
      revisedTotalDutiesEgp: revisedTotalDutiesEgp ?? this.revisedTotalDutiesEgp,
      revisedEstimateDate: revisedEstimateDate ?? this.revisedEstimateDate,
      revisedEstimateNotes: revisedEstimateNotes ?? this.revisedEstimateNotes,
      // Column C
      actualDutyTotal: actualDutyTotal ?? this.actualDutyTotal,
      actualCifEgp: actualCifEgp ?? this.actualCifEgp,
      actualExchangeRate: actualExchangeRate ?? this.actualExchangeRate,
      nafezaClaimNumber: nafezaClaimNumber ?? this.nafezaClaimNumber,
      nafezaClaimDate: nafezaClaimDate ?? this.nafezaClaimDate,
      dutyVarianceReason: dutyVarianceReason ?? this.dutyVarianceReason,
    );
  }
}

class CustomsDeclarationAssessmentHelper {
  static CustomsDeclarationAssessment calculateAssessment(
    dynamic file,
    AppLocalizations l, {
    String? declarationNo,
    String? registrationDate,
    String? status,
    List<dynamic>? cachedAcids,
    List<dynamic>? cachedBankDocs,
    List<dynamic>? cachedReviews,
    List<dynamic>? cachedBookings,
    List<CustomsTariffModel>? cachedTariffs,
    List<dynamic>? cachedPos,
    List<CurrencyModel>? cachedCurrencies,
    // Optional Column B / C overrides or bookings
    ShipmentBookingModel? linkedBooking,
    double? revisedExchangeRate,
    double? revisedFreightUsd,
    double? insuranceEgp,
    double? unloadingEgp,
    double? extraFeesEgp,
    double? actualDutyTotal,
    double? actualCifEgp,
    double? actualExchangeRate,
    String? nafezaClaimNumber,
    String? nafezaClaimDate,
    String? dutyVarianceReason,
  }) {
    final int fileId = file.importFileId;
    final String declNo = declarationNo ?? file.form46No ?? '';
    final String regDate = registrationDate ?? file.form46Date ?? '';
    final String declStatus = status ?? '';

    // 1. ACID
    String acidVal = file.acidNumber ?? '';
    if (acidVal.isEmpty && cachedAcids != null) {
      final matchedAcid = cachedAcids.where((a) => a.importFileId == fileId).firstOrNull;
      if (matchedAcid != null && matchedAcid.acidNumber.isNotEmpty) {
        acidVal = matchedAcid.acidNumber;
      }
    }

    // 2. Form 4
    String f4Val = file.form4No ?? '';
    if (f4Val.isEmpty && cachedBankDocs != null) {
      final matchedF4 = cachedBankDocs.where((d) => d.importFileId == fileId && d.docType == 'Form 4').firstOrNull;
      if (matchedF4 != null && matchedF4.docReferenceNumber != 'PENDING' && matchedF4.docReferenceNumber.isNotEmpty) {
        f4Val = matchedF4.docReferenceNumber;
      }
    }

    // 3. B/L
    String blVal = '';
    if (cachedReviews != null) {
      final linkedReview = cachedReviews.where((r) => r.importFileId == fileId).firstOrNull;
      if (linkedReview != null) {
        final extractedBl = linkedReview.draftExtractedData?['draft_bl_number'] ??
            linkedReview.draftExtractedData?['bl_number'] ??
            linkedReview.systemDataSnapshot?['draft_bl_number'] ??
            linkedReview.draftBlNumber;
        if (extractedBl != null && extractedBl.toString().trim().isNotEmpty) {
          blVal = extractedBl.toString().trim();
        }
      }
    }
    if (blVal.isEmpty && cachedBookings != null) {
      final linkedBookingItem = cachedBookings.where((b) => b.importFileId == fileId).firstOrNull;
      if (linkedBookingItem != null) {
        blVal = linkedBookingItem.bookingConfirmationNo ?? linkedBookingItem.bookingCode;
      }
    }
    if (blVal.isEmpty && file.customFileNumber != null && file.customFileNumber!.isNotEmpty) {
      blVal = file.customFileNumber!;
    }

    // 4. HS Codes and Tariffs
    final allTariffs = cachedTariffs ?? [];
    List<String> fileHsCodes = [];
    if (cachedPos != null) {
      final linkedPos = cachedPos.where((p) => p.importFileId == fileId).toList();
      for (var po in linkedPos) {
        for (var item in po.items) {
          if (item.hsCode != null && item.hsCode!.trim().isNotEmpty) {
            fileHsCodes.add(item.hsCode!.trim());
          }
        }
      }
    }
    final primaryTariff = Form46Calculator.matchTariff(fileHsCodes, allTariffs);

    final String hsCode = primaryTariff?.hsCode ?? (fileHsCodes.isNotEmpty ? fileHsCodes.first : '');
    final String hsDesc = primaryTariff?.hsDescription ?? l.customsDeclDefaultItemDesc;

    final fobRes = Form46Calculator.invoiceFob(List<InvoiceItemModel>.from(file.invoicesData as List));
    final String currency = fobRes.currency;
    final f = Form46Calculator.compute(
      fobForeign: fobRes.amount,
      fobIssue: fobRes.issue,
      customsFxRate: Form46Calculator.customsRateFor(
        currency,
        cachedCurrencies ?? [],
      ),
      tariff: primaryTariff,
    );

    // 5. Column B: Revised Figures
    ShipmentBookingModel? resolvedBooking = linkedBooking;
    if (resolvedBooking == null && cachedBookings != null) {
      final b = cachedBookings.where((x) => x.importFileId == fileId).firstOrNull;
      if (b is ShipmentBookingModel) {
        resolvedBooking = b;
      }
    }

    Form46RevisedFigures? rev;
    final effectiveRevRate = revisedExchangeRate ?? f.exchangeRate;
    if (fobRes.amount != null && effectiveRevRate != null && primaryTariff != null) {
      rev = Form46Calculator.calculateRevisedFigures(
        fobUsd: fobRes.amount,
        exchangeRate: effectiveRevRate,
        booking: resolvedBooking,
        bookingFreightUsd: revisedFreightUsd,
        insuranceEgp: insuranceEgp ?? 0.0,
        unloadingEgp: unloadingEgp ?? 0.0,
        extraFeesEgp: extraFeesEgp ?? 0.0,
        tariff: primaryTariff,
      );
    }

    final bool isEuropeanOrExempt = f.hasExemption;
    final String exemptionTitle = f.dutyRate == null
        ? ''
        : (isEuropeanOrExempt
            ? l.customsDeclEur1ExemptionTitle
            : l.customsDeclMfnExemptionTitle(f.dutyRate!.toStringAsFixed(1)));

    return CustomsDeclarationAssessment(
      declarationNo: declNo,
      importFileCode: file.importFileCode,
      primaryNameWithCode: file.primaryNameWithCode,
      supplierName: file.supplierName,
      companyName: file.companyName,
      acidNumber: acidVal,
      form4Number: f4Val,
      blNumber: blVal,
      hsCode: hsCode,
      hsDescription: hsDesc,
      fobForeign: f.fobForeign,
      currency: currency,
      exchangeRate: f.exchangeRate,
      fobEgp: f.fobEgp,
      cifEgp: f.cifEgp,
      dutyRate: f.dutyRate,
      importDutyEgp: f.importDutyEgp,
      devRate: f.devRate,
      devFeeEgp: f.devFeeEgp,
      serviceRate: f.serviceRate,
      serviceFeeEgp: f.serviceFeeEgp,
      otherFeesEgp: f.otherFeesEgp,
      vatRate: f.vatRate,
      scheduleTaxEgp: f.scheduleTaxEgp,
      importFeeEgp: f.importFeeEgp,
      vatBaseEgp: f.vatBaseEgp,
      vatEgp: f.vatEgp,
      totalDutiesEgp: f.totalDutiesEgp,
      missing: f.missing,
      hasExemption: isEuropeanOrExempt,
      exemptionTitle: exemptionTitle,
      registrationDate: regDate,
      status: declStatus,
      // Column B
      revisedExchangeRate: rev?.exchangeRate ?? revisedExchangeRate,
      revisedFreightUsd: rev?.freightUsd ?? revisedFreightUsd,
      revisedFreightEgp: rev?.freightEgp,
      revisedInsuranceEgp: rev?.insuranceEgp ?? insuranceEgp,
      revisedUnloadingEgp: rev?.unloadingEgp ?? unloadingEgp,
      revisedDutyRate: rev?.dutyRate,
      revisedExtraFeesEgp: rev?.extraFeesEgp ?? extraFeesEgp,
      revisedCifEgp: rev?.cifEgp,
      revisedImportDutyEgp: rev?.importDutyEgp,
      revisedVatEgp: rev?.vatEgp,
      revisedDevFeeEgp: rev?.devFeeEgp,
      revisedTotalDutiesEgp: rev?.totalDutiesEgp,
      revisedEstimateDate: rev?.estimateDate,
      revisedEstimateNotes: rev?.notes,
      // Column C
      actualDutyTotal: actualDutyTotal,
      actualCifEgp: actualCifEgp,
      actualExchangeRate: actualExchangeRate,
      nafezaClaimNumber: nafezaClaimNumber,
      nafezaClaimDate: nafezaClaimDate,
      dutyVarianceReason: dutyVarianceReason,
    );
  }
}
