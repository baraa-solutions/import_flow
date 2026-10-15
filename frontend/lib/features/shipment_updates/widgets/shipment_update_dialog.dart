import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../providers/shipment_updates_provider.dart';

class ShipmentUpdateDialog extends ConsumerStatefulWidget {
  final int? initialFileId;
  final String? initialFileCode;
  final String? initialTargetPhase;
  final String? defaultCategory;

  const ShipmentUpdateDialog({
    super.key,
    this.initialFileId,
    this.initialFileCode,
    this.initialTargetPhase,
    this.defaultCategory,
  });

  static Future<void> show(
    BuildContext context, {
    int? initialFileId,
    String? initialFileCode,
    String? initialTargetPhase,
    String? defaultCategory,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShipmentUpdateDialog(
        initialFileId: initialFileId,
        initialFileCode: initialFileCode,
        initialTargetPhase: initialTargetPhase,
        defaultCategory: defaultCategory,
      ),
    );
  }

  @override
  ConsumerState<ShipmentUpdateDialog> createState() => _ShipmentUpdateDialogState();
}

class _ShipmentUpdateDialogState extends ConsumerState<ShipmentUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _noteController;
  late TextEditingController _dateController;
  late TextEditingController _costItemController;
  late TextEditingController _newCostController;

  int? _selectedFileId;
  String? _selectedFileCode;
  String _selectedPhase = 'Phase 1';
  String _updateCategory = 'Follow-up & Notes';
  String _alertPriority = 'Normal';
  bool _isSubmitting = false;

  static const List<String> _phaseCodes = [
    'Phase 1',
    'Phase 2',
    'Phase 3',
    'Phase 4',
    'Phase 5',
    'Phase 6',
    'Phase 7',
    'Phase 8',
    'Phase 9',
    'Phase 10',
  ];

  String _getPhaseName(AppLocalizations l, String code) {
    switch (code) {
      case 'Phase 1':
        return l.shipmentUpdatePhase1Name;
      case 'Phase 2':
        return l.shipmentUpdatePhase2Name;
      case 'Phase 3':
        return l.shipmentUpdatePhase3Name;
      case 'Phase 4':
        return l.shipmentUpdatePhase4Name;
      case 'Phase 5':
        return l.shipmentUpdatePhase5Name;
      case 'Phase 6':
        return l.shipmentUpdatePhase6Name;
      case 'Phase 7':
        return l.shipmentUpdatePhase7Name;
      case 'Phase 8':
        return l.shipmentUpdatePhase8Name;
      case 'Phase 9':
        return l.shipmentUpdatePhase9Name;
      case 'Phase 10':
        return l.shipmentUpdatePhase10Name;
      default:
        return code;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFileId = widget.initialFileId;
    _selectedFileCode = widget.initialFileCode;
    _selectedPhase = widget.initialTargetPhase ?? 'Phase 1';
    _updateCategory = widget.defaultCategory ?? 'Follow-up & Notes';

    _noteController = TextEditingController();
    _dateController = TextEditingController(text: DateTime.now().toString().split(' ')[0]);
    _costItemController = TextEditingController();
    _newCostController = TextEditingController(text: '0.0');
  }

  @override
  void dispose() {
    _noteController.dispose();
    _dateController.dispose();
    _costItemController.dispose();
    _newCostController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFileId == null || _selectedFileCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.shipmentUpdateFieldShipmentRequired, severity: AppSeverity.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'import_file_id': _selectedFileId,
        'import_file_code': _selectedFileCode,
        'update_category': _updateCategory,
        'target_phase': _selectedPhase,
        'phase_status': 'Current',
        'log_date': _dateController.text,
        'note': _noteController.text.trim(),
        'adjusted_cost_item': _updateCategory == 'Phase Cost Adjustment' ? _costItemController.text.trim() : null,
        'new_cost': _updateCategory == 'Phase Cost Adjustment' ? double.tryParse(_newCostController.text) ?? 0.0 : 0.0,
        'alert_priority': _updateCategory == 'Future Phase Alert' ? _alertPriority : 'Normal',
      };

      await ref.read(shipmentUpdatesProvider.notifier).createLog(payload);
      // The update can move the file's current module / notes.
      ref.invalidate(importFilesProvider);
      ref.invalidate(lifecycleBoardSummaryProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.shipmentUpdateSuccessSaved, severity: AppSeverity.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, ApiErrorText.of(l, e), severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _copySuffix(AppLocalizations l, TextEditingController c) {
    return IconButton(
      icon: const Icon(Icons.copy_rounded, size: 16),
      tooltip: l.shipmentUpdateCopyFieldTooltip,
      onPressed: () => CopyHelper.copy(context, c.text, customMessage: l.shipmentUpdateCopyFieldTooltip),
    );
  }

  Widget _costField(AppLocalizations l, String label, TextEditingController c, {bool numeric = true}) {
    return CcField(
      label: label,
      child: TextFormField(
        controller: c,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: ccInputDecoration(suffix: _copySuffix(l, c)),
      ),
    );
  }

  Widget _readOnlyCostField(AppLocalizations l, String label, String value) {
    return CcField(
      label: label,
      child: TextFormField(
        key: ValueKey('prev_cost_${_selectedFileId ?? 0}_$value'),
        initialValue: value,
        readOnly: true,
        enabled: false,
        decoration: ccInputDecoration(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFilesState = ref.watch(importFilesProvider);

    ImportFileModel? selectedFile;
    importFilesState.whenData((files) {
      for (final f in files) {
        if (f.importFileId == _selectedFileId) {
          selectedFile = f;
          break;
        }
      }
    });
    final currentCostText = selectedFile != null
        ? '${selectedFile!.estimatedCost.toStringAsFixed(2)} ${selectedFile!.estimatedCostCurrency}'
        : '0.00';

    return SelectionArea(
      child: Form(
        key: _formKey,
        child: CcStageDialogShell(
          title: l.shipmentUpdateDialogTitle,
          icon: Icons.published_with_changes,
          maxWidth: 680,
          chips: [
            if (_selectedFileCode != null && _selectedFileCode!.isNotEmpty)
              CcHeaderChip(Icons.folder_open_outlined, _selectedFileCode!, ltr: true),
          ],
          confirmLabel: l.shipmentUpdateBtnSaveUpdate,
          confirmIcon: Icons.check,
          confirmVariant: AppButtonVariant.primary,
          cancelKey: const Key('shipmentUpdateCancelBtn'),
          confirmKey: const Key('shipmentUpdateSaveBtn'),
          isSubmitting: _isSubmitting,
          onConfirm: _submit,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CcFormSection(
                title: l.suSectionShipment,
                icon: Icons.local_shipping_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    importFilesState.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (files) {
                        return SearchableDropdownField<int>(
                          value: _selectedFileId,
                          labelText: l.shipmentUpdateFieldShipmentLabel,
                          items: files
                              .map((f) => SearchableDropdownItem<int>(
                                    value: f.importFileId,
                                    label: '${f.primaryNameWithCode} - ${f.supplierName} (${f.currentModule})',
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedFileId = val;
                              if (val != null) {
                                final sel = files.firstWhere((f) => f.importFileId == val);
                                _selectedFileCode = sel.importFileCode;
                              }
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    CcFieldRow(
                      gap: 14,
                      children: [
                        SearchableDropdownField<String>(
                          value: _updateCategory,
                          labelText: l.shipmentUpdateFieldCategoryLabel,
                          items: [
                            SearchableDropdownItem(value: 'Follow-up & Notes', label: l.shipmentUpdateCatOptFollowUp),
                            SearchableDropdownItem(value: 'Phase Cost Adjustment', label: l.shipmentUpdateCatOptCostAdjustment),
                            SearchableDropdownItem(value: 'Future Phase Alert', label: l.shipmentUpdateCatOptFutureAlert),
                            SearchableDropdownItem(value: 'Daily Check-in', label: l.shipmentUpdateCatOptDailyCheckin),
                          ],
                          onChanged: (v) => setState(() => _updateCategory = v ?? _updateCategory),
                        ),
                        SearchableDropdownField<String>(
                          value: _selectedPhase,
                          labelText: l.shipmentUpdateFieldTargetStageLabel,
                          items: _phaseCodes
                              .map((code) => SearchableDropdownItem(value: code, label: _getPhaseName(l, code)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedPhase = v ?? _selectedPhase),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_updateCategory == 'Phase Cost Adjustment') ...[
                const SizedBox(height: 14),
                CcFormSection(
                  title: l.shipmentUpdateCatOptCostAdjustment,
                  icon: Icons.price_change_outlined,
                  accent: AppTheme.orange,
                  child: CcFieldRow(
                    gap: 12,
                    children: [
                      _costField(l, l.shipmentUpdateFieldCostItemLabel, _costItemController, numeric: false),
                      _readOnlyCostField(l, l.shipmentUpdateFieldPrevCostLabel, currentCostText),
                      _costField(l, l.shipmentUpdateFieldNewCostLabel, _newCostController),
                    ],
                  ),
                ),
              ],
              if (_updateCategory == 'Future Phase Alert') ...[
                const SizedBox(height: 14),
                CcFormSection(
                  title: l.shipmentUpdateCatOptFutureAlert,
                  icon: Icons.notification_important_outlined,
                  accent: AppTheme.orange,
                  child: SearchableDropdownField<String>(
                    value: _alertPriority,
                    labelText: l.shipmentUpdateFieldAlertPriorityLabel,
                    items: [
                      SearchableDropdownItem(value: 'Low', label: l.shipmentUpdatePriorityLow),
                      SearchableDropdownItem(value: 'Normal', label: l.shipmentUpdatePriorityNormal),
                      SearchableDropdownItem(value: 'High', label: l.shipmentUpdatePriorityHigh),
                      SearchableDropdownItem(value: 'Critical', label: l.shipmentUpdatePriorityCritical),
                    ],
                    onChanged: (v) => setState(() => _alertPriority = v ?? _alertPriority),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              CcFormSection(
                title: l.suSectionDetails,
                icon: Icons.notes_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CcField(
                      label: l.shipmentUpdateFieldDateLabel,
                      child: TextFormField(
                        controller: _dateController,
                        textDirection: TextDirection.ltr,
                        decoration: ccInputDecoration(
                          prefix: Icons.event,
                          suffix: _copySuffix(l, _dateController),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    CcField(
                      label: l.shipmentUpdateFieldNotesLabel,
                      child: TextFormField(
                        controller: _noteController,
                        maxLines: 3,
                        decoration: ccInputDecoration(
                          hint: l.shipmentUpdateFieldNotesHint,
                          suffix: _copySuffix(l, _noteController),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l.shipmentUpdateFieldNotesRequired : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
