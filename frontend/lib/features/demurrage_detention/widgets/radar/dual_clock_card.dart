import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../demurrage_status.dart';

/// One of the two penalty clocks: accrued amount (severity coloured), a free-
/// days progress bar and the key counters.
class DualClockCard extends StatelessWidget {
  const DualClockCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.severity,
    required this.statusNote,
    required this.totalAmount,
    required this.currency,
    required this.consumedDays,
    required this.freeDays,
    required this.overdueDays,
    this.extraLabel,
    this.extraValue,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final AppSeverity severity;
  final String statusNote;
  final double totalAmount;
  final String currency;
  final int consumedDays;
  final int freeDays;
  final int overdueDays;
  final String? extraLabel;
  final String? extraValue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDanger = severity == AppSeverity.danger;
    final fg = AppTheme.severityForegroundOf(context, severity);
    final progress = freeDays <= 0 ? (consumedDays > 0 ? 1.0 : 0.0) : (consumedDays / freeDays).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsetsDirectional.all(18),
      decoration: AppTheme.cardDecorationOf(context).copyWith(
        border: Border.all(
          color: isDanger ? fg.withValues(alpha: 0.6) : AppTheme.borderOf(context),
          width: isDanger ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => CopyHelper.copy(
              context,
              totalAmount.toStringAsFixed(2),
              customMessage: l10n.demurrageCopyFieldTooltip,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: CcMoneyText(totalAmount, currency: currency, fontSize: 24, color: isDanger ? fg : null)),
                const SizedBox(width: 6),
                Icon(Icons.copy_rounded, size: 15, color: AppTheme.textMutedOf(context)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: fg,
              backgroundColor: AppTheme.surfaceAltOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.freeDaysConsumed(consumedDays, freeDays),
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
          ),
          Divider(height: 22, color: AppTheme.borderOf(context)),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.colFreeDays}: ${l10n.daysCountFormatted(freeDays)}',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${l10n.colOverdueDays}: ${l10n.daysCountFormatted(overdueDays)}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDanger ? fg : AppTheme.textSecondaryOf(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (extraLabel != null && extraValue != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    extraLabel!,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
                  ),
                ),
                LtrText(extraValue!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          CcStatusChip(label: statusNote, severity: severity, icon: DemurrageStatusStyle.iconOf(severity)),
        ],
      ),
    );
  }
}
