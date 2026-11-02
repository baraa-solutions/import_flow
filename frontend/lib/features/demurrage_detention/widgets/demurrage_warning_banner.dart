import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';

/// 🚢 Demurrage & Detention Warning Banner — ImportFlow ERP
///
/// Smart operational alert banner for Inland Transport and Customs Clearance screens.
class DemurrageWarningBanner extends StatelessWidget {
  final int remainingFreeDays;
  final double accruedFineAmount;
  final String currency;
  final String? containerNumber;
  final int? totalContainers;
  final VoidCallback? onActionPressed;
  final String? actionLabel;
  final VoidCallback? onDismiss;
  final bool isCompact;

  const DemurrageWarningBanner({
    super.key,
    required this.remainingFreeDays,
    required this.accruedFineAmount,
    this.currency = 'USD',
    this.containerNumber,
    this.totalContainers,
    this.onActionPressed,
    this.actionLabel,
    this.onDismiss,
    this.isCompact = false,
  });

  bool get _hasFines => accruedFineAmount > 0 || remainingFreeDays <= 0;
  bool get _isNearExpiry => remainingFreeDays > 0 && remainingFreeDays <= 2 && accruedFineAmount <= 0;

  AppSeverity get _severity {
    if (_hasFines) return AppSeverity.danger;
    if (_isNearExpiry) return AppSeverity.warning;
    return AppSeverity.success;
  }

  Color get _statusColor => switch (_severity) {
        AppSeverity.danger => AppTheme.crimson,
        AppSeverity.warning => AppTheme.orange,
        _ => AppTheme.emerald,
      };

  IconData get _icon => switch (_severity) {
        AppSeverity.danger => Icons.crisis_alert_rounded,
        AppSeverity.warning => Icons.hourglass_bottom_rounded,
        _ => Icons.verified_outlined,
      };

  AppButtonVariant get _buttonVariant => switch (_severity) {
        AppSeverity.danger => AppButtonVariant.danger,
        AppSeverity.warning => AppButtonVariant.warning,
        _ => AppButtonVariant.primary,
      };

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;
    final color = _statusColor;
    final bg = AppTheme.severityBackgroundOf(context, _severity);
    final fg = AppTheme.severityForegroundOf(context, _severity);

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: isCompact ? 10 : 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icon, color: color, size: isCompact ? 18 : 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTitleRow(isArabic, fg, color),
                            const SizedBox(height: 4),
                            _buildDescription(isArabic, fg),
                          ],
                        ),
                      ),
                      if (onActionPressed != null || onDismiss != null) ...[
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onActionPressed != null)
                              AppButton(
                                label: actionLabel ??
                                    (isArabic ? 'تسجيل إرجاع الحاوية' : 'Register Container Return'),
                                variant: _buttonVariant,
                                size: AppButtonSize.small,
                                icon: Icons.assignment_return_outlined,
                                onPressed: onActionPressed,
                              ),
                            if (onDismiss != null) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                color: fg.withValues(alpha: 0.7),
                                tooltip: isArabic ? 'إخفاء التنبيه' : 'Dismiss Alert',
                                onPressed: onDismiss,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(bool isArabic, Color fg, Color accentColor) {
    final title = _hasFines
        ? (isArabic
            ? 'غرامات أرضيات وتأخير متراكمة — تجاوز فترة السماح'
            : 'Demurrage and Detention Incurred — Free Days Exceeded')
        : (_isNearExpiry
            ? (isArabic
                ? 'تحذير: اقتراب انتهاء أيام السماح (أقل من 48 ساعة)'
                : 'Warning: Free Days Expiring Soon (Under 48 Hours)')
            : (isArabic ? 'أيام السماح سارية وآمنة' : 'Free Time Active and Safe'));

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.bold,
            fontSize: isCompact ? 13 : 14,
          ),
        ),
        if (containerNumber != null && containerNumber!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
            ),
            child: LtrText(
              containerNumber!,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        if (totalContainers != null && totalContainers! > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isArabic ? '$totalContainers حاويات' : '$totalContainers Containers',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
      ],
    );
  }

  Widget _buildDescription(bool isArabic, Color fg) {
    final String text;
    if (_hasFines) {
      final overdue = remainingFreeDays < 0 ? remainingFreeDays.abs() : 0;
      final fine = accruedFineAmount.toStringAsFixed(2);
      text = isArabic
          ? (overdue > 0
              ? 'تجاوزت الحاوية فترة السماح بـ $overdue يوم. الغرامة: $fine $currency. يرجى إعادتها فوراً.'
              : 'الغرامة المحتسبة حالياً: $fine $currency. يرجى توثيق إرجاع الحاوية الفارغة فوراً.')
          : (overdue > 0
              ? 'Free time exceeded by $overdue days. Accrued fine: $fine $currency. Return container immediately.'
              : 'Current fine: $fine $currency. Record empty return promptly.');
    } else if (_isNearExpiry) {
      text = isArabic
          ? 'متبقي $remainingFreeDays ${remainingFreeDays == 1 ? "يوم" : "يومين"} على انتهاء السماح. نسق النقل والإرجاع فوراً.'
          : 'Only $remainingFreeDays free days left. Coordinate inland haulage and return immediately.';
    } else {
      text = isArabic
          ? 'متبقي $remainingFreeDays يوماً من فترة السماح بدون غرامات. جدول الشاحنات للإرجاع في الموعد.'
          : '$remainingFreeDays free days remaining with zero demurrage fees. Schedule return on time.';
    }

    return Text(
      text,
      style: TextStyle(
        color: fg.withValues(alpha: 0.9),
        fontSize: isCompact ? 11.5 : 12.5,
        height: 1.35,
      ),
    );
  }
}
