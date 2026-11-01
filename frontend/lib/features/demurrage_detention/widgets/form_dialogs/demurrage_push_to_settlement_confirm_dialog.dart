import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../models/demurrage_model.dart';

/// Confirm posting demurrage/detention charges to a linked import file's financial settlement.
class DemurragePushToSettlementConfirmDialog extends StatelessWidget {
  const DemurragePushToSettlementConfirmDialog({
    super.key,
    required this.item,
  });

  final DemurrageTrackingModel item;

  static Future<bool?> show(BuildContext context, DemurrageTrackingModel item) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DemurragePushToSettlementConfirmDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fileCode = item.importFileCode ?? (item.importFileId != null ? '#${item.importFileId}' : '-');
    final rateStr = item.exchangeRate != null ? item.exchangeRate!.toStringAsFixed(4) : '-';

    return SelectionArea(
      child: CcStageDialogShell(
        key: const Key('pushToSettlementConfirmDialog'),
        title: l.demPushConfirmTitle,
        icon: Icons.receipt_long_rounded,
        accent: AppTheme.emerald,
        maxWidth: 520,
        confirmLabel: l.demPushConfirmBtn,
        confirmVariant: AppButtonVariant.success,
        confirmIcon: Icons.receipt_long_rounded,
        confirmKey: const Key('pushToSettlementConfirmBtn'),
        cancelKey: const Key('pushToSettlementCancelBtn'),
        isSubmitting: false,
        onConfirm: () => Navigator.of(context).pop(true),
        chips: [
          CcHeaderChip(Icons.folder_outlined, fileCode, ltr: true),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                l.demPushConfirmMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CcFormSection(
              title: l.totalEstimatedCostLabel,
              icon: Icons.monetization_on_outlined,
              child: Column(
                children: [
                  CcFieldRow(
                    children: [
                      CcFact(
                        label: l.demPushConfirmFileCode,
                        value: fileCode,
                        mono: true,
                      ),
                      CcFact(
                        label: l.demPushConfirmRate,
                        value: rateStr,
                        mono: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CcFieldRow(
                    children: [
                      CcFact(
                        label: l.demPushConfirmDemurrageFx,
                        value: '${item.totalDemurrageFx.toStringAsFixed(2)} ${item.currency}',
                        mono: true,
                      ),
                      CcFact(
                        label: l.demPushConfirmDetentionFx,
                        value: '${item.totalDetentionFx.toStringAsFixed(2)} ${item.currency}',
                        mono: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CcFieldRow(
                    children: [
                      CcFact(
                        label: l.demPushConfirmStorageEgp,
                        value: '${item.totalStorageEgp.toStringAsFixed(2)} EGP',
                        mono: true,
                      ),
                      CcFact(
                        label: l.demPushConfirmTotalEgp,
                        value: '${item.totalCostEgp.toStringAsFixed(2)} EGP',
                        mono: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
