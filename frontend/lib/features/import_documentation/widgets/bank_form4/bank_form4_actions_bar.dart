import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../idoc_ui_b.dart';
import 'bank_form4_localizer.dart';

/// Bottom action bar and readiness advisory warning for Form 4 submission.
class BankForm4ActionsBar extends StatelessWidget {
  final bool isSaving;
  final bool isEditing;
  final bool hasActiveDoc;
  final bool canSubmit;
  final int blockersCount;
  final VoidCallback? onSave;
  final VoidCallback onSwitchToRegistry;

  const BankForm4ActionsBar({
    super.key,
    required this.isSaving,
    required this.isEditing,
    required this.hasActiveDoc,
    required this.canSubmit,
    required this.blockersCount,
    required this.onSave,
    required this.onSwitchToRegistry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasActiveDoc && !canSubmit) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    BankForm4Localizer.draftReadinessWarning(context, blockersCount),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            IdocBUi.fit(AppButton(
              key: const Key('saveForm4SubmitBtn'),
              label: isSaving
                  ? context.l10n.loading
                  : isEditing
                      ? context.l10n.updateForm4Button
                      : context.l10n.saveForm4Button,
              onPressed: isSaving ? null : onSave,
              icon: Icons.save,
              isLoading: isSaving,
            )),
            IdocBUi.fit(AppButton(
              label: context.l10n.goToBankRegistryButton,
              onPressed: onSwitchToRegistry,
              variant: AppButtonVariant.secondary,
              icon: Icons.history_edu,
            )),
          ],
        ),
      ],
    );
  }
}
