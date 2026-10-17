import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../shipping_scenarios/models/shipping_scenario_model.dart';
import 'freight_booking_ui.dart';

/// One evaluated shipping quote with its apply / selected action.
class FbkQuoteCard extends StatelessWidget {
  const FbkQuoteCard({
    super.key,
    required this.session,
    required this.item,
    required this.isSelected,
    required this.onApply,
  });

  final ShippingEvaluationModel session;
  final ShippingScenarioItemModel item;
  final bool isSelected;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final okFg = AppTheme.severityForegroundOf(context, AppSeverity.success);
    final secondary = TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context));

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              item.providerName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryOf(context)),
            ),
            if (item.isRecommended)
              AppStatusBadge(
                label: l.freightBookingBestQuoteBadge,
                severity: AppSeverity.warning,
                size: AppStatusBadgeSize.small,
                icon: Icons.star,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l.freightBookingQuoteVesselDetails(
              item.vesselName, item.voyageNumber ?? '-', item.polName ?? '-', item.podName ?? '-'),
          style: secondary,
        ),
        const SizedBox(height: 2),
        Text(
          l.freightBookingQuoteScheduleDetails(item.sailingDate, item.estimatedArrivalDate, item.freeTimeDays),
          style: secondary,
        ),
      ],
    );

    final price = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        LtrText(
          '${CcFormat.money(item.totalQuotationAmount)} ${item.quotationCurrency}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: okFg),
        ),
        Text(
          l.freightBookingQuoteStudyRef(session.sessionCode, session.cargoReadyDate),
          style: TextStyle(fontSize: 10, color: AppTheme.textMutedOf(context)),
        ),
      ],
    );

    final action = FbkUi.fit(AppButton(
      label: isSelected ? l.freightBookingSelectedQuoteBtn : l.freightBookingApplyQuoteBtn,
      icon: isSelected ? Icons.check_circle : Icons.check,
      variant: isSelected ? AppButtonVariant.success : AppButtonVariant.secondary,
      size: AppButtonSize.small,
      onPressed: onApply,
    ));

    return Container(
      padding: const EdgeInsetsDirectional.all(10),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.severityBackgroundOf(context, AppSeverity.success) : AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isSelected ? okFg : AppTheme.borderOf(context),
          width: isSelected ? 1.6 : 1,
        ),
      ),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              info,
              const SizedBox(height: 8),
              Row(
                children: [Expanded(child: price), const SizedBox(width: 8), action],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: info),
            Expanded(flex: 2, child: price),
            const SizedBox(width: 12),
            action,
          ],
        );
      }),
    );
  }
}
