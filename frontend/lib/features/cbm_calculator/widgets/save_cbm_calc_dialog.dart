import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/stored_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/cbm_calculator_model.dart';
import '../providers/cbm_calculator_provider.dart';

/// 💾 Save CBM Calculation Session Dialog
///
/// Encapsulates text editing controllers, validation, and session creation/updating.
class SaveCbmCalcDialog extends ConsumerStatefulWidget {
  final List<CBMItemModel> items;
  final bool isStackable;
  final String quickShipmentMode;
  final int? activeSessionId;
  final String? activeSessionCode;
  final String? activeSessionTitle;
  final String? activeSessionNotes;
  final int? activeSessionImportFileId;
  final VoidCallback onSavedSuccess;
  final VoidCallback onClearActiveSession;

  const SaveCbmCalcDialog({
    super.key,
    required this.items,
    required this.isStackable,
    required this.quickShipmentMode,
    this.activeSessionId,
    this.activeSessionCode,
    this.activeSessionTitle,
    this.activeSessionNotes,
    this.activeSessionImportFileId,
    required this.onSavedSuccess,
    required this.onClearActiveSession,
  });

  static void show(
    BuildContext context, {
    required List<CBMItemModel> items,
    required bool isStackable,
    required String quickShipmentMode,
    int? activeSessionId,
    String? activeSessionCode,
    String? activeSessionTitle,
    String? activeSessionNotes,
    int? activeSessionImportFileId,
    required VoidCallback onSavedSuccess,
    required VoidCallback onClearActiveSession,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: SaveCbmCalcDialog(
          items: items,
          isStackable: isStackable,
          quickShipmentMode: quickShipmentMode,
          activeSessionId: activeSessionId,
          activeSessionCode: activeSessionCode,
          activeSessionTitle: activeSessionTitle,
          activeSessionNotes: activeSessionNotes,
          activeSessionImportFileId: activeSessionImportFileId,
          onSavedSuccess: onSavedSuccess,
          onClearActiveSession: onClearActiveSession,
        ),
      ),
    );
  }

  @override
  ConsumerState<SaveCbmCalcDialog> createState() => _SaveCbmCalcDialogState();
}

class _SaveCbmCalcDialogState extends ConsumerState<SaveCbmCalcDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  int? _selectedImportFileId;

  @override
  void initState() {
    super.initState();
    final isEditing = widget.activeSessionId != null;
    _titleCtrl = TextEditingController(
      text: isEditing
          ? (widget.activeSessionTitle ?? storedText.calculationSessionTitle)
          : storedText.calculationSessionTitle,
    );
    _notesCtrl = TextEditingController(text: isEditing ? (widget.activeSessionNotes ?? '') : '');
    _selectedImportFileId = isEditing ? widget.activeSessionImportFileId : null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.activeSessionId != null;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_document : Icons.save_outlined,
            color: isEditing ? AppTheme.wcagOrange : AppTheme.emerald,
          ),
          const SizedBox(width: 8),
          Text(
            isEditing
                ? '${l.saveChangesInSession} [${widget.activeSessionCode ?? ""}]'
                : l.saveCalculationSession,
            style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEditing)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.wcagOrange.withValues(alpha: 0.2) : AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.wcagOrange),
                  ),
                  child: Text(
                    l.activeEditSessionHint,
                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.wcagOrange),
                  ),
                ),
              SearchableDropdownField<int?>(
                value: _selectedImportFileId,
                labelText: l.importFileIdLabel,
                searchHintText: l.importFileIdLabel,
                items: [
                  SearchableDropdownItem<int?>(
                    value: null,
                    label: '-- ${l.allStatuses} --',
                  ),
                  ...importFiles.map((f) => SearchableDropdownItem<int?>(
                        value: f.importFileId,
                        label: '${f.primaryNameWithCode} - ${f.companyName}',
                        subtitle: f.companyName,
                      )),
                ],
                onChanged: (v) => setState(() => _selectedImportFileId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(labelText: '${l.calculationSessionTitle} *'),
                validator: (v) => v == null || v.trim().isEmpty ? l.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(labelText: l.notesAndCargoRemarks),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l.cancel,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () => Navigator.pop(context),
        ),
        if (isEditing) ...[
          AppButton(
            label: l.saveAsNewSession,
            icon: Icons.copy,
            variant: AppButtonVariant.primary,
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final calc = CBMCalculationModel(
                  calcCode: '',
                  importFileId: _selectedImportFileId,
                  title: _titleCtrl.text.trim(),
                  notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                  isStackable: widget.isStackable,
                  shipmentMode: widget.quickShipmentMode.toUpperCase(),
                  items: widget.items,
                );
                final ok = await ref.read(cbmCalculatorProvider.notifier).createCalculation(calc);
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  widget.onClearActiveSession();
                  AppTheme.snackBar(context, l.operationSuccessful, severity: AppSeverity.success);
                  widget.onSavedSuccess();
                } else if (context.mounted) {
                  final err = ref.read(cbmCalculatorProvider).errorText(l);
                  AppTheme.snackBar(context, err, severity: AppSeverity.danger);
                }
              }
            },
          ),
          const SizedBox(width: 6),
          AppButton(
            label: '${l.saveChangesInSession} [${widget.activeSessionCode ?? ""}]',
            icon: Icons.check,
            variant: AppButtonVariant.success,
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final payload = {
                  'title': _titleCtrl.text.trim(),
                  'import_file_id': _selectedImportFileId,
                  'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                  'is_stackable': widget.isStackable,
                  'shipment_mode': widget.quickShipmentMode.toUpperCase(),
                  'items': widget.items.map((i) => i.toCreateJson()).toList(),
                };
                final ok = await ref.read(cbmCalculatorProvider.notifier).updateCalculation(widget.activeSessionId!, payload);
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  AppTheme.snackBar(
                    context,
                    '${l.saveChangesInSession} [${widget.activeSessionCode ?? ""}]',
                    severity: AppSeverity.success,
                  );
                  widget.onSavedSuccess();
                } else if (context.mounted) {
                  final err = ref.read(cbmCalculatorProvider).errorText(l);
                  AppTheme.snackBar(context, err, severity: AppSeverity.danger);
                }
              }
            },
          ),
        ] else ...[
          AppButton(
            label: l.saveChanges,
            icon: Icons.save,
            variant: AppButtonVariant.success,
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final calc = CBMCalculationModel(
                  calcCode: '',
                  importFileId: _selectedImportFileId,
                  title: _titleCtrl.text.trim(),
                  notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                  isStackable: widget.isStackable,
                  shipmentMode: widget.quickShipmentMode.toUpperCase(),
                  items: widget.items,
                );
                final ok = await ref.read(cbmCalculatorProvider.notifier).createCalculation(calc);
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  AppTheme.snackBar(context, l.operationSuccessful, severity: AppSeverity.success);
                  widget.onSavedSuccess();
                } else if (context.mounted) {
                  final err = ref.read(cbmCalculatorProvider).errorText(l);
                  AppTheme.snackBar(context, err, severity: AppSeverity.danger);
                }
              }
            },
          ),
        ],
      ],
    );
  }
}
