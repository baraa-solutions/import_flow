import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import 'shipping_format_helper.dart';

/// Five-node milestone progress line: reached nodes are emerald, the labels sit
/// under the nodes so nothing overflows on narrow windows.
class ShippingMilestoneTimeline extends StatelessWidget {
  const ShippingMilestoneTimeline({super.key, required this.stepIndex, required this.labels});

  final int stepIndex;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final border = AppTheme.borderOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0 ? Colors.transparent : (i <= stepIndex - 1 ? AppTheme.emerald : border),
                      ),
                    ),
                    _node(context, i),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == labels.length - 1 ? Colors.transparent : (i < stepIndex - 1 ? AppTheme.emerald : border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: (i + 1) <= stepIndex ? FontWeight.bold : FontWeight.normal,
                      color: (i + 1) <= stepIndex ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _node(BuildContext context, int i) {
    final reached = (i + 1) <= stepIndex;
    return CircleAvatar(
      radius: 11,
      backgroundColor: reached ? AppTheme.emerald : AppTheme.borderOf(context),
      child: reached
          ? const Icon(Icons.check, size: 13, color: AppTheme.white)
          : Text('${i + 1}', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

/// One milestone date-time slot: tinted when set, with Pick / Set now / clear.
class ShippingMilestoneBox extends StatelessWidget {
  const ShippingMilestoneBox({
    super.key,
    required this.stepNumber,
    required this.stepTitle,
    required this.valueText,
    required this.onPick,
    required this.onSetNow,
    required this.onClear,
    this.noteText,
  });

  final String stepNumber;
  final String stepTitle;
  final String? valueText;
  final String? noteText;
  final VoidCallback onPick;
  final VoidCallback onSetNow;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasValue = valueText != null && valueText!.trim().isNotEmpty;
    final hasNote = noteText != null && noteText!.trim().isNotEmpty;
    final okFg = AppTheme.severityForegroundOf(context, AppSeverity.success);
    final warnFg = AppTheme.severityForegroundOf(context, AppSeverity.warning);

    return Container(
      padding: const EdgeInsetsDirectional.all(8),
      decoration: BoxDecoration(
        color: hasValue ? AppTheme.severityBackgroundOf(context, AppSeverity.success) : AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: hasValue ? okFg.withValues(alpha: 0.6) : AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$stepNumber. $stepTitle',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: hasValue ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context),
                  ),
                ),
              ),
              if (hasValue)
                InkWell(
                  onTap: onClear,
                  child: Icon(Icons.cancel, size: 15, color: AppTheme.textMutedOf(context)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: hasValue ? okFg.withValues(alpha: 0.5) : AppTheme.borderOf(context)),
              ),
              child: Row(
                children: [
                  Icon(hasValue ? Icons.check_circle : Icons.schedule, size: 14, color: hasValue ? okFg : AppTheme.cobalt),
                  const SizedBox(width: 6),
                  Expanded(
                    child: LtrText(
                      ShippingFormat.dateTime(valueText, context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                        color: hasValue ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ),
                  if (hasValue) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: l.cargoShippingCopyFieldTooltip,
                      child: InkWell(
                        onTap: () => CopyHelper.copy(
                          context,
                          ShippingFormat.dateTime(valueText, context),
                          customMessage: l.cargoShippingSlaCopyMilestoneSuccess,
                        ),
                        child: Icon(Icons.copy, size: 12, color: okFg),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasNote) ...[
            const SizedBox(height: 6),
            Tooltip(
              message: l.cargoShippingCopyFieldTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: () => CopyHelper.copy(context, noteText!),
                child: Container(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: warnFg.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note_alt, size: 12, color: warnFg),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          noteText!,
                          style: TextStyle(fontSize: 10.5, color: warnFg, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: CcUi.fit(AppButton(
                  label: l.cargoShippingPickBtn,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: onPick,
                )),
              ),
              const SizedBox(width: 4),
              CcUi.fit(AppButton(
                label: l.cargoShippingSetNowBtn,
                variant: AppButtonVariant.saveDraft,
                size: AppButtonSize.small,
                onPressed: onSetNow,
              )),
            ],
          ),
        ],
      ),
    );
  }
}
