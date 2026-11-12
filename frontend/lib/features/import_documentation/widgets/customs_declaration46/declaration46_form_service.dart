import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../../customs_tariff/models/customs_tariff_model.dart';
import '../../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../../freight_booking/providers/freight_booking_provider.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../models/customs_declaration_assessment.dart';
import '../../providers/import_documentation_provider.dart';
import '../../services/customs_declaration46_calculator.dart';

class Form46LoadedData {
  final String acidNumber;
  final String form4Number;
  final String blNumber;
  final String form46No;
  final DateTime declarationDate;
  final String? selectedOffice;
  final List<CustomsTariffModel> matchedTariffs;
  final double? appliedDutyRate;
  final List<String> figuresMissing;
  final String cifEgp;
  final String importDutyEgp;
  final String vatEgp;
  final String otherFeesEgp;
  final String totalDutiesEgp;
  final bool hasExemption;
  final List<Map<String, dynamic>> regulatoryApprovals;
  final Form46Figures? figures;

  const Form46LoadedData({
    required this.acidNumber,
    required this.form4Number,
    required this.blNumber,
    required this.form46No,
    required this.declarationDate,
    required this.selectedOffice,
    required this.matchedTariffs,
    required this.appliedDutyRate,
    required this.figuresMissing,
    required this.cifEgp,
    required this.importDutyEgp,
    required this.vatEgp,
    required this.otherFeesEgp,
    required this.totalDutiesEgp,
    required this.hasExemption,
    required this.regulatoryApprovals,
    this.figures,
  });
}

class CustomsDeclaration46FormService {
  /// Loads the form with the official customs exchange rate in force on the declaration date
  /// (Trello MzO3XGmf / H10). The rate is fetched from the backend `as_of_date` lookup; when no rate
  /// exists for that day the figures report it as missing instead of using today's rate.
  static Future<Form46LoadedData> loadForFileAtDeclarationDate(
    WidgetRef ref,
    int fileId, {
    DateTime? onDate,
  }) async {
    final draft = loadForFile(ref, fileId, onDate: onDate);
    final currency = _fobCurrency(ref, fileId);
    if (currency == null || currency.isEmpty) return draft;
    final rate = await ref
        .read(currenciesProvider.notifier)
        .fetchCustomsExchangeRate(currencyCode: currency, onDate: draft.declarationDate);
    return loadForFile(ref, fileId, onDate: draft.declarationDate, customsFxRateOverride: (value: rate));
  }

  static String? _fobCurrency(WidgetRef ref, int fileId) {
    final file = (ref.read(importFilesProvider).valueOrNull ?? []).where((f) => f.importFileId == fileId).firstOrNull;
    if (file == null) return null;
    return Form46Calculator.invoiceFob(List<InvoiceItemModel>.from(file.invoicesData as List)).currency;
  }

  /// [onDate] replaces the stored declaration date (the customs FX rate follows it).
  /// [customsFxRateOverride] carries a rate already resolved for that date; `(value: null)` means
  /// "no rate on that date" and is not replaced by the latest rate.
  static Form46LoadedData loadForFile(
    WidgetRef ref,
    int fileId, {
    DateTime? onDate,
    ({double? value})? customsFxRateOverride,
  }) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;

    if (file == null) {
      return Form46LoadedData(
        acidNumber: '',
        form4Number: '',
        blNumber: '',
        form46No: '',
        declarationDate: DateTime.now(),
        selectedOffice: null,
        matchedTariffs: [],
        appliedDutyRate: null,
        figuresMissing: const [],
        cifEgp: '0.00',
        importDutyEgp: '0.00',
        vatEgp: '0.00',
        otherFeesEgp: '0.00',
        totalDutiesEgp: '0.00',
        hasExemption: false,
        regulatoryApprovals: [],
      );
    }

    String acidVal = file.acidNumber ?? '';
    if (acidVal.isEmpty) {
      final acids = ref.read(acidSessionsProvider).valueOrNull ?? [];
      final matchedAcid = acids.where((a) => a.importFileId == fileId).firstOrNull;
      if (matchedAcid != null && matchedAcid.acidNumber.isNotEmpty) {
        acidVal = matchedAcid.acidNumber;
      }
    }

    String f4Val = file.form4No ?? '';
    if (f4Val.isEmpty) {
      final bankDocs = ref.read(bankingDocumentsProvider).valueOrNull ?? [];
      final matchedF4 = bankDocs.where((d) => d.importFileId == fileId && d.docType == 'Form 4').firstOrNull;
      if (matchedF4 != null && matchedF4.docReferenceNumber != 'PENDING' && matchedF4.docReferenceNumber.isNotEmpty) {
        f4Val = matchedF4.docReferenceNumber;
      }
    }

    String blVal = '';
    final reviews = ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    final linkedReview = reviews.where((r) => r.importFileId == fileId).firstOrNull;
    if (linkedReview != null) {
      final extractedBl = linkedReview.draftExtractedData?['draft_bl_number'] ??
          linkedReview.draftExtractedData?['bl_number'] ??
          linkedReview.systemDataSnapshot?['draft_bl_number'] ??
          linkedReview.draftBlNumber;
      if (extractedBl != null && extractedBl.toString().trim().isNotEmpty) {
        blVal = extractedBl.toString().trim();
      }
    }
    if (blVal.isEmpty) {
      final bookings = ref.read(freightBookingProvider).valueOrNull ?? [];
      final linkedBooking = bookings.where((b) => b.importFileId == fileId).firstOrNull;
      if (linkedBooking != null) {
        blVal = linkedBooking.bookingConfirmationNo ?? linkedBooking.bookingCode;
      }
    }
    if (blVal.isEmpty && file.customFileNumber != null && file.customFileNumber!.isNotEmpty) {
      blVal = file.customFileNumber!;
    }

    final declaration46No = file.form46No ?? '';
    DateTime declarationDate = DateTime.now();
    if (file.form46Date != null && file.form46Date!.isNotEmpty) {
      final parsedDate = DateTime.tryParse(file.form46Date!);
      if (parsedDate != null) declarationDate = parsedDate;
    }
    if (onDate != null) declarationDate = onDate;

    String? selectedOffice;
    if (file.portOfDischarge != null && file.portOfDischarge!.isNotEmpty) {
      final pod = file.portOfDischarge!.toLowerCase();
      if (pod.contains('dekheila') || pod.contains('دخيلة')) {
        selectedOffice = 'El Dekheila Port Customs';
      } else if (pod.contains('alex') || pod.contains('إسكندرية')) {
        selectedOffice = 'Alexandria Port Customs';
      } else if (pod.contains('said') || pod.contains('بورسعيد')) {
        selectedOffice = 'Port Said Customs';
      } else if (pod.contains('damietta') || pod.contains('دمياط')) {
        selectedOffice = 'Damietta Port Customs';
      } else if (pod.contains('sokhna') || pod.contains('سخنة')) {
        selectedOffice = 'Sokhna Port Customs';
      }
    }

    final allTariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final List<String> fileHsCodes = [];
    final poState = ref.read(purchaseOrdersProvider);
    final linkedPos = poState.purchaseOrders.where((p) => p.importFileId == fileId).toList();
    for (var po in linkedPos) {
      for (var item in po.items) {
        if (item.hsCode != null && item.hsCode!.trim().isNotEmpty) {
          fileHsCodes.add(item.hsCode!.trim());
        }
      }
    }

    // Tariff rows held by the app are the active versions only, so they are matched as of today;
    // a past version needs the backend history lookup (get_active_tariff_on_date).
    final primaryTariff = Form46Calculator.matchTariff(fileHsCodes, allTariffs);
    final matchedTariffs = Form46Calculator.matchTariffs(fileHsCodes, allTariffs);

    final fobRes = Form46Calculator.invoiceFob(List<InvoiceItemModel>.from(file.invoicesData as List));
    final figures = Form46Calculator.compute(
      fobForeign: fobRes.amount,
      fobIssue: fobRes.issue,
      customsFxRate: customsFxRateOverride != null
          ? customsFxRateOverride.value
          : Form46Calculator.customsRateFor(
              fobRes.currency,
              ref.read(currenciesProvider).valueOrNull ?? [],
            ),
      tariff: primaryTariff,
    );

    final regulatoryApprovals = matchedTariffs.map((t) => <String, dynamic>{
      'hs_code': t.hsCode,
      'description': t.hsDescription,
      'authority': t.regulatoryAuthority,
      'requires_inspection': t.requiresInspection,
      'requires_coo': t.requiresCoo,
      'requires_acid': t.requiresAcid,
      'note': t.priorApprovalNote,
    }).toList();

    return Form46LoadedData(
      acidNumber: acidVal,
      form4Number: f4Val,
      blNumber: blVal,
      form46No: declaration46No,
      declarationDate: declarationDate,
      selectedOffice: selectedOffice,
      matchedTariffs: matchedTariffs,
      appliedDutyRate: figures.dutyRate,
      figuresMissing: figures.missing,
      cifEgp: figures.cifEgp?.toStringAsFixed(2) ?? '',
      importDutyEgp: figures.importDutyEgp?.toStringAsFixed(2) ?? '',
      vatEgp: figures.vatEgp?.toStringAsFixed(2) ?? '',
      otherFeesEgp: figures.otherFeesEgp?.toStringAsFixed(2) ?? '',
      totalDutiesEgp: figures.totalDutiesEgp?.toStringAsFixed(2) ?? '',
      hasExemption: figures.hasExemption,
      regulatoryApprovals: regulatoryApprovals,
      figures: figures,
    );
  }

  static ({int? matchedFileId, Form46LoadedData data}) loadClonedAssessment(WidgetRef ref, CustomsDeclarationAssessment a) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final matchedFile = files.where((f) => f.importFileCode == a.importFileCode).firstOrNull;

    final regApprovals = (ref.read(customsTariffProvider).valueOrNull ?? [])
        .where((t) => t.hsCode == a.hsCode)
        .map((t) => <String, dynamic>{
              'hs_code': t.hsCode,
              'description': t.hsDescription,
              'authority': t.regulatoryAuthority,
              'requires_inspection': t.requiresInspection,
              'requires_coo': t.requiresCoo,
              'requires_acid': t.requiresAcid,
              'note': t.priorApprovalNote,
            })
        .toList();

    return (
      matchedFileId: matchedFile?.importFileId,
      data: Form46LoadedData(
        acidNumber: a.acidNumber,
        form4Number: a.form4Number,
        blNumber: a.blNumber,
        form46No: '46-DRAFT-${a.importFileCode}',
        declarationDate: DateTime.now(),
        selectedOffice: null,
        matchedTariffs: [],
        appliedDutyRate: a.dutyRate,
        figuresMissing: a.missing,
        cifEgp: a.cifEgp?.toStringAsFixed(2) ?? '',
        importDutyEgp: a.importDutyEgp?.toStringAsFixed(2) ?? '',
        vatEgp: a.vatEgp?.toStringAsFixed(2) ?? '',
        otherFeesEgp: a.otherFeesEgp?.toStringAsFixed(2) ?? '',
        totalDutiesEgp: a.totalDutiesEgp?.toStringAsFixed(2) ?? '',
        hasExemption: a.hasExemption,
        regulatoryApprovals: regApprovals,
        figures: Form46Figures(
          fobForeign: a.fobForeign,
          exchangeRate: a.exchangeRate,
          fobEgp: a.fobEgp,
          cifEgp: a.cifEgp,
          dutyRate: a.dutyRate,
          importDutyEgp: a.importDutyEgp,
          devRate: a.devRate,
          devFeeEgp: a.devFeeEgp,
          serviceRate: a.serviceRate,
          serviceFeeEgp: a.serviceFeeEgp,
          otherFeesEgp: a.otherFeesEgp,
          vatRate: a.vatRate,
          vatBaseEgp: a.vatBaseEgp,
          vatEgp: a.vatEgp,
          totalDutiesEgp: a.totalDutiesEgp,
          hasExemption: a.hasExemption,
          missing: a.missing,
        ),
      ),
    );
  }

  static Future<bool> saveDeclaration46({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l,
    required int importFileId,
    required String declaration46No,
    required DateTime declarationDate,
    required String customsOffice,
    required String channelType,
    required int tariffItemsCount,
    required String? notes,
    double? customsExchangeRate,
    double? importDutyAmount,
    double? vatAmount,
    double? totalDutyPayable,
    double? estimatedDutyTotal,
    double? actualDutyTotal,
    double? dutyVarianceAmount,
    double? dutyVariancePercentage,
    String? dutyVarianceReason,
    String? nafezaClaimNumber,
    DateTime? nafezaClaimDate,
  }) async {
    try {
      final payload = <String, dynamic>{
        'import_file_id': importFileId,
        'declaration_46_no': declaration46No.trim(),
        'declaration_46_date': declarationDate.toIso8601String(),
        'customs_office_name': customsOffice,
        'channel_type': channelType,
        'regulatory_bodies': <String>[],
        'mts_certificate_number': null,
        'customs_tariff_items_count': tariffItemsCount > 0 ? tariffItemsCount : 1,
        'inspection_notes': notes != null && notes.trim().isNotEmpty ? notes.trim() : null,
        if (customsExchangeRate != null) 'customs_exchange_rate': customsExchangeRate,
        if (importDutyAmount != null) 'import_duty_amount': importDutyAmount,
        if (vatAmount != null) 'vat_amount': vatAmount,
        if (totalDutyPayable != null) 'total_duty_payable': totalDutyPayable,
        if (estimatedDutyTotal != null) 'estimated_duty_total': estimatedDutyTotal,
        if (actualDutyTotal != null) 'actual_duty_total': actualDutyTotal,
        if (dutyVarianceAmount != null) 'duty_variance_amount': dutyVarianceAmount,
        if (dutyVariancePercentage != null) 'duty_variance_percentage': dutyVariancePercentage,
        if (dutyVarianceReason != null && dutyVarianceReason.trim().isNotEmpty)
          'duty_variance_reason': dutyVarianceReason.trim(),
        if (nafezaClaimNumber != null && nafezaClaimNumber.trim().isNotEmpty)
          'nafeza_claim_number': nafezaClaimNumber.trim(),
        if (nafezaClaimDate != null)
          'nafeza_claim_date': nafezaClaimDate.toIso8601String(),
      };

      await ref.read(customsClearanceProvider.notifier).registerDeclaration46(payload);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.customsDeclSaveSuccess, severity: AppSeverity.success),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.ccDecError(ApiErrorText.of(l, e)), severity: AppSeverity.danger),
        );
      }
      return false;
    }
  }

  static void copyDeclarationAsTsv({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l,
    required int? importFileId,
    required String declaration46No,
    required String submissionDate,
    required String acidNumber,
    required String form4Number,
    required String blNumber,
    required String? selectedOffice,
    required String? selectedChannel,
    required String cifTotal,
    required String dutyRate,
    required String vatRate,
    required String totalDuties,
    required bool hasExemption,
    required double? appliedDutyRate,
    required String miss,
  }) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == importFileId).firstOrNull;

    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclSubmissionDateLabel.replaceAll('*', '').trim(),
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclAcidNumberLabel,
      l.customsDeclForm4NumberLabel,
      l.customsDeclBlNumberLabel,
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclCifTotalEgpLabel,
      l.customsDeclImportDutyRateLabel,
      l.customsDeclVatRateLabel,
      l.customsDeclTotalDutiesLabel,
      l.customsDeclExemptionHeader,
    ];

    final values = [
      declaration46No,
      submissionDate,
      file?.primaryNameWithCode ?? '-',
      file?.supplierName ?? '-',
      acidNumber,
      form4Number,
      blNumber,
      selectedOffice ?? '-',
      selectedChannel ?? '-',
      cifTotal,
      dutyRate,
      vatRate,
      totalDuties,
      hasExemption ? l.customsDeclEur1ExemptionTitle : l.customsDeclMfnExemptionTitle(appliedDutyRate.fixedOrMissing(1, miss)),
    ];

    TableCopyHelper.copyRow(context, values, headers: headers);
  }
}
