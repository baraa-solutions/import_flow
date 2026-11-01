import 'package:flutter/material.dart';

import '../../../features/import_files/models/import_file_model.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../copyable_data_helper.dart';

class LifecycleCompletionBar extends StatelessWidget {
  final ImportFileModel file;
  final bool isAr;
  final AppLocalizations l;

  const LifecycleCompletionBar({
    super.key,
    required this.file,
    required this.isAr,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final completedSteps = (file.progressPercent / 10).round().clamp(0, 10);
    final percent = file.progressPercent.round().clamp(0, 100);

    // Tone cue colors & icons: 0-39% 🔴 | 40-74% 🟡 | 75-99% 🟢 | 100% ✅
    final Color toneColor;
    final String toneIcon;
    if (percent >= 100) {
      toneColor = AppTheme.emerald;
      toneIcon = '✅';
    } else if (percent >= 75) {
      toneColor = AppTheme.emerald;
      toneIcon = '🟢';
    } else if (percent >= 40) {
      toneColor = AppTheme.orange;
      toneIcon = '🟡';
    } else {
      toneColor = AppTheme.crimson;
      toneIcon = '🔴';
    }

    if (percent >= 100) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.emeraldLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.emeraldBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded,
                color: AppTheme.emerald, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isAr
                    ? l.aiLifecycleAllCompleted
                    : 'All shipment stages successfully completed (100%).',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr
                    ? l.aiLifecycleCompletionRate(
                        toneIcon, percent, completedSteps, 10)
                    : 'Completion Rate: $toneIcon $percent% ($completedSteps of 10 steps)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: toneColor,
                ),
              ),
              InkWell(
                onTap: () => CopyHelper.copy(
                  context,
                  file.importFileCode,
                  customMessage: isAr
                      ? l.aiLifecycleFileCodeCopied
                      : 'File code copied to clipboard',
                ),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          file.customFileNumber?.isNotEmpty == true
                              ? file.customFileNumber!
                              : file.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.copy_rounded,
                          size: 11, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 10-block visual progress bar
          Row(
            children: List.generate(10, (index) {
              final isFilled = index < completedSteps;
              return Expanded(
                child: Container(
                  height: 6,
                  margin:
                      EdgeInsetsDirectional.only(end: index < 9 ? 2 : 0),
                  decoration: BoxDecoration(
                    color: isFilled ? toneColor : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
