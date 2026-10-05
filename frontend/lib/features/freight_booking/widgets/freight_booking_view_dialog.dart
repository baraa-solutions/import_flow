import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/freight_booking_model.dart';
import 'freight_booking_ui.dart';

/// Read-only booking details: carrier, route and schedule, containers,
/// charges, total and the quoted-vs-executed comparison.
class FreightBookingViewDialog extends StatelessWidget {
  final ShipmentBookingModel booking;
  const FreightBookingViewDialog({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = booking;
    final st = FbkUi.status(l, b.status);
    final hasComparison = b.originalFreightCostUsd > 0 || b.costSavingsUsd > 0 || b.costVarianceUsd != 0.0;

    return CcStageDialogShell(
      title: l.freightBookingViewTitle(b.bookingCode),
      icon: Icons.visibility,
      maxWidth: 820,
      isSubmitting: false,
      showCancel: false,
      confirmLabel: l.close,
      confirmIcon: Icons.close,
      confirmVariant: AppButtonVariant.secondary,
      onConfirm: () => Navigator.pop(context),
      body: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summary(context, l, st),
            const SizedBox(height: 12),
            CcSectionCard(
              title: l.freightBookingViewRouteSection,
              icon: Icons.alt_route,
              child: _routeFacts(context, l),
            ),
            CcSectionCard(
              title: l.freightBookingViewContainersSection,
              icon: Icons.inventory_2_outlined,
              child: _containers(context, l),
            ),
            CcSectionCard(
              title: l.freightBookingViewChargesSection,
              icon: Icons.payments_outlined,
              child: _charges(context, l),
            ),
            if (hasComparison) _comparison(l),
          ],
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, AppLocalizations l, ({AppSeverity severity, String label, IconData icon}) st) {
    final b = booking;
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CcStatusChip(label: st.label, severity: st.severity, icon: st.icon),
          _fact(l.freightBookingViewShippingLine, FbkFormat.orDash(b.shippingLineName)),
          _fact(l.freightBookingViewConfirmNo, FbkFormat.orDash(b.bookingConfirmationNo), mono: true),
          if (b.billOfLadingNo != null) _fact('B/L', b.billOfLadingNo!, mono: true),
        ],
      ),
    );
  }

  Widget _fact(String label, String value, {bool mono = false}) =>
      ConstrainedBox(constraints: const BoxConstraints(minWidth: 120, maxWidth: 260), child: CcFact(label: label, value: value, mono: mono));

  Widget _note(String text, Color color) => Text(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
      );

  Widget _routeFacts(BuildContext context, AppLocalizations l) {
    final b = booking;
    final delayed = b.departureDelayDays > 0;
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        _fact(l.freightBookingViewPol, FbkFormat.orDash(b.polName)),
        _fact(l.freightBookingViewPod, FbkFormat.orDash(b.podName)),
        _fact(l.freightBookingColVesselVoyage, '${FbkFormat.orDash(b.vesselName)} / ${FbkFormat.orDash(b.voyageNumber)}'),
        _fact(l.freightBookingEtdLabel, FbkFormat.isoDate(b.etd), mono: true),
        _fact(l.freightBookingEtaLabel, FbkFormat.isoDate(b.eta), mono: true),
        _note(l.freightBookingViewTransitTime(b.transitTimeDays), AppTheme.textPrimaryOf(context)),
        if (b.atd != null)
          _note(
            l.freightBookingViewAtd(FbkFormat.isoDate(b.atd), delayed ? '+${b.departureDelayDays}d' : '0d'),
            AppTheme.severityForegroundOf(context, delayed ? AppSeverity.danger : AppSeverity.success),
          ),
        if (b.atd != null)
          _note(
            l.freightBookingViewExpectedWh(FbkFormat.isoDate(b.expectedWarehouseArrivalDate)),
            AppTheme.textPrimaryOf(context),
          ),
      ],
    );
  }

  Widget _containers(BuildContext context, AppLocalizations l) {
    final b = booking;
    if (b.containersData.isEmpty) {
      return Text('—', style: TextStyle(color: AppTheme.textMutedOf(context)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in b.containersData)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.quantity}x ${c.containerType} (${c.vgmWeightKg.toStringAsFixed(0)} kg)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                ),
                for (final indiv in c.individualContainers)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2, start: 8),
                    child: LtrText(
                      '• ${indiv.containerNumber.isEmpty ? "-" : indiv.containerNumber} | ${indiv.sealNumber.isEmpty ? "-" : indiv.sealNumber}',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _charges(BuildContext context, AppLocalizations l) {
    final b = booking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final ch in b.costChargesData)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${ch.chargeType} (${ch.quantity}x ${CcFormat.money(ch.rate)} ${ch.currency})',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
                const SizedBox(width: 8),
                CcMoneyText(ch.total, currency: ch.currency),
              ],
            ),
          ),
        Divider(color: AppTheme.borderOf(context)),
        Row(
          children: [
            Expanded(
              child: Text(
                l.freightBookingViewTotalFreight,
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
              ),
            ),
            CcMoneyText(
              b.totalFreightCostUsd,
              currency: 'USD',
              fontSize: 16,
              color: AppTheme.severityForegroundOf(context, AppSeverity.success),
            ),
          ],
        ),
      ],
    );
  }

  Widget _comparison(AppLocalizations l) {
    final b = booking;
    final orig = b.originalFreightCostUsd;
    // Unknown executed cost: show 0.00 in the summary but never infer savings.
    final execKnown = b.totalFreightCostUsd;
    final exec = execKnown ?? 0.0;
    final hasSavings = b.hasSavings || (execKnown != null && orig > 0 && exec < orig);
    final hasIncrease = b.hasCostIncrease || (execKnown != null && orig > 0 && exec > orig);
    final breakdown = (b.quotationDetailsData['savings_breakdown'] as List<dynamic>?) ?? [];
    final lines = [
      for (final item in breakdown)
        l.freightBookingBreakdownSavingsUnit(
          (item['charge_type'] ?? '').toString(),
          ((item['original_unit_rate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
          ((item['executed_unit_rate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
          ((item['unit_diff'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
          (item['quantity'] ?? 1).toString(),
          (item['unit_type'] ?? '').toString(),
          ((item['item_savings'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
        ),
    ];
    return FbkSavingsSummary(
      original: orig,
      executed: exec,
      hasSavings: hasSavings,
      hasIncrease: hasIncrease,
      providerName: b.scenarioProviderName,
      breakdownLines: lines,
      notes: b.savingsNotes,
    );
  }
}
