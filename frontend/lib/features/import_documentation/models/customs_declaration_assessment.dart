import '../../../core/localization/app_localizations.dart';
import '../../currencies/models/currency_model.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../import_files/models/import_file_model.dart';
import '../services/customs_declaration46_calculator.dart';

class CustomsDeclarationAssessment {
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
  final double? fobForeign;
  final String currency;
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
  final bool hasExemption;
  final String exemptionTitle;
  final String registrationDate;
  final String status;

  /// Missing inputs (`tariff`, `fx_rate`, `fob`); empty when fully computed.
  final List<String> missing;

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
  });

  bool get isComplete => missing.isEmpty;
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
      final linkedBooking = cachedBookings.where((b) => b.importFileId == fileId).firstOrNull;
      if (linkedBooking != null) {
        blVal = linkedBooking.bookingConfirmationNo ?? linkedBooking.bookingCode;
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
    );
  }
}
