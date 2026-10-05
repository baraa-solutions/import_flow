import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

/// Warning shown above the comparison table when some lines have no valid tariff
/// (`tariff_missing_lines_count > 0`): those lines carry zero taxes and are excluded from the totals.
class TariffMissingBanner extends StatelessWidget {
  const TariffMissingBanner({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.orangeLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.orange),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.tariffMissingLinesWarning(count),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small badge for a comparison line whose status is TARIFF_MISSING.
class TariffMissingBadge extends StatelessWidget {
  const TariffMissingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Tooltip(
      message: l.tariffMissingLineHint,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.orangeLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 13, color: AppTheme.wcagOrange),
            const SizedBox(width: 4),
            Text(
              l.tariffMissingBadge,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
            ),
          ],
        ),
      ),
    );
  }
}
