import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../../operational_dashboard/providers/operational_dashboard_provider.dart';
import '../../../smart_tasks/providers/smart_tasks_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../models/import_requirement_model.dart';
import '../../providers/import_requirements_provider.dart';
import '../pillars/pillars.dart';
import 'hs_codes_selector_card.dart';
import 'sections/hs_sync_helper.dart';
import 'sections/import_requirements_controllers.dart';
import 'sections/import_requirements_footer_section.dart';
import 'sections/import_requirements_header_section.dart';
import 'sections/import_requirements_pillars_state.dart';
import 'sections/pillars_workspace_section.dart';

/// 📝 Import Requirements Interactive Form Tab — ImportFlow ERP
///
/// Encapsulates the entire multi-pillar compliance form, prefill banner,
/// statutory 5 Pillars wiring, and advanced operational pillars.
class ImportRequirementsFormTab extends ConsumerStatefulWidget {
  final VoidCallback onSavedSuccessfully;
  final VoidCallback onGoToRegistryRequested;

  const ImportRequirementsFormTab({
    super.key,
    required this.onSavedSuccessfully,
    required this.onGoToRegistryRequested,
  });

  @override
  ConsumerState<ImportRequirementsFormTab> createState() => ImportRequirementsFormTabState();
}

class ImportRequirementsFormTabState extends ConsumerState<ImportRequirementsFormTab> {
  // Form State
  int _activePillarIndex = 0;
  int? _editingAssessmentId;
  String? _editingAssessmentCode;
  int? _selectedImportFileId;
  String? _selectedImportFileCode;
  int? _selectedSupplierId;
  String? _selectedSupplierName;
  String? _selectedConsultationCode;
  int? _selectedConsultationId;
  double _consultationReadiness = 0.0;
  bool _isSaving = false;
  List<PrefillMessage> _prefillMessages = const [];

  final List<ImportRequirementHSCodeItemModel> _hsCodeItems = [];
  int _selectedHsItemIndex = 0;

  final _formKey = GlobalKey<FormState>();
  final _c = ImportRequirementsControllers();
  final _p = ImportRequirementsPillarsState();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void resetForm() {
    setState(() {
      _editingAssessmentId = null;
      _editingAssessmentCode = null;
      _selectedImportFileId = null;
      _selectedImportFileCode = null;
      _selectedSupplierId = null;
      _selectedSupplierName = null;
      _selectedConsultationCode = null;
      _selectedConsultationId = null;
      _consultationReadiness = 0.0;
      _prefillMessages = const [];
      _hsCodeItems.clear();
      _selectedHsItemIndex = 0;
      _activePillarIndex = 0;

      _c.clearAll();
      _p.reset();
    });
  }

  void loadAssessment(ImportRequirementModel item) {
    setState(() {
      _editingAssessmentId = item.assessmentId;
      _editingAssessmentCode = item.assessmentCode;
      _selectedImportFileId = item.importFileId;
      _selectedImportFileCode = item.importFileCode;
      _selectedSupplierId = item.supplierId;
      _selectedSupplierName = item.supplierName;
      _selectedConsultationCode = item.consultationCode;
      _selectedConsultationId = item.consultationId;

      _hsCodeItems.clear();
      _hsCodeItems.addAll(item.hsCodeItems);
      _selectedHsItemIndex = 0;

      _c.loadFromAssessment(item);
      _p.loadFromAssessment(item);

      if (_hsCodeItems.isNotEmpty) {
        _loadHsItemState(0);
      }
    });
  }

  Future<void> _onImportFileChanged(int? fileId) async {
    if (fileId == null) {
      resetForm();
      return;
    }
    final l10n = context.l10n;
    try {
      final prefill = await ref.read(importRequirementsProvider.notifier).fetchPrefillData(fileId);
      if (!mounted || prefill == null) return;

      setState(() {
        _prefillMessages = prefill.messages;
        _selectedImportFileId = prefill.importFileId;
        _selectedImportFileCode = prefill.importFileCode;
        _selectedSupplierId = prefill.supplierId;
        _selectedSupplierName = prefill.supplierName;
        _selectedConsultationCode = prefill.consultationCode;
        _selectedConsultationId = prefill.consultationId;
        _consultationReadiness = prefill.readinessPercentage;

        _hsCodeItems.clear();
        _hsCodeItems.addAll(prefill.hsCodeItems);
        _selectedHsItemIndex = 0;

        _c.loadFromPrefill(prefill);
        _p.loadFromPrefill(prefill);

        if (_hsCodeItems.isNotEmpty) {
          _loadHsItemState(0);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.prefillImportRequirementSuccess(prefill.hsCodeItems.length, prefill.importFileCode)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, ApiErrorText.of(l10n, e), severity: AppSeverity.danger),
        );
      }
    }
  }

  void _saveCurrentHsItemState() {
    if (_hsCodeItems.isEmpty || _selectedHsItemIndex < 0 || _selectedHsItemIndex >= _hsCodeItems.length) return;
    _hsCodeItems[_selectedHsItemIndex] = HsSyncHelper.syncCurrentItem(
      current: _hsCodeItems[_selectedHsItemIndex],
      hsCode: _c.hsCodeCtrl.text.trim(),
      commodityDescription: _c.descCtrl.text.trim(),
      countryOfOrigin: _c.originCtrl.text.trim(),
      currency: _c.currencyCtrl.text.trim(),
      itemValueStr: _c.valueCtrl.text,
      decree43Applicable: _p.decree43Applicable,
      whiteListRequired: _p.whiteListRequired,
      whiteListVerified: _p.whiteListVerified,
      decree43Action: _p.decree43Action,
      decree43Justification: _p.decree43Justification,
      factoryRegistrationNo: _c.factoryRegCtrl.text.trim(),
      cooRequired: _p.cooRequired,
      cooType: _p.cooType,
      cooStatus: _p.cooStatus,
      cooNotes: _c.cooNotesCtrl.text.trim(),
      inspectionRequired: _p.inspectionRequired,
      inspectionBody: _p.inspectionBody,
      inspectionStatus: _p.inspectionStatus,
      inspectionReportNo: _c.inspReportNoCtrl.text.trim(),
      inspectionNotes: _c.inspNotesCtrl.text.trim(),
      permitRequired: _p.importPermitRequired,
      regulatoryAuthority: _p.permitIssuingAuthority,
      permitNumber: _c.permitNumberCtrl.text.trim(),
      permitStatus: _p.permitStatus,
      permitNotes: _c.permitNotesCtrl.text.trim(),
      msdsRequired: _p.msdsRequired,
      msdsStatus: _p.msdsStatus,
      msdsNotes: _c.msdsNotesCtrl.text.trim(),
      halalCertRequired: _p.halalCertRequired,
      halalCertStatus: _p.halalCertStatus,
      halalCertNotes: _c.halalNotesCtrl.text.trim(),
      coaRequired: _p.coaRequired,
      coaStatus: _p.coaStatus,
      coaNotes: _c.coaNotesCtrl.text.trim(),
      specialNotes: _c.specialNotesCtrl.text.trim(),
    );
  }

  void _loadHsItemState(int index) {
    if (index < 0 || index >= _hsCodeItems.length) return;
    final itm = _hsCodeItems[index];
    _selectedHsItemIndex = index;
    _c.loadFromHsItem(itm);
    _p.loadFromHsItem(itm);
  }

  void _autoCompleteAllPillars() {
    final l10n = context.l10n;
    setState(() {
      _p.autoCompleteAll();
      _saveCurrentHsItemState();
    });
    AppTheme.snackBar(context, l10n.completeAllPillarsSuccessSnack, severity: AppSeverity.success);
  }

  Future<void> _saveAssessment() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate() || _selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.pleaseSelectImportFileError, severity: AppSeverity.warning),
      );
      return;
    }

    setState(() => _isSaving = true);
    _saveCurrentHsItemState();

    final payload = HsSyncHelper.buildPayload(
      selectedImportFileId: _selectedImportFileId,
      selectedImportFileCode: _selectedImportFileCode,
      hsCode: _c.hsCodeCtrl.text.trim(),
      commodityDescription: _c.descCtrl.text.trim(),
      countryOfOrigin: _c.originCtrl.text.trim(),
      currency: _c.currencyCtrl.text.trim(),
      itemValueStr: _c.valueCtrl.text,
      hsCodeItems: _hsCodeItems,
      selectedSupplierId: _selectedSupplierId,
      selectedSupplierName: _selectedSupplierName,
      decree43Applicable: _p.decree43Applicable,
      whiteListRequired: _p.whiteListRequired,
      whiteListVerified: _p.whiteListVerified,
      decree43Action: _p.decree43Action,
      decree43Justification: _p.decree43Justification,
      factoryRegistrationNo: _c.factoryRegCtrl.text.trim(),
      cooRequired: _p.cooRequired,
      cooType: _p.cooType,
      cooStatus: _p.cooStatus,
      cooNotes: _c.cooNotesCtrl.text.trim(),
      inspectionRequired: _p.inspectionRequired,
      inspectionBody: _p.inspectionBody,
      inspectionStatus: _p.inspectionStatus,
      inspectionReportNo: _c.inspReportNoCtrl.text.trim(),
      inspectionNotes: _c.inspNotesCtrl.text.trim(),
      importPermitRequired: _p.importPermitRequired,
      permitIssuingAuthority: _p.permitIssuingAuthority,
      permitNumber: _c.permitNumberCtrl.text.trim(),
      permitStatus: _p.permitStatus,
      permitNotes: _c.permitNotesCtrl.text.trim(),
      msdsRequired: _p.msdsRequired,
      msdsStatus: _p.msdsStatus,
      msdsNotes: _c.msdsNotesCtrl.text.trim(),
      halalCertRequired: _p.halalCertRequired,
      halalCertStatus: _p.halalCertStatus,
      halalCertNotes: _c.halalNotesCtrl.text.trim(),
      coaRequired: _p.coaRequired,
      coaStatus: _p.coaStatus,
      coaNotes: _c.coaNotesCtrl.text.trim(),
      cargoxVerified: _p.cargoxVerified,
      cargoxStatus: _p.cargoxStatus,
      isShelflifeApplicable: _p.isShelflifeApplicable,
      samplingRequired: _p.samplingRequired,
      labType: _p.labType,
      isHazmat: _p.isHazmat,
      imoClass: _p.imoClass,
      acidNumber: _c.acidNumberCtrl.text.trim(),
      consultationId: _selectedConsultationId,
      consultationCode: _selectedConsultationCode,
      confirmationStatus: _p.confirmationStatus,
      isPostAcidConfirmed: _p.isPostAcidConfirmed,
      sailingStatus: _p.sailingStatus,
      sailingDate: _c.sailingDateCtrl.text.trim(),
      overallStatus: _p.overallStatus,
      riskLevel: _p.riskLevel,
      assessedBy: _c.assessedByCtrl.text.trim(),
      assessmentNotes: _c.specialNotesCtrl.text.trim(),
    );

    try {
      if (_editingAssessmentId != null) {
        await ref.read(importRequirementsProvider.notifier).updateRequirement(_editingAssessmentId!, payload);
      } else {
        await ref.read(importRequirementsProvider.notifier).addRequirement(payload);
      }

      ref.invalidate(lifecycleBoardSummaryProvider);
      ref.invalidate(operationalDashboardProvider);
      ref.invalidate(smartTasksProvider);
      ref.invalidate(importFilesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, _editingAssessmentId != null
                  ? l10n.updateRequirementSuccessSnack(_editingAssessmentCode ?? '')
                  : l10n.createRequirementSuccessSnack, severity: AppSeverity.success),
        );
      }
      resetForm();
      widget.onSavedSuccessfully();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, ApiErrorText.of(l10n, e), severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showDecree43JustificationDialog() async {
    final l10n = context.l10n;
    final saved = await Decree43JustificationDialog.show(context, initialJustification: _p.decree43Justification);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _p.decree43Action = 'justified';
        _p.decree43Justification = saved;
        _saveCurrentHsItemState();
      });
      AppTheme.snackBar(context, l10n.decree43JustificationSavedBadge, severity: AppSeverity.success);
    }
  }

  void _createDecree43RegistrationTask() {
    final l10n = context.l10n;
    setState(() {
      _p.decree43Action = 'task_created';
      _p.decree43Justification = null;
      _saveCurrentHsItemState();
    });
    ref.read(smartTasksProvider.notifier).fetchTasks();
    ref.read(operationalDashboardProvider.notifier).fetchDashboard();
    AppTheme.snackBar(context, l10n.decree43TaskCreatedSuccessSnack, severity: AppSeverity.warning);
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ImportRequirementsHeaderSection(
                sailingStatus: _p.sailingStatus,
                acidNumber: _c.acidNumberCtrl.text,
                inspectionStatus: _p.inspectionStatus,
                cooStatus: _p.cooStatus,
                whiteListVerified: _p.whiteListVerified,
                prefillMessages: _prefillMessages,
                importFiles: importFiles,
                suppliers: suppliers,
                selectedImportFileId: _selectedImportFileId,
                onImportFileChanged: _onImportFileChanged,
                acidNumberCtrl: _c.acidNumberCtrl,
                selectedSupplierId: _selectedSupplierId,
                onSupplierChanged: (v) {
                  setState(() {
                    _selectedSupplierId = v;
                    final matched = suppliers.where((s) => s.supplierId == v).firstOrNull;
                    if (matched != null) {
                      _selectedSupplierName = matched.companyName;
                      if (matched.foreignExporterCountry.isNotEmpty) {
                        _c.originCtrl.text = matched.foreignExporterCountry;
                      }
                      if (matched.foreignExporterId.isNotEmpty) {
                        _c.factoryRegCtrl.text = matched.foreignExporterId;
                      }
                    }
                  });
                },
                selectedConsultationCode: _selectedConsultationCode,
                consultationReadiness: _consultationReadiness,
              ),
              const SizedBox(height: 12),
              HsCodesSelectorCard(
                hsCodeItems: _hsCodeItems,
                selectedHsItemIndex: _selectedHsItemIndex,
                onHsItemSelected: (idx) {
                  if (_selectedHsItemIndex == idx) return;
                  setState(() {
                    _saveCurrentHsItemState();
                    _loadHsItemState(idx);
                  });
                },
                hsCodeCtrl: _c.hsCodeCtrl,
                descCtrl: _c.descCtrl,
                originCtrl: _c.originCtrl,
                currencyCtrl: _c.currencyCtrl,
                valueCtrl: _c.valueCtrl,
                isDecree43Applicable: _p.decree43Applicable,
                isWhiteListVerified: _p.whiteListVerified,
                decree43Action: _p.decree43Action,
                isCooRequired: _p.cooRequired,
                cooStatus: _p.cooStatus,
                isInspectionRequired: _p.inspectionRequired,
                inspectionStatus: _p.inspectionStatus,
                isImportPermitRequired: _p.importPermitRequired,
                permitStatus: _p.permitStatus,
                isPostAcidConfirmed: _p.isPostAcidConfirmed,
              ),
              const SizedBox(height: 12),
              PillarsWorkspaceSection(
                activePillarIndex: _activePillarIndex,
                onPillarTabSelected: (idx) => setState(() => _activePillarIndex = idx),
                state: _p,
                controllers: _c,
                onStateUpdated: () => setState(_saveCurrentHsItemState),
                onRequestJustification: _showDecree43JustificationDialog,
                onCreateDashboardTask: _createDecree43RegistrationTask,
              ),
              const SizedBox(height: 12),
              ImportRequirementsFooterSection(
                supplierName: _selectedSupplierName,
                supplierCountry: _c.originCtrl.text,
                cargoxId: _p.cargoxId,
                cargoxStatus: _p.cargoxStatus,
                onCargoXChanged: (d) => setState(() {
                  _p.cargoxId = d.cargoxPlatformId;
                  _p.cargoxStatus = d.status;
                  _p.cargoxVerified = d.isAccountAuthorized;
                }),
                isShelflifeApplicable: _p.isShelflifeApplicable,
                eosSpecNumber: _p.eosSpecNumber,
                onShelfLifeChanged: (d) => setState(() {
                  _p.isShelflifeApplicable = d.isSubjectToShelfLife;
                  _p.eosSpecNumber = d.eosSpecNumber;
                }),
                samplingRequired: _p.samplingRequired,
                labType: _p.labType,
                onTestingLabChanged: (d) => setState(() {
                  _p.samplingRequired = true;
                  _p.labType = d.assignedLaboratory;
                }),
                isHazmat: _p.isHazmat,
                imoClass: _p.imoClass,
                onHazmatChanged: (d) => setState(() {
                  _p.isHazmat = d.isHazardous;
                  _p.imoClass = d.imdgClass;
                }),
                isEditing: _editingAssessmentId != null,
                isSaving: _isSaving,
                onAutoComplete: _autoCompleteAllPillars,
                onRefresh: () {
                  ref.read(importRequirementsProvider.notifier).refreshData();
                  ref.read(importFilesProvider.notifier).fetchImportFiles();
                  ref.read(suppliersProvider.notifier).fetchSuppliers();
                  ref.read(customsTariffProvider.notifier).fetchTariffs();
                },
                onReset: resetForm,
                onSaveDraft: () {
                  _p.overallStatus = 'Draft';
                  _saveAssessment();
                },
                onSubmit: _saveAssessment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
