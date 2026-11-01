import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

class BrokerQuoteHeader extends StatelessWidget {
  final String? rfqTitle;
  final VoidCallback? onAddQuote;
  final VoidCallback? onSmartExtract;

  const BrokerQuoteHeader({
    super.key,
    this.rfqTitle,
    this.onAddQuote,
    this.onSmartExtract,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.compare_arrows_rounded,
            color: AppTheme.cobalt,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.clearanceQuotesScreenTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              if (rfqTitle != null && rfqTitle!.isNotEmpty)
                Text(
                  rfqTitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (onAddQuote != null)
          AppButton(
            label: l10n.clearanceQuotesAddManualQuoteBtn,
            icon: Icons.add,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: onAddQuote,
          ),
        if (onSmartExtract != null) ...[
          const SizedBox(width: 8),
          AppButton(
            label: l10n.clearanceQuotesSmartExtractQuoteBtn,
            icon: Icons.auto_awesome,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onSmartExtract,
          ),
        ],
      ],
    );
  }
}
