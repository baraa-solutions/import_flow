import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../financial_ui.dart';

class SwiftExtractActionsBar extends StatelessWidget {
  final VoidCallback onSampleExtract;
  final VoidCallback onPasteExtract;
  final VoidCallback onUploadExtract;

  const SwiftExtractActionsBar({
    super.key,
    required this.onSampleExtract,
    required this.onPasteExtract,
    required this.onUploadExtract,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cobaltLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cobaltBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.wcagCobalt, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${l10n.swiftExtractorHeader}:',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.wcagCobalt,
              ),
            ),
          ),
          FinancialUi.fit(AppButton(
            label: l10n.swiftSampleMT103Chip,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            icon: Icons.description,
            onPressed: onSampleExtract,
          )),
          const SizedBox(width: 4),
          FinancialUi.fit(AppButton(
            label: l10n.swiftPasteAndExtractChip,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            icon: Icons.paste,
            onPressed: onPasteExtract,
          )),
          const SizedBox(width: 4),
          FinancialUi.fit(AppButton(
            label: l10n.swiftUploadDocChip,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            icon: Icons.upload_file,
            onPressed: onUploadExtract,
          )),
        ],
      ),
    );
  }
}
