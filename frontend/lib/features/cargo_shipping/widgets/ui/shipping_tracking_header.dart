import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';

/// Header of one tracked unit (FCL container / LCL consolidation): copyable
/// title, tracking-status chip, SLA-breach chip and the quick-save action.
class ShippingTrackingHeader extends StatelessWidget {
  const ShippingTrackingHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.copyText,
    required this.copyMessage,
    required this.statusLabel,
    required this.statusSeverity,
    required this.quickSaveLabel,
    required this.onQuickSave,
    this.breached = false,
    this.actions,
  });

  final IconData icon;
  final String title;
  final String copyText;
  final String? copyMessage;
  final String statusLabel;
  final AppSeverity statusSeverity;
  final bool breached;
  final String quickSaveLabel;
  final VoidCallback onQuickSave;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.cobalt, size: 20),
            const SizedBox(width: 8),
            Tooltip(
              message: l.cargoShippingCopyFieldTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: () => CopyHelper.copy(context, copyText, customMessage: copyMessage),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 13, color: AppTheme.textMutedOf(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: l.cargoShippingCopyFieldTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: () => CopyHelper.copy(
                  context,
                  statusLabel,
                  customMessage: '${l.cargoShippingSlaTsvHeaderTrackingStatus}: $statusLabel',
                ),
                child: AppStatusBadge(label: statusLabel, severity: statusSeverity, size: AppStatusBadgeSize.small),
              ),
            ),
            if (breached) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: l.cargoShippingCopyFieldTooltip,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  onTap: () => CopyHelper.copy(context, l.cargoShippingSlaBreachedBadge),
                  child: AppStatusBadge(
                    label: l.cargoShippingSlaBreachedBadge,
                    severity: AppSeverity.danger,
                    icon: Icons.alarm_off,
                    size: AppStatusBadgeSize.small,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            CcUi.fit(AppButton(
              label: quickSaveLabel,
              icon: Icons.save,
              variant: AppButtonVariant.saveDraft,
              size: AppButtonSize.small,
              onPressed: onQuickSave,
            )),
            if (actions != null) ...[
              const SizedBox(width: 8),
              actions!,
            ],
          ],
        ),
      ],
    );
  }
}
