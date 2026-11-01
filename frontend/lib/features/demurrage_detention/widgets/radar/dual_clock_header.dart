import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';

class DualClockHeader extends StatelessWidget {
  final String billOfLadingNo;
  final String carrierName;
  final Color onDark;
  final VoidCallback? onCopyMetrics;
  final VoidCallback onClose;

  const DualClockHeader({
    super.key,
    required this.billOfLadingNo,
    required this.carrierName,
    required this.onDark,
    this.onCopyMetrics,
    required this.onClose,
  });

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onDark),
          const SizedBox(width: 4),
          Flexible(
            child: LtrText(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: onDark)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 16),
      color: AppTheme.charcoal,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(Icons.speed_rounded, color: AppTheme.cobalt, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dualClockRadarDialogTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.white),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _chip(Icons.description_outlined, l10n.billOfLadingLabel(billOfLadingNo)),
                    _chip(Icons.directions_boat_outlined, carrierName),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded, color: onDark, size: 20),
            tooltip: l10n.dualClockCopyMetricsBtn,
            onPressed: onCopyMetrics,
          ),
          IconButton(
            icon: Icon(Icons.close, color: onDark),
            tooltip: l10n.close,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
