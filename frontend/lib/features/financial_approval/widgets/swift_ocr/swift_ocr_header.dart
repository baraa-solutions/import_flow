import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../financial_ui.dart';

class SwiftOcrHeader extends StatelessWidget {
  final bool isAutoFillMode;
  final bool isSmartSectionExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onLoadSample;

  const SwiftOcrHeader({
    super.key,
    required this.isAutoFillMode,
    required this.isSmartSectionExpanded,
    required this.onToggleExpanded,
    this.onLoadSample,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.charcoal,
            AppTheme.cobalt.withValues(alpha: 0.9),
          ],
          begin: AlignmentDirectional.centerEnd,
          end: AlignmentDirectional.centerStart,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.orange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAutoFillMode
                  ? l10n.swiftExtractorTitle
                  : l10n.swiftExtractorHeader,
              style: const TextStyle(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onLoadSample != null) ...[
            FinancialUi.fit(AppButton(
              label: l10n.swiftLoadSampleBtn,
              variant: AppButtonVariant.secondary,
              icon: Icons.description,
              onPressed: onLoadSample,
            )),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: isSmartSectionExpanded
                ? l10n.swiftCollapseToolTooltip
                : l10n.swiftExpandToolTooltip,
            icon: Icon(
              isSmartSectionExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: AppTheme.white,
            ),
            onPressed: onToggleExpanded,
          ),
        ],
      ),
    );
  }
}
