import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/customs_consultation_model.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/buttons/app_button.dart';

void showBlockingIssuesDialog(BuildContext context, List<CustomsChecklistItemModel> checklist, Function(List<CustomsChecklistItemModel>) onUpdate) {
  final l = context.l10n;
  final blockingItems = checklist.where((i) => i.isBlockingShipment && i.status != 'Approved').toList();

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.crimson, width: 1.5),
            ),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.crimson,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, color: AppTheme.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${l.blockingIssuesTitle} (${blockingItems.length})',
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.crimsonLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.crimsonBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppTheme.crimson, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.blockingConditionTooltip,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (blockingItems.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            l.clearanceReadyStatus,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                          ),
                        ),
                      )
                    else
                      ...blockingItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.charcoalSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.cloudWhite),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.crimson.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${idx + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: AppTheme.crimson,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: CopyableText(
                                      item.documentType,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: AppTheme.charcoal,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.orangeLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${l.statusCol}: ${item.status == 'Blocked' ? l.statusBlocked : (item.status == 'Pending' ? l.statusPending : (item.status == 'Action Required' ? l.statusActionRequired : item.status))}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: AppTheme.wcagOrange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${l.responsiblePartyLabel}: ${item.requiredText.isNotEmpty ? item.requiredText : (item.regulatoryAgency ?? "-")}',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textStrong),
                              ),
                              if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${l.notes}: ${item.remarks}',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal, fontStyle: FontStyle.italic),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AppButton(
                                    label: l.statusApproved,
                                    icon: Icons.check_circle_outline,
                                    variant: AppButtonVariant.success,
                                    size: AppButtonSize.small,
                                    onPressed: () {
                                      final realIndex = checklist.indexWhere((c) => c.documentType == item.documentType);
                                      if (realIndex != -1) {
                                        checklist[realIndex] = checklist[realIndex].copyWith(
                                          status: 'Approved',
                                          verifiedDate: DateTime.now().toString().split(' ')[0],
                                        );
                                      }
                                      onUpdate(checklist);
                                      setModalState(() {
                                        blockingItems.removeWhere((i) => i.documentType == item.documentType);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            actions: [
              AppButton(
                label: l.close,
                icon: Icons.check,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        },
      );
    },
  );
}

