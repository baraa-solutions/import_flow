import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/demurrage_model.dart';

class DualClockAlerts extends StatelessWidget {
  final CarrierClockModel carrierClock;
  final PortStorageClockModel portClock;

  const DualClockAlerts({
    super.key,
    required this.carrierClock,
    required this.portClock,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool warning72h = portClock.isCritical72hWarning && !portClock.isOverdue;
    final String portAdvice = l10n.dualClockHoursUntilPenalties(portClock.hoursUntilPenalties);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Storage Overdue while Carrier Safe Alert (21-Day Trap Avoidance)
        if (portClock.isOverdue && !carrierClock.isOverdue)
          Container(
            margin: const EdgeInsetsDirectional.only(bottom: 16),
            padding: const EdgeInsetsDirectional.all(14),
            decoration: BoxDecoration(
              color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.severityForegroundOf(context, AppSeverity.danger), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.report_problem_rounded,
                    color: AppTheme.severityForegroundOf(context, AppSeverity.danger), size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تنبيه فخ الـ 21 يوماً: سريان أرضيات ساحات الميناء!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.severityForegroundOf(context, AppSeverity.danger),
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'سماح الخط الملاحي ما زال سارياً (متبقي ${carrierClock.daysRemaining} يوم بدون غرامات خط)، لكن فترة سماح الميناء الـ 7 أيام انتهت وتتراكم أرضيات بالجنيه المصري (${portClock.accruedStorageEgp.toStringAsFixed(2)} ج.م). سارع بالإفراج والسحب!',
                        style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // 72-Hour Warning Alert
        if (warning72h && !portClock.isOverdue)
          Container(
            margin: const EdgeInsetsDirectional.only(bottom: 16),
            padding: const EdgeInsetsDirectional.all(14),
            decoration: BoxDecoration(
              color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.severityForegroundOf(context, AppSeverity.warning), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppTheme.severityForegroundOf(context, AppSeverity.warning), size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dualClockWarning72hTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                          fontSize: 13.5,
                        ),
                      ),
                      if (portAdvice.isNotEmpty)
                        Text(portAdvice, style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
