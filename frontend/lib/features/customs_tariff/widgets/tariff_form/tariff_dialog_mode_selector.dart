import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class TariffDialogModeSelector extends StatelessWidget {
  final int activeModeIndex;
  final ValueChanged<int> onModeChanged;

  const TariffDialogModeSelector({
    super.key,
    required this.activeModeIndex,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onModeChanged(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: activeModeIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: activeModeIndex == 0
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.content_paste_go,
                      size: 16,
                      color: activeModeIndex == 0 ? AppTheme.cobalt : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.tariffModeSmartText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: activeModeIndex == 0 ? FontWeight.bold : FontWeight.normal,
                          color: activeModeIndex == 0 ? AppTheme.cobalt : Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => onModeChanged(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: activeModeIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: activeModeIndex == 1
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune,
                      size: 16,
                      color: activeModeIndex == 1 ? AppTheme.cobalt : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.tariffModeManualForm,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: activeModeIndex == 1 ? FontWeight.bold : FontWeight.normal,
                          color: activeModeIndex == 1 ? AppTheme.cobalt : Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
