import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../l10n/container_eir_l10n.dart';

class ContainerEirHeader extends StatelessWidget {
  final VoidCallback onClose;

  const ContainerEirHeader({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment_turned_in, color: AppTheme.cobalt, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.containerEirDialogTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.containerEirDialogSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l.closeBtn,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
