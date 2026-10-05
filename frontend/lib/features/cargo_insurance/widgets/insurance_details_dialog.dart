import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/cargo_insurance_model.dart';
import '../services/cargo_insurance_export_service.dart';

// =============================================================================
// Details Dialog: Official Printable Marine Insurance Certificate Preview
// =============================================================================
class CargoInsuranceDetailsDialog extends ConsumerWidget {
  final CargoInsuranceModel certificate;
  const CargoInsuranceDetailsDialog({super.key, required this.certificate});

  String _policyTypeLabel(AppLocalizations l, String v) {
    switch (v) {
      case 'SPECIFIC':
        return l.insurancePolicyTypeSpecific;
      case 'OPEN_DECLARATION':
        return l.insurancePolicyTypeOpen;
      default:
        return v;
    }
  }

  String _modeLabel(AppLocalizations l, String v) {
    switch (v) {
      case 'OCEAN':
        return l.insuranceTransportModeOcean;
      case 'AIR':
        return l.insuranceTransportModeAir;
      case 'ROAD':
        return l.insuranceTransportModeRoad;
      default:
        return v;
    }
  }

  String _clauseLabel(AppLocalizations l, String v) {
    switch (v) {
      case 'ICC_A':
        return l.insuranceClauseIccA;
      case 'ICC_B':
        return l.insuranceClauseIccB;
      case 'ICC_C':
        return l.insuranceClauseIccC;
      case 'AIR_ALL_RISKS':
        return l.insuranceClauseAirAllRisks;
      default:
        return v;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final shipmentCode = certificate.importFileId != null ? 'IMP-${certificate.importFileId}' : null;
    final shipmentTitle = shipmentCode != null
        ? DisplayNameResolver.resolveShipmentTitleByCode(shipmentCode, shipments: importFiles, isArabic: isAr)
        : null;
    final cur = certificate.currency;
    String money(double v) => '${CcFormat.money(v)} $cur';

    return SelectionArea(
      child: CcStageDialogShell(
        title: l.insurancePreviewCertificateHeader,
        icon: Icons.verified_user_rounded,
        accent: AppTheme.cobalt,
        maxWidth: 840,
        chips: [
          CcHeaderChip(Icons.shield_rounded, certificate.certificateCode, ltr: true),
          CcHeaderChip(
            certificate.status == 'ISSUED' ? Icons.check_circle_outline : Icons.hourglass_bottom_rounded,
            certificate.status == 'ISSUED' ? l.insurancePreviewOfficialIssuedBadge : l.insurancePreviewDraftBadge,
          ),
        ],
        confirmLabel: l.insurancePreviewPrintBtn,
        confirmIcon: Icons.print_rounded,
        confirmVariant: AppButtonVariant.primary,
        isSubmitting: false,
        onConfirm: () => CargoInsuranceExportService.printOrSaveCertificatesPdf(context, [certificate]),
        footerLeading: Row(
          children: [
            Expanded(
              child: Text(
                l.insurancePreviewLegalDisclaimer,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context), fontStyle: FontStyle.italic),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
              tooltip: l.insuranceCopyRowSummaryBtn,
              onPressed: () {
                final summary = CargoInsuranceExportService.toRowSummary(certificate, l);
                CopyHelper.copy(context, summary, customMessage: l.insuranceCopyRowSummarySuccess);
              },
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(context, l.insurancePreviewSecInsuredDetails, Icons.badge_outlined, [
              _Row(l.insurancePreviewInsuredLabel, certificate.insuredEntityName),
              _Row(l.insurancePreviewCompanyLabel, certificate.insuranceCompanyName ?? '-'),
              _Row(l.insurancePreviewPolicyNoLabel, certificate.policyNumber ?? l.insPendingOnDemand),
              if (shipmentCode != null) _Row(l.insuranceFieldLinkImportFile, '$shipmentTitle ($shipmentCode)'),
              _Row(l.insurancePreviewPolicyTypeLabel, _policyTypeLabel(l, certificate.policyType)),
            ]),
            const SizedBox(height: 12),
            _card(context, l.insurancePreviewSecRouteDetails, Icons.route_outlined, [
              _Row(l.insurancePreviewTransportModeLabel, _modeLabel(l, certificate.transportMode)),
              _Row(
                l.insurancePreviewVesselFlightLabel,
                '${certificate.vesselOrFlightNo ?? "-"} / ${l.insVoyage(certificate.voyageNumber ?? "-")}',
              ),
              _Row(l.insurancePreviewPolLabel, certificate.portOfLoading),
              _Row(l.insurancePreviewPodLabel, certificate.portOfDischarge),
              _Row(l.insurancePreviewTrackingLabel, certificate.trackingReference ?? '-', mono: true),
            ]),
            const SizedBox(height: 12),
            _card(context, l.insurancePreviewSecValuation, Icons.calculate_outlined, [
              _Row(l.insurancePreviewInvoiceFobLabel, money(certificate.invoiceValue), mono: true),
              _Row(l.insurancePreviewFreightLabel, money(certificate.freightCost), mono: true),
              _Row(l.insurancePreviewCifBaseLabel, money(certificate.cifValue), mono: true),
              _Row(l.insurancePreviewInsuredSumLabel, money(certificate.insuredValue), mono: true, bold: true),
            ]),
            const SizedBox(height: 12),
            _card(context, l.insurancePreviewSecPremium, Icons.payments_outlined, [
              _Row(l.insurancePreviewCoverageClauseLabel, _clauseLabel(l, certificate.coverageClause)),
              _Row(
                l.insurancePreviewBasePremiumLabel,
                '${money(certificate.basePremium)} (${(certificate.baseRate * 100).toStringAsFixed(2)}%)',
                mono: true,
              ),
              _Row(l.insurancePreviewWarStrikesLabel, money(certificate.warStrikesPremium), mono: true),
              _Row(
                l.insurancePreviewFeesTaxesLabel,
                money(certificate.issuanceFee + certificate.taxAmount),
                mono: true,
              ),
              _Row(l.insurancePreviewTotalGrossPremiumLabel, money(certificate.totalPayablePremium), mono: true, bold: true),
            ]),
            const SizedBox(height: 12),
            CcSectionCard(
              title: l.insurancePreviewSecCargoSpecs,
              icon: Icons.inventory_2_outlined,
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(context, '${l.insurancePreviewDescPrefix} ${certificate.goodsDescription ?? l.insGeneralCargo}'),
                  _bullet(
                    context,
                    '${l.insurancePreviewPackagesPrefix} ${certificate.packageCount ?? "-"} ${certificate.packageType ?? l.insPackagesDefault} • ${l.insurancePreviewGrossWtPrefix} ${certificate.grossWeightKg ?? "-"} ${l.insKgUnit}',
                  ),
                  _bullet(context, '${l.insurancePreviewSurveyAgentPrefix} ${certificate.surveyAgentInDestination ?? "-"}'),
                  _bullet(
                    context,
                    '${l.insurancePreviewClaimsPayablePrefix} ${certificate.claimsPayableAt ?? l.insClaimsDefault} ${l.insInCurrency(certificate.currency)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
        child: Text('• $text', style: const TextStyle(fontSize: 12.5)),
      );

  Widget _card(BuildContext context, String title, IconData icon, List<_Row> rows) {
    return CcSectionCard(
      title: title,
      icon: icon,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(r.label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: r.mono
                          ? LtrText(
                              r.value,
                              textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 12.5, fontWeight: r.bold ? FontWeight.w800 : FontWeight.w600),
                            )
                          : Text(
                              r.value,
                              textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 12.5, fontWeight: r.bold ? FontWeight.w800 : FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value, {this.mono = false, this.bold = false});
  final String label;
  final String value;
  final bool mono;
  final bool bold;
}
