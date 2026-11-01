import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../financial_ui.dart';

class SwiftHeaderBar extends StatelessWidget {
  final bool isSmartSectionExpanded;
  final VoidCallback onLoadSample;
  final VoidCallback onToggleExpanded;

  const SwiftHeaderBar({
    super.key,
    required this.isSmartSectionExpanded,
    required this.onLoadSample,
    required this.onToggleExpanded,
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
              l10n.swiftExtractorHeader,
              style: const TextStyle(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          FinancialUi.fit(AppButton(
            label: l10n.swiftLoadSampleBtn,
            variant: AppButtonVariant.secondary,
            icon: Icons.description,
            onPressed: onLoadSample,
          )),
          const SizedBox(width: 8),
          IconButton(
            tooltip: isSmartSectionExpanded
                ? l10n.swiftCollapseToolTooltip
                : l10n.swiftExpandToolTooltip,
            icon: Icon(
              isSmartSectionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: AppTheme.white,
            ),
            onPressed: onToggleExpanded,
          ),
        ],
      ),
    );
  }
}
