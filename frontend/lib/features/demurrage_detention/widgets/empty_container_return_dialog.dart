import '../../../core/localization/api_error_text.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/demurrage_model.dart';
import '../providers/demurrage_provider.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/localization/app_localizations.dart';

/// TR-05: تسجيل وتوثيق إرجاع الحاويات الفارغة للخط الملاحي (EIR)
/// يوقف عدادات الغرامات بالكامل وينقل الشحنة للمرحلة التاسعة (تكلفة الوصول والتسوية الختامية)
class EmptyContainerReturnDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final String? initialContainerNumber;
  final String? initialEirNumber;
  final String? initialDepotName;

  const EmptyContainerReturnDialog({
    super.key,
    this.initialImportFileId,
    this.initialContainerNumber,
    this.initialEirNumber,
    this.initialDepotName,
  });

  static Future<EmptyContainerReturnResponseModel?> show(
    BuildContext context, {
    int? initialImportFileId,
    String? initialContainerNumber,
    String? initialEirNumber,
    String? initialDepotName,
  }) {
    return showDialog<EmptyContainerReturnResponseModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EmptyContainerReturnDialog(
        initialImportFileId: initialImportFileId,
        initialContainerNumber: initialContainerNumber,
        initialEirNumber: initialEirNumber,
        initialDepotName: initialDepotName,
      ),
    );
  }

  @override
  ConsumerState<EmptyContainerReturnDialog> createState() =>
      _EmptyContainerReturnDialogState();
}

class _EmptyContainerReturnDialogState
    extends ConsumerState<EmptyContainerReturnDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedImportFileId;
  late final TextEditingController _eirNumberCtrl;
  late final TextEditingController _depotNameCtrl;
  final _driverNameCtrl = TextEditingController();
  final _truckPlateNoCtrl = TextEditingController();
  final _damageNotesCtrl = TextEditingController();
  final _damageFeeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _emptyReturnDate = DateTime.now();
  String _containerCondition = 'SOUND_CLEAN';
  bool _isSubmitting = false;

  /// Depot codes (DomainEnumType.depot); labels follow the UI language.
  final List<String> _popularDepots = DomainEnums.codesOf(DomainEnumType.depot);

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;

    final randomId = 1000 + Random().nextInt(9000);
    final autoEir = widget.initialEirNumber ??
        'EIR-${DateTime.now().year}-$randomId';
    _eirNumberCtrl = TextEditingController(text: autoEir);

    _depotNameCtrl = TextEditingController(
      text: DomainEnums.initialCode(DomainEnumType.depot, widget.initialDepotName, widget.initialDepotName ?? _popularDepots.first),
    );
  }

  @override
  void dispose() {
    _eirNumberCtrl.dispose();
    _depotNameCtrl.dispose();
    _driverNameCtrl.dispose();
    _truckPlateNoCtrl.dispose();
    _damageNotesCtrl.dispose();
    _damageFeeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _regenerateEirNumber() {
    final randomId = 1000 + Random().nextInt(9000);
    setState(() {
      _eirNumberCtrl.text = 'EIR-${DateTime.now().year}-$randomId';
    });
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.erSelectFileSnack, severity: AppSeverity.warning),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final submitModel = EmptyContainerReturnSubmitModel(
        importFileId: _selectedImportFileId!,
        eirNumber: _eirNumberCtrl.text.trim(),
        emptyReturnDate:
            _emptyReturnDate.toIso8601String().split('T').first,
        depotName: _depotNameCtrl.text.trim(),
        returnedContainers: widget.initialContainerNumber != null
            ? [widget.initialContainerNumber!]
            : null,
        containerCondition: _containerCondition,
        damageNotes: _containerCondition != 'SOUND_CLEAN'
            ? _damageNotesCtrl.text.trim()
            : null,
        damageFeeEstimated: _containerCondition != 'SOUND_CLEAN'
            ? double.tryParse(_damageFeeCtrl.text.trim()) ?? 0.0
            : 0.0,
        driverName: _driverNameCtrl.text.trim().isNotEmpty
            ? _driverNameCtrl.text.trim()
            : null,
        truckPlateNo: _truckPlateNoCtrl.text.trim().isNotEmpty
            ? _truckPlateNoCtrl.text.trim()
            : null,
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
      );

      final res = await ref
          .read(demurrageProvider.notifier)
          .recordEmptyContainerReturn(submitModel);

      if (mounted && res != null) {
        final snack = AppTheme.snackBar(
          context,
          context.l10n.emptyReturnRecordedSuccess(res.containersReturnedCount, res.totalContainersCount),
          severity: AppSeverity.success,
        );
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(res);
        messenger.showSnackBar(snack);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            ApiErrorText.of(context.l10n, e, fallback: context.l10n.emptyReturnRecordFailed),
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filesAsync = ref.watch(importFilesProvider);

    return Form(
      key: _formKey,
      child: CcStageDialogShell(
        title: l.erTitle,
        icon: Icons.assignment_turned_in_rounded,
        accent: AppTheme.emerald,
        maxWidth: 800,
        chips: [
          if (widget.initialContainerNumber != null)
            CcHeaderChip(Icons.inventory_2_outlined, l.erContainerChip(widget.initialContainerNumber!), ltr: true),
        ],
        confirmKey: const Key('submitEmptyContainerReturnBtn'),
        confirmLabel: l.erConfirmBtn,
        loadingLabel: l.erSubmitting,
        isSubmitting: _isSubmitting,
        onConfirm: _submit,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.erSubtitle,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context)),
            ),
            const SizedBox(height: 14),
            CcFormSection(
              title: l.erTargetFile,
              icon: Icons.folder_shared_outlined,
              child: _buildFileSelector(l, filesAsync),
            ),
            const SizedBox(height: 14),
            _buildRadarNoticeBanner(l),
            const SizedBox(height: 14),
            CcFormSection(
              title: l.erSectionHandover,
              icon: Icons.assignment_outlined,
              accent: AppTheme.emerald,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildEirAndDateRow(l),
                  const SizedBox(height: 14),
                  _buildDepotSelector(l),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildContainerConditionSection(l),
            const SizedBox(height: 14),
            CcFormSection(
              title: l.erSectionTransport,
              icon: Icons.local_shipping_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDriverAndTruckRow(l),
                  const SizedBox(height: 14),
                  CcField(
                    label: l.erExtraNotes,
                    child: TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: ccInputDecoration(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector(AppLocalizations l, AsyncValue<List<ImportFileModel>> filesAsync) {
    return filesAsync.when(
      data: (files) {
        if (files.isEmpty) {
          return Text(l.erNoImportFiles, style: TextStyle(color: AppTheme.textSecondaryOf(context)));
        }

        ImportFileModel? selectedFile;
        for (final f in files) {
          if (f.importFileId == _selectedImportFileId) {
            selectedFile = f;
            break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchableDropdownField<int>(
              key: const Key('emptyReturnImportFileDropdown'),
              items: files
                  .map((f) => SearchableDropdownItem<int>(
                        value: f.importFileId,
                        label: '${f.primaryNameWithCode} — ${f.companyName}',
                      ))
                  .toList(),
              value: _selectedImportFileId,
              hintText: l.erFileHint,
              onChanged: (val) {
                setState(() => _selectedImportFileId = val);
              },
            ),
            if (selectedFile != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsetsDirectional.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 10,
                  children: [
                    CcFact(label: l.erDetailImporter, value: _dash(selectedFile.companyName)),
                    CcFact(label: l.erDetailSupplier, value: _dash(selectedFile.supplierName)),
                    CcFact(label: l.erDetailInland, value: _dash(selectedFile.inlandTransportStatus)),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        ApiErrorText.of(l, e, fallback: l.erFilesLoadFailed),
        style: TextStyle(color: AppTheme.severityForegroundOf(context, AppSeverity.danger)),
      ),
    );
  }

  String _dash(String v) => v.trim().isEmpty ? '-' : v;

  /// What recording the return does to the radar and the shipment lifecycle.
  Widget _buildRadarNoticeBanner(AppLocalizations l) {
    final fg = AppTheme.severityForegroundOf(context, AppSeverity.success);
    final bg = AppTheme.severityBackgroundOf(context, AppSeverity.success);
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.erRadarImpactTitle,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: fg),
                ),
                const SizedBox(height: 4),
                Text(
                  l.erRadarImpactBody,
                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context), height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEirAndDateRow(AppLocalizations l) {
    return CcFieldRow(
      children: [
        CcField(
          label: l.erEirLabel,
          isRequired: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('eirNumberField'),
                controller: _eirNumberCtrl,
                textDirection: TextDirection.ltr,
                decoration: ccInputDecoration(
                  hint: 'e.g. EIR-2026-88001',
                  prefix: Icons.receipt_long_outlined,
                  suffix: IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: l.erRegenerate,
                    onPressed: _regenerateEirNumber,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return l.erEirValidation;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        CcField(
          label: l.erReturnDate,
          isRequired: true,
          child: CcDateTile(
            date: _emptyReturnDate,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _emptyReturnDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _emptyReturnDate = picked);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDepotSelector(AppLocalizations l) {
    return SearchableDropdownField<String>(
      key: const Key('depotNameDropdown'),
      labelText: l.erDepotLabel,
      isRequired: true,
      items: _popularDepots
          .map((d) => SearchableDropdownItem<String>(
                value: d,
                label: DomainEnums.label(l, DomainEnumType.depot, d),
              ))
          .toList(),
      value: _popularDepots.contains(_depotNameCtrl.text)
          ? _depotNameCtrl.text
          : null,
      hintText: l.erDepotHint,
      onChanged: (val) {
        if (val != null) {
          setState(() => _depotNameCtrl.text = val);
        }
      },
    );
  }

  Widget _buildContainerConditionSection(AppLocalizations l) {
    final cards = [
      _buildConditionCard(
        'SOUND_CLEAN',
        l.erCondSound,
        l.erCondSoundSub,
        Icons.check_circle_outline,
        AppTheme.emerald,
      ),
      _buildConditionCard(
        'MINOR_DAMAGE',
        l.erCondMinor,
        l.erCondMinorSub,
        Icons.warning_amber_rounded,
        AppTheme.orange,
      ),
      _buildConditionCard(
        'REPAIR_REQUIRED',
        l.erCondRepair,
        l.erCondRepairSub,
        Icons.build_outlined,
        AppTheme.crimson,
      ),
    ];
    return CcFormSection(
      title: l.erConditionTitle,
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 560) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      cards[i],
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: cards[i]),
                    ],
                  ],
                ),
              );
            },
          ),
          if (_containerCondition != 'SOUND_CLEAN') ...[
            const SizedBox(height: 14),
            CcFieldRow(
              children: [
                CcField(
                  label: l.erDamageNotes,
                  child: TextFormField(
                    controller: _damageNotesCtrl,
                    decoration: ccInputDecoration(hint: l.erDamageNotesHint),
                  ),
                ),
                CcField(
                  label: l.erDamageFee,
                  child: TextFormField(
                    controller: _damageFeeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: ccInputDecoration(prefix: Icons.attach_money),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConditionCard(
    String code,
    String title,
    String subtitle,
    IconData icon,
    Color activeColor,
  ) {
    final isSelected = _containerCondition == code;
    return InkWell(
      onTap: () => setState(() => _containerCondition = code),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.08) : AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.borderOf(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: isSelected ? activeColor : AppTheme.textMutedOf(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? activeColor : AppTheme.textPrimaryOf(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverAndTruckRow(AppLocalizations l) {
    return CcFieldRow(
      children: [
        CcField(
          label: l.erDriver,
          child: TextFormField(
            controller: _driverNameCtrl,
            decoration: ccInputDecoration(prefix: Icons.person_outline),
          ),
        ),
        CcField(
          label: l.erTruckPlate,
          child: TextFormField(
            controller: _truckPlateNoCtrl,
            decoration: ccInputDecoration(prefix: Icons.local_shipping_outlined),
          ),
        ),
      ],
    );
  }
}
