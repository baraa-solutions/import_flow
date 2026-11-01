import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../core/widgets/smart_upload_button.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/customs_clearance_model.dart';
import '../../providers/customs_clearance_provider.dart';
import '../customs_ui.dart';
import 'clearance_dialog_actions.dart';

/// Create / edit / clone dialog of a clearance record.
class ClearanceFormDialog extends ConsumerStatefulWidget {
  const ClearanceFormDialog({super.key, this.recordToEdit, this.isCloneDraft = false});

  final CustomsClearanceModel? recordToEdit;
  final bool isCloneDraft;

  @override
  ConsumerState<ClearanceFormDialog> createState() => _ClearanceFormDialogState();
}

class _ClearanceFormDialogState extends ConsumerState<ClearanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedImportFileId;
  final TextEditingController _decl46Ctrl = TextEditingController();
  final TextEditingController _officeCtrl = TextEditingController(text: 'Alexandria Port Customs');
  final TextEditingController _doNumberCtrl = TextEditingController();
  final TextEditingController _freeDaysCtrl = TextEditingController(text: '14');
  String _channelType = 'Red Channel';
  final TextEditingController _dutyCtrl = TextEditingController(text: '0');
  final TextEditingController _vatCtrl = TextEditingController(text: '0');
  final TextEditingController _scheduleTaxCtrl = TextEditingController(text: '0');
  final TextEditingController _whtCtrl = TextEditingController(text: '0');
  final TextEditingController _labFeesCtrl = TextEditingController(text: '0');
  final TextEditingController _estimatedDutyCtrl = TextEditingController(text: '0');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recordToEdit;
    if (r != null) {
      _selectedImportFileId = widget.isCloneDraft ? null : r.importFileId;
      _decl46Ctrl.text = widget.isCloneDraft ? '' : (r.declaration46No ?? '');
      _officeCtrl.text = r.customsOfficeName;
      _doNumberCtrl.text = widget.isCloneDraft ? '' : (r.deliveryOrderNumber ?? '');
      _freeDaysCtrl.text = r.freeDaysAllowed.toString();
      _channelType = r.channelType;
      _dutyCtrl.text = r.importDutyAmount.toString();
      _vatCtrl.text = r.vatAmount.toString();
      _scheduleTaxCtrl.text = r.scheduleTaxAmount.toString();
      _whtCtrl.text = r.whtAmount.toString();
      _labFeesCtrl.text = r.labServiceFees.toString();
      _estimatedDutyCtrl.text = r.estimatedDutyTotal.toString();
    }
  }

  void _applyExtractedNafezaData(Map<String, dynamic> ext, AppLocalizations l) {
    setState(() {
      if (ext['declaration_no'] != null && ext['declaration_no'].toString().isNotEmpty) {
        _decl46Ctrl.text = ext['declaration_no'].toString();
      }
      if (ext['customs_office_name'] != null && ext['customs_office_name'].toString().isNotEmpty) {
        _officeCtrl.text = ext['customs_office_name'].toString();
      }
      if (ext['channel_type'] != null && ext['channel_type'].toString().isNotEmpty) {
        _channelType = ext['channel_type'].toString();
      }
      if (ext['import_duty'] != null) _dutyCtrl.text = ext['import_duty'].toString();
      if (ext['vat_amount'] != null) _vatCtrl.text = ext['vat_amount'].toString();
      if (ext['schedule_tax'] != null) _scheduleTaxCtrl.text = ext['schedule_tax'].toString();
      if (ext['wht_amount'] != null) _whtCtrl.text = ext['wht_amount'].toString();
      if (ext['lab_service_fees'] != null) _labFeesCtrl.text = ext['lab_service_fees'].toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, l.customsClearanceExtractNafezaSuccess, severity: AppSeverity.success),
    );
  }

  @override
  void dispose() {
    _decl46Ctrl.dispose();
    _officeCtrl.dispose();
    _doNumberCtrl.dispose();
    _freeDaysCtrl.dispose();
    _dutyCtrl.dispose();
    _vatCtrl.dispose();
    _scheduleTaxCtrl.dispose();
    _whtCtrl.dispose();
    _labFeesCtrl.dispose();
    _estimatedDutyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations l) async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isCloneDraft &&
        widget.recordToEdit != null &&
        _selectedImportFileId == widget.recordToEdit!.importFileId) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.isArabic
              ? 'الاستنساخ متاح لشحنة أخرى فقط، لا يمكن استنساخ البيان لنفس ملف الشحنة.'
              : 'Cloning is only allowed to a different shipment file.',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final duty = double.tryParse(_dutyCtrl.text) ?? 0.0;
    final vat = double.tryParse(_vatCtrl.text) ?? 0.0;
    final sched = double.tryParse(_scheduleTaxCtrl.text) ?? 0.0;
    final wht = double.tryParse(_whtCtrl.text) ?? 0.0;
    final lab = double.tryParse(_labFeesCtrl.text) ?? 0.0;
    final total = duty + vat + sched + wht + lab;

    final payload = {
      'import_file_id': _selectedImportFileId,
      'declaration_46_no': _decl46Ctrl.text.trim().isNotEmpty ? _decl46Ctrl.text.trim() : null,
      'customs_office_name': _officeCtrl.text.trim(),
      'channel_type': _channelType,
      'delivery_order_number': _doNumberCtrl.text.trim().isNotEmpty ? _doNumberCtrl.text.trim() : null,
      'free_days_allowed': int.tryParse(_freeDaysCtrl.text) ?? 14,
      'import_duty_amount': duty,
      'vat_amount': vat,
      'schedule_tax_amount': sched,
      'wht_amount': wht,
      'lab_service_fees': lab,
      'total_duty_payable': total,
      'estimated_duty_total': double.tryParse(_estimatedDutyCtrl.text) ?? 0.0,
    };

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final successBar = AppTheme.snackBar(context, l.customsClearanceSaveRecordSuccess, severity: AppSeverity.success);
    try {
      if (widget.recordToEdit != null && !widget.isCloneDraft) {
        await ref.read(customsClearanceProvider.notifier).updateRecord(
              widget.recordToEdit!.customsClearanceId,
              payload,
            );
      } else {
        await ref.read(customsClearanceProvider.notifier).createRecord(payload);
      }
      navigator.pop();
      messenger.showSnackBar(successBar);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          l.customsClearanceSaveRecordError(ApiErrorText.of(l, e)),
          severity: AppSeverity.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _dec(String label, {Widget? suffix}) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, suffixIcon: suffix);

  Widget _numField(TextEditingController c, String label) => TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        decoration: _dec(label),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final availableFiles = widget.isCloneDraft && widget.recordToEdit != null
        ? importFiles.where((f) => f.importFileId != widget.recordToEdit!.importFileId).toList()
        : importFiles;
    final isEditing = widget.recordToEdit != null && !widget.isCloneDraft;
    final titleText = widget.isCloneDraft
        ? l.cloneCustomsClearanceDialogTitle
        : (!isEditing
            ? l.customsClearanceNewDialogTitle
            : l.customsClearanceEditDialogTitle(widget.recordToEdit!.clearanceCode));

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.gavel_rounded, color: AppTheme.cobalt),
          const SizedBox(width: 10),
          Expanded(child: Text(titleText, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          SmartUploadButton(
            module: SmartUploadModule.customsClearance,
            compact: true,
            label: l.customsClearanceExtractNafezaBtn,
            onDataExtracted: (res) => _applyExtractedNafezaData(res.extractedFields, l),
          ),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 720.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CcSectionCard(
                    title: l.ccFormSectionDeclaration,
                    icon: Icons.description_outlined,
                    child: Column(
                      children: [
                        SearchableDropdownField<int>(
                          value: _selectedImportFileId,
                          enabled: !isEditing,
                          labelText: l.customsClearanceImportFileLabel,
                          searchHintText: l.customsClearanceImportFileSearchHint,
                          isRequired: true,
                          items: availableFiles
                              .map((f) => SearchableDropdownItem<int>(
                                    value: f.importFileId,
                                    label: '${f.primaryNameWithCode} - ${f.companyName}',
                                    subtitle: 'PO: ${f.poNumber ?? "N/A"} | ACID: ${f.acidNumber ?? "N/A"}',
                                  ))
                              .toList(),
                          onChanged: isEditing ? null : (val) => setState(() => _selectedImportFileId = val),
                          validator: (val) => val == null ? l.customsClearanceSelectFileValidator : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _decl46Ctrl,
                                textDirection: TextDirection.ltr,
                                decoration: _dec(l.customsClearanceDecl46Label, suffix: ccCopyIcon(context, _decl46Ctrl)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _doNumberCtrl,
                                textDirection: TextDirection.ltr,
                                decoration: _dec(l.customsClearanceDoNumberLabel, suffix: ccCopyIcon(context, _doNumberCtrl)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _freeDaysCtrl,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                decoration: _dec(l.customsClearanceFreeDaysInputLabel),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _officeCtrl,
                                decoration: _dec(l.customsClearanceOfficeInputLabel),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? l.customsClearanceOfficeValidator : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SearchableDropdownField<String>(
                                value: _channelType,
                                isDense: false,
                                isRequired: true,
                                labelText: l.customsClearanceChannelLabel,
                                decoration: _dec(l.customsClearanceChannelLabel),
                                items: [
                                  SearchableDropdownItem(
                                    value: 'Red Channel',
                                    label: l.customsClearanceChannelRed,
                                    icon: Icons.flag_rounded,
                                  ),
                                  SearchableDropdownItem(
                                    value: 'Green Channel',
                                    label: l.customsClearanceChannelGreen,
                                    icon: Icons.check_circle_outline,
                                  ),
                                  SearchableDropdownItem(
                                    value: 'Yellow Channel',
                                    label: l.customsClearanceChannelYellow,
                                    icon: Icons.flag_outlined,
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _channelType = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  CcSectionCard(
                    title: l.customsClearanceDutyBreakdownHeader,
                    icon: Icons.calculate_outlined,
                    accent: AppTheme.emerald,
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _numField(_dutyCtrl, l.customsClearanceImportDutyInput)),
                            const SizedBox(width: 8),
                            Expanded(child: _numField(_vatCtrl, l.customsClearanceVatInput)),
                            const SizedBox(width: 8),
                            Expanded(child: _numField(_scheduleTaxCtrl, l.customsClearanceScheduleTaxInput)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _numField(_whtCtrl, l.customsClearanceWhtInput)),
                            const SizedBox(width: 8),
                            Expanded(child: _numField(_labFeesCtrl, l.customsClearanceLabFeesInput)),
                            const SizedBox(width: 8),
                            Expanded(child: _numField(_estimatedDutyCtrl, l.customsClearanceEstimatedDutyInput)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: ccDialogActions(
        context: context,
        confirmLabel: l.customsClearanceSaveRecordBtn,
        isLoading: _isLoading,
        onConfirm: _isLoading ? null : () => _save(l),
      ),
    );
  }
}
