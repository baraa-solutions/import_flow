import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';

InputDecoration _dec(BuildContext context, AppLocalizations l, String label, TextEditingController? copyOf) =>
    InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      suffixIcon: copyOf == null
          ? null
          : IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: l.drawingSamplesCopyFieldTooltip,
              onPressed: () => CopyHelper.copy(context, copyOf.text),
            ),
    );

List<Widget> _actions(
  BuildContext ctx,
  AppLocalizations l, {
  required String saveLabel,
  required VoidCallback onSave,
  AppButtonVariant variant = AppButtonVariant.primary,
}) =>
    [
      AppButton(
        label: l.cancel,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        onPressed: () => Navigator.pop(ctx),
      ),
      AppButton(
        label: saveLabel,
        icon: Icons.save,
        variant: variant,
        size: AppButtonSize.small,
        onPressed: onSave,
      ),
    ];

/// Collects a drawn-sample record. Returns the new row (local, session-only
/// registry) or null when cancelled.
Future<Map<String, dynamic>?> showAddSampleDialog(BuildContext context) async {
  final l = context.l10n;
  final formKey = GlobalKey<FormState>();
  final authCtrl = TextEditingController(text: l.ccSampleDefaultAuthority);
  final receiptCtrl = TextEditingController();
  final testTypeCtrl = TextEditingController(text: l.ccSampleDefaultTestType);
  final notesCtrl = TextEditingController();

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.science, color: AppTheme.cobalt),
          const SizedBox(width: 8),
          Expanded(child: Text(l.customsClearanceAddSampleDialogTitle)),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: (MediaQuery.of(ctx).size.width - 48).clamp(320.0, 520.0),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: authCtrl,
                    decoration: _dec(ctx, l, l.customsClearanceSampleAuthLabel, authCtrl),
                    validator: (v) => v == null || v.trim().isEmpty ? l.drawingSamplesValidationRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: receiptCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: _dec(ctx, l, l.customsClearanceSampleReceiptLabel, receiptCtrl),
                    validator: (v) => v == null || v.trim().isEmpty ? l.drawingSamplesValidationRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: testTypeCtrl,
                    decoration: _dec(ctx, l, l.customsClearanceSampleTestTypeLabel, testTypeCtrl),
                    validator: (v) => v == null || v.trim().isEmpty ? l.drawingSamplesValidationRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: _dec(ctx, l, l.customsClearanceSampleNotesLabel, notesCtrl),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: _actions(
        ctx,
        l,
        saveLabel: l.customsClearanceSampleSaveButton,
        onSave: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.pop(ctx, {
            'sample_id': 'SMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
            'authority': authCtrl.text.trim(),
            'drawing_date': DateTime.now().toString().substring(0, 10),
            'receipt_no': receiptCtrl.text.trim(),
            'test_type': testTypeCtrl.text.trim(),
            'status': 'PENDING',
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : '-',
          });
        },
      ),
    ),
  );

  authCtrl.dispose();
  receiptCtrl.dispose();
  testTypeCtrl.dispose();
  notesCtrl.dispose();
  return result;
}

/// Collects a shortage protocol (manifest vs landed quantity). Returns the new
/// row or null when cancelled.
Future<Map<String, dynamic>?> showAddShortageDialog(BuildContext context) async {
  final l = context.l10n;
  final formKey = GlobalKey<FormState>();
  final containerCtrl = TextEditingController();
  final itemDescCtrl = TextEditingController();
  final manifestQtyCtrl = TextEditingController();
  final landedQtyCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  String actionVal = 'DEDUCT_DUTY';

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: AppTheme.crimson),
            const SizedBox(width: 8),
            Expanded(child: Text(l.drawingSamplesAddShortageDialogTitle)),
          ],
        ),
        content: SelectionArea(
          child: SizedBox(
            width: (MediaQuery.of(ctx).size.width - 48).clamp(320.0, 540.0),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: containerCtrl,
                      textDirection: TextDirection.ltr,
                      decoration: _dec(ctx, l, l.drawingSamplesFieldContainerNo, containerCtrl),
                      validator: (v) => v == null || v.trim().isEmpty ? l.drawingSamplesValidationRequired : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: itemDescCtrl,
                      decoration: _dec(ctx, l, l.drawingSamplesFieldItemDesc, itemDescCtrl),
                      validator: (v) => v == null || v.trim().isEmpty ? l.drawingSamplesValidationRequired : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: manifestQtyCtrl,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            decoration: _dec(ctx, l, l.drawingSamplesFieldManifestQty, manifestQtyCtrl),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return l.drawingSamplesValidationRequired;
                              final n = double.tryParse(v);
                              if (n == null || n <= 0) return l.drawingSamplesValidationPositiveNumber;
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: landedQtyCtrl,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            decoration: _dec(ctx, l, l.drawingSamplesFieldLandedQty, landedQtyCtrl),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return l.drawingSamplesValidationRequired;
                              final landed = double.tryParse(v);
                              if (landed == null || landed < 0) return l.drawingSamplesValidationPositiveNumber;
                              final manifest = double.tryParse(manifestQtyCtrl.text);
                              if (manifest != null && landed > manifest) {
                                return l.drawingSamplesValidationLandedExceeds;
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: actionVal,
                      isDense: false,
                      isRequired: true,
                      labelText: l.drawingSamplesColShortageAction,
                      decoration: InputDecoration(
                        labelText: l.drawingSamplesColShortageAction,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        SearchableDropdownItem(
                          value: 'DEDUCT_DUTY',
                          label: l.drawingSamplesShortageActionDeductDuty,
                        ),
                        SearchableDropdownItem(
                          value: 'CARRIER_CLAIM',
                          label: l.drawingSamplesShortageActionCarrierClaim,
                        ),
                        SearchableDropdownItem(
                          value: 'SURVEY_ENDORSED',
                          label: l.drawingSamplesShortageActionSurveyEndorsement,
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => actionVal = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: _dec(ctx, l, l.drawingSamplesColShortageNotes, notesCtrl),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: _actions(
          ctx,
          l,
          saveLabel: l.save,
          variant: AppButtonVariant.danger,
          onSave: () {
            if (!formKey.currentState!.validate()) return;
            final manifest = double.tryParse(manifestQtyCtrl.text) ?? 0;
            final landed = double.tryParse(landedQtyCtrl.text) ?? 0;
            final shortage = (manifest - landed).clamp(0, double.infinity);
            final pct = manifest > 0 ? ((shortage / manifest) * 100).toStringAsFixed(1) : '0.0';
            Navigator.pop(ctx, {
              'shortage_id': 'SHR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
              'container_no': containerCtrl.text.trim(),
              'item_desc': itemDescCtrl.text.trim(),
              'manifest_qty': manifest.toStringAsFixed(0),
              'landed_qty': landed.toStringAsFixed(0),
              'shortage_qty': shortage.toStringAsFixed(0),
              'shortage_pct': pct,
              'action': actionVal,
              'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : '-',
            });
          },
        ),
      ),
    ),
  );

  containerCtrl.dispose();
  itemDescCtrl.dispose();
  manifestQtyCtrl.dispose();
  landedQtyCtrl.dispose();
  notesCtrl.dispose();
  return result;
}
