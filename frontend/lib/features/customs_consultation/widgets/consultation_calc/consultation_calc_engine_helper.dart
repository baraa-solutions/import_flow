import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../../models/customs_consultation_model.dart';
import '../../utils/customs_estimate_payload_builder.dart';

/// Calculation engine, valuation aggregation, and compliance sync helpers.
class ConsultationCalcEngineHelper {
  /// Builds a deterministic cache key for duty estimations.
  static String buildEstimateCacheKey({
    required int? selectedImportFileId,
    required int? selectedPoId,
    required String customsCurrency,
    required String exchangeRateText,
    required String freightForeignText,
    required String freightCurrency,
    required String freightExchangeRateText,
    required String freightEgpText,
    required String insuranceOption,
    required String insuranceEgpText,
    required DateTime studyDate,
  }) {
    return '$selectedImportFileId|$selectedPoId|$customsCurrency|'
        '${exchangeRateText.trim()}|'
        '${freightForeignText.trim()}|$freightCurrency|'
        '${freightExchangeRateText.trim()}|'
        '${freightEgpText.trim()}|$insuranceOption|'
        '${insuranceEgpText.trim()}|'
        '${studyDate.year}-${studyDate.month}-${studyDate.day}';
  }

  /// Calculates line items from matching PO lines and applies tariffs.
  static List<CustomsItemCalcRow> calculateCustomsLines({
    required WidgetRef ref,
    required int? selectedImportFileId,
    required int? selectedPoId,
    required String estimateCacheKey,
    required List<CustomsItemCalcRow> engineCalculatedLines,
    required String? currentEstimateCacheKey,
    required double? exchangeRate,
  }) {
    final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final tariffsList = ref.watch(customsTariffProvider).valueOrNull ?? [];

    List<PurchaseOrderModel> matchingPOs = [];
    if (selectedImportFileId != null) {
      final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
      final file = importFiles
          .where((f) => f.importFileId == selectedImportFileId)
          .firstOrNull;
      if (file != null) {
        matchingPOs = allPOs
            .where((p) =>
                (p.importFileId != null &&
                    p.importFileId == file.importFileId) ||
                (file.importFileCode.isNotEmpty &&
                    p.importFileCode != null &&
                    p.importFileCode == file.importFileCode) ||
                (file.poIds != null &&
                    p.poId != null &&
                    file.poIds!.contains(p.poId)))
            .toList();
      }
    } else if (selectedPoId != null) {
      matchingPOs = allPOs.where((p) => p.poId == selectedPoId).toList();
    }

    final List<POLineItemModel> allPoLines = [];
    String? defaultOriginCountry;
    for (final po in matchingPOs) {
      if (defaultOriginCountry == null &&
          po.countryOfOrigin != null &&
          po.countryOfOrigin!.trim().isNotEmpty) {
        defaultOriginCountry = po.countryOfOrigin!.trim();
      }
      for (final item in po.items) {
        allPoLines.add(item);
      }
    }

    if (allPoLines.isEmpty) return [];

    if (engineCalculatedLines.isNotEmpty &&
        currentEstimateCacheKey == estimateCacheKey) {
      return engineCalculatedLines;
    }

    return CustomsEstimatePayloadBuilder.mapEngineResponseToCalcRows(
      engineResponse: {},
      allLines: allPoLines,
      tariffs: tariffsList,
      defaultOriginCountry: defaultOriginCountry,
      exchangeRate: exchangeRate,
    );
  }

  /// Groups customs line items by HS Code when grouping is enabled.
  static List<CustomsItemCalcRow> getAggregatedCustomsLines(
    List<CustomsItemCalcRow> rawLines, {
    required bool groupByHsCode,
  }) {
    if (!groupByHsCode) return rawLines;

    final Map<String, List<CustomsItemCalcRow>> grouped = {};
    for (final line in rawLines) {
      grouped.putIfAbsent(line.hsCode, () => []).add(line);
    }

    final List<CustomsItemCalcRow> aggregated = [];
    for (final entry in grouped.entries) {
      final hs = entry.key;
      final lines = entry.value;
      if (lines.length == 1) {
        aggregated.add(lines.first);
        continue;
      }

      final distinctDescriptions =
          lines.map((l) => l.description.trim()).toSet().toList();
      final String mergedDesc = distinctDescriptions.length == 1
          ? distinctDescriptions.first
          : distinctDescriptions.join(' • ');

      final double totalQty = lines.fold(0.0, (s, l) => s + l.qty);
      final String unit = lines.first.unit;
      final double totalForeignPrice =
          lines.fold(0.0, (s, l) => s + l.foreignPrice);
      final double totalFobEgp = lines.fold(0.0, (s, l) => s + l.fobEgp);
      final double totalFreightEgp =
          lines.fold(0.0, (s, l) => s + l.freightEgp);
      final double totalInsuranceEgp =
          lines.fold(0.0, (s, l) => s + l.insuranceEgp);
      final double totalCifEgp = lines.fold(0.0, (s, l) => s + l.cifEgp);

      final first = lines.first;
      final double totalDutyAmountEgp =
          lines.fold(0.0, (s, l) => s + l.dutyAmountEgp);
      final double totalVatBaseEgp =
          lines.fold(0.0, (s, l) => s + l.vatBaseEgp);
      final double totalVatAmountEgp =
          lines.fold(0.0, (s, l) => s + l.vatAmountEgp);
      final double totalScheduleTaxAmountEgp =
          lines.fold(0.0, (s, l) => s + l.scheduleTaxAmountEgp);
      final double totalDevFeeAmountEgp =
          lines.fold(0.0, (s, l) => s + l.developmentFeeAmountEgp);
      final double totalSvcAmountEgp =
          lines.fold(0.0, (s, l) => s + l.customsServiceFeeAmountEgp);
      final double totalTaxes =
          lines.fold(0.0, (s, l) => s + l.totalTaxesAndDutiesEgp);

      final distinctOrigins = lines
          .map((l) => l.countryOfOrigin)
          .where((o) => o != null && o.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      aggregated.add(CustomsItemCalcRow(
        hsCode: hs,
        description: mergedDesc,
        qty: totalQty,
        unit: unit,
        foreignPrice: totalForeignPrice,
        fobEgp: totalFobEgp,
        freightEgp: totalFreightEgp,
        insuranceEgp: totalInsuranceEgp,
        cifEgp: totalCifEgp,
        dutyRate: first.dutyRate,
        baseDutyRate: first.baseDutyRate,
        dutyAmountEgp: totalDutyAmountEgp,
        vatRate: first.vatRate,
        vatBaseEgp: totalVatBaseEgp,
        vatAmountEgp: totalVatAmountEgp,
        scheduleTaxRate: first.scheduleTaxRate,
        scheduleTaxAmountEgp: totalScheduleTaxAmountEgp,
        developmentFeeRate: first.developmentFeeRate,
        developmentFeeAmountEgp: totalDevFeeAmountEgp,
        customsServiceFeeRate: first.customsServiceFeeRate,
        customsServiceFeeAmountEgp: totalSvcAmountEgp,
        totalTaxesAndDutiesEgp: totalTaxes,
        requiresCoo: lines.any((l) => l.requiresCoo),
        requiresInspection: lines.any((l) => l.requiresInspection),
        requiresAcid: lines.any((l) => l.requiresAcid),
        regulatoryAuthority: first.regulatoryAuthority,
        priorApprovalNote: first.priorApprovalNote,
        countryOfOrigin:
            distinctOrigins.isNotEmpty ? distinctOrigins.join(' / ') : null,
        appliedAgreementName: first.appliedAgreementName,
        hasExemption: lines.any((l) => l.hasExemption),
        exemptionConditionsNote: first.exemptionConditionsNote,
        requiredDocument: first.requiredDocument,
        isTariffMissing: lines.any((l) => l.isTariffMissing),
        status:
            lines.any((l) => l.isTariffMissing) ? 'TARIFF_MISSING' : first.status,
      ));
    }
    return aggregated;
  }

  /// Automatically fetches the highest ocean freight quote from linked shipping sessions.
  static void autoFetchFreightFromScenarios({
    required BuildContext context,
    required WidgetRef ref,
    required int fileId,
    required TextEditingController exchangeRateController,
    required void Function({
      required String foreignAmount,
      required String currency,
      required String fxRate,
      required String freightEgp,
    }) onApplied,
  }) {
    final allSessions = ref.read(shippingScenariosProvider).sessions;
    final linkedSessions =
        allSessions.where((s) => s.importFileId == fileId).toList();
    if (linkedSessions.isEmpty) return;

    double highestQuotation = 0.0;
    String highestCurrency = 'USD';
    for (final session in linkedSessions) {
      for (final item in session.items) {
        final amount = item.totalQuotationAmount;
        final currency = item.quotationCurrency;
        if (amount != null && currency != null && amount > highestQuotation) {
          highestQuotation = amount;
          highestCurrency = currency;
        }
      }
    }
    if (highestQuotation <= 0) return;

    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final matchedCurrency =
        currencies.where((c) => c.currencyCode == highestCurrency).firstOrNull;
    final rate = matchedCurrency?.latestCustomsRate ??
        double.tryParse(exchangeRateController.text);
    if (rate == null || rate <= 0) return;
    final freightEgp = highestQuotation * rate;

    onApplied(
      foreignAmount: highestQuotation.toStringAsFixed(2),
      currency: highestCurrency,
      fxRate: rate.toStringAsFixed(4),
      freightEgp: freightEgp.toStringAsFixed(2),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.freightAutoFetchedDetailsToast(
            highestQuotation.toStringAsFixed(2),
            highestCurrency,
            rate.toStringAsFixed(4),
            freightEgp.toStringAsFixed(2),
          ),
          severity: AppSeverity.info,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Synchronizes detected regulatory requirements from HS codes into the checklist.
  static void syncHsRequirementsToChecklist({
    required BuildContext context,
    required List<CustomsItemCalcRow> calcLines,
    required List<CustomsChecklistItemModel> checklist,
    required TextEditingController estimatedDutiesController,
    bool silent = false,
  }) {
    if (calcLines.isEmpty) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.noPoItemsFoundForFileToast,
            severity: AppSeverity.warning,
          ),
        );
      }
      return;
    }

    final validLines = calcLines.where((l) => !l.isTariffMissing).toList();
    final acidHsCodes =
        validLines.where((l) => l.requiresAcid).map((l) => l.hsCode).toSet().toList();
    final cooHsCodes =
        validLines.where((l) => l.requiresCoo).map((l) => l.hsCode).toSet().toList();
    final goeicHsCodes = validLines
        .where((l) => l.requiresInspection)
        .map((l) => l.hsCode)
        .toSet()
        .toList();

    final Map<String, Set<String>> authHsMap = {};
    for (final line in validLines) {
      if (line.regulatoryAuthority != null &&
          line.regulatoryAuthority!.trim().isNotEmpty) {
        authHsMap
            .putIfAbsent(line.regulatoryAuthority!, () => <String>{})
            .add(line.hsCode);
      }
    }

    int addedCount = 0;

    String formatHsCodeList(List<String> list) {
      if (list.isEmpty) return '';
      if (list.length <= 2) return list.join(' | ');
      return '${list.take(2).join(" | ")} (+${list.length - 2})';
    }

    if (acidHsCodes.isNotEmpty) {
      const docName = 'Advance ACID Filing (Nafeza / CargoX)';
      final hasExisting = checklist.any((c) => c.documentType.contains('ACID'));
      if (!hasExisting) {
        checklist.add(CustomsChecklistItemModel(
          documentType: docName,
          hsCode: formatHsCodeList(acidHsCodes),
          isRequired: true,
          isBlockingShipment: true,
          responsibleParty: 'Importer Team',
          regulatoryAgency: 'Nafeza / CargoX',
          status: 'Approved',
          remarks:
              'يشمل بنود: ${acidHsCodes.join(" ، ")} — رقم القيد الجمركي المبدئي إلزامي لإصدار بوليصة الشحن.',
        ));
        addedCount++;
      }
    }

    if (cooHsCodes.isNotEmpty) {
      const docName = 'Certificate of Origin (COO)';
      final hasExisting = checklist.any((c) =>
          c.documentType.contains('COO') || c.documentType.contains('شهادة المنشأ'));
      if (!hasExisting) {
        checklist.add(CustomsChecklistItemModel(
          documentType: docName,
          hsCode: formatHsCodeList(cooHsCodes),
          isRequired: true,
          isBlockingShipment: true,
          responsibleParty: 'Supplier / Exporter',
          regulatoryAgency: 'Chamber of Commerce / Embassy',
          status: 'Pending',
          remarks:
              'يشمل بنود: ${cooHsCodes.join(" ، ")} — شهادة منشأ واحدة لكامل الشحنة، تصدر من الغرفة التجارية وتُوثق بالسفارة المصرية.',
        ));
        addedCount++;
      }
    }

    if (goeicHsCodes.isNotEmpty) {
      const docName = 'GOEIC Inspection';
      final hasExisting = checklist.any((c) =>
          c.documentType.contains('GOEIC') ||
          c.documentType.contains('الصادرات والواردات'));
      if (!hasExisting) {
        checklist.add(CustomsChecklistItemModel(
          documentType: docName,
          hsCode: formatHsCodeList(goeicHsCodes),
          isRequired: true,
          isBlockingShipment: true,
          responsibleParty: 'Customs Broker',
          regulatoryAgency: 'GOEIC',
          status: 'Pending',
          remarks:
              'يشمل بنود: ${goeicHsCodes.join(" ، ")} — فحص ظاهري وسحب عينات معمل لكامل الشحنة.',
        ));
        addedCount++;
      }
    }

    for (final entry in authHsMap.entries) {
      final authority = entry.key;
      final hsList = entry.value.toList();
      final docName = 'Prior Technical Approval from $authority';
      final hasExisting = checklist.any((c) =>
          c.documentType == docName ||
          c.documentType == 'موافقة $authority الفنية المسبقة');
      if (!hasExisting) {
        final priorNote = calcLines
            .where((l) => l.regulatoryAuthority == authority)
            .map((l) => l.priorApprovalNote)
            .where((n) => n != null)
            .firstOrNull;
        checklist.add(CustomsChecklistItemModel(
          documentType: docName,
          hsCode: formatHsCodeList(hsList),
          isRequired: true,
          isBlockingShipment: true,
          responsibleParty: 'Importer Team',
          regulatoryAgency: authority,
          status: 'Pending',
          remarks:
              'يشمل بنود: ${hsList.join(" ، ")} — ${priorNote ?? "يتطلب موافقة فنية مسبقة واستخراج تصريح الإفراج الجمركي."}',
        ));
        addedCount++;
      }
    }

    final grandTotal =
        calcLines.fold(0.0, (s, l) => s + l.totalTaxesAndDutiesEgp);
    estimatedDutiesController.text = grandTotal.toStringAsFixed(2);

    if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.hsRequirementsSyncedToast(calcLines.length, addedCount),
          severity: AppSeverity.success,
        ),
      );
    }
  }
}
