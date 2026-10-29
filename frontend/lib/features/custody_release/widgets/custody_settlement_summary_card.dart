import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Summary metric cards for the Customs Custody & Under-Bond Release module.
class CustodySettlementSummaryCard extends StatelessWidget {
  final int totalDossiers;
  final int lockedCount;
  final int releasedCount;
  final int breachesCount;

  const CustodySettlementSummaryCard({
    super.key,
    required this.totalDossiers,
    required this.lockedCount,
    required this.releasedCount,
    required this.breachesCount,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;

    return MetricCardStrip(
      metrics: [
        MetricCardData(
          title: isArabic ? 'إجمالي الملفات' : 'Total Dossiers',
          value: '$totalDossiers',
          icon: Icons.folder_outlined,
          color: AppTheme.cobalt,
        ),
        MetricCardData(
          title: isArabic ? 'محظور الصرف بالمخزن 🔒' : 'Locked Under Custody 🔒',
          value: '$lockedCount',
          icon: Icons.lock_clock_rounded,
          color: Colors.orange,
        ),
        MetricCardData(
          title: isArabic ? 'مفرج نهائياً 🔓' : 'Final Released 🔓',
          value: '$releasedCount',
          icon: Icons.verified_rounded,
          color: AppTheme.emerald,
        ),
        MetricCardData(
          title: isArabic ? 'بلاغات خرق الأحراز ⚠️' : 'Breach Reports ⚠️',
          value: '$breachesCount',
          icon: Icons.warning_rounded,
          color: AppTheme.crimson,
        ),
      ],
    );
  }
}
