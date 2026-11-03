import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../services/local_process_sync_service.dart';
import '../sync_console_widget.dart';
import '../sync_progress_and_diff_widget.dart';

/// Tab 1: Direct Operations & Visual Diff Inspector for ProductionSyncHubDialog
class SyncOperationsTab extends StatelessWidget {
  final bool isRunning;
  final String currentAction;
  final SyncProgressEvent? progress;
  final SyncDiffSummary? diffSummary;
  final List<ConsoleLogLine> consoleLogs;
  final VoidCallback onCompareDatabases;
  final VoidCallback onClearLogs;

  const SyncOperationsTab({
    super.key,
    required this.isRunning,
    required this.currentAction,
    required this.progress,
    required this.diffSummary,
    required this.consoleLogs,
    required this.onCompareDatabases,
    required this.onClearLogs,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      children: [
        // Action Buttons Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                ),
                icon: isRunning && currentAction == l.prodSyncCompareTablesBtn
                    ? const AppLoadingState.inline()
                    : const Icon(Icons.compare_arrows_rounded, size: 17),
                label: Text(
                  l.prodSyncCompareTablesBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: isRunning ? null : onCompareDatabases,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Visual Progress & Database Changes Diff Inspector
        SyncProgressAndDiffWidget(
          progress: progress,
          diffSummary: diffSummary,
          isRunning: isRunning,
          onCheckDiff: onCompareDatabases,
        ),
        const SizedBox(height: 10),

        // Live Console Terminal Output
        Expanded(
          child: SyncConsoleWidget(
            logs: consoleLogs,
            isRunning: isRunning,
            onClear: onClearLogs,
          ),
        ),
      ],
    );
  }
}
