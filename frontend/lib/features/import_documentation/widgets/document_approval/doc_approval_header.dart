import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class DocApprovalHeader extends StatelessWidget {
  final int activeViewIndex;
  final ValueChanged<int> onViewChanged;

  const DocApprovalHeader({
    super.key,
    required this.activeViewIndex,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                key: const Key('dualSignoffChoiceChip'),
                avatar: Icon(
                  Icons.verified_user,
                  size: 16,
                  color: activeViewIndex == 0 ? AppTheme.white : AppTheme.cobalt,
                ),
                label: Text(
                  context.l10n.customsApprovalTabDualSignoff,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                selected: activeViewIndex == 0,
                selectedColor: AppTheme.cobalt,
                labelStyle: TextStyle(
                  color: activeViewIndex == 0 ? AppTheme.white : AppTheme.textPrimaryOf(context),
                ),
                onSelected: (selected) {
                  if (selected) onViewChanged(0);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                key: const Key('centralArchiveChoiceChip'),
                avatar: Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: activeViewIndex == 1 ? AppTheme.white : AppTheme.emerald,
                ),
                label: Text(
                  context.l10n.customsApprovalTabCentralArchive,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                selected: activeViewIndex == 1,
                selectedColor: AppTheme.emerald,
                labelStyle: TextStyle(
                  color: activeViewIndex == 1 ? AppTheme.white : AppTheme.textPrimaryOf(context),
                ),
                onSelected: (selected) {
                  if (selected) onViewChanged(1);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
