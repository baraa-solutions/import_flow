import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isSampleDrawn = true;
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
    'VETERINARY_QUARANTINE',
    'NTRA',
    'WEIGHTS_MEASURES',
    'EDA',
  ];

  @override
  void initState() {
    super.initState();
    final rec = widget.clearanceRecord;
    _inspectorController = TextEditingController(
      text: rec?.inspectorName ?? '',
    );
    _samplingRecordController = TextEditingController(
      text: rec?.samplingRecordNo ?? '',
    );
    _goeicCertController = TextEditingController(
      text: rec?.goeicCertificateNo ?? '',
    );
    _labFeesController = TextEditingController(
      text: rec?.labServiceFees != null ? rec!.labServiceFees.toString() : '0',
    );
    _inspectionNotesController = TextEditingController(
      text: rec?.inspectionNotes ?? '',
    );

    if (rec != null) {
      if (rec.inspectionYard != null && rec.inspectionYard!.isNotEmpty) {
        _selectedYard = rec.inspectionYard;
      }
      if (rec.inspectionResult.isNotEmpty) {
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

      _inspectionDate = rec.inspectionDate != null
          ? (DateTime.tryParse(rec.inspectionDate!) ?? DateTime.now())
          : DateTime.now();
      _samplingDate = rec.samplingDate != null
          ? (DateTime.tryParse(rec.samplingDate!) ?? DateTime.now())
          : DateTime.now();
    } else {
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

    final channel = widget.clearanceRecord?.channelType;
    final channelInfo = channel != null && channel.trim().isNotEmpty
        ? CcUi.channelStyle(l, channel)
        : null;
    final channelLabel = channelInfo?.label ?? '—';
    final channelIcon = channelInfo?.icon ?? Icons.security_rounded;
    final channelColor = channelInfo != null
        ? AppTheme.severityForegroundOf(context, channelInfo.severity)
        : AppTheme.charcoal;

    final String dateValue;
    if (file.form46Date != null && file.form46Date!.trim().isNotEmpty) {
      final trimmed = file.form46Date!.trim();
      dateValue = trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
    } else {
      dateValue = '—';
    }

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
            CcFieldRow(
              gap: 12,
              children: [
                _buildInfoBadge(
                  title: l.ccInsBadgeDecl,
                  value: file.form46No ?? l.ccInsBadgeDeclFallback,
                  icon: Icons.assignment_turned_in_rounded,
                  accentColor: AppTheme.cobalt,
                ),
                _buildInfoBadge(
                  title: l.ccInsBadgeChannel,
                  value: channelLabel,
                  icon: channelIcon,
                  accentColor: channelColor,
                ),
                _buildInfoBadge(
                  title: l.ccInsBadgeDate,
                  value: dateValue,
                  icon: Icons.calendar_today_rounded,
                  accentColor: AppTheme.charcoal,
                  ltr: true,
                ),
              ],
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
                          _buildResultCards(
                            l,
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

            CcFormSection(
              title: l.ccInsSection2,
              icon: Icons.science_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: _isSampleDrawn,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l.ccInsSampleSwitchTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    subtitle: Text(
                      _isSampleDrawn ? l.ccInsSampleSwitchOn : l.ccInsSampleSwitchOff,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
                    ),
                    activeThumbColor: AppTheme.emerald,
                    onChanged: (val) {
                      setState(() {
                        _isSampleDrawn = val;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_isSampleDrawn) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _samplingRecordController,
                            textDirection: TextDirection.ltr,
                            decoration: _dec(
                              l.ccInsSampleRecordLabel,
                              hint: l.ccInsSampleRecordHint,
                              icon: Icons.numbers_rounded,
                            ),
                            validator: (val) {
                              if (_isSampleDrawn && (val == null || val.trim().length < 3)) {
                                return l.ccInsSamplingNoRequired;
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () => _pickDate(isSampling: true),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            child: InputDecorator(
                              decoration: _dec(l.ccInsSampleDateLabel, icon: Icons.event_note_rounded),
                              child: LtrText(CcFormat.date(_samplingDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(l.ccInsBodiesLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    FormField<Set<String>>(
                      validator: (_) {
                        if (_isSampleDrawn && _selectedSampledBodies.isEmpty) {
                          return l.ccInsBodiesRequired;
                        }
                        return null;
                      },
                      builder: (state) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: _regulatoryAgencyOptions.map((agency) {
                                final isSelected = _selectedSampledBodies.contains(agency);
                                return FilterChip(
                                  label: Text(
                                    DomainEnums.label(l, DomainEnumType.regulatoryBody, agency),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppTheme.cobaltMedium,
                                  checkmarkColor: AppTheme.cobalt,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedSampledBodies.add(agency);
                                      } else {
                                        _selectedSampledBodies.remove(agency);
                                      }
                                    });
                                    state.didChange(_selectedSampledBodies);
                                  },
                                );
                              }).toList(),
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
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _goeicCertController,
                            textDirection: TextDirection.ltr,
                            decoration: _dec(l.ccInsGoeicLabel, hint: l.ccInsGoeicHint, icon: Icons.verified_rounded),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _labFeesController,
                            textDirection: TextDirection.ltr,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: _dec(l.ccInsLabFeesLabel, icon: Icons.payments_rounded, suffixText: 'EGP'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(l.ccInsTestStatusLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSampleStatusChip('Samples Under Testing', l.ccInsStatusTesting,
                            Icons.hourglass_top_rounded, AppTheme.orange),
                        _buildSampleStatusChip(
                            'Approved', l.ccInsStatusApproved, Icons.check_circle_rounded, AppTheme.emerald),
                        _buildSampleStatusChip(
                            'Rejected', l.ccInsStatusRejected, Icons.cancel_rounded, AppTheme.crimson),
                      ],
                    ),
                  ],
                ],
              ),
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

  Widget _buildResultCards(
    AppLocalizations l, {
    required ValueChanged<String> onSelected,
    String? selectedResult,
  }) {
    final results = <({String id, String label, String desc, AppSeverity severity, IconData icon})>[
      (
        id: 'Conforming',
        label: l.ccInsResConforming,
        desc: l.ccInsResConformingDesc,
        severity: AppSeverity.success,
        icon: Icons.check_circle_rounded
      ),
      (
        id: 'Shortage',
        label: l.ccInsResShortage,
        desc: l.ccInsResShortageDesc,
        severity: AppSeverity.warning,
        icon: Icons.remove_circle_outline_rounded
      ),
      (
        id: 'Surplus',
        label: l.ccInsResSurplus,
        desc: l.ccInsResSurplusDesc,
        severity: AppSeverity.info,
        icon: Icons.add_circle_outline_rounded
      ),
      (
        id: 'Discrepancy',
        label: l.ccInsResDiscrepancy,
        desc: l.ccInsResDiscrepancyDesc,
        severity: AppSeverity.danger,
        icon: Icons.warning_amber_rounded
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: results.map((result) {
        final isSelected = selectedResult == result.id;
        final color = AppTheme.severityForegroundOf(context, result.severity);
        return Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onSelected(result.id),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Container(
                padding: const EdgeInsetsDirectional.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.severityBackgroundOf(context, result.severity)
                      : AppTheme.surfaceOf(context),
                  border: Border.all(
                    color: isSelected ? color : AppTheme.borderOf(context),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(result.icon, size: 18, color: isSelected ? color : AppTheme.textSecondaryOf(context)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            result.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? color : AppTheme.textPrimaryOf(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.desc,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoBadge({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    bool ltr = false,
  }) {
    final valueStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: accentColor);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                ltr
                    ? LtrText(value, style: valueStyle, overflow: TextOverflow.ellipsis)
                    : Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleStatusChip(String code, String label, IconData icon, Color color) {
    final isSelected = _selectedSampleTestStatus == code;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? color : AppTheme.textSecondaryOf(context)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11.5, color: isSelected ? color : AppTheme.textPrimaryOf(context))),
        ],
      ),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.15),
      onSelected: (selected) {
        if (selected) setState(() => _selectedSampleTestStatus = code);
      },
    );
  }
}
