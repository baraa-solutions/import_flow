import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';
import 'customs_ui.dart';

/// Read-only details dialog for a [CustomsClearanceModel].
/// Displays Phase-06 and Phase-07 customs clearance information in structured read-only sections.
class ClearanceDetailsDialog extends ConsumerStatefulWidget {
  final CustomsClearanceModel? record;
  final int? recordId;

  const ClearanceDetailsDialog({
    super.key,
    this.record,
    this.recordId,
  }) : assert(record != null || recordId != null, 'Either record or recordId must be provided');

  static Future<void> show(
    BuildContext context, {
    CustomsClearanceModel? record,
    int? recordId,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ClearanceDetailsDialog(record: record, recordId: recordId),
    );
  }

  @override
  ConsumerState<ClearanceDetailsDialog> createState() => _ClearanceDetailsDialogState();
}

class _ClearanceDetailsDialogState extends ConsumerState<ClearanceDetailsDialog> {
  Future<CustomsClearanceModel>? _loadFuture;

  @override
  void initState() {
    super.initState();
    if (widget.record == null && widget.recordId != null) {
      _loadFuture = ref.read(customsClearanceProvider.notifier).getRecord(widget.recordId!);
    }
  }

  void _retry() {
    if (widget.recordId != null) {
      setState(() {
        _loadFuture = ref.read(customsClearanceProvider.notifier).getRecord(widget.recordId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.record != null) {
      return _buildDialogWithRecord(context, widget.record!);
    }

    return FutureBuilder<CustomsClearanceModel>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Dialog(
            child: SizedBox(
              height: 240,
              child: CcStateView.loading(),
            ),
          );
        }
        if (snapshot.hasError) {
          final l = context.l10n;
          return Dialog(
            child: SizedBox(
              height: 280,
              child: CcStateView.error(
                message: ApiErrorText.of(l, snapshot.error),
                actionLabel: l.retry,
                onAction: _retry,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          final l = context.l10n;
          return Dialog(
            child: SizedBox(
              height: 240,
              child: CcStateView.empty(message: l.customsClearanceEmptyRecords),
            ),
          );
        }
        return _buildDialogWithRecord(context, snapshot.data!);
      },
    );
  }

  Widget _buildDialogWithRecord(BuildContext context, CustomsClearanceModel r) {
    final l = context.l10n;
    final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final matchingFile = allFiles.where((f) => f.importFileId == r.importFileId).firstOrNull;
    final fileCode = matchingFile?.importFileCode ?? 'IMP-${r.importFileId}';
    final shipName = DisplayNameResolver.resolveShipmentNameByCode(
      fileCode,
      shipments: allFiles,
      isArabic: l.isArabic,
    );

    final status = CcUi.statusStyle(l, r.status);
    final channel = CcUi.channelStyle(l, r.channelType);

    final headerChips = [
      CcHeaderChip(Icons.tag, r.clearanceCode, ltr: true),
      CcHeaderChip(channel.icon, channel.label),
      CcHeaderChip(Icons.verified_outlined, status.label),
    ];

    void copyAllTsv() {
      final actual = CcFormat.fixed(r.effectiveDutyTotal);
      final est = CcFormat.fixed(r.estimatedDutyTotal);
      final tsv = StringBuffer();
      tsv.writeln('Code\t${r.clearanceCode}');
      tsv.writeln('Import File\t$fileCode - $shipName');
      tsv.writeln('Customs Office\t${r.customsOfficeName}');
      tsv.writeln('Channel\t${r.channelType}');
      tsv.writeln('Status\t${r.status}');
      tsv.writeln('Declaration 46\t${r.declaration46No ?? '-'}');
      tsv.writeln('Delivery Order\t${r.deliveryOrderNumber ?? '-'}');
      tsv.writeln('Broker\t${r.brokerName ?? '-'}');
      tsv.writeln('Effective Duty\t$actual');
      tsv.writeln('Estimated Duty\t$est');
      tsv.writeln('Bank Receipt\t${r.bankReceiptNo ?? '-'}');
      tsv.writeln('Release Permit\t${r.releasePermitNo ?? '-'}');

      CopyHelper.copy(
        context,
        tsv.toString(),
        customMessage: l.copyCustomsClearanceRowSuccess,
      );
    }

    return CcStageDialogShell(
      title: '${l.viewDetails} — ${r.clearanceCode}',
      icon: Icons.visibility_outlined,
      accent: AppTheme.cobalt,
      chips: headerChips,
      confirmLabel: l.close,
      confirmIcon: Icons.check,
      confirmVariant: AppButtonVariant.secondary,
      onConfirm: () => Navigator.of(context).pop(),
      isSubmitting: false,
      showCancel: false,
      maxWidth: 900,
      footerLeading: AppButton(
        label: l.copyAllData,
        icon: Icons.copy_all_outlined,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        onPressed: copyAllTsv,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Shipment & Master Data
          CcSectionCard(
            title: l.customsClearanceFileRefLabel,
            icon: Icons.inventory_2_outlined,
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _fact(l.importFiles, fileCode, mono: true),
                _fact(l.customsClearanceFileRefLabel, shipName),
                _fact(l.customsClearanceOfficeLabel, r.customsOfficeName),
                _fact(l.customsClearanceChannelLabel, channel.label),
                _fact(l.status, status.label),
                if ((r.portArrivalDate ?? '').isNotEmpty)
                  _fact(l.drawingSamplesColSamplingDate, r.portArrivalDate!),
              ],
            ),
          ),

          // Section 2: CS-01 Customs Broker Authorization
          CcSectionCard(
            title: l.ccBrkTitle,
            icon: Icons.badge_outlined,
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _fact(l.ccBrkBrokerLabel, r.brokerName ?? CcFormat.unknown),
                _fact(l.ccBrkNoLabel, r.delegationNumber ?? CcFormat.unknown, mono: true),
                _fact(l.ccBrkDateLabel, r.delegationDate ?? CcFormat.unknown),
                _fact(l.ccBrkMandateTitle, r.mandateLetterCode ?? CcFormat.unknown, mono: true),
                _fact(l.status, r.delegationStatus),
                if ((r.authorizationNotes ?? '').isNotEmpty)
                  _fact(l.notes, r.authorizationNotes!),
              ],
            ),
          ),

          // Section 3: CS-02 Delivery Order Payment
          CcSectionCard(
            title: l.ccDoTitle,
            icon: Icons.receipt_long_outlined,
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _fact(l.ccDoNumberLabel, r.deliveryOrderNumber ?? CcFormat.unknown, mono: true),
                _fact(l.ccDoDateLabel, r.deliveryOrderDate ?? CcFormat.unknown),
                _fact(l.ccDoExpiryLabel, r.deliveryOrderExpiry ?? CcFormat.unknown),
                _fact(l.ccDoFreeDaysChip, l.ccCloneDaysValue(r.freeDaysAllowed)),
                _fact(l.ccDoAgentLabel, r.shippingAgentName ?? CcFormat.unknown),
                _fact(
                  l.ccDoFeesLabel,
                  r.deliveryOrderFees != null
                      ? '${CcFormat.money(r.deliveryOrderFees)} ${r.deliveryOrderCurrency}'
                      : CcFormat.unknown,
                ),
                _fact(l.ccDoPaymentRefLabel, r.deliveryOrderPaymentRef ?? CcFormat.unknown, mono: true),
                _fact(l.ccDutyDateLabel, r.deliveryOrderPaidAt ?? CcFormat.unknown),
                _fact(l.status, r.deliveryOrderStatus),
                if ((r.deliveryOrderNotes ?? '').isNotEmpty)
                  _fact(l.notes, r.deliveryOrderNotes!),
              ],
            ),
          ),

          // Section 4: CS-03 Customs Declaration 46
          CcSectionCard(
            title: l.ccDecTitle,
            icon: Icons.description_outlined,
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _fact(l.ccDecNoLabel, r.declaration46No ?? CcFormat.unknown, mono: true),
                _fact(l.ccDecDateLabel, r.declaration46Date ?? CcFormat.unknown),
                _fact(l.ccDecMtsLabel, r.mtsCertificateNumber ?? CcFormat.unknown, mono: true),
                _fact(l.ccDecOfficeLabel, r.customsOfficeName),
                _fact(l.customsClearanceChannelLabel, channel.label),
                _fact(l.ccDecTariffLabel, '${r.customsTariffItemsCount}'),
                if (r.regulatoryBodies.isNotEmpty)
                  _fact(l.ccDecBodiesSection, r.regulatoryBodies.join(', ')),
              ],
            ),
          ),

          // Section 5: CL-02 Final Customs Duties Assessment
          CcSectionCard(
            title: l.ccAssessTitle,
            icon: Icons.calculate_outlined,
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _fact(l.ccAssessClaimNoLabel, r.nafezaClaimNumber ?? CcFormat.unknown, mono: true),
                _fact(l.ccAssessClaimDateLabel, r.nafezaClaimDate ?? CcFormat.unknown),
                _fact(l.status, r.assessmentStatus),
                _fact(l.ccAssessFxLabel, r.customsExchangeRate != null ? '${r.customsExchangeRate}' : CcFormat.unknown),
                _fact(l.ccAssessImportDuty, '${CcFormat.money(r.importDutyAmount)} ${l.egpCurrency}'),
                _fact(l.ccAssessVat, '${CcFormat.money(r.vatAmount)} ${l.egpCurrency}'),
                _fact(l.ccAssessScheduleTax, '${CcFormat.money(r.scheduleTaxAmount)} ${l.egpCurrency}'),
                _fact(l.ccAssessDevFee, '${CcFormat.money(r.developmentFeeAmount)} ${l.egpCurrency}'),
                _fact(l.ccAssessServiceFees, '${CcFormat.money(r.customsServiceFees)} ${l.egpCurrency}'),
                _fact(l.ccAssessWht, '${CcFormat.money(r.whtAmount)} ${l.egpCurrency}'),
                _fact(l.ccAssessLabFees, '${CcFormat.money(r.labServiceFees)} ${l.egpCurrency}'),
                _fact(l.customsClearanceTotalDutiesCard, '${CcFormat.money(r.effectiveDutyTotal)} ${l.egpCurrency}'),
                _fact(l.customsClearanceColEstimatedDuty, '${CcFormat.money(r.estimatedDutyTotal)} ${l.egpCurrency}'),
                _fact(
                  l.customsClearanceColDutyVariance,
                  '${CcFormat.signedMoney(r.dutyVarianceAmount)} (${CcFormat.percent(r.dutyVariancePercentage)})',
                ),
              ],
            ),
          ),

          // Section 6: CL-03 Customs Duty Payment
          CcSectionCard(
            title: l.ccDutyDialogTitle,
            icon: Icons.payments_outlined,
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _fact(l.customsClearanceColPaymentStatus, r.paymentStatus),
                _fact(l.ccDutySadadLabel, r.sadadNumber ?? CcFormat.unknown, mono: true),
                _fact(l.ccDutyBankLabel, r.payingBankName ?? CcFormat.unknown),
                _fact(l.finalDutyColBankReceipt, r.bankReceiptNo ?? CcFormat.unknown, mono: true),
                _fact(l.ccDutyDateLabel, r.paymentDate ?? CcFormat.unknown),
                _fact(l.customsClearanceColActualDuty, '${CcFormat.money(r.dutyPaidAmount)} ${l.egpCurrency}'),
                if ((r.paymentNotes ?? '').isNotEmpty)
                  _fact(l.notes, r.paymentNotes!),
              ],
            ),
          ),

          // Section 7: CL-04 Customs Final Release
          CcSectionCard(
            title: l.ccRelTitle,
            icon: Icons.assignment_turned_in_outlined,
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _fact(l.status, r.status),
                _fact(l.ccRelPermitNoLabel, r.releasePermitNo ?? CcFormat.unknown, mono: true),
                _fact(l.ccRelDateLabel, r.releaseDate ?? CcFormat.unknown),
                _fact(l.ccRelOfficerLabel, r.releaseOfficerName ?? CcFormat.unknown),
                _fact(l.ccRelGatePassLabel, r.gatePassNumber ?? CcFormat.unknown, mono: true),
                _fact(l.ccRelGateOutDateLabel, r.portGateOutDate ?? CcFormat.unknown),
                _fact(l.ccRelDispatchTitle, r.dispatchAuthorized ? l.lgxYes : l.lgxNo),
                _fact(l.ccRelDemurrageLabel, '${CcFormat.money(r.demurrageStorageFees)} ${l.egpCurrency}'),
              ],
            ),
          ),

          // Section 8: Inspection, Sampling & Under-Bond
          CcSectionCard(
            title: l.drawingSamplesSummaryHeader,
            icon: Icons.science_outlined,
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _fact(l.ccInsYardLabel, r.inspectionYard ?? CcFormat.unknown),
                _fact(l.ccInsResultLabel, r.inspectionResult),
                _fact(l.ccInsInspectorLabel, r.inspectorName ?? CcFormat.unknown),
                _fact(l.ccInsSampleSwitchTitle, r.isSampleDrawn ? l.lgxYes : l.lgxNo),
                _fact(l.ccInsSampleDateLabel, r.samplingDate ?? CcFormat.unknown),
                _fact(l.ccInsSampleRecordLabel, r.samplingRecordNo ?? CcFormat.unknown, mono: true),
                if (r.sampledRegulatoryBodies.isNotEmpty)
                  _fact(l.ccInsBodiesLabel, r.sampledRegulatoryBodies.join(', ')),
                _fact(l.underBondModeUnderBond, r.isUnderBondRelease ? l.lgxYes : l.lgxNo),
                if ((r.bondGuaranteeRef ?? '').isNotEmpty)
                  _fact(l.underBondGuaranteeRefLabel, r.bondGuaranteeRef!, mono: true),
                _fact(l.warehouseReceivingColQuarantine, r.quarantineLock ? l.lgxYes : l.lgxNo),
                _fact(l.drawingSamplesColLabResult, r.labTestResult),
                if ((r.labCertificateNumber ?? '').isNotEmpty)
                  _fact(l.underBondLabCertLabel, r.labCertificateNumber!, mono: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _fact(String label, String value, {bool mono = false}) {
    return SizedBox(
      width: 190,
      child: CcFact(label: label, value: value, mono: mono),
    );
  }
}
