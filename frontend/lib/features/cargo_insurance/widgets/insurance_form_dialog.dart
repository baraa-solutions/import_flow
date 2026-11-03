import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/cargo_insurance_model.dart';
import '../providers/cargo_insurance_provider.dart';
import 'insurance_form/insurance_form_controllers.dart';
import 'insurance_form/insurance_inputs_column.dart';
import 'insurance_form/insurance_calculation_column.dart';

// =============================================================================
// Form Dialog: Add / Edit & Calculate Insurance Certificate
// =============================================================================
class CargoInsuranceFormDialog extends ConsumerStatefulWidget {
  final CargoInsuranceModel? certificateToEdit;
  final int? initialImportFileId;
  const CargoInsuranceFormDialog({super.key, this.certificateToEdit, this.initialImportFileId});

  @override
  ConsumerState<CargoInsuranceFormDialog> createState() => CargoInsuranceFormDialogState();
}

class CargoInsuranceFormDialogState extends ConsumerState<CargoInsuranceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = InsuranceFormControllers();

  int? _selectedImportFileId;
  bool _isSaving = false;
  InsuranceCalculationResultModel? _calculationPreview;
  String? _calcError;
  Timer? _calcDebounce;
  int _calcSeq = 0;

  @override
  void initState() {
    super.initState();
    if (widget.certificateToEdit != null) {
      final c = widget.certificateToEdit!;
      _selectedImportFileId = c.importFileId;
      _controllers.populateFromCertificate(c);
    } else if (widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoFillFromImportFile(widget.initialImportFileId!);
      });
    }
    _runLiveCalculation();
  }

  @override
  void dispose() {
    _calcDebounce?.cancel();
    _controllers.dispose();
    super.dispose();
  }

  void _autoFillFromImportFile(int fileId) {
    final files = ref.read(importFilesProvider).value ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file != null) {
      _handleImportFileSelected(file);
    }
  }

  void _runLiveCalculation() {
    _calcDebounce?.cancel();
    _calcDebounce = Timer(const Duration(milliseconds: 400), _fetchCalculation);
  }

  Future<void> _fetchCalculation() async {
    final seq = ++_calcSeq;
    try {
      final result = await ref.read(cargoInsuranceProvider.notifier).calculateInsurance(_controllers.toCalculationPayload());
      if (!mounted || seq != _calcSeq) return;
      setState(() {
        _calculationPreview = result;
        _calcError = null;
      });
    } catch (e) {
      if (!mounted || seq != _calcSeq) return;
      setState(() {
        _calcError = ApiErrorText.of(context.l10n, e);
      });
    }
  }

  void _handleImportFileSelected(ImportFileModel? file) {
    if (file == null) return;
    setState(() {
      _selectedImportFileId = file.importFileId;
      _controllers.autoFillFromImportFile(ref, file);
    });
    _runLiveCalculation();
  }

  Future<void> _saveCertificate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final l = context.l10n;
    final payload = _controllers.toSavePayload(_selectedImportFileId);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      if (widget.certificateToEdit == null) {
        await ref.read(cargoInsuranceProvider.notifier).createCertificate(payload);
        if (mounted) {
          messenger.showSnackBar(
            AppTheme.snackBar(context, l.insuranceCreatedSuccessMsg, severity: AppSeverity.success),
          );
        }
      } else {
        await ref.read(cargoInsuranceProvider.notifier).updateCertificate(widget.certificateToEdit!.certificateId, payload);
        if (mounted) {
          messenger.showSnackBar(
            AppTheme.snackBar(context, l.insuranceUpdatedSuccessMsg, severity: AppSeverity.success),
          );
        }
      }
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(context, l.insuranceSaveErrorMsg(ApiErrorText.of(l, e)), severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFiles = ref.watch(importFilesProvider).asData?.value ?? [];

    return Form(
      key: _formKey,
      child: SelectionArea(
        child: CcStageDialogShell(
          title: widget.certificateToEdit == null
              ? l.insuranceDialogNewTitle
              : l.insuranceDialogEditTitle(widget.certificateToEdit!.certificateCode),
          icon: Icons.shield_rounded,
          accent: AppTheme.cobalt,
          maxWidth: 1100,
          chips: [
            if (widget.certificateToEdit != null)
              CcHeaderChip(Icons.tag, widget.certificateToEdit!.certificateCode, ltr: true),
          ],
          confirmLabel: l.insuranceSaveDraftBtn,
          loadingLabel: l.insuranceSavingState,
          isSubmitting: _isSaving,
          onConfirm: _saveCertificate,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.insuranceDialogSubtitle,
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context)),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) {
                  final left = InsuranceInputsColumn(
                    controllers: _controllers,
                    selectedImportFileId: _selectedImportFileId,
                    importFiles: importFiles,
                    onImportFileSelected: _handleImportFileSelected,
                    onLiveCalc: _runLiveCalculation,
                    onStateChanged: () => setState(() {}),
                  );
                  final right = InsuranceCalculationColumn(
                    controllers: _controllers,
                    calculationPreview: _calculationPreview,
                    calcError: _calcError,
                  );
                  if (c.maxWidth < 820) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [left, const SizedBox(height: 16), right],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: left),
                      const SizedBox(width: 18),
                      Expanded(flex: 4, child: right),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
