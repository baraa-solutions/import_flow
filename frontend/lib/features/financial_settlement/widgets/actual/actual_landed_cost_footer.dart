import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../settlement_ui.dart';

/// Footer approval bar with user & notes inputs for Actual Landed Cost calculation
class ActualLandedCostFooter extends StatelessWidget {
  final TextEditingController approvedByController;
  final TextEditingController notesController;
  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onApprove;

  const ActualLandedCostFooter({
    super.key,
    required this.approvedByController,
    required this.notesController,
    required this.isSubmitting,
    required this.onCancel,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: SettlementTokens.panelFill,
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(12),
          bottomEnd: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: SettlementTokens.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  key: const Key('actualLandedCostApprovedByField'),
                  controller: approvedByController,
                  decoration: InputDecoration(
                    labelText: l10n.settlementClo02ApprovedByLabel,
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: TextField(
                  key: const Key('actualLandedCostNotesField'),
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: l10n.settlementClo02NotesLabel,
                    prefixIcon: const Icon(Icons.notes, size: 18),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SettlementFit(
                child: AppButton(
                  key: const Key('actualLandedCostCancelBtn'),
                  label: l10n.settlementCancel,
                  icon: Icons.cancel_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: isSubmitting ? null : onCancel,
                ),
              ),
              const SizedBox(width: 12),
              SettlementFit(
                child: AppButton(
                  key: const Key('actualLandedCostApproveBtn'),
                  label: isSubmitting ? l10n.settlementClo02Approving : l10n.settlementClo02Approve,
                  icon: Icons.verified,
                  variant: AppButtonVariant.success,
                  isLoading: isSubmitting,
                  onPressed: isSubmitting ? null : onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
