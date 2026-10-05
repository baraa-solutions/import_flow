import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/live_pulse_badge.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/demurrage_model.dart';
import 'demurrage_status.dart';

/// One container-tracking session: identity (tracking code / B/L / carrier),
/// the key milestone dates, the accrued exposure (right-aligned, severity
/// coloured) and the row actions. A coloured strip on the start edge makes the
/// risk level scannable down the list.
class DemurrageTrackingCard extends StatelessWidget {
  const DemurrageTrackingCard({
    super.key,
    required this.item,
    required this.onCopySummary,
    required this.onPrintSlip,
    required this.onOpenRadar,
    required this.onUpdateDates,
    required this.onReturnContainers,
    required this.onPushToSettlement,
  });

  final DemurrageTrackingModel item;
  final VoidCallback onCopySummary;
  final VoidCallback onPrintSlip;
  final VoidCallback onOpenRadar;
  final VoidCallback onUpdateDates;
  final VoidCallback onReturnContainers;
  final VoidCallback onPushToSettlement;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final severity = DemurrageStatusStyle.ofTracking(item.status);
    final accent = AppTheme.severityForegroundOf(context, severity);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: DecoratedBox(
        decoration: AppTheme.cardDecorationOf(context),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _identityRow(context, l),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: AppTheme.borderOf(context)),
                    const SizedBox(height: 12),
                    _bodyRow(context, l, severity),
                    const SizedBox(height: 14),
                    _actions(context, l),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identityRow(BuildContext context, AppLocalizations l) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            _copyChip(context, l, item.trackingCode),
            Tooltip(
              message: l.demurrageCopyFieldTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: () => CopyHelper.copy(context, item.billOfLadingNo),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.billOfLadingLabel(item.billOfLadingNo),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded, size: 13, color: AppTheme.textMutedOf(context)),
                  ],
                ),
              ),
            ),
            Text(
              '${item.carrierName} - ${item.portName}',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context)),
            ),
          ],
        ),
        LivePulseBadge.demurrage(
          status: item.status,
          accruedPenaltyEgp: item.totalCostEgp,
          customLabel: l.localizedDemurrageStatus(item.status),
          size: PulseBadgeSize.regular,
        ),
      ],
    );
  }

  Widget _copyChip(BuildContext context, AppLocalizations l, String code) {
    return Tooltip(
      message: l.demurrageCopyFieldTooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: () => CopyHelper.copy(context, code),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAltOf(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LtrText(
                code,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: 12, color: AppTheme.textMutedOf(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bodyRow(BuildContext context, AppLocalizations l, AppSeverity severity) {
    final facts = Wrap(
      spacing: 28,
      runSpacing: 12,
      children: [
        _fact(l.dischargeDateLabel, item.dischargeDate, mono: true),
        _fact(l.gateOutDateLabel, item.gateOutDate ?? l.notGatedOutYet, mono: item.gateOutDate != null),
        _fact(l.emptyReturnDateLabel, item.emptyReturnDate ?? l.notReturnedYet, mono: item.emptyReturnDate != null),
        _fact(l.containersCountLabel, l.containersCountValue(item.containers.length)),
        _fact(
          l.demDaysSinceDischarge,
          l.daysCountFormatted(DemurrageStatusStyle.daysSinceDischarge(item.dischargeDate, item.gateOutDate)),
        ),
      ],
    );
    final exposure = _exposure(context, l, severity);

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [facts, const SizedBox(height: 14), exposure],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: facts),
            const SizedBox(width: 24),
            SizedBox(width: 260, child: exposure),
          ],
        );
      },
    );
  }

  Widget _fact(String label, String value, {bool mono = false}) => CcFact(label: label, value: value, mono: mono);

  /// Accrued exposure: the headline figure (EGP, right-aligned) plus the
  /// per-clock breakdown the tracking already carries.
  Widget _exposure(BuildContext context, AppLocalizations l, AppSeverity severity) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    final hasCost = item.totalCostEgp > 0;
    final color = hasCost ? AppTheme.severityForegroundOf(context, AppSeverity.danger) : AppTheme.severityForegroundOf(context, AppSeverity.success);
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l.totalEstimatedCostLabel,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: CcMoneyText(item.totalCostEgp, color: color, fontSize: 20),
            ),
          ),
          if (hasCost) ...[
            const SizedBox(height: 8),
            _breakdownLine(context, l.demurrageFeeMetric, item.totalDemurrageFx, item.currency),
            _breakdownLine(context, l.detentionFeeMetric, item.totalDetentionFx, item.currency),
            _breakdownLine(context, l.portStorageFeeMetric, item.totalStorageEgp, l.egpCurrency),
          ],
        ],
      ),
    );
  }

  Widget _breakdownLine(BuildContext context, String label, double value, String currency) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
            ),
          ),
          const SizedBox(width: 8),
          CcMoneyText(value, currency: currency, fontSize: 11.5, textAlign: TextAlign.end),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, AppLocalizations l) {
    final returned = DemurrageStatusStyle.isReturned(item.status);
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        CcUi.fit(AppButton(
          label: l.demurrageCopySummaryBtn,
          icon: Icons.copy_rounded,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.small,
          onPressed: onCopySummary,
        )),
        CcUi.fit(AppButton(
          label: l.demurragePrintSlipTooltip,
          icon: Icons.print_outlined,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.small,
          onPressed: onPrintSlip,
        )),
        CcUi.fit(AppButton(
          label: l.dualClockRadarBtn,
          icon: Icons.speed_rounded,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onOpenRadar,
        )),
        CcUi.fit(AppButton(
          label: l.updateGateOutAndReturnDatesBtn,
          icon: Icons.edit_calendar_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onUpdateDates,
        )),
        CcUi.fit(AppButton(
          key: Key('emptyContainerReturnBtn_${item.trackingId}'),
          label: returned ? l.demReturnedEirBtn : l.demReturnContainersBtn,
          icon: Icons.assignment_turned_in_rounded,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onReturnContainers,
        )),
        if (!item.isPushedToSettlement)
          CcUi.fit(AppButton(
            label: l.pushToFinancialSettlementBtn,
            icon: Icons.receipt_long_rounded,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: onPushToSettlement,
          ))
        else
          CcUi.fit(AppButton(
            label: l.alreadyPushedToSettlementBtn,
            icon: Icons.check_circle_outline,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: null,
          )),
      ],
    );
  }
}

/// A carrier tariff policy: carrier/container type, the three free-day
/// allowances and the daily storage rate.
class DemurragePolicyCard extends StatelessWidget {
  const DemurragePolicyCard({super.key, required this.policy, required this.onCopy});

  final DemurragePolicyModel policy;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = policy;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsetsDirectional.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.policy_outlined, size: 18, color: AppTheme.cobalt),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${p.carrierName} - ${p.containerType}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
              CcStatusChip(label: l.currencyLabelFormatted(p.currency), severity: AppSeverity.info),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 16),
                tooltip: l.policyCopySummaryBtn,
                onPressed: onCopy,
              ),
            ],
          ),
          Divider(height: 20, color: AppTheme.borderOf(context)),
          Wrap(
            spacing: 36,
            runSpacing: 12,
            children: [
              CcFact(label: l.demurrageFreeLabel, value: l.daysCountFormatted(p.demurrageFreeDays)),
              CcFact(label: l.detentionFreeLabel, value: l.daysCountFormatted(p.detentionFreeDays)),
              CcFact(label: l.portStorageFreeLabel, value: l.daysCountFormatted(p.portStorageFreeDays)),
              CcFact(
                label: l.dailyStorageRateLabel,
                value: l.egpPerDayFormatted(p.portStorageDailyRateEgp.toStringAsFixed(0)),
                mono: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
