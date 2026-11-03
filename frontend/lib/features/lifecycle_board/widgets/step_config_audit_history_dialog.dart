import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/step_config_model.dart';
import '../providers/step_config_provider.dart';

/// Modal dialog displaying the audit trail and historical policy modifications for a step config.
class StepConfigAuditHistoryDialog extends ConsumerWidget {
  final StepConfigModel config;

  const StepConfigAuditHistoryDialog({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: Color(0xFF2C3E50)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.stepConfigAuditDialogTitle(config.stepCode),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          height: 400,
          child: FutureBuilder<List<StepConfigAuditLogModel>>(
            future: ref.read(stepConfigProvider.notifier).fetchAuditLogs(config.stepCode),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingState();
              }
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return Center(
                  child: Text(
                    l.stepConfigAuditEmpty,
                    style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (ctx, idx) {
                  final item = logs[idx];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.stepConfigAuditBy(item.changedBy),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              item.changedAt,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              l.stepConfigAuditPolicyChange,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item.oldPolicy ?? "blocked"} → ${item.newPolicy ?? "blocked"}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.flatCobalt,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${l.stepConfigAuditJustification} ${item.justification}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.flatCobalt),
                                tooltip: l.stepConfigCopyRowTooltip,
                                onPressed: () {
                                  CopyHelper.copy(
                                    context,
                                    item.justification,
                                    customMessage: l.stepConfigCopyRowSuccess,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.stepConfigAuditCloseBtn),
          ),
        ],
      ),
    );
  }
}
