import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Header toolbar of the customs duties calculation tab.
///
/// Contains engine title, subtitle, fast reconciliation invoice fetcher,
/// checklist HS requirements sync trigger, and card expand/collapse toggle.
class DutiesCalcHeader extends StatelessWidget {
  final bool isTaxReviewMode;
  final bool isRecalculating;
  final VoidCallback? onFetchReconciledFinalInvoice;
  final VoidCallback onSyncHsRequirementsToChecklist;
  final bool isCustomsCalculatorExpanded;
  final VoidCallback onToggleCustomsCalculatorExpanded;

  const DutiesCalcHeader({
    super.key,
    required this.isTaxReviewMode,
    this.isRecalculating = false,
    this.onFetchReconciledFinalInvoice,
    required this.onSyncHsRequirementsToChecklist,
    required this.isCustomsCalculatorExpanded,
    required this.onToggleCustomsCalculatorExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;
          final titleWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calculate, color: AppTheme.cobalt, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.customsCalculationEngine,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.charcoal,
                      ),
                    ),
                    Text(
                      l.customsCalculationEngineSub,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actionButtons = <Widget>[
            if (isTaxReviewMode) ...[
              AppButton(
                label: l.fetchReconciledFinalInvoice,
                icon: Icons.flash_on,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                isLoading: isRecalculating,
                onPressed: isRecalculating ? null : onFetchReconciledFinalInvoice,
              ),
            ],
            AppButton(
              label: l.syncHsRequirementsToChecklist,
              icon: Icons.sync_alt,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: onSyncHsRequirementsToChecklist,
            ),
            IconButton(
              icon: Icon(
                isCustomsCalculatorExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
              tooltip: l.view,
              onPressed: onToggleCustomsCalculatorExpanded,
            ),
          ];

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actionButtons,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleWidget),
              ...actionButtons.map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: w,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
