import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';

/// Collects a joint discrepancy / damage protocol (local, session-only
/// registry). Returns the new row, or null when cancelled.
Future<Map<String, dynamic>?> showAddDiscrepancyProtocolDialog(BuildContext context) async {
  final l = context.l10n;
  final formKey = GlobalKey<FormState>();
  final declCtrl = TextEditingController();
  final containerCtrl = TextEditingController();
  final damageTypeCtrl = TextEditingController();
  final damagedQtyCtrl = TextEditingController(text: '1');
  final lossCtrl = TextEditingController();
  final partyCtrl = TextEditingController();
  final committeeCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  String claimStatus = 'CLAIM_SUBMITTED';

  InputDecoration dec(BuildContext ctx, String label, TextEditingController c) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: l.discrepancyDamageCopyFieldTooltip,
          onPressed: () => CopyHelper.copy(ctx, c.text),
        ),
      );

  String? required(String? v) =>
      v == null || v.trim().isEmpty ? l.discrepancyDamageValidationRequired : null;

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.report_problem, color: AppTheme.crimson),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.discrepancyDamageAddDialogTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SelectionArea(
          child: SizedBox(
            width: (MediaQuery.of(ctx).size.width - 48).clamp(320.0, 560.0),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: declCtrl,
                            textDirection: TextDirection.ltr,
                            decoration: dec(ctx, l.discrepancyDamageFieldDeclarationNo, declCtrl),
                            validator: required,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: containerCtrl,
                            textDirection: TextDirection.ltr,
                            decoration: dec(ctx, l.discrepancyDamageFieldContainerNo, containerCtrl),
                            validator: required,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: damageTypeCtrl,
                            decoration: dec(ctx, l.discrepancyDamageFieldDamageType, damageTypeCtrl),
                            validator: required,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: damagedQtyCtrl,
                            textDirection: TextDirection.ltr,
                            decoration: dec(ctx, l.discrepancyDamageFieldDamagedQty, damagedQtyCtrl),
                            validator: required,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: lossCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textDirection: TextDirection.ltr,
                            decoration: dec(ctx, l.discrepancyDamageFieldEstimatedLoss, lossCtrl),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return l.discrepancyDamageValidationRequired;
                              }
                              final n = double.tryParse(v.trim());
                              if (n == null || n < 0) {
                                return l.discrepancyDamageValidationPositiveNumber;
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: partyCtrl,
                            decoration: dec(ctx, l.discrepancyDamageFieldResponsibleParty, partyCtrl),
                            validator: required,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: claimStatus,
                            isDense: false,
                            isRequired: true,
                            labelText: l.discrepancyDamageColClaimStatus,
                            decoration: InputDecoration(
                              labelText: l.discrepancyDamageColClaimStatus,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              SearchableDropdownItem(
                                value: 'CLAIM_SUBMITTED',
                                label: l.discrepancyDamageClaimSubmitted,
                              ),
                              SearchableDropdownItem(
                                value: 'APPROVED',
                                label: l.discrepancyDamageClaimApproved,
                              ),
                              SearchableDropdownItem(
                                value: 'UNDER_REVIEW',
                                label: l.discrepancyDamageClaimUnderReview,
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => claimStatus = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: committeeCtrl,
                            decoration: dec(ctx, l.discrepancyDamageFieldCommittee, committeeCtrl),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: dec(ctx, l.discrepancyDamageFieldNotes, notesCtrl),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          AppButton(
            label: l.cancel,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(ctx),
          ),
          AppButton(
            label: l.customsClearanceDamageSaveButton,
            icon: Icons.check,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, {
                'protocol_no': 'DMG-ALX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                'declaration_no': declCtrl.text.trim(),
                'container_no': containerCtrl.text.trim(),
                'damage_type': damageTypeCtrl.text.trim(),
                'damaged_qty': damagedQtyCtrl.text.trim(),
                'estimated_loss_egp': double.tryParse(lossCtrl.text.trim()) ?? 0.0,
                'responsible_party': partyCtrl.text.trim(),
                'insurance_claim_status': claimStatus,
                'committee': committeeCtrl.text.trim(),
                'date': DateTime.now().toString().substring(0, 10),
                'notes': notesCtrl.text.trim(),
              });
            },
          ),
        ],
      ),
    ),
  );

  declCtrl.dispose();
  containerCtrl.dispose();
  damageTypeCtrl.dispose();
  damagedQtyCtrl.dispose();
  lossCtrl.dispose();
  partyCtrl.dispose();
  committeeCtrl.dispose();
  notesCtrl.dispose();
  return result;
}
