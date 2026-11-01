import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';
import 'customs_ui.dart';
import 'inspection/customs_inspection_info_header.dart';
import 'inspection/customs_inspection_result_cards.dart';
import 'inspection/customs_inspection_sampling_section.dart';

/// Modal dialog for CL-01: Customs Inspection & Samples GOEIC Report
/// (field inspection, sampling and regulatory conformity).
class CustomsInspectionSamplingDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final CustomsClearanceModel? clearanceRecord;

  const CustomsInspectionSamplingDialog({
    super.key,
    required this.file,
    this.clearanceRecord,
  });

  static Future<bool?> show(
    BuildContext context,
    ImportFileModel file, {
    CustomsClearanceModel? clearanceRecord,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomsInspectionSamplingDialog(
        file: file,
        clearanceRecord: clearanceRecord,
      ),
    );
  }

  @override
  ConsumerState<CustomsInspectionSamplingDialog> createState() =>
      _CustomsInspectionSamplingDialogState();
}

class _CustomsInspectionSamplingDialogState
    extends ConsumerState<CustomsInspectionSamplingDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _inspectorController;
  late TextEditingController _samplingRecordController;
  late TextEditingController _goeicCertController;
  late TextEditingController _labFeesController;
  late TextEditingController _inspectionNotesController;

  late DateTime _inspectionDate;
  late DateTime _samplingDate;

  String _selectedInspectionType = 'Physical & Sampling';
  String? _selectedYard;
  String? _selectedResult;
  bool _isSampleDrawn = false;
  String _selectedSampleTestStatus = 'Samples Under Testing';

  final Set<String> _selectedSampledBodies = {};

  bool _isSubmitting = false;

  final List<String> _inspectionYards = DomainEnums.codesOf(DomainEnumType.inspectionYard);

  final List<String> _regulatoryAgencyOptions = const [
    'GOEIC',
    'NFSA',
    'CHEMISTRY_DEPT',
    'ATOMIC_ENERGY',
    'AGRICULTURAL_QUARANTINE',
    'VETERINARY_QUARARANTINE',
    'NTRA',
    'WEIGHTS_MEASURES',
    'EDA',
  ];

  @override
  void initState() {
    super.initState();
    final rec = widget.clearanceRecord;
    final bool hasExistingInspection = rec != null && rec.inspectionDate != null;

    if (hasExistingInspection) {
      _inspectorController = TextEditingController(text: rec.inspectorName ?? '');
      _samplingRecordController = TextEditingController(text: rec.samplingRecordNo ?? '');
      _goeicCertController = TextEditingController(text: rec.goeicCertificateNo ?? '');
      _labFeesController = TextEditingController(
        text: rec.labServiceFees != null ? rec.labServiceFees.toString() : '0',
      );
      _inspectionNotesController = TextEditingController(text: rec.inspectionNotes ?? '');

      if (rec.inspectionYard != null && rec.inspectionYard!.isNotEmpty) {
        _selectedYard = rec.inspectionYard;
      }
      if (rec.inspectionResult != null && rec.inspectionResult!.isNotEmpty) {
        _selectedResult = rec.inspectionResult;
      }
      if (rec.inspectionType.isNotEmpty) {
        _selectedInspectionType = rec.inspectionType;
      }
      _isSampleDrawn = rec.isSampleDrawn;
      if (rec.sampleTestStatus.isNotEmpty) {
        _selectedSampleTestStatus = rec.sampleTestStatus;
      }
      if (rec.sampledRegulatoryBodies.isNotEmpty) {
        _selectedSampledBodies.addAll(rec.sampledRegulatoryBodies);
      }

      _inspectionDate = DateTime.tryParse(rec.inspectionDate!) ?? DateTime.now();
      _samplingDate = rec.samplingDate != null
          ? (DateTime.tryParse(rec.samplingDate!) ?? DateTime.now())
          : DateTime.now();
    } else {
      _inspectorController = TextEditingController();
      _samplingRecordController = TextEditingController();
      _goeicCertController = TextEditingController();
      _labFeesController = TextEditingController(text: '0');
      _inspectionNotesController = TextEditingController();

      _selectedYard = null;
      _selectedResult = null;
      _selectedInspectionType = 'Physical & Sampling';
      _isSampleDrawn = false;
      _selectedSampleTestStatus = 'Samples Under Testing';
      _selectedSampledBodies.clear();

      _inspectionDate = DateTime.now();
      _samplingDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _inspectorController.dispose();
    _samplingRecordController.dispose();
    _goeicCertController.dispose();
    _labFeesController.dispose();
    _inspectionNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isSampling}) async {
    final initialDate = isSampling ? _samplingDate : _inspectionDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isSampling) {
          _samplingDate = picked;
        } else {
          _inspectionDate = picked;
        }
      });
    }
  }

  Future<void> _submitInspectionSampling() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSubmitting = true);

    try {
      final labFees = double.tryParse(_labFeesController.text.trim()) ?? 0.0;

      final payload = {
        'import_file_id': widget.file.importFileId,
        'inspection_date': _inspectionDate.toIso8601String(),
        'inspection_type': _selectedInspectionType,
        'inspection_yard': _selectedYard,
        'inspector_name': _inspectorController.text.trim().isNotEmpty
            ? _inspectorController.text.trim()
            : null,
        'inspection_result': _selectedResult,
        'is_sample_drawn': _isSampleDrawn,
        'sampling_date': _isSampleDrawn ? _samplingDate.toIso8601String() : null,
        'sampling_record_no': _isSampleDrawn && _samplingRecordController.text.trim().isNotEmpty
            ? _samplingRecordController.text.trim()
            : null,
        'sample_test_status': _selectedSampleTestStatus,
        'sampled_regulatory_bodies': _isSampleDrawn ? _selectedSampledBodies.toList() : [],
        'goeic_certificate_no': _goeicCertController.text.trim().isNotEmpty
            ? _goeicCertController.text.trim()
            : null,
        'lab_service_fees': labFees,
        'inspection_notes': _inspectionNotesController.text.trim().isNotEmpty
            ? _inspectionNotesController.text.trim()
            : null,
      };
      final result = _selectedResult ?? '';

      await ref
          .read(customsClearanceProvider.notifier)
          .recordInspectionSampling(payload);

      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(context, l.ccInsSuccess(result), severity: AppSeverity.success),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccInsError(ApiErrorText.of(l, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon, Widget? suffix, String? suffixText}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: suffix,
        suffixText: suffixText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final file = widget.file;

    final inspectionTypes = <String, String>{
      'Physical & Sampling': l.ccInsType1,
      '100% Full Inspection': l.ccInsType2,
      'Random Sample Check': l.ccInsType3,
      'X-Ray Scan & Inspection': l.ccInsType4,
      'Document Review Only': l.ccInsType5,
    };

    return CcStageDialogShell(
      title: l.ccInsTitle,
      icon: Icons.biotech_rounded,
      accent: AppTheme.cobalt,
      maxWidth: 860,
      chips: [
        CcHeaderChip(Icons.layers_outlined, l.ccInsChipStage),
        CcHeaderChip(Icons.folder_outlined, l.ccInsChipFile(file.importFileCode, file.companyName)),
      ],
      confirmLabel: l.ccInsConfirm,
      loadingLabel: l.ccInsConfirming,
      confirmIcon: Icons.save_rounded,
      isSubmitting: _isSubmitting,
      onConfirm: _submitInspectionSampling,
      footerLeading: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppTheme.textMutedOf(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.ccInsFooterNote,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomsInspectionInfoHeader(
              file: file,
              clearanceRecord: widget.clearanceRecord,
            ),
            const SizedBox(height: 20),
            CcFormSection(
              title: l.ccInsSection1,
              icon: Icons.fact_check_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: SearchableDropdownField<String>(
                          key: const Key('inspectionYardDropdown'),
                          labelText: l.ccInsYardLabel,
                          hintText: l.ccInsYardHint,
                          items: _inspectionYards
                              .map(
                                (yard) => SearchableDropdownItem<String>(
                                  value: yard,
                                  label: DomainEnums.label(l, DomainEnumType.inspectionYard, yard),
                                ),
                              )
                              .toList(),
                          value: _selectedYard,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.warehouse_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                          ),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedYard = val);
                          },
                          validator: (val) {
                            if (val == null || val.isEmpty) return l.ccInsYardRequired;
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => _pickDate(isSampling: false),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          child: InputDecorator(
                            decoration: _dec(l.ccInsDateLabel, icon: Icons.calendar_month_rounded),
                            child: LtrText(CcFormat.date(_inspectionDate),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(l.ccInsTypeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: inspectionTypes.entries.map((type) {
                      final isSelected = _selectedInspectionType == type.key;
                      return ChoiceChip(
                        label: Text(type.value),
                        selected: isSelected,
                        selectedColor: AppTheme.cobaltMedium,
                        showCheckmark: false,
                        avatar: isSelected ? const Icon(Icons.check, size: 16, color: AppTheme.cobalt) : null,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.cobalt : AppTheme.textPrimaryOf(context),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedInspectionType = type.key);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _inspectorController,
                    decoration: _dec(l.ccInsInspectorLabel, hint: l.ccInsInspectorHint, icon: Icons.badge_rounded),
                  ),
                  const SizedBox(height: 16),
                  Text(l.ccInsResultLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  FormField<String>(
                    validator: (_) {
                      if (_selectedResult == null || _selectedResult!.isEmpty) {
                        return l.ccInsResultRequired;
                      }
                      return null;
                    },
                    builder: (state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomsInspectionResultCards(
                            selectedResult: _selectedResult,
                            onSelected: (val) {
                              setState(() => _selectedResult = val);
                              state.didChange(val);
                            },
                          ),
                          if (state.hasError) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsetsDirectional.only(start: 4),
                              child: Text(
                                state.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CustomsInspectionSamplingSection(
              isSampleDrawn: _isSampleDrawn,
              onSampleDrawnChanged: (val) => setState(() => _isSampleDrawn = val),
              samplingRecordController: _samplingRecordController,
              samplingDate: _samplingDate,
              onPickSamplingDate: () => _pickDate(isSampling: true),
              selectedSampledBodies: _selectedSampledBodies,
              regulatoryAgencyOptions: _regulatoryAgencyOptions,
              onSampledBodiesChanged: (val) => setState(() {
                _selectedSampledBodies.clear();
                _selectedSampledBodies.addAll(val);
              }),
              goeicCertController: _goeicCertController,
              labFeesController: _labFeesController,
              selectedSampleTestStatus: _selectedSampleTestStatus,
              onSampleTestStatusChanged: (val) => setState(() => _selectedSampleTestStatus = val),
              dec: _dec,
            ),
            const SizedBox(height: 20),
            CcFormSection(
              title: l.ccInsSection3,
              icon: Icons.notes_rounded,
              child: TextFormField(
                controller: _inspectionNotesController,
                maxLines: 3,
                decoration: _dec(l.ccInsNotesLabel, hint: l.ccInsNotesHint, icon: Icons.edit_note_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
