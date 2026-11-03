import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../settlement_ui.dart';

class FinalSettlementSignoffForm extends StatelessWidget {
  final TextEditingController settledByController;
  final TextEditingController notesController;
  final double settlementReadinessPercent;
  final bool acknowledgeUnpaid;
  final ValueChanged<bool> onAcknowledgeChanged;

  const FinalSettlementSignoffForm({
    super.key,
    required this.settledByController,
    required this.notesController,
    required this.settlementReadinessPercent,
    required this.acknowledgeUnpaid,
    required this.onAcknowledgeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettlementPanel(
      filled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettlementSectionHeader(
            title: l10n.settlementClo01SignOffTitle,
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: settledByController,
                  decoration: InputDecoration(
                    labelText: l10n.settlementClo01SettledByLabel,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: l10n.settlementClo01NotesLabel,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.edit_note, size: 18),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (settlementReadinessPercent < 100.0) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => onAcknowledgeChanged(!acknowledgeUnpaid),
              child: Row(
                children: [
                  Checkbox(
                    key: const Key('acknowledgeUnpaidCheckbox'),
                    value: acknowledgeUnpaid,
                    onChanged: (val) => onAcknowledgeChanged(val ?? false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'إقرار بوجود فواتير ومصروفات غير مسددة (${settlementReadinessPercent.toStringAsFixed(1)}% جاهزية) والمتابعة في اعتماد التسوية',
                      style: const TextStyle(fontSize: 12, color: AppTheme.orange, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
