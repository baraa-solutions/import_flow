import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../services/local_process_sync_service.dart';
import 'production_sync_db_card.dart';
import 'sync_console_widget.dart';
import 'sync_progress_and_diff_widget.dart';

/// Tab 2: Developer Operations, DB comparisons, and real-time diff & console.
class ProductionSyncDevOperationsTab extends StatelessWidget {
  final LocalProcessSyncService service;
  final LocalDbStats devStats;
  final LocalDbStats prodStats;
  final bool isRunning;
  final SyncProgressEvent? progress;
  final SyncDiffSummary? diffSummary;
  final List<ConsoleLogLine> consoleLogs;
  final AppLocalizations l;
  final VoidCallback onCompareDatabases;
  final VoidCallback onClearLogs;

  const ProductionSyncDevOperationsTab({
    super.key,
    required this.service,
    required this.devStats,
    required this.prodStats,
    required this.isRunning,
    required this.progress,
    required this.diffSummary,
    required this.consoleLogs,
    required this.l,
    required this.onCompareDatabases,
    required this.onClearLogs,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // DB Status Cards
                  Row(
                    children: [
                      Expanded(
                        child: ProductionSyncDbCard(
                          title: l.prodSyncDevDbTitle,
                          path: service.devDbPath,
                          stats: devStats,
                          color: AppTheme.cobalt,
                          icon: Icons.code_rounded,
                          l: l,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ProductionSyncDbCard(
                          title: l.prodSyncProdDbTitle,
                          path: service.prodDbPath,
                          stats: prodStats,
                          color: AppTheme.emerald,
                          icon: Icons.desktop_windows_rounded,
                          l: l,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Action Buttons Row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.compare_arrows_rounded, size: 16),
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

                  // Visual Progress & Diff Inspector
                  SyncProgressAndDiffWidget(
                    progress: progress,
                    diffSummary: diffSummary,
                    isRunning: isRunning,
                    onCheckDiff: onCompareDatabases,
                  ),
                  const SizedBox(height: 8),

                  // Live Console Terminal Output
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 180),
                      child: SyncConsoleWidget(
                        logs: consoleLogs,
                        isRunning: isRunning,
                        onClear: onClearLogs,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
