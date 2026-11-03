import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// 🏛️ Pillar 1 Widget: Decree 43 / 2016 & Factory Registration
///
/// Implements compliance verification for Egyptian Decree 43/2016, whitelist
/// eligibility, factory registration code, and decision resolution workflows.
class Pillar1Decree43Widget extends StatelessWidget {
  final bool decree43Applicable;
  final bool whiteListVerified;
  final TextEditingController factoryRegCtrl;
  final String? decree43Action; // 'justified', 'task_created', or null
  final String? decree43Justification;
  final ValueChanged<bool> onDecree43ApplicableChanged;
  final ValueChanged<bool> onWhiteListVerifiedChanged;
  final VoidCallback onRequestJustification;
  final VoidCallback onCreateDashboardTask;

  const Pillar1Decree43Widget({
    super.key,
    required this.decree43Applicable,
    required this.whiteListVerified,
    required this.factoryRegCtrl,
    required this.decree43Action,
    required this.decree43Justification,
    required this.onDecree43ApplicableChanged,
    required this.onWhiteListVerifiedChanged,
    required this.onRequestJustification,
    required this.onCreateDashboardTask,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pillar1Header,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    title: Text(
                      l10n.decree43ApplicableCheck,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(l10n.decree43ApplicableSub),
                    value: decree43Applicable,
                    onChanged: (v) => onDecree43ApplicableChanged(v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    title: Text(
                      l10n.whiteListVerifiedCheck,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(l10n.whiteListVerifiedSub),
                    value: whiteListVerified,
                    onChanged: (v) => onWhiteListVerifiedChanged(v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: factoryRegCtrl,
            decoration: InputDecoration(
              labelText: l10n.factoryRegNumFieldLabel,
              hintText: l10n.factoryRegNumHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.badge, color: AppTheme.cobalt),
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: l10n.requirementCopyFieldTooltip,
                onPressed: () => CopyHelper.copy(
                  context,
                  factoryRegCtrl.text,
                  customMessage: l10n.requirementCopySummarySuccess,
                ),
              ),
            ),
          ),
          _buildDecree43DecisionCard(context),
        ],
      ),
    );
  }

  Widget _buildDecree43DecisionCard(BuildContext context) {
    final l10n = context.l10n;

    if (!decree43Applicable || whiteListVerified) {
      return const SizedBox.shrink();
    }

    if (decree43Action == 'justified') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.emeraldLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.emerald),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AppTheme.emerald, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.decree43JustificationSavedBadge,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    decree43Justification ?? '',
                    style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                  ),
                ],
              ),
            ),
            AppButton(
              label: l10n.edit,
              icon: Icons.edit,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: onRequestJustification,
            ),
          ],
        ),
      );
    }

    if (decree43Action == 'task_created') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.orangeLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.orange),
        ),
        child: Row(
          children: [
            const Icon(Icons.assignment_late_outlined, color: AppTheme.orange, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.decree43TaskCreatedBadge,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.orange),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.decree43TaskExplanation,
                    style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                  ),
                ],
              ),
            ),
            AppButton(
              label: l10n.decree43ExemptionChangeBtn,
              icon: Icons.gavel_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: onRequestJustification,
            ),
          ],
        ),
      );
    }

    // Default: Decision Prompt Card with 2 choices
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.crimsonLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.crimsonBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.decree43WarningNotRegistered,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.crimson),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.decree43WarningNotRegisteredDesc,
            style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              AppButton(
                label: l10n.decree43OptionRequestJustification,
                icon: Icons.gavel_rounded,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: onRequestJustification,
              ),
              AppButton(
                label: l10n.decree43OptionCreateDashboardTask,
                icon: Icons.notification_add_rounded,
                variant: AppButtonVariant.warning,
                size: AppButtonSize.small,
                onPressed: onCreateDashboardTask,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
