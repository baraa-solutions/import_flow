import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../../operational_dashboard/providers/operational_dashboard_provider.dart';
import '../../../smart_tasks/providers/smart_tasks_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../models/import_requirement_model.dart';
import '../../providers/import_requirements_provider.dart';
import '../pillars/pillars.dart';
import '../prefill_messages_banner.dart';
import 'advanced_operational_pillars_accordion.dart';
import 'hs_codes_selector_card.dart';
import 'import_file_selector_card.dart';
import 'import_requirements_bottom_bar.dart';
import 'import_requirements_lifecycle_stepper.dart';

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

  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _hsCodeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'USD');
  final _valueCtrl = TextEditingController();
  final _acidNumberCtrl = TextEditingController();
  final _factoryRegCtrl = TextEditingController();
  final _cooNotesCtrl = TextEditingController();
  final _inspReportNoCtrl = TextEditingController();
  final _inspNotesCtrl = TextEditingController();
  final _permitNumberCtrl = TextEditingController();
  final _permitNotesCtrl = TextEditingController();
  final _msdsNotesCtrl = TextEditingController();
  final _halalNotesCtrl = TextEditingController();
  final _coaNotesCtrl = TextEditingController();
  final _specialNotesCtrl = TextEditingController();
  final _sailingDateCtrl = TextEditingController();
  final _assessedByCtrl = TextEditingController();

  // 5 Pillars State
  bool _decree43Applicable = false;
  bool _whiteListRequired = false;
  bool _whiteListVerified = false;
  String? _decree43Action;
  String? _decree43Justification;

  bool _cooRequired = false;
  String? _cooType;
  String _cooStatus = 'Not Required';

  bool _inspectionRequired = false;
  String? _inspectionBody;
  String _inspectionStatus = 'Not Required';

  bool _importPermitRequired = false;
  String? _permitIssuingAuthority;
  String _permitStatus = 'Not Required';

  bool _msdsRequired = false;
  String _msdsStatus = 'Not Required';
  bool _halalCertRequired = false;
  String _halalCertStatus = 'Not Required';
  bool _coaRequired = false;
  String _coaStatus = 'Not Required';

  String _confirmationStatus = 'Pending Confirmation';
  bool _isPostAcidConfirmed = false;
  String _sailingStatus = 'Pre-Sailing';
  String _overallStatus = 'Draft';
  String _riskLevel = 'Low';

  // Advanced Pillars State
  bool _cargoxVerified = false;
  String _cargoxStatus = 'PENDING';
  String? _cargoxId;
  bool _isShelflifeApplicable = false;
  String? _eosSpecNumber;
  bool _samplingRequired = false;
  String? _labType;
  bool _isHazmat = false;
  String? _imoClass;

  @override
  void initState() {
    super.initState();
    _assessedByCtrl.text = 'كمال - استشاري التخليص الجمركي';
  }

  @override
  void dispose() {
    _hsCodeCtrl.dispose();
    _descCtrl.dispose();
    _originCtrl.dispose();
    _currencyCtrl.dispose();
    _valueCtrl.dispose();
    _acidNumberCtrl.dispose();
    _factoryRegCtrl.dispose();
    _cooNotesCtrl.dispose();
    _inspReportNoCtrl.dispose();
    _inspNotesCtrl.dispose();
    _permitNumberCtrl.dispose();
    _permitNotesCtrl.dispose();
    _msdsNotesCtrl.dispose();
    _halalNotesCtrl.dispose();
    _coaNotesCtrl.dispose();
    _specialNotesCtrl.dispose();
    _sailingDateCtrl.dispose();
    _assessedByCtrl.dispose();
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

      _hsCodeCtrl.clear();
      _descCtrl.clear();
      _originCtrl.clear();
      _currencyCtrl.text = 'USD';
      _valueCtrl.clear();
      _acidNumberCtrl.clear();
      _factoryRegCtrl.clear();
      _cooNotesCtrl.clear();
      _inspReportNoCtrl.clear();
      _inspNotesCtrl.clear();
      _permitNumberCtrl.clear();
      _permitNotesCtrl.clear();
      _msdsNotesCtrl.clear();
      _halalNotesCtrl.clear();
      _coaNotesCtrl.clear();
      _specialNotesCtrl.clear();
      _sailingDateCtrl.clear();
      _assessedByCtrl.text = 'كمال - استشاري التخليص الجمركي';

      _decree43Applicable = false;
      _whiteListRequired = false;
      _whiteListVerified = false;
      _decree43Action = null;
      _decree43Justification = null;
      _cooRequired = false;
      _cooType = null;
      _cooStatus = 'Not Required';
      _inspectionRequired = false;
      _inspectionBody = null;
      _inspectionStatus = 'Not Required';
      _importPermitRequired = false;
      _permitIssuingAuthority = null;
      _permitStatus = 'Not Required';
      _msdsRequired = false;
      _msdsStatus = 'Not Required';
      _halalCertRequired = false;
      _halalCertStatus = 'Not Required';
      _coaRequired = false;
      _coaStatus = 'Not Required';
      _confirmationStatus = 'Pending Confirmation';
      _isPostAcidConfirmed = false;
      _sailingStatus = 'Pre-Sailing';
      _overallStatus = 'Draft';
      _riskLevel = 'Low';

      _cargoxVerified = false;
      _cargoxStatus = 'PENDING';
      _cargoxId = null;
      _isShelflifeApplicable = false;
      _eosSpecNumber = null;
      _samplingRequired = false;
      _labType = null;
      _isHazmat = false;
      _imoClass = null;
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

      _acidNumberCtrl.text = item.acidNumber ?? '';
      _sailingDateCtrl.text = item.sailingDate ?? '';
      _assessedByCtrl.text = item.assessedBy;
      _confirmationStatus = item.confirmationStatus;
      _isPostAcidConfirmed = item.isPostAcidConfirmed;
      _sailingStatus = item.sailingStatus;
      _overallStatus = item.overallStatus;
      _riskLevel = item.riskLevel;

      _cargoxVerified = item.cargoxVerified;
      _cargoxStatus = item.cargoxStatus;
      _isShelflifeApplicable = item.isShelflifeApplicable;
      _samplingRequired = item.samplingRequired;
      _labType = item.labType;
      _isHazmat = item.isHazmat;
      _imoClass = item.imoClass;

      _hsCodeItems.clear();
      _hsCodeItems.addAll(item.hsCodeItems);
      _selectedHsItemIndex = 0;

      if (_hsCodeItems.isNotEmpty) {
        _loadHsItemState(0);
      } else {
        _hsCodeCtrl.text = item.hsCode ?? '';
        _descCtrl.text = item.commodityDescription ?? '';
        _originCtrl.text = item.countryOfOrigin ?? '';
        _currencyCtrl.text = item.currency ?? 'USD';
        _valueCtrl.text = item.shipmentValue.toStringAsFixed(2);
        _factoryRegCtrl.text = item.factoryRegistrationNo ?? '';
        _decree43Applicable = item.decree43Applicable;
        _whiteListRequired = item.whiteListRequired;
        _whiteListVerified = item.whiteListVerified;
        _decree43Action = item.decree43Action;
        _decree43Justification = item.decree43Justification;
        _cooRequired = item.cooRequired;
        _cooType = item.cooType;
        _cooStatus = item.cooStatus;
        _cooNotesCtrl.text = item.cooNotes ?? '';
        _inspectionRequired = item.inspectionRequired;
        _inspectionBody = item.inspectionBody;
        _inspectionStatus = item.inspectionStatus;
        _inspReportNoCtrl.text = item.inspectionReportNo ?? '';
        _inspNotesCtrl.text = item.inspectionNotes ?? '';
        _importPermitRequired = item.importPermitRequired;
        _permitIssuingAuthority = item.permitIssuingAuthority;
        _permitNumberCtrl.text = item.permitNumber ?? '';
        _permitStatus = item.permitStatus;
        _permitNotesCtrl.text = item.permitNotes ?? '';
        _msdsRequired = item.msdsRequired;
        _msdsStatus = item.msdsStatus;
        _msdsNotesCtrl.text = item.msdsNotes ?? '';
        _halalCertRequired = item.halalCertRequired;
        _halalCertStatus = item.halalCertStatus;
        _halalNotesCtrl.text = item.halalCertNotes ?? '';
        _coaRequired = item.coaRequired;
        _coaStatus = item.coaStatus;
        _coaNotesCtrl.text = item.coaNotes ?? '';
        _specialNotesCtrl.text = item.assessmentNotes ?? '';
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
        _acidNumberCtrl.text = prefill.acidNumber ?? '';
        _originCtrl.text = prefill.countryOfOrigin ?? 'China';
        _currencyCtrl.text = prefill.currency ?? '';
        _valueCtrl.text = prefill.shipmentValue != null ? prefill.shipmentValue!.toStringAsFixed(2) : '';
        _factoryRegCtrl.text = prefill.factoryRegistrationNo ?? prefill.foreignExporterId ?? '';

        _cargoxVerified = prefill.cargoxVerified;
        _cargoxStatus = prefill.cargoxStatus;
        _isShelflifeApplicable = prefill.isShelflifeApplicable;
        _samplingRequired = prefill.samplingRequired;
        _labType = prefill.labType;
        _isHazmat = prefill.isHazmat;
        _imoClass = prefill.imoClass;

        _hsCodeItems.clear();
        _hsCodeItems.addAll(prefill.hsCodeItems);
        _selectedHsItemIndex = 0;

        if (_hsCodeItems.isNotEmpty) {
          _loadHsItemState(0);
        } else {
          _hsCodeCtrl.text = prefill.hsCode ?? '';
          _descCtrl.text = prefill.commodityDescription ?? '';
          _decree43Applicable = prefill.decree43Applicable;
          _whiteListRequired = prefill.whiteListRequired;
          _whiteListVerified = prefill.whiteListVerified;
          _cooRequired = prefill.cooRequired;
          _cooType = prefill.cooType;
          _cooStatus = prefill.cooStatus;
          _cooNotesCtrl.text = prefill.cooNotes ?? '';
          _inspectionRequired = prefill.inspectionRequired;
          _inspectionBody = prefill.inspectionBody;
          _inspectionStatus = prefill.inspectionStatus;
          _inspNotesCtrl.text = prefill.inspectionNotes ?? '';
          _importPermitRequired = prefill.importPermitRequired;
          _permitIssuingAuthority = DomainEnums.legacyToCode(
            DomainEnumType.regulatoryBody,
            prefill.permitIssuingAuthority,
          );
          _permitStatus = prefill.permitStatus;
          _permitNotesCtrl.text = prefill.permitNotes ?? '';
          _msdsRequired = prefill.msdsRequired;
          _msdsStatus = prefill.msdsStatus;
          _halalCertRequired = prefill.halalCertRequired;
          _halalCertStatus = prefill.halalCertStatus;
          _coaRequired = prefill.coaRequired;
          _coaStatus = prefill.coaStatus;
          _specialNotesCtrl.text = prefill.specialNotes ?? '';
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
    final current = _hsCodeItems[_selectedHsItemIndex];
    _hsCodeItems[_selectedHsItemIndex] = current.copyWith(
      hsCode: _hsCodeCtrl.text.trim(),
      commodityDescription: _descCtrl.text.trim(),
      countryOfOrigin: _originCtrl.text.trim(),
      currency: _currencyCtrl.text.trim(),
      itemValue: double.tryParse(_valueCtrl.text) ?? current.itemValue,
      decree43Applicable: _decree43Applicable,
      whiteListRequired: _whiteListRequired,
      whiteListVerified: _whiteListVerified,
      decree43Action: _decree43Action,
      decree43Justification: _decree43Justification,
      factoryRegistrationNo: _factoryRegCtrl.text.trim(),
      cooRequired: _cooRequired,
      cooType: _cooType,
      cooStatus: _cooStatus,
      cooNotes: _cooNotesCtrl.text.trim(),
      inspectionRequired: _inspectionRequired,
      inspectionBody: _inspectionBody,
      inspectionStatus: _inspectionStatus,
      inspectionReportNo: _inspReportNoCtrl.text.trim(),
      inspectionNotes: _inspNotesCtrl.text.trim(),
      permitRequired: _importPermitRequired,
      regulatoryAuthority: _permitIssuingAuthority,
      permitNumber: _permitNumberCtrl.text.trim(),
      permitStatus: _permitStatus,
      permitNotes: _permitNotesCtrl.text.trim(),
      msdsRequired: _msdsRequired,
      msdsStatus: _msdsStatus,
      msdsNotes: _msdsNotesCtrl.text.trim(),
      halalCertRequired: _halalCertRequired,
      halalCertStatus: _halalCertStatus,
      halalCertNotes: _halalNotesCtrl.text.trim(),
      coaRequired: _coaRequired,
      coaStatus: _coaStatus,
      coaNotes: _coaNotesCtrl.text.trim(),
      specialNotes: _specialNotesCtrl.text.trim(),
    );
  }

  void _loadHsItemState(int index) {
    if (index < 0 || index >= _hsCodeItems.length) return;
    final itm = _hsCodeItems[index];
    _selectedHsItemIndex = index;
    _hsCodeCtrl.text = itm.hsCode;
    _descCtrl.text = itm.commodityDescription ?? '';
    _originCtrl.text = itm.countryOfOrigin ?? _originCtrl.text;
    _currencyCtrl.text = itm.currency ?? _currencyCtrl.text;
    _valueCtrl.text = itm.itemValue > 0 ? itm.itemValue.toStringAsFixed(2) : _valueCtrl.text;
    _factoryRegCtrl.text = itm.factoryRegistrationNo ?? _factoryRegCtrl.text;
    _decree43Applicable = itm.decree43Applicable;
    _whiteListRequired = itm.whiteListRequired;
    _whiteListVerified = itm.whiteListVerified;
    _decree43Action = itm.decree43Action;
    _decree43Justification = itm.decree43Justification;
    _cooRequired = itm.cooRequired;
    _cooType = itm.cooType;
    _cooStatus = itm.cooStatus;
    _cooNotesCtrl.text = itm.cooNotes ?? '';
    _inspectionRequired = itm.inspectionRequired;
    _inspectionBody = itm.inspectionBody;
    _inspectionStatus = itm.inspectionStatus;
    _inspReportNoCtrl.text = itm.inspectionReportNo ?? '';
    _inspNotesCtrl.text = itm.inspectionNotes ?? '';
    _importPermitRequired = itm.permitRequired;
    _permitIssuingAuthority = itm.regulatoryAuthority;
    _permitNumberCtrl.text = itm.permitNumber ?? '';
    _permitStatus = itm.permitStatus;
    _permitNotesCtrl.text = itm.permitNotes ?? '';
    _msdsRequired = itm.msdsRequired;
    _msdsStatus = itm.msdsStatus;
    _msdsNotesCtrl.text = itm.msdsNotes ?? '';
    _halalCertRequired = itm.halalCertRequired;
    _halalCertStatus = itm.halalCertStatus;
    _halalNotesCtrl.text = itm.halalCertNotes ?? '';
    _coaRequired = itm.coaRequired;
    _coaStatus = itm.coaStatus;
    _coaNotesCtrl.text = itm.coaNotes ?? '';
    _specialNotesCtrl.text = itm.specialNotes ?? '';
  }

  void _autoCompleteAllPillars() {
    final l10n = context.l10n;
    setState(() {
      _whiteListVerified = true;
      _cooStatus = 'Obtained';
      _inspectionStatus = 'Completed';
      _permitStatus = 'Approved';
      _msdsStatus = 'Obtained';
      _halalCertStatus = 'Obtained';
      _coaStatus = 'Obtained';
      _isPostAcidConfirmed = true;
      _confirmationStatus = 'Confirmed';
      _sailingStatus = 'Cleared for Sailing';
      _overallStatus = 'Complete';
      _riskLevel = 'Low';
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

    final payload = {
      'import_file_id': _selectedImportFileId,
      'import_file_code': _selectedImportFileCode,
      'hs_code': _hsCodeCtrl.text.trim(),
      'commodity_description': _descCtrl.text.trim(),
      'country_of_origin': _originCtrl.text.trim(),
      'currency': _currencyCtrl.text.trim(),
      'shipment_value': double.tryParse(_valueCtrl.text) ?? 0.0,
      'shipment_value_usd': double.tryParse(_valueCtrl.text) ?? 0.0,
      'hs_code_items': _hsCodeItems.map((e) => e.toJson()).toList(),
      'supplier_id': _selectedSupplierId,
      'supplier_name': _selectedSupplierName,
      'decree_43_applicable': _decree43Applicable,
      'white_list_required': _whiteListRequired,
      'white_list_verified': _whiteListVerified,
      'decree_43_action': _decree43Action,
      'decree_43_justification': _decree43Justification,
      'factory_registration_no': _factoryRegCtrl.text.trim(),
      'coo_required': _cooRequired,
      'coo_type': _cooType,
      'coo_status': _cooStatus,
      'coo_notes': _cooNotesCtrl.text.trim(),
      'inspection_required': _inspectionRequired,
      'inspection_body': _inspectionBody,
      'inspection_status': _inspectionStatus,
      'inspection_report_no': _inspReportNoCtrl.text.trim(),
      'inspection_notes': _inspNotesCtrl.text.trim(),
      'import_permit_required': _importPermitRequired,
      'permit_issuing_authority': _permitIssuingAuthority,
      'permit_number': _permitNumberCtrl.text.trim(),
      'permit_status': _permitStatus,
      'permit_notes': _permitNotesCtrl.text.trim(),
      'msds_required': _msdsRequired,
      'msds_status': _msdsStatus,
      'msds_notes': _msdsNotesCtrl.text.trim(),
      'halal_cert_required': _halalCertRequired,
      'halal_cert_status': _halalCertStatus,
      'halal_cert_notes': _halalNotesCtrl.text.trim(),
      'coa_required': _coaRequired,
      'coa_status': _coaStatus,
      'coa_notes': _coaNotesCtrl.text.trim(),
      'cargox_verified': _cargoxVerified,
      'cargox_status': _cargoxStatus,
      'is_shelflife_applicable': _isShelflifeApplicable,
      'sampling_required': _samplingRequired,
      'lab_type': _labType,
      'is_hazmat': _isHazmat,
      'imo_class': _imoClass,
      'acid_number': _acidNumberCtrl.text.trim(),
      'consultation_id': _selectedConsultationId,
      'consultation_code': _selectedConsultationCode,
      'confirmation_status': _confirmationStatus,
      'is_post_acid_confirmed': _isPostAcidConfirmed,
      'confirmed_at': _isPostAcidConfirmed ? DateTime.now().toIso8601String() : null,
      'confirmed_by': _assessedByCtrl.text.trim(),
      'sailing_status': _sailingStatus,
      'sailing_date': _sailingDateCtrl.text.trim(),
      'overall_status': _overallStatus,
      'risk_level': _riskLevel,
      'assessed_by': _assessedByCtrl.text.trim(),
      'assessment_notes': _specialNotesCtrl.text.trim(),
    };

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
    final saved = await Decree43JustificationDialog.show(context, initialJustification: _decree43Justification);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _decree43Action = 'justified';
        _decree43Justification = saved;
        _saveCurrentHsItemState();
      });
      AppTheme.snackBar(context, l10n.decree43JustificationSavedBadge, severity: AppSeverity.success);
    }
  }

  void _createDecree43RegistrationTask() {
    final l10n = context.l10n;
    setState(() {
      _decree43Action = 'task_created';
      _decree43Justification = null;
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
              ImportRequirementsLifecycleStepper(
                sailingStatus: _sailingStatus,
                acidNumber: _acidNumberCtrl.text,
                inspectionStatus: _inspectionStatus,
                cooStatus: _cooStatus,
                whiteListVerified: _whiteListVerified,
              ),
              const SizedBox(height: 12),
              PrefillMessagesBanner(messages: _prefillMessages),
              const SizedBox(height: 12),
              ImportFileSelectorCard(
                importFiles: importFiles,
                suppliers: suppliers,
                selectedImportFileId: _selectedImportFileId,
                onImportFileChanged: _onImportFileChanged,
                acidNumberCtrl: _acidNumberCtrl,
                selectedSupplierId: _selectedSupplierId,
                onSupplierChanged: (v) {
                  setState(() {
                    _selectedSupplierId = v;
                    final matched = suppliers.where((s) => s.supplierId == v).firstOrNull;
                    if (matched != null) {
                      _selectedSupplierName = matched.companyName;
                      if (matched.foreignExporterCountry.isNotEmpty) {
                        _originCtrl.text = matched.foreignExporterCountry;
                      }
                      if (matched.foreignExporterId.isNotEmpty) {
                        _factoryRegCtrl.text = matched.foreignExporterId;
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
                hsCodeCtrl: _hsCodeCtrl,
                descCtrl: _descCtrl,
                originCtrl: _originCtrl,
                currencyCtrl: _currencyCtrl,
                valueCtrl: _valueCtrl,
                isDecree43Applicable: _decree43Applicable,
                isWhiteListVerified: _whiteListVerified,
                decree43Action: _decree43Action,
                isCooRequired: _cooRequired,
                cooStatus: _cooStatus,
                isInspectionRequired: _inspectionRequired,
                inspectionStatus: _inspectionStatus,
                isImportPermitRequired: _importPermitRequired,
                permitStatus: _permitStatus,
                isPostAcidConfirmed: _isPostAcidConfirmed,
              ),
              const SizedBox(height: 12),
              PillarsWorkspaceCard(
                activePillarIndex: _activePillarIndex,
                onPillarTabSelected: (idx) => setState(() => _activePillarIndex = idx),
                whiteListVerified: _whiteListVerified,
                cooFulfilled: _cooStatus == 'Obtained',
                inspectionFulfilled: _inspectionStatus == 'Completed',
                permitFulfilled: _permitStatus == 'Approved',
                techCertsFulfilled: _isPostAcidConfirmed,
                hsCode: _hsCodeCtrl.text,
                commodityDescription: _descCtrl.text,
                pillar1Child: Pillar1Decree43Widget(
                  decree43Applicable: _decree43Applicable,
                  whiteListVerified: _whiteListVerified,
                  factoryRegCtrl: _factoryRegCtrl,
                  decree43Action: _decree43Action,
                  decree43Justification: _decree43Justification,
                  onDecree43ApplicableChanged: (v) => setState(() {
                    _decree43Applicable = v;
                    _saveCurrentHsItemState();
                  }),
                  onWhiteListVerifiedChanged: (v) => setState(() {
                    _whiteListVerified = v;
                    _saveCurrentHsItemState();
                  }),
                  onRequestJustification: _showDecree43JustificationDialog,
                  onCreateDashboardTask: _createDecree43RegistrationTask,
                ),
                pillar2Child: Pillar2CooWidget(
                  cooRequired: _cooRequired,
                  cooType: _cooType,
                  cooStatus: _cooStatus,
                  cooNotesCtrl: _cooNotesCtrl,
                  onCooRequiredChanged: (v) => setState(() {
                    _cooRequired = v;
                    _saveCurrentHsItemState();
                  }),
                  onCooTypeChanged: (v) => setState(() {
                    _cooType = v;
                    _saveCurrentHsItemState();
                  }),
                  onCooStatusChanged: (v) => setState(() {
                    _cooStatus = v;
                    _saveCurrentHsItemState();
                  }),
                ),
                pillar3Child: Pillar3InspectionWidget(
                  inspectionRequired: _inspectionRequired,
                  inspectionBody: _inspectionBody,
                  inspectionStatus: _inspectionStatus,
                  inspReportNoCtrl: _inspReportNoCtrl,
                  inspNotesCtrl: _inspNotesCtrl,
                  onInspectionRequiredChanged: (v) => setState(() {
                    _inspectionRequired = v;
                    _saveCurrentHsItemState();
                  }),
                  onInspectionBodyChanged: (v) => setState(() {
                    _inspectionBody = v;
                    _saveCurrentHsItemState();
                  }),
                  onInspectionStatusChanged: (v) => setState(() {
                    _inspectionStatus = v;
                    _saveCurrentHsItemState();
                  }),
                ),
                pillar4Child: Pillar4PermitsWidget(
                  importPermitRequired: _importPermitRequired,
                  permitIssuingAuthority: _permitIssuingAuthority,
                  permitStatus: _permitStatus,
                  permitNumberCtrl: _permitNumberCtrl,
                  permitNotesCtrl: _permitNotesCtrl,
                  onImportPermitRequiredChanged: (v) => setState(() {
                    _importPermitRequired = v;
                    _saveCurrentHsItemState();
                  }),
                  onPermitIssuingAuthorityChanged: (v) => setState(() {
                    _permitIssuingAuthority = v;
                    _saveCurrentHsItemState();
                  }),
                  onPermitStatusChanged: (v) => setState(() {
                    _permitStatus = v;
                    _saveCurrentHsItemState();
                  }),
                ),
                pillar5Child: Pillar5TechCertsWidget(
                  msdsRequired: _msdsRequired,
                  halalCertRequired: _halalCertRequired,
                  coaRequired: _coaRequired,
                  sailingStatus: _sailingStatus,
                  riskLevel: _riskLevel,
                  overallStatus: _overallStatus,
                  sailingDateCtrl: _sailingDateCtrl,
                  specialNotesCtrl: _specialNotesCtrl,
                  onMsdsRequiredChanged: (v) => setState(() {
                    _msdsRequired = v;
                    _saveCurrentHsItemState();
                  }),
                  onHalalCertRequiredChanged: (v) => setState(() {
                    _halalCertRequired = v;
                    _saveCurrentHsItemState();
                  }),
                  onCoaRequiredChanged: (v) => setState(() {
                    _coaRequired = v;
                    _saveCurrentHsItemState();
                  }),
                  onSailingStatusChanged: (v) => setState(() {
                    _sailingStatus = v;
                    _saveCurrentHsItemState();
                  }),
                  onRiskLevelChanged: (v) => setState(() {
                    _riskLevel = v;
                    _saveCurrentHsItemState();
                  }),
                  onOverallStatusChanged: (v) => setState(() {
                    _overallStatus = v;
                    _saveCurrentHsItemState();
                  }),
                ),
              ),
              const SizedBox(height: 12),
              AdvancedOperationalPillarsAccordion(
                supplierName: _selectedSupplierName,
                supplierCountry: _originCtrl.text,
                cargoxId: _cargoxId,
                cargoxStatus: _cargoxStatus,
                onCargoXChanged: (d) => setState(() {
                  _cargoxId = d.cargoxPlatformId;
                  _cargoxStatus = d.status;
                  _cargoxVerified = d.isAccountAuthorized;
                }),
                isShelflifeApplicable: _isShelflifeApplicable,
                eosSpecNumber: _eosSpecNumber,
                onShelfLifeChanged: (d) => setState(() {
                  _isShelflifeApplicable = d.isSubjectToShelfLife;
                  _eosSpecNumber = d.eosSpecNumber;
                }),
                samplingRequired: _samplingRequired,
                labType: _labType,
                onTestingLabChanged: (d) => setState(() {
                  _samplingRequired = true;
                  _labType = d.assignedLaboratory;
                }),
                isHazmat: _isHazmat,
                imoClass: _imoClass,
                onHazmatChanged: (d) => setState(() {
                  _isHazmat = d.isHazardous;
                  _imoClass = d.imdgClass;
                }),
              ),
              const SizedBox(height: 16),
              ImportRequirementsBottomBar(
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
                  _overallStatus = 'Draft';
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
