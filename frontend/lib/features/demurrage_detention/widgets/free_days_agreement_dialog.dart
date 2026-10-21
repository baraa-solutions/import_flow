import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/demurrage_model.dart';
import '../providers/demurrage_provider.dart';

/// BK-02: تسجيل وتوثيق فترات السماح المجانية الممنوحة للحاويات
/// يتيح لضابط اللوجستيات توثيق الاتفاق مع الخط الملاحي لتغذية رادار الغرامات تلقائياً.
/// Extra free days an agreement grants over [baseline]; null when no baseline is recorded
/// (no tariff is ever invented).
int? extraFreeDaysOverBaseline(int agreed, int? baseline) {
  if (baseline == null) return null;
  final extra = agreed - baseline;
  return extra > 0 ? extra : 0;
}

class FreeDaysAgreementDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final String? initialCarrierName;
  final int? initialDemurrageDays;
  final int? initialDetentionDays;

  const FreeDaysAgreementDialog({
    super.key,
    this.initialImportFileId,
    this.initialCarrierName,
    this.initialDemurrageDays,
    this.initialDetentionDays,
  });

  static Future<FreeDaysAgreementModel?> show(
    BuildContext context, {
    int? initialImportFileId,
    String? initialCarrierName,
    int? initialDemurrageDays,
    int? initialDetentionDays,
  }) {
    return showDialog<FreeDaysAgreementModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FreeDaysAgreementDialog(
        initialImportFileId: initialImportFileId,
        initialCarrierName: initialCarrierName,
        initialDemurrageDays: initialDemurrageDays,
        initialDetentionDays: initialDetentionDays,
      ),
    );
  }

  @override
  ConsumerState<FreeDaysAgreementDialog> createState() => _FreeDaysAgreementDialogState();
}

class _FreeDaysAgreementDialogState extends ConsumerState<FreeDaysAgreementDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedImportFileId;
  String _carrierName = 'MSC';
  late final TextEditingController _demurrageController;
  late final TextEditingController _detentionController;
  late final TextEditingController _storageController;
  final _refController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _agreementDate = DateTime.now();
  bool _isSubmitting = false;
  bool _isLoadingExisting = false;

  final List<String> _carriers = [
    'MSC',
    'Maersk',
    'CMA CGM',
    'COSCO',
    'Hapag-Lloyd',
    'ONE',
    'Evergreen',
    'Yang Ming',
    'OOCL',
    'ZIM',
  ];

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    if (widget.initialCarrierName != null && widget.initialCarrierName!.isNotEmpty) {
      _carrierName = widget.initialCarrierName!;
    }
    _demurrageController = TextEditingController(
      text: widget.initialDemurrageDays?.toString() ?? '',  // no invented agreement days
    );
    _detentionController = TextEditingController(
      text: widget.initialDetentionDays?.toString() ?? '',
    );
    _storageController = TextEditingController();

    if (_selectedImportFileId != null) {
      _loadExistingAgreement(_selectedImportFileId!);
    }
  }

  @override
  void dispose() {
    _demurrageController.dispose();
    _detentionController.dispose();
    _storageController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingAgreement(int fileId) async {
    setState(() => _isLoadingExisting = true);
    try {
      final agr = await ref.read(demurrageProvider.notifier).fetchFreeDaysAgreement(fileId);
      if (agr != null && mounted) {
        setState(() {
          if (agr.carrierName.isNotEmpty) {
            _carrierName = agr.carrierName;
          }
          _demurrageController.text = agr.agreedDemurrageFreeDays.toString();
          _detentionController.text = agr.agreedDetentionFreeDays.toString();
          _storageController.text = agr.portStorageFreeDays.toString();
          if (agr.agreementReference != null) {
            _refController.text = agr.agreementReference!;
          }
          if (agr.notes != null) {
            _notesController.text = agr.notes!;
          }
          if (agr.agreementDate != null) {
            try {
              _agreementDate = DateTime.parse(agr.agreementDate!);
            } catch (_) {}
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  int get _demDays => int.tryParse(_demurrageController.text) ?? 0;
  int get _detDays => int.tryParse(_detentionController.text) ?? 0;
  int get _storDays => int.tryParse(_storageController.text) ?? 0;

  /// Free days currently recorded on the selected import file (backend value), or null.
  int? _baselineDemDays(List<ImportFileModel> files) {
    for (final f in files) {
      if (f.importFileId == _selectedImportFileId) return f.targetFreeDays;
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.fdaSelectImportFile, severity: AppSeverity.warning),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'import_file_id': _selectedImportFileId,
        'carrier_name': _carrierName,
        'agreed_demurrage_free_days': _demDays,
        'agreed_detention_free_days': _detDays,
        // Left blank = not set: omitted so the backend keeps the policy value.
        if (_storageController.text.trim().isNotEmpty) 'port_storage_free_days': _storDays,
        'agreement_reference': _refController.text.trim().isEmpty ? null : _refController.text.trim(),
        'agreement_date': _agreementDate.toIso8601String().split('T').first,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      final result = await ref.read(demurrageProvider.notifier).registerFreeDaysAgreement(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            result != null ? l.fdaSuccessWithDays(result.agreedDemurrageFreeDays) : l.fdaSuccess,
            severity: AppSeverity.success,
          ),
        );
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            ApiErrorText.of(context.l10n, e, fallback: context.l10n.freeDaysDocumentFailed),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get _isDirty {
    if (_selectedImportFileId != widget.initialImportFileId) return true;
    if (_refController.text.trim().isNotEmpty) return true;
    if (_notesController.text.trim().isNotEmpty) return true;
    if (_carrierName != (widget.initialCarrierName ?? 'MSC')) return true;
    if (_demurrageController.text.trim() != (widget.initialDemurrageDays?.toString() ?? '')) return true;
    if (_detentionController.text.trim() != (widget.initialDetentionDays?.toString() ?? '')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFiles = ref.watch(importFilesProvider).asData?.value ?? [];
    String? selectedCode;
    for (final f in importFiles) {
      if (f.importFileId == _selectedImportFileId) {
        selectedCode = f.importFileCode;
        break;
      }
    }

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Form(
        key: _formKey,
        child: CcStageDialogShell(
          title: l.fdaDialogTitle,
          icon: Icons.verified_user_outlined,
          accent: AppTheme.emerald,
          maxWidth: 760,
          chips: [
            if (selectedCode != null) CcHeaderChip(Icons.folder_open_outlined, selectedCode, ltr: true),
            CcHeaderChip(Icons.directions_boat_outlined, _carrierName, ltr: true),
          ],
          headerActions: [
            if (_isLoadingExisting)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white),
                ),
              ),
          ],
          confirmLabel: l.fdaConfirmBtn,
          loadingLabel: l.fdaSubmitting,
          isSubmitting: _isSubmitting,
          onConfirm: _handleSubmit,
          onCancel: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
          body: _buildBody(context, l, importFiles),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l, List<ImportFileModel> importFiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.fdaIntro,
          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context)),
        ),
        const SizedBox(height: 14),
        CcFormSection(
          title: l.fdaSectionAgreement,
          icon: Icons.handshake_outlined,
          accent: AppTheme.emerald,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchableDropdownField<int>(
                labelText: l.fdaLinkedImportFile,
                isRequired: true,
                value: _selectedImportFileId,
                items: importFiles
                    .map(
                      (f) => SearchableDropdownItem<int>(
                        value: f.importFileId,
                        label: '${f.importFileCode} - ${f.supplierName}',
                        subtitle: f.targetFreeDays == null ? null : l.fdaCurrentFreeDays(f.targetFreeDays!),
                      ),
                    )
                    .toList(),
                onChanged: widget.initialImportFileId != null
                    ? null
                    : (val) {
                        setState(() => _selectedImportFileId = val);
                        if (val != null) {
                          _loadExistingAgreement(val);
                        }
                      },
                validator: (val) => val == null ? l.fdaSelectImportFile : null,
              ),
              const SizedBox(height: 16),
              CcFieldRow(
                children: [
                  SearchableDropdownField<String>(
                    labelText: l.fdaCarrier,
                    isRequired: true,
                    value: _carrierName,
                    items: _carriers.map((c) => SearchableDropdownItem<String>(value: c, label: c)).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _carrierName = val);
                    },
                  ),
                  CcField(
                    label: l.fdaAgreementDate,
                    child: CcDateTile(
                      date: _agreementDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _agreementDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _agreementDate = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CcFormSection(
          title: l.fdaSectionFreeDays,
          icon: Icons.timer_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsetsDirectional.only(bottom: 12),
                padding: const EdgeInsetsDirectional.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'اتفاقية الـ 21 يوماً مع الخط الملاحي تسري على غرامات تأخير الحاوية (Demurrage) فقط. أما أرضيات ساحات الميناء (Port Storage) فتخضع لـ 7 أيام سماح افتراضياً وفق تعريفة الميناء.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              CcFieldRow(
                gap: 14,
                children: [
                  _daysField(l, _demurrageController, l.fdaPortDemurrage, const [5, 14, 21, 28], min: 1),
                  _daysField(l, _detentionController, l.fdaDetention, const [7, 14, 21], min: 1),
                  _daysField(l, _storageController, l.fdaPortStorage, const [3, 5, 7, 10], min: 0, optional: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CcFormSection(
          title: l.fdaSectionReference,
          icon: Icons.receipt_long_outlined,
          child: CcFieldRow(
            children: [
              CcField(
                label: l.fdaClauseRef,
                child: TextFormField(
                  controller: _refController,
                  decoration: ccInputDecoration(hint: l.fdaClauseRefHint, prefix: Icons.receipt_long),
                ),
              ),
              CcField(
                label: l.fdaNotes,
                child: TextFormField(
                  controller: _notesController,
                  decoration: ccInputDecoration(hint: l.fdaNotesHint, prefix: Icons.note_alt_outlined),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSavingsCard(context, l, importFiles),
      ],
    );
  }

  /// One numeric "days" input with its quick-pick chips (the chip matching the
  /// current value is highlighted).
  Widget _daysField(
    AppLocalizations l,
    TextEditingController controller,
    String label,
    List<int> presets, {
    required int min,
    bool optional = false,
  }) {
    return CcField(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: ccInputDecoration(suffixText: l.whatIfDaysUnit),
            validator: (val) {
              if (optional && (val ?? '').trim().isEmpty) return null;
              final v = int.tryParse(val ?? '');
              if (v == null || v < min) return l.fdaEnterValidNumber;
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final days in presets)
                ChoiceChip(
                  label: Text(l.fdaDaysCount(days), style: const TextStyle(fontSize: 11.5)),
                  selected: controller.text.trim() == days.toString(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (_) => setState(() => controller.text = days.toString()),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard(BuildContext context, AppLocalizations l, List<ImportFileModel> importFiles) {
    final baseline = _baselineDemDays(importFiles);
    final savedDem = extraFreeDaysOverBaseline(_demDays, baseline);
    final fg = AppTheme.severityForegroundOf(context, AppSeverity.success);
    final bg = AppTheme.severityBackgroundOf(context, AppSeverity.success);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.savings_outlined, color: fg, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l.fdaSavingsTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final tiles = [
                _metricTile(
                  context,
                  l.fdaExtraDemDays,
                  savedDem == null ? '-' : l.fdaDaysPlus(savedDem),
                  baseline == null ? l.demFdaNoBaseline : l.demFdaAboveFileDays(baseline),
                  AppTheme.cobalt,
                ),
                _metricTile(
                  context,
                  l.fdaExtraDetDays,
                  '-',
                  l.demFdaNoBaseline,
                  AppTheme.orange,
                ),
                _metricTile(
                  context,
                  l.fdaTotalProtected,
                  l.fdaDaysCount(_demDays + _detDays),
                  l.fdaSafePeriod,
                  AppTheme.emerald,
                ),
              ];
              if (c.maxWidth < 520) {
                return Column(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      tiles[i],
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt, size: 16, color: AppTheme.orange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${l.demFdaNoTariffNote} ${l.fdaOperationalNote}',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context), height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(BuildContext context, String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsetsDirectional.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(height: 2),
          LtrText(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context)),
          ),
        ],
      ),
    );
  }
}
