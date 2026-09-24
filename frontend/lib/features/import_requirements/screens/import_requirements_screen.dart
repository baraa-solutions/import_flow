import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_consultation/providers/customs_consultation_provider.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../operational_dashboard/providers/operational_dashboard_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../models/import_requirement_model.dart';
import '../providers/import_requirements_provider.dart';

Color _getStatusColor(String status) {
  switch (status) {
    case 'Obtained':
    case 'Completed':
    case 'Approved':
    case 'Cleared':
    case 'Confirmed':
    case 'Cleared for Sailing':
    case 'Sailed':
    case 'تم الاستلام والتحقق':
    case 'تم الفحص واجتياز المطابقة':
    case 'تمت الموافقة والاعتماد':
    case 'معتمد ومصرح للشحن':
    case 'مؤكد ومصرح للشحن':
    case 'جاهز للإبحار':
    case 'تم الإبحار':
      return AppTheme.emerald;
    case 'Pending':
    case 'In Progress':
    case 'Applied':
    case 'Scheduled':
    case 'Pre-Sailing':
    case 'مطلوبة':
    case 'قيد الاستيفاء':
    case 'قيد الاستيفاء والتأكيد':
    case 'تم تقديم الطلب':
    case 'تم التكليف والتنسيق':
    case 'قبل الإبحار':
      return AppTheme.orange;
    case 'Rejected':
    case 'مرفوض':
    case 'مرفوضة':
      return AppTheme.crimson;
    case 'Waived':
    case 'تم الإعفاء':
      return AppTheme.cobalt;
    default:
      return Colors.grey.shade600;
  }
}

Color _getRiskLevelColor(String risk) {
  switch (risk) {
    case 'Low':
    case 'منخفض':
    case 'منخفض (Low)':
      return AppTheme.emerald;
    case 'Medium':
    case 'متوسط':
    case 'متوسط (Medium)':
      return AppTheme.orange;
    case 'High':
    case 'مرتفع':
    case 'مرتفع (High)':
      return AppTheme.crimson;
    default:
      return Colors.grey;
  }
}

class ImportRequirementsScreen extends ConsumerStatefulWidget {
  const ImportRequirementsScreen({super.key});

  @override
  ConsumerState<ImportRequirementsScreen> createState() => _ImportRequirementsScreenState();
}

class _ImportRequirementsScreenState extends ConsumerState<ImportRequirementsScreen> with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  final TextEditingController _searchController = TextEditingController();
  
  // Registry Filters
  String _registryStatusFilter = 'All';
  String _registryRiskFilter = 'All';
  String _registryActiveFilter = 'Active'; // 'All', 'Active', 'Deleted'

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

  // Selected HS Code items
  final List<ImportRequirementHSCodeItemModel> _hsCodeItems = [];
  int _selectedHsItemIndex = 0;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _hsCodeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'USD');
  final _valueCtrl = TextEditingController(text: '0.0');
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
  final _assessedByCtrl = TextEditingController(text: 'Kamal (Import Compliance Mgr)');

  // Pillar Form State Variables
  bool _decree43Applicable = false;
  bool _whiteListRequired = false;
  bool _whiteListVerified = false;
  String? _decree43Action; // 'justified', 'task_created', or null
  String? _decree43Justification;

  bool _cooRequired = false;
  String _cooType = 'EUR.1';
  String _cooStatus = 'Not Required';

  bool _inspectionRequired = false;
  String _inspectionBody = 'SGS';
  String _inspectionStatus = 'Not Required';

  bool _importPermitRequired = false;
  String _permitIssuingAuthority = 'EEAA';
  String _permitStatus = 'Not Required';

  bool _msdsRequired = false;
  String _msdsStatus = 'Not Required';

  bool _halalCertRequired = false;
  String _halalCertStatus = 'Not Required';

  bool _coaRequired = false;
  String _coaStatus = 'Not Required';

  String _confirmationStatus = 'Pending Confirmation';
  bool _isPostAcidConfirmed = false;
  String _sailingStatus = 'Pre-Sailing'; // Pre-Sailing, Cleared for Sailing, Sailed
  String _overallStatus = 'Draft';
  String _riskLevel = 'Low';

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _searchController.dispose();
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

  void _refreshAllData() {
    if (!ref.read(importRequirementsProvider).isLoading) {
      ref.read(importRequirementsProvider.notifier).refreshData();
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(suppliersProvider).isLoading) {
      ref.read(suppliersProvider.notifier).fetchSuppliers();
    }
    if (!ref.read(customsTariffProvider).isLoading) {
      ref.read(customsTariffProvider.notifier).fetchTariffs();
    }
    if (!ref.read(customsConsultationsProvider).isLoading) {
      ref.read(customsConsultationsProvider.notifier).fetchConsultations();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
  }

  void _resetForm() {
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
      _hsCodeItems.clear();
      _selectedHsItemIndex = 0;

      _hsCodeCtrl.clear();
      _descCtrl.clear();
      _originCtrl.clear();
      _currencyCtrl.text = 'USD';
      _valueCtrl.text = '0.0';
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

      _decree43Applicable = false;
      _whiteListRequired = false;
      _whiteListVerified = false;
      _decree43Action = null;
      _decree43Justification = null;
      _cooRequired = false;
      _cooType = 'EUR.1';
      _cooStatus = 'Not Required';
      _inspectionRequired = false;
      _inspectionBody = 'SGS';
      _inspectionStatus = 'Not Required';
      _importPermitRequired = false;
      _permitIssuingAuthority = 'EEAA';
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
      _activePillarIndex = 0;
    });
  }

  Future<void> _onImportFileChanged(int? fileId) async {
    if (fileId == null) {
      _resetForm();
      return;
    }

    final prefill = await ref.read(importRequirementsProvider.notifier).fetchPrefillData(fileId);
    if (!mounted) return;

    final l10n = context.l10n;

    if (prefill != null) {
      setState(() {
        _selectedImportFileId = prefill.importFileId;
        _selectedImportFileCode = prefill.importFileCode;
        _selectedSupplierId = prefill.supplierId;
        _selectedSupplierName = prefill.supplierName;
        _selectedConsultationCode = prefill.consultationCode;
        _selectedConsultationId = prefill.consultationId;
        _consultationReadiness = prefill.readinessPercentage;

        _acidNumberCtrl.text = prefill.acidNumber ?? '';
        _originCtrl.text = prefill.countryOfOrigin ?? 'China';
        _currencyCtrl.text = prefill.currency;
        _valueCtrl.text = prefill.shipmentValue.toStringAsFixed(2);
        _factoryRegCtrl.text = prefill.factoryRegistrationNo ?? prefill.foreignExporterId ?? '';

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
          _decree43Action = null;
          _decree43Justification = null;

          _cooRequired = prefill.cooRequired;
          _cooType = prefill.cooType ?? 'EUR.1';
          _cooStatus = prefill.cooStatus;
          _cooNotesCtrl.text = prefill.cooNotes ?? '';

          _inspectionRequired = prefill.inspectionRequired;
          _inspectionBody = prefill.inspectionBody ?? 'SGS';
          _inspectionStatus = prefill.inspectionStatus;
          _inspNotesCtrl.text = prefill.inspectionNotes ?? '';

          _importPermitRequired = prefill.importPermitRequired;
          _permitIssuingAuthority = prefill.permitIssuingAuthority ?? 'EEAA';
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
        SnackBar(
          content: Text(l10n.prefillImportRequirementSuccess(prefill.hsCodeItems.length, prefill.importFileCode)),
          backgroundColor: AppTheme.cobalt,
          duration: const Duration(seconds: 3),
        ),
      );
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
    _selectedHsItemIndex = index;
    final itm = _hsCodeItems[index];

    _hsCodeCtrl.text = itm.hsCode;
    _descCtrl.text = itm.commodityDescription ?? '';
    _originCtrl.text = itm.countryOfOrigin ?? _originCtrl.text;
    _currencyCtrl.text = itm.currency;
    _valueCtrl.text = itm.itemValue.toStringAsFixed(2);

    _decree43Applicable = itm.decree43Applicable;
    _whiteListRequired = itm.whiteListRequired;
    _whiteListVerified = itm.whiteListVerified;
    _decree43Action = itm.decree43Action;
    _decree43Justification = itm.decree43Justification;
    _factoryRegCtrl.text = itm.factoryRegistrationNo ?? '';

    _cooRequired = itm.cooRequired;
    _cooType = itm.cooType ?? 'EUR.1';
    _cooStatus = itm.cooStatus;
    _cooNotesCtrl.text = itm.cooNotes ?? '';

    _inspectionRequired = itm.inspectionRequired;
    _inspectionBody = itm.inspectionBody ?? 'SGS';
    _inspectionStatus = itm.inspectionStatus;
    _inspReportNoCtrl.text = itm.inspectionReportNo ?? '';
    _inspNotesCtrl.text = itm.inspectionNotes ?? '';

    _importPermitRequired = itm.permitRequired;
    _permitIssuingAuthority = itm.regulatoryAuthority ?? 'EEAA';
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

  void _loadAssessmentForEditing(ImportRequirementModel item) {
    setState(() {
      _editingAssessmentId = item.assessmentId;
      _editingAssessmentCode = item.assessmentCode;
      _selectedImportFileId = item.importFileId;
      _selectedImportFileCode = item.importFileCode;
      _selectedSupplierId = item.supplierId;
      _selectedSupplierName = item.supplierName;
      _selectedConsultationCode = item.consultationCode;
      _selectedConsultationId = item.consultationId;

      _hsCodeCtrl.text = item.hsCode ?? '';
      _descCtrl.text = item.commodityDescription ?? '';
      _originCtrl.text = item.countryOfOrigin ?? '';
      _currencyCtrl.text = item.currency;
      _valueCtrl.text = item.shipmentValue.toStringAsFixed(2);
      _acidNumberCtrl.text = item.acidNumber ?? '';
      _factoryRegCtrl.text = item.factoryRegistrationNo ?? '';
      _cooNotesCtrl.text = item.cooNotes ?? '';
      _inspReportNoCtrl.text = item.inspectionReportNo ?? '';
      _inspNotesCtrl.text = item.inspectionNotes ?? '';
      _permitNumberCtrl.text = item.permitNumber ?? '';
      _permitNotesCtrl.text = item.permitNotes ?? '';
      _msdsNotesCtrl.text = item.msdsNotes ?? '';
      _halalNotesCtrl.text = item.halalCertNotes ?? '';
      _coaNotesCtrl.text = item.coaNotes ?? '';
      _specialNotesCtrl.text = item.assessmentNotes ?? '';
      _sailingDateCtrl.text = item.sailingDate ?? '';
      _assessedByCtrl.text = item.assessedBy;

      _hsCodeItems.clear();
      _hsCodeItems.addAll(item.hsCodeItems);
      _selectedHsItemIndex = 0;

      if (_hsCodeItems.isNotEmpty) {
        _loadHsItemState(0);
      } else {
        _decree43Applicable = item.decree43Applicable;
        _whiteListRequired = item.whiteListRequired;
        _whiteListVerified = item.whiteListVerified;
        _decree43Action = item.decree43Action;
        _decree43Justification = item.decree43Justification;

        _cooRequired = item.cooRequired;
        _cooType = item.cooType ?? 'EUR.1';
        _cooStatus = item.cooStatus;

        _inspectionRequired = item.inspectionRequired;
        _inspectionBody = item.inspectionBody ?? 'SGS';
        _inspectionStatus = item.inspectionStatus;

        _importPermitRequired = item.importPermitRequired;
        _permitIssuingAuthority = item.permitIssuingAuthority ?? 'EEAA';
        _permitStatus = item.permitStatus;

        _msdsRequired = item.msdsRequired;
        _msdsStatus = item.msdsStatus;
        _halalCertRequired = item.halalCertRequired;
        _halalCertStatus = item.halalCertStatus;
        _coaRequired = item.coaRequired;
        _coaStatus = item.coaStatus;
      }

      _confirmationStatus = item.confirmationStatus;
      _isPostAcidConfirmed = item.isPostAcidConfirmed;
      _sailingStatus = item.sailingStatus;
      _overallStatus = item.overallStatus;
      _riskLevel = item.riskLevel;
    });

    _mainTabController.animateTo(0);
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.loadedRequirementForEditingSnack(item.assessmentCode)),
        backgroundColor: AppTheme.cobalt,
      ),
    );
  }

  void _autoCompleteAllPillars() {
    setState(() {
      _whiteListVerified = true;
      _decree43Action = null;
      _cooStatus = 'Obtained';
      _inspectionStatus = 'Completed';
      _permitStatus = 'Approved';
      _msdsStatus = 'Obtained';
      _halalCertStatus = 'Obtained';
      _coaStatus = 'Obtained';
      _isPostAcidConfirmed = true;
      _confirmationStatus = 'Confirmed & Cleared for Sailing';
      _sailingStatus = 'Cleared for Sailing';
      _overallStatus = 'Confirmed';
      _riskLevel = 'Low';
      if (_factoryRegCtrl.text.isEmpty) _factoryRegCtrl.text = 'GOEIC-REG-PASS-2026';
      if (_inspReportNoCtrl.text.isEmpty) _inspReportNoCtrl.text = 'ILAC-SGS-99201';
      if (_permitNumberCtrl.text.isEmpty) _permitNumberCtrl.text = 'PERMIT-GOEIC-8871';
      _saveCurrentHsItemState();
    });
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.completeAllPillarsSuccessSnack),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  Future<void> _saveAssessment() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fillRequiredFieldsError), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectImportFileError), backgroundColor: Colors.orange),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.updateRequirementSuccessSnack(_editingAssessmentCode ?? '')),
              backgroundColor: AppTheme.emerald,
            ),
          );
        }
      } else {
        await ref.read(importRequirementsProvider.notifier).addRequirement(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.createRequirementSuccessSnack),
              backgroundColor: AppTheme.emerald,
            ),
          );
        }
      }

      // Invalidate board and dashboard states for instant live reflection
      ref.invalidate(lifecycleBoardSummaryProvider);
      ref.invalidate(operationalDashboardProvider);
      ref.invalidate(smartTasksProvider);
      ref.invalidate(importFilesProvider);

      _resetForm();
      _mainTabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception:', '').trim();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 8),
                Text(l10n.saveRequirementErrorTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Text(errorMsg, style: const TextStyle(fontSize: 13, height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.close),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                onPressed: () {
                  Navigator.pop(ctx);
                  _mainTabController.animateTo(1);
                },
                child: Text(l10n.goToSavedRequirementsBtn, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.verified_outlined, color: AppTheme.cobalt, size: 24),
            const SizedBox(width: 10),
            Text(
              l10n.importRequirementsScreenTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AppTheme.charcoal,
        bottom: TabBar(
          controller: _mainTabController,
          indicatorColor: AppTheme.emerald,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(icon: const Icon(Icons.assignment_outlined, size: 18), text: l10n.importRequirementsFormTab),
            Tab(icon: const Icon(Icons.folder_shared_outlined, size: 18), text: l10n.importRequirementsRegistryTab),
          ],
        ),
        actions: [
          const BackToDashboardButton(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: l10n.refresh,
            onPressed: _refreshAllData,
          ),
        ],
      ),
      body: SelectionArea(
        child: TabBarView(
          controller: _mainTabController,
          children: [
            _buildInteractiveAssessmentFormTab(),
            _buildSavedAssessmentsRegistryTab(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: INTERACTIVE 5-PILLARS ASSESSMENT FORM
  // ===========================================================================
  Widget _buildInteractiveAssessmentFormTab() {
    final l10n = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Editing Banner if in Edit Mode
            if (_editingAssessmentId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cobalt),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, color: AppTheme.cobalt, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.editingRequirementBanner(_editingAssessmentCode ?? ''),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal, fontSize: 13),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _resetForm,
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      label: Text(l10n.cancelEditingAndStartNewBtn, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Card 1: Lifecycle & Progress Tracker (من إصدار ACID حتى الإبحار)
            _buildLifecycleProgressCard(),
            const SizedBox(height: 12),

            // Card 2: Import File & Supplier Info Card
            _buildImportFileSelectorCard(importFiles, suppliers),
            const SizedBox(height: 12),

            // Card 3: HS Codes List & Values Selector
            _buildHsCodesSelectorCard(),
            const SizedBox(height: 12),

            // Card 4: 5 Pillars Interactive Tabs Workspace
            _build5PillarsWorkspaceCard(),
            const SizedBox(height: 16),

            // Card 5: Bottom Final Actions Toolbar
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLifecycleProgressCard() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.requirementsLifecycleCardTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(_sailingStatus).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor(_sailingStatus)),
                ),
                child: Text(
                  l10n.sailingStatusBadge(_sailingStatus),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _getStatusColor(_sailingStatus)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStepNode(
                step: '1',
                title: l10n.acidIssuanceStep,
                subtitle: _acidNumberCtrl.text.isNotEmpty
                    ? _acidNumberCtrl.text
                    : l10n.acidIssuedInPhaseText,
                isCompleted: _acidNumberCtrl.text.isNotEmpty,
                isActive: true,
              ),
              _buildStepConnector(isCompleted: _acidNumberCtrl.text.isNotEmpty),
              _buildStepNode(
                step: '2',
                title: l10n.preShipmentInspectionStep,
                subtitle: _inspectionStatus == 'Completed' ? l10n.completedAndPassedInspection : l10n.pendingInspectionCoordination,
                isCompleted: _inspectionStatus == 'Completed',
                isActive: true,
              ),
              _buildStepConnector(isCompleted: _inspectionStatus == 'Completed'),
              _buildStepNode(
                step: '3',
                title: l10n.approvalsAndCertsStep,
                subtitle: _cooStatus == 'Obtained' && _whiteListVerified ? l10n.allCertsFulfilled100 : l10n.pendingApprovals,
                isCompleted: _cooStatus == 'Obtained' && _whiteListVerified,
                isActive: true,
              ),
              _buildStepConnector(isCompleted: _sailingStatus == 'Cleared for Sailing' || _sailingStatus == 'Sailed'),
              _buildStepNode(
                step: '4',
                title: l10n.sailingClearanceStep,
                subtitle: _sailingStatus,
                isCompleted: _sailingStatus == 'Cleared for Sailing' || _sailingStatus == 'Sailed',
                isActive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required String step,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
  }) {
    final color = isCompleted ? AppTheme.emerald : (isActive ? AppTheme.cobalt : Colors.grey);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: color,
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(step, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color), overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector({required bool isCompleted}) {
    return Container(
      width: 16,
      height: 2,
      color: isCompleted ? AppTheme.emerald : Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildImportFileSelectorCard(List<dynamic> importFiles, List<dynamic> suppliers) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(l10n.linkImportFileAndConsultationHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
              const Spacer(),
              if (_selectedConsultationCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cobalt),
                  ),
                  child: Text(l10n.consultationStudyBadge(_selectedConsultationCode, _consultationReadiness.toInt()), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SearchableDropdownField<int?>(
                  labelText: l10n.linkedImportFileFieldLabel,
                  hintText: l10n.selectImportFileHint,
                  value: _selectedImportFileId,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l10n.selectImportFileOption),
                    ...importFiles.map((f) => SearchableDropdownItem<int?>(
                          value: f.importFileId,
                          label: '${f.primaryNameWithCode} - ${f.companyName} | ACID: ${f.acidNumber ?? l10n.acidNotIssued}',
                        )),
                  ],
                  onChanged: _onImportFileChanged,
                  validator: (v) => v == null ? l10n.pleaseSelectImportFileError : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _acidNumberCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.acidNumberFieldLabel,
                    hintText: l10n.acidNumberOptionalHint,
                    helperText: l10n.acidNumberOptionalHint,
                    helperStyle: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.numbers, color: AppTheme.cobalt, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _acidNumberCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                    ),
                  ),
                  validator: null, // Optional in Pre-Planning / Requirements Stage
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<int?>(
                  labelText: l10n.foreignSupplierFieldLabel,
                  hintText: l10n.foreignSupplierHint,
                  value: _selectedSupplierId,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l10n.notSpecifiedOption),
                    ...suppliers.map((s) => SearchableDropdownItem<int?>(
                          value: s.supplierId,
                          label: '${s.companyName} (${s.foreignExporterCountry ?? "N/A"})',
                        )),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedSupplierId = v;
                      final matched = suppliers.where((s) => s.supplierId == v).firstOrNull;
                      if (matched != null) {
                        _selectedSupplierName = matched.companyName;
                        _originCtrl.text = matched.foreignExporterCountry ?? _originCtrl.text;
                        _factoryRegCtrl.text = matched.foreignExporterId ?? _factoryRegCtrl.text;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHsCodesSelectorCard() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.hsCodesSelectorCardTitle(_hsCodeItems.length),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.emerald),
                ),
                child: Text(
                  l10n.totalHsValueBadge(_valueCtrl.text, _currencyCtrl.text),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // If multiple HS codes exist, display an interactive horizontal list of chips/cards
          if (_hsCodeItems.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.alt_route_rounded, color: AppTheme.cobalt, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        l10n.hsCodeSequenceNavTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                      ),
                      const Spacer(),
                      Text(
                        l10n.requirementSelectHsInstruction,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(_hsCodeItems.length, (idx) {
                      final itm = _hsCodeItems[idx];
                      final isSelected = _selectedHsItemIndex == idx;

                      final fulfilledCount = isSelected
                          ? [
                              (!_decree43Applicable || _whiteListVerified || _decree43Action == 'justified'),
                              (!_cooRequired || _cooStatus == 'Obtained'),
                              (!_inspectionRequired || _inspectionStatus == 'Completed'),
                              (!_importPermitRequired || _permitStatus == 'Approved'),
                              _isPostAcidConfirmed,
                            ].where((b) => b).length
                          : itm.fulfilledPillarsCount;

                      final isFullyCompliant = isSelected
                          ? (fulfilledCount == 5)
                          : itm.isFullyCompliant;

                      final isDecree43Warning = isSelected
                          ? (_decree43Applicable && !_whiteListVerified && _decree43Action != 'justified')
                          : (itm.decree43Applicable && !itm.whiteListVerified && itm.decree43Action != 'justified');

                      return InkWell(
                        onTap: () {
                          if (_selectedHsItemIndex == idx) return;
                          setState(() {
                            _saveCurrentHsItemState();
                            _loadHsItemState(idx);
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppTheme.cobalt : Colors.grey.shade300,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: AppTheme.cobalt.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 18,
                                color: isSelected ? AppTheme.cobalt : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        l10n.hsItemCodeLabel(itm.hsCode, itm.itemCode ?? 'Item'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isFullyCompliant
                                              ? AppTheme.emerald.withOpacity(0.12)
                                              : (isDecree43Warning ? const Color(0xFFFEE2E2) : Colors.grey.shade100),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isFullyCompliant
                                                ? AppTheme.emerald
                                                : (isDecree43Warning ? AppTheme.crimson : Colors.grey.shade300),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isFullyCompliant
                                                  ? Icons.check
                                                  : (isDecree43Warning ? Icons.warning_amber_rounded : Icons.pending_actions),
                                              size: 11,
                                              color: isFullyCompliant
                                                  ? AppTheme.emerald
                                                  : (isDecree43Warning ? AppTheme.crimson : Colors.grey.shade700),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              isFullyCompliant
                                                  ? l10n.hsCodeFullyCompliantChip
                                                  : (isDecree43Warning ? l10n.decree43NotRegisteredBadge : l10n.requirementPillarsProgressBadge(fulfilledCount)),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isFullyCompliant
                                                    ? AppTheme.emerald
                                                    : (isDecree43Warning ? AppTheme.crimson : Colors.grey.shade700),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.hsItemDescLabel(itm.commodityDescription ?? '', itm.itemValue.toStringAsFixed(2), itm.currency),
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

          // Primary HS Code Detail Fields
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _hsCodeCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.hsCodeFieldLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.qr_code_2, color: AppTheme.cobalt, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _hsCodeCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.hsCodeRequiredError : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.commodityDescFieldLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.description, color: AppTheme.cobalt, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _descCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commodityDescRequiredError : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _originCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.countryOfOriginFieldLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.public, color: AppTheme.cobalt, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _originCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.countryOfOriginRequiredError : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _currencyCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.currencyFieldLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _currencyCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _valueCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.valueInCurrencyFieldLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.monetization_on, color: AppTheme.emerald, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _valueCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build5PillarsWorkspaceCard() {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-tabs Selector for 5 Pillars
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPillarTabButton(0, l10n.pillar1Decree43Tab, Icons.factory_outlined, _whiteListVerified),
                  _buildPillarTabButton(1, l10n.pillar2CooTab, Icons.public, _cooStatus == 'Obtained'),
                  _buildPillarTabButton(2, l10n.pillar3InspectionTab, Icons.fact_check_outlined, _inspectionStatus == 'Completed'),
                  _buildPillarTabButton(3, l10n.pillar4PermitsTab, Icons.account_balance_outlined, _permitStatus == 'Approved'),
                  _buildPillarTabButton(4, l10n.pillar5TechCertsTab, Icons.science_outlined, _isPostAcidConfirmed),
                ],
              ),
            ),
          ),

          // Pillar Content Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAdaptivePillarAlertBanner(),
                IndexedStack(
                  index: _activePillarIndex,
                  children: [
                    _buildPillar1Content(),
                    _buildPillar2Content(),
                    _buildPillar3Content(),
                    _buildPillar4Content(),
                    _buildPillar5Content(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarTabButton(int index, String title, IconData icon, bool isFulfilled) {
    final isSelected = _activePillarIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => setState(() => _activePillarIndex = index),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.cobalt : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.charcoal),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? Colors.white : AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 6),
              if (isFulfilled)
                const Icon(Icons.check_circle, size: 14, color: AppTheme.emerald)
              else
                Icon(Icons.circle_outlined, size: 12, color: isSelected ? Colors.white70 : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // Pillar 1: Decree 43
  Widget _buildPillar1Content() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pillar1Header, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                title: Text(l10n.decree43ApplicableCheck, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.decree43ApplicableSub),
                value: _decree43Applicable,
                onChanged: (v) => setState(() => _decree43Applicable = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              )),
            ),
            Expanded(
              child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                title: Text(l10n.whiteListVerifiedCheck, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.whiteListVerifiedSub),
                value: _whiteListVerified,
                onChanged: (v) => setState(() => _whiteListVerified = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              )),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _factoryRegCtrl,
          decoration: InputDecoration(
            labelText: l10n.factoryRegNumFieldLabel,
            hintText: l10n.factoryRegNumHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.badge, color: AppTheme.cobalt),
            suffixIcon: IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: l10n.requirementCopyFieldTooltip,
              onPressed: () => CopyHelper.copy(context, _factoryRegCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
            ),
          ),
        ),
        _buildDecree43DecisionCard(),
      ],
    );
  }

  // Pillar 2: Certificate of Origin
  Widget _buildPillar2Content() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pillar2Header, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                title: Text(l10n.cooRequiredCheck, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _cooRequired,
                onChanged: (v) => setState(() => _cooRequired = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              )),
            ),
            Expanded(
              flex: 2,
              child: SearchableDropdownField<String>(
                labelText: l10n.cooTypeFieldLabel,
                value: _cooType,
                items: [
                  SearchableDropdownItem(value: 'EUR.1', label: l10n.cooTypeEur1Option),
                  SearchableDropdownItem(value: 'Form A', label: l10n.cooTypeFormAOption),
                  SearchableDropdownItem(value: 'Arab League COO', label: l10n.cooTypeGaftaOption),
                  SearchableDropdownItem(value: 'COMESA', label: l10n.cooTypeComesaOption),
                  SearchableDropdownItem(value: 'Standard COO', label: l10n.cooTypeStandardChamberOption),
                ],
                onChanged: (v) => setState(() => _cooType = v ?? _cooType),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SearchableDropdownField<String>(
                labelText: l10n.cooStatusFieldLabel,
                value: _cooStatus,
                items: [
                  SearchableDropdownItem(value: 'Not Required', label: l10n.statusInactive),
                  SearchableDropdownItem(value: 'Pending', label: l10n.cooStatusPendingOption),
                  SearchableDropdownItem(value: 'Obtained', label: l10n.cooStatusObtainedOption),
                  SearchableDropdownItem(value: 'Waived', label: l10n.cooStatusWaivedOption),
                ],
                onChanged: (v) => setState(() => _cooStatus = v ?? _cooStatus),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _cooNotesCtrl,
          decoration: InputDecoration(
            labelText: l10n.cooNotesFieldLabel,
            hintText: l10n.cooNotesHint,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: l10n.requirementCopyFieldTooltip,
              onPressed: () => CopyHelper.copy(context, _cooNotesCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
            ),
          ),
        ),
      ],
    );
  }

  // Pillar 3: Pre-Shipment Inspection
  Widget _buildPillar3Content() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pillar3Header, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                title: Text(l10n.inspectionRequiredCheck, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _inspectionRequired,
                onChanged: (v) => setState(() => _inspectionRequired = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              )),
            ),
            Expanded(
              flex: 2,
              child: SearchableDropdownField<String>(
                labelText: l10n.inspectionBodyFieldLabel,
                value: _inspectionBody,
                items: [
                  SearchableDropdownItem(value: 'SGS', label: l10n.inspectionBodySgsOption),
                  SearchableDropdownItem(value: 'Bureau Veritas', label: l10n.inspectionBodyBvOption),
                  SearchableDropdownItem(value: 'TÜV', label: l10n.inspectionBodyTuvOption),
                  SearchableDropdownItem(value: 'Intertek', label: l10n.inspectionBodyIntertekOption),
                  SearchableDropdownItem(value: 'QIMA', label: l10n.inspectionBodyQimaOption),
                  SearchableDropdownItem(value: 'ILAC ISO 17025', label: l10n.inspectionBodyIlacOption),
                ],
                onChanged: (v) => setState(() => _inspectionBody = v ?? _inspectionBody),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SearchableDropdownField<String>(
                labelText: l10n.inspectionStatusFieldLabel,
                value: _inspectionStatus,
                items: [
                  SearchableDropdownItem(value: 'Not Required', label: l10n.statusInactive),
                  SearchableDropdownItem(value: 'Pending', label: l10n.inspectionStatusPendingOption),
                  SearchableDropdownItem(value: 'Scheduled', label: l10n.inspectionStatusScheduledOption),
                  SearchableDropdownItem(value: 'Completed', label: l10n.inspectionStatusCompletedOption),
                  SearchableDropdownItem(value: 'Rejected', label: l10n.inspectionStatusRejectedOption),
                ],
                onChanged: (v) => setState(() => _inspectionStatus = v ?? _inspectionStatus),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _inspReportNoCtrl,
                decoration: InputDecoration(
                  labelText: l10n.inspectionReportNumFieldLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l10n.requirementCopyFieldTooltip,
                    onPressed: () => CopyHelper.copy(context, _inspReportNoCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _inspNotesCtrl,
                decoration: InputDecoration(
                  labelText: l10n.inspectionNotesFieldLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l10n.requirementCopyFieldTooltip,
                    onPressed: () => CopyHelper.copy(context, _inspNotesCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Pillar 4: Prior Import Permits
  Widget _buildPillar4Content() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pillar4Header, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                title: Text(l10n.importPermitRequiredCheck, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _importPermitRequired,
                onChanged: (v) => setState(() => _importPermitRequired = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              )),
            ),
            Expanded(
              flex: 2,
              child: SearchableDropdownField<String>(
                labelText: l10n.issuingAuthorityFieldLabel,
                value: _permitIssuingAuthority,
                items: [
                  SearchableDropdownItem(value: 'EEAA', label: l10n.authorityEeaaOption),
                  SearchableDropdownItem(value: 'NFSA', label: l10n.authorityNfsaOption),
                  SearchableDropdownItem(value: 'EDA', label: l10n.authorityEdaOption),
                  SearchableDropdownItem(value: 'NTRA', label: l10n.authorityNtraOption),
                  SearchableDropdownItem(value: 'Public Security', label: l10n.authorityPublicSecurityOption),
                  SearchableDropdownItem(value: 'Chemistry Authority', label: l10n.authorityChemistryOption),
                  SearchableDropdownItem(value: 'GOEIC', label: l10n.authorityGoeicOption),
                ],
                onChanged: (v) => setState(() => _permitIssuingAuthority = v ?? _permitIssuingAuthority),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SearchableDropdownField<String>(
                labelText: l10n.permitStatusFieldLabel,
                value: _permitStatus,
                items: [
                  SearchableDropdownItem(value: 'Not Required', label: l10n.statusInactive),
                  SearchableDropdownItem(value: 'Applied', label: l10n.permitStatusAppliedOption),
                  SearchableDropdownItem(value: 'Approved', label: l10n.permitStatusApprovedOption),
                  SearchableDropdownItem(value: 'Rejected', label: l10n.permitStatusRejectedOption),
                ],
                onChanged: (v) => setState(() => _permitStatus = v ?? _permitStatus),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _permitNumberCtrl,
                decoration: InputDecoration(
                  labelText: l10n.permitNumberFieldLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l10n.requirementCopyFieldTooltip,
                    onPressed: () => CopyHelper.copy(context, _permitNumberCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _permitNotesCtrl,
                decoration: InputDecoration(
                  labelText: l10n.permitNotesFieldLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l10n.requirementCopyFieldTooltip,
                    onPressed: () => CopyHelper.copy(context, _permitNotesCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Pillar 5: Technical Certificates & Sailing Confirmation
  Widget _buildPillar5Content() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pillar5Header, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                title: Text(l10n.msdsRequiredCheck, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                value: _msdsRequired,
                onChanged: (v) => setState(() => _msdsRequired = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              )),
            ),
            Expanded(
              child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                title: Text(l10n.halalCertRequiredCheck, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                value: _halalCertRequired,
                onChanged: (v) => setState(() => _halalCertRequired = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              )),
            ),
            Expanded(
              child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                title: Text(l10n.coaRequiredCheck, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                value: _coaRequired,
                onChanged: (v) => setState(() => _coaRequired = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              )),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  labelText: l10n.sailingStatusFieldLabel,
                  value: _sailingStatus,
                  items: [
                    SearchableDropdownItem(value: 'Pre-Sailing', label: l10n.sailingStatusPreSailingOption),
                    SearchableDropdownItem(value: 'Cleared for Sailing', label: l10n.sailingStatusClearedOption),
                    SearchableDropdownItem(value: 'Sailed', label: l10n.sailingStatusSailedOption),
                  ],
                  onChanged: (v) => setState(() => _sailingStatus = v ?? _sailingStatus),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _sailingDateCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.sailingDateFieldLabel,
                    hintText: 'YYYY-MM-DD',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.directions_boat, color: AppTheme.cobalt, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _sailingDateCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  labelText: l10n.riskLevelFieldLabel,
                  value: _riskLevel,
                  items: [
                    SearchableDropdownItem(value: 'Low', label: l10n.riskLevelLowOption),
                    SearchableDropdownItem(value: 'Medium', label: l10n.riskLevelMediumOption),
                    SearchableDropdownItem(value: 'High', label: l10n.riskLevelHighOption),
                  ],
                  onChanged: (v) => setState(() => _riskLevel = v ?? _riskLevel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  labelText: l10n.statusCol,
                  value: _overallStatus,
                  items: [
                    SearchableDropdownItem(value: 'Draft', label: l10n.overallStatusDraftOption),
                    SearchableDropdownItem(value: 'In Progress', label: l10n.overallStatusInProgressOption),
                    SearchableDropdownItem(value: 'Complete', label: l10n.overallStatusCompleteOption),
                    SearchableDropdownItem(value: 'Confirmed', label: l10n.overallStatusConfirmedOption),
                  ],
                  onChanged: (v) => setState(() => _overallStatus = v ?? _overallStatus),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _specialNotesCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.requirementsTsvHeaderNotes,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.note_alt_outlined, color: AppTheme.cobalt, size: 18),
            suffixIcon: IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: l10n.requirementCopyFieldTooltip,
              onPressed: () => CopyHelper.copy(context, _specialNotesCtrl.text, customMessage: l10n.copiedToClipboardGeneric),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE0F2FE),
              foregroundColor: AppTheme.cobalt,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: _autoCompleteAllPillars,
            icon: const Icon(Icons.bolt, color: AppTheme.cobalt, size: 18),
            label: Text(l10n.completeAllPillarsBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.charcoal,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: _refreshAllData,
            icon: const Icon(Icons.refresh, size: 18, color: AppTheme.cobalt),
            label: Text(l10n.refresh, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade800,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: _resetForm,
            icon: const Icon(Icons.cleaning_services_outlined, size: 18, color: Colors.blueGrey),
            label: Text(l10n.cancelEditingAndStartNewBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: AppTheme.cobalt,
              elevation: 0,
              side: const BorderSide(color: AppTheme.cobalt),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: _isSaving ? null : _saveAssessment,
            icon: const Icon(Icons.save_outlined, size: 18, color: AppTheme.cobalt),
            label: Text(l10n.saveRequirementDraftBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 2,
            ),
            onPressed: _isSaving ? null : _saveAssessment,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline, size: 20),
            label: Text(
              _editingAssessmentId != null ? l10n.updateRequirementSubmitBtn : l10n.saveRequirementSubmitBtn,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: SAVED ASSESSMENTS REGISTRY
  // ===========================================================================
  Widget _buildSavedAssessmentsRegistryTab() {
    final l10n = context.l10n;
    final asyncReqs = ref.watch(importRequirementsProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          MasterDataToolbarWidget(
            moduleEndpoint: 'import-requirements',
            title: 'Import_Requirements_Registry',
            onRefreshNeeded: _refreshAllData,
          ),
          const SizedBox(height: 12),

          // Export Actions Row
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.cobalt,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: Text(l10n.requirementsExportTsvBtn),
                onPressed: () {
                  final list = asyncReqs.valueOrNull ?? [];
                  _copyRequirementsTsv(list);
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: Text(l10n.requirementsExportExcelBtn),
                onPressed: () {
                  final list = asyncReqs.valueOrNull ?? [];
                  MasterDataExportService.exportImportRequirementsToExcel(context, list);
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.charcoal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: Text(l10n.requirementsExportPdfBtn),
                onPressed: () {
                  final list = asyncReqs.valueOrNull ?? [];
                  MasterDataExportService.printOrSaveImportRequirementsListPdf(context, list);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, val, _) {
                      return TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n.searchRequirementsHint,
                          prefixIcon: const Icon(Icons.search, color: AppTheme.cobalt),
                          suffixIcon: val.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    labelText: l10n.complianceStatusFilterLabel,
                    value: _registryStatusFilter,
                    items: [
                      SearchableDropdownItem(value: 'All', label: l10n.partnerCatAll),
                      SearchableDropdownItem(value: 'Draft', label: l10n.overallStatusDraftOption),
                      SearchableDropdownItem(value: 'In Progress', label: l10n.overallStatusInProgressOption),
                      SearchableDropdownItem(value: 'Complete', label: l10n.overallStatusCompleteOption),
                      SearchableDropdownItem(value: 'Confirmed', label: l10n.overallStatusConfirmedOption),
                    ],
                    onChanged: (v) => setState(() => _registryStatusFilter = v ?? 'All'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    labelText: l10n.riskLevelFilterLabel,
                    value: _registryRiskFilter,
                    items: [
                      SearchableDropdownItem(value: 'All', label: l10n.partnerCatAll),
                      SearchableDropdownItem(value: 'Low', label: l10n.riskLevelLowOption),
                      SearchableDropdownItem(value: 'Medium', label: l10n.riskLevelMediumOption),
                      SearchableDropdownItem(value: 'High', label: l10n.riskLevelHighOption),
                    ],
                    onChanged: (v) => setState(() => _registryRiskFilter = v ?? 'All'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    labelText: l10n.activeDeletedFilterLabel,
                    value: _registryActiveFilter,
                    items: [
                      SearchableDropdownItem(value: 'All', label: l10n.allRecordsActiveAndDeleted),
                      SearchableDropdownItem(value: 'Active', label: l10n.activeOnlyOption),
                      SearchableDropdownItem(value: 'Deleted', label: l10n.deletedOnlyOption),
                    ],
                    onChanged: (v) => setState(() => _registryActiveFilter = v ?? 'Active'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Registry DataTable
          Expanded(
            child: asyncReqs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(l10n.requirementsFetchError(err.toString()), style: const TextStyle(color: Colors.red)),
              ),
              data: (list) {
                final filtered = list.where((item) {
                  // Search query filter
                  final query = _searchController.text.trim().toLowerCase();
                  if (query.isNotEmpty) {
                    final matchCode = item.assessmentCode.toLowerCase().contains(query);
                    final matchFile = (item.importFileCode ?? '').toLowerCase().contains(query);
                    final matchHs = (item.hsCode ?? '').toLowerCase().contains(query);
                    final matchAcid = (item.acidNumber ?? '').toLowerCase().contains(query);
                    final matchSupp = (item.supplierName ?? '').toLowerCase().contains(query);
                    final matchDesc = (item.commodityDescription ?? '').toLowerCase().contains(query);
                    if (!matchCode && !matchFile && !matchHs && !matchAcid && !matchSupp && !matchDesc) {
                      return false;
                    }
                  }

                  // Status filter
                  if (_registryStatusFilter != 'All' && item.overallStatus != _registryStatusFilter) {
                    return false;
                  }

                  // Risk filter
                  if (_registryRiskFilter != 'All' && item.riskLevel != _registryRiskFilter) {
                    return false;
                  }

                  // Active filter
                  if (_registryActiveFilter == 'Active' && !item.isActive) return false;
                  if (_registryActiveFilter == 'Deleted' && item.isActive) return false;

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(l10n.noRequirementsFound, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                          onPressed: () => _mainTabController.animateTo(0),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: Text(l10n.createNewRequirementBtn, style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final req = filtered[idx];
                      return _buildRegistryRow(req);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistryRow(ImportRequirementModel req) {
    final l10n = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final matchingFile = importFiles.where((f) => f.importFileId == req.importFileId).firstOrNull;
    final fileTitle = matchingFile?.primaryNameWithCode ?? req.importFileCode ?? (req.importFileId != null ? 'IMP-${req.importFileId}' : '');
    final companyName = (matchingFile?.companyName.isNotEmpty == true && matchingFile?.companyName != 'N/A')
        ? matchingFile!.companyName
        : l10n.fallbackImportingCompany;
    final displayName = fileTitle.isNotEmpty ? '$fileTitle - $companyName' : req.assessmentCode;

    return Material(type: MaterialType.transparency, child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: req.isActive ? AppTheme.cobalt.withOpacity(0.12) : Colors.grey.shade300,
        child: Icon(
          req.isActive ? Icons.verified : Icons.delete_outline,
          color: req.isActive ? AppTheme.cobalt : Colors.grey,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => CopyHelper.copy(context, req.assessmentCode, customMessage: l10n.requirementCopySummarySuccess),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy, size: 10, color: AppTheme.cobalt),
                  const SizedBox(width: 4),
                  Text(req.assessmentCode, style: const TextStyle(fontSize: 11, color: AppTheme.cobalt, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (req.acidNumber != null && req.acidNumber!.isNotEmpty)
            InkWell(
              onTap: () => CopyHelper.copy(context, req.acidNumber!, customMessage: l10n.requirementCopySummarySuccess),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy, size: 10, color: AppTheme.emerald),
                    const SizedBox(width: 4),
                    Text(l10n.reqAcidNumberBadge(req.acidNumber!), style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          const Spacer(),
          if (!req.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red)),
              child: Text(l10n.deletedOnlyOption, style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.requirementRowSubtitle(req.hsCode ?? "N/A", req.commodityDescription ?? "", req.shipmentValue.toStringAsFixed(2), req.currency, req.supplierName ?? "N/A", req.countryOfOrigin ?? "N/A"),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildBadge(l10n.sailingStatusBadgeRow(req.sailingStatus), _getStatusColor(req.sailingStatus)),
                _buildBadge(l10n.requirementStatusBadgeRow(req.overallStatus), _getStatusColor(req.overallStatus)),
                _buildBadge(l10n.riskLevelBadgeRow(req.riskLevel), _getRiskLevelColor(req.riskLevel)),
                if (req.hsCodeItems.isNotEmpty)
                  _buildBadge(l10n.hsItemsCountBadge(req.hsCodeItems.length), AppTheme.cobalt),
                if (req.decree43Applicable && req.whiteListVerified)
                  _buildBadge(l10n.decree43VerifiedBadge, AppTheme.emerald),
                if (req.cooRequired && req.cooStatus == 'Obtained')
                  _buildBadge(l10n.cooObtainedBadge, AppTheme.emerald),
                if (req.inspectionRequired && req.inspectionStatus == 'Completed')
                  _buildBadge(l10n.inspectionPassedBadge, AppTheme.emerald),
              ],
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Copy Summary Button
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 18),
            tooltip: l10n.requirementCopySummaryBtn,
            onPressed: () {
              final summary = _buildRequirementRowSummary(req);
              CopyHelper.copy(context, summary, customMessage: l10n.requirementCopySummarySuccess);
            },
          ),
          // View Details Dialog Button
          IconButton(
            icon: const Icon(Icons.visibility_outlined, color: AppTheme.charcoal, size: 18),
            tooltip: l10n.requirementDetailsDialogTitle,
            onPressed: () => _showRequirementDetailsDialog(req),
          ),
          // Print Slip Button
          IconButton(
            icon: const Icon(Icons.print_outlined, color: AppTheme.emerald, size: 18),
            tooltip: l10n.printRequirementSlipBtn,
            onPressed: () => MasterDataExportService.printOrSaveImportRequirementSlipPdf(context, req),
          ),
          // Edit Button (Restores if deleted and loads into form)
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.cobalt),
            tooltip: l10n.editRequirementTooltip,
            onPressed: () => _loadAssessmentForEditing(req),
          ),
          // Restore Button if inactive
          if (!req.isActive)
            IconButton(
              icon: const Icon(Icons.restore_from_trash, color: AppTheme.emerald),
              tooltip: l10n.restoreRequirementTooltip,
              onPressed: () async {
                if (req.assessmentId != null) {
                  await ref.read(importRequirementsProvider.notifier).restoreRequirement(req.assessmentId!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.restoredRequirementSuccessSnack(req.assessmentCode)), backgroundColor: AppTheme.emerald),
                    );
                  }
                }
              },
            ),
          // Delete Button
          if (req.isActive)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: l10n.deleteRequirementTooltip,
              onPressed: () => _confirmDeleteAssessment(req),
            ),
        ],
      ),
    ));
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildCopyableBadge(String text, Color color) {
    return InkWell(
      onTap: () => CopyHelper.copy(context, text, customMessage: context.l10n.requirementCopySummarySuccess),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy, size: 11, color: color),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12, color: AppTheme.charcoal)),
          ),
        ],
      ),
    );
  }

  String _buildRequirementRowSummary(ImportRequirementModel req) {
    final l10n = context.l10n;
    final b = StringBuffer();
    b.writeln('${l10n.requirementsTsvHeaderCode}: ${req.assessmentCode}');
    if (req.importFileCode != null && req.importFileCode!.isNotEmpty) {
      b.writeln('${l10n.requirementsTsvHeaderFileCode}: ${req.importFileCode}');
    }
    if (req.acidNumber != null && req.acidNumber!.isNotEmpty) {
      b.writeln('ACID: ${req.acidNumber}');
    }
    b.writeln('${l10n.requirementsTsvHeaderHsCode}: ${req.hsCode ?? "-"}');
    b.writeln('${l10n.requirementsTsvHeaderCommodity}: ${req.commodityDescription ?? "-"}');
    b.writeln('${l10n.requirementsTsvHeaderSupplier}: ${req.supplierName ?? "-"}');
    b.writeln('${l10n.requirementsTsvHeaderOrigin}: ${req.countryOfOrigin ?? "-"}');
    b.writeln('${l10n.requirementsTsvHeaderValue}: ${req.shipmentValue.toStringAsFixed(2)} ${req.currency}');
    b.writeln('${l10n.requirementsTsvHeaderDecree43}: ${req.decree43Applicable ? (req.whiteListVerified ? (req.factoryRegistrationNo ?? l10n.decree43VerifiedBadge) : (req.decree43Action ?? l10n.decree43NotRegisteredBadge)) : "-"}');
    b.writeln('${l10n.requirementsTsvHeaderCoo}: ${req.cooRequired ? '${req.cooType ?? "COO"} (${req.cooStatus})' : "-"}');
    b.writeln('${l10n.requirementsTsvHeaderInspection}: ${req.inspectionRequired ? '${req.inspectionBody ?? "Inspection"} (${req.inspectionStatus})' : "-"}');
    b.writeln('${l10n.requirementsTsvHeaderPermit}: ${req.importPermitRequired ? '${req.permitIssuingAuthority ?? "Authority"} (${req.permitStatus})' : "-"}');
    b.writeln('${l10n.requirementsTsvHeaderTechCerts}: ${req.isPostAcidConfirmed ? l10n.overallStatusConfirmedOption : req.sailingStatus}');
    b.writeln('${l10n.requirementsTsvHeaderRiskLevel}: ${req.riskLevel}');
    b.writeln('${l10n.requirementsTsvHeaderOverallStatus}: ${req.overallStatus}');
    if (req.assessedBy.isNotEmpty) {
      b.writeln('${l10n.requirementsTsvHeaderAssessedBy}: ${req.assessedBy}');
    }
    if (req.assessmentNotes != null && req.assessmentNotes!.isNotEmpty) {
      b.writeln('${l10n.requirementsTsvHeaderNotes}: ${req.assessmentNotes}');
    }
    return b.toString().trim();
  }

  void _copyRequirementsTsv(List<ImportRequirementModel> reqs) {
    final l10n = context.l10n;
    if (reqs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noRequirementsFound), backgroundColor: AppTheme.charcoal),
      );
      return;
    }
    final headers = [
      l10n.requirementsTsvHeaderCode,
      l10n.requirementsTsvHeaderFileCode,
      'ACID',
      l10n.requirementsTsvHeaderHsCode,
      l10n.requirementsTsvHeaderCommodity,
      l10n.requirementsTsvHeaderSupplier,
      l10n.requirementsTsvHeaderOrigin,
      l10n.requirementsTsvHeaderValue,
      l10n.requirementsTsvHeaderCurrency,
      l10n.requirementsTsvHeaderDecree43,
      l10n.requirementsTsvHeaderCoo,
      l10n.requirementsTsvHeaderInspection,
      l10n.requirementsTsvHeaderPermit,
      l10n.requirementsTsvHeaderTechCerts,
      l10n.requirementsTsvHeaderSailingStatus,
      l10n.requirementsTsvHeaderOverallStatus,
      l10n.requirementsTsvHeaderRiskLevel,
      l10n.requirementsTsvHeaderAssessedBy,
      l10n.requirementsTsvHeaderNotes,
    ];
    final rows = reqs.map((req) {
      return [
        req.assessmentCode,
        req.importFileCode ?? '',
        req.acidNumber ?? '',
        req.hsCode ?? '',
        (req.commodityDescription ?? '').replaceAll('\t', ' ').replaceAll('\n', ' '),
        req.supplierName ?? '',
        req.countryOfOrigin ?? '',
        req.shipmentValue.toStringAsFixed(2),
        req.currency,
        req.decree43Applicable ? (req.whiteListVerified ? (req.factoryRegistrationNo ?? 'Registered') : (req.decree43Action ?? 'Non-compliant')) : 'N/A',
        req.cooRequired ? '${req.cooType ?? "COO"} (${req.cooStatus})' : 'N/A',
        req.inspectionRequired ? '${req.inspectionBody ?? "Inspection"} (${req.inspectionStatus})' : 'N/A',
        req.importPermitRequired ? '${req.permitIssuingAuthority ?? "Authority"} (${req.permitStatus})' : 'N/A',
        req.isPostAcidConfirmed ? 'Confirmed' : req.sailingStatus,
        req.sailingStatus,
        req.overallStatus,
        req.riskLevel,
        req.assessedBy,
        (req.assessmentNotes ?? '').replaceAll('\t', ' ').replaceAll('\n', ' '),
      ].join('\t');
    }).toList();

    final tsv = [headers.join('\t'), ...rows].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.requirementsExportTsvSuccess);
  }

  void _showRequirementDetailsDialog(ImportRequirementModel req) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.fact_check_outlined, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.requirementDetailsDialogTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SelectionArea(
          child: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildCopyableBadge(req.assessmentCode, AppTheme.cobalt),
                      if (req.importFileCode != null && req.importFileCode!.isNotEmpty)
                        _buildCopyableBadge(req.importFileCode!, AppTheme.charcoal),
                      if (req.acidNumber != null && req.acidNumber!.isNotEmpty)
                        _buildCopyableBadge(l10n.reqAcidNumberBadge(req.acidNumber!), AppTheme.emerald),
                      _buildBadge(req.overallStatus, _getStatusColor(req.overallStatus)),
                      _buildBadge(req.riskLevel, _getRiskLevelColor(req.riskLevel)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Basic Info Grid
                  _buildDetailRow(l10n.hsCodeFieldLabel, req.hsCode ?? '-'),
                  _buildDetailRow(l10n.commodityDescFieldLabel, req.commodityDescription ?? '-'),
                  _buildDetailRow(l10n.foreignSupplierFieldLabel, req.supplierName ?? '-'),
                  _buildDetailRow(l10n.countryOfOriginFieldLabel, req.countryOfOrigin ?? '-'),
                  _buildDetailRow(l10n.valueInCurrencyFieldLabel, '${req.shipmentValue.toStringAsFixed(2)} ${req.currency}'),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // 5 Pillars Breakdown
                  Text(
                    l10n.importRequirementsFormTab,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    l10n.pillar1Decree43Tab,
                    req.decree43Applicable
                        ? (req.whiteListVerified ? (req.factoryRegistrationNo ?? l10n.decree43VerifiedBadge) : (req.decree43Action ?? l10n.decree43NotRegisteredBadge))
                        : '-',
                  ),
                  _buildDetailRow(
                    l10n.pillar2CooTab,
                    req.cooRequired ? '${req.cooType ?? "COO"} (${req.cooStatus})' : '-',
                  ),
                  _buildDetailRow(
                    l10n.pillar3InspectionTab,
                    req.inspectionRequired ? '${req.inspectionBody ?? "Inspection"} (${req.inspectionStatus})' : '-',
                  ),
                  _buildDetailRow(
                    l10n.pillar4PermitsTab,
                    req.importPermitRequired ? '${req.permitIssuingAuthority ?? "Authority"} (${req.permitStatus})' : '-',
                  ),
                  _buildDetailRow(
                    l10n.pillar5TechCertsTab,
                    req.isPostAcidConfirmed ? l10n.overallStatusConfirmedOption : req.sailingStatus,
                  ),
                  if (req.assessmentNotes != null && req.assessmentNotes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    _buildDetailRow(l10n.requirementsTsvHeaderNotes, req.assessmentNotes!),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.cobalt),
            icon: const Icon(Icons.copy, size: 16),
            label: Text(l10n.requirementCopySummaryBtn),
            onPressed: () {
              final summary = _buildRequirementRowSummary(req);
              CopyHelper.copy(context, summary, customMessage: l10n.requirementCopySummarySuccess);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 16),
            label: Text(l10n.printRequirementSlipBtn),
            onPressed: () {
              Navigator.pop(ctx);
              MasterDataExportService.printOrSaveImportRequirementSlipPdf(context, req);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAssessment(ImportRequirementModel req) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(l10n.confirmDeleteRequirementTitle),
          ],
        ),
        content: Text(l10n.confirmDeleteRequirementContent(req.assessmentCode, req.importFileCode ?? '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              if (req.assessmentId != null) {
                await ref.read(importRequirementsProvider.notifier).deleteRequirement(req.assessmentId!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.deletedRequirementSuccessSnack(req.assessmentCode)), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Decree 43 Decision Flow ─────────────────────────────────────────────────
  Future<void> _showDecree43JustificationDialog() async {
    final l10n = context.l10n;
    final justCtrl = TextEditingController(text: _decree43Justification ?? '');

    final sampleReasons = [
      l10n.decree43JustificationReasonProductionInput,
      l10n.decree43JustificationReasonPrivateUse,
      l10n.decree43JustificationReasonSpareParts,
      l10n.decree43JustificationReasonMinisterialExemption,
      l10n.decree43SampleReasonGoeicReview,
    ];

    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Text(l10n.decree43JustificationDialogTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            content: SelectionArea(
              child: SizedBox(
                width: 580,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        l10n.decree43JustificationDialogDesc,
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.decree43CommonExemptionsTitle,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: sampleReasons.map((r) => ActionChip(
                        label: Text(r, style: const TextStyle(fontSize: 10)),
                        backgroundColor: Colors.grey.shade100,
                        onPressed: () {
                          justCtrl.text = r;
                          setDState(() {});
                        },
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: justCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.decree43OptionRequestJustification,
                        hintText: l10n.decree43JustificationHint,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.requirementCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, justCtrl.text, customMessage: l10n.requirementCopySummarySuccess),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text(l10n.cancel),
                onPressed: () => Navigator.pop(ctx),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
                icon: const Icon(Icons.check, size: 16),
                label: Text(l10n.save),
                onPressed: () {
                  final txt = justCtrl.text.trim();
                  if (txt.isEmpty) return;
                  setState(() {
                    _decree43Action = 'justified';
                    _decree43Justification = txt;
                    _saveCurrentHsItemState();
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.decree43JustificationSavedBadge),
                      backgroundColor: AppTheme.emerald,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    } finally {
      justCtrl.dispose();
    }
  }

  void _createDecree43RegistrationTask() {
    final l10n = context.l10n;
    setState(() {
      _decree43Action = 'task_created';
      _decree43Justification = null;
      _saveCurrentHsItemState();
    });
    // Trigger live refresh in background
    ref.read(smartTasksProvider.notifier).fetchTasks();
    ref.read(operationalDashboardProvider.notifier).fetchDashboard();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.decree43TaskCreatedSuccessSnack),
        backgroundColor: AppTheme.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildDecree43DecisionCard() {
    final l10n = context.l10n;
    if (!_decree43Applicable || _whiteListVerified) {
      return const SizedBox.shrink();
    }

    if (_decree43Action == 'justified') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.emerald),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AppTheme.emerald, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.decree43JustificationSavedBadge,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _decree43Justification ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 14, color: AppTheme.cobalt),
              label: Text(l10n.edit, style: const TextStyle(fontSize: 11)),
              onPressed: _showDecree43JustificationDialog,
            ),
          ],
        ),
      );
    }

    if (_decree43Action == 'task_created') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.orange),
        ),
        child: Row(
          children: [
            const Icon(Icons.assignment_late_outlined, color: AppTheme.orange, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.decree43TaskCreatedBadge,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.orange),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.decree43TaskExplanation,
                    style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.cobalt, side: const BorderSide(color: AppTheme.cobalt)),
              icon: const Icon(Icons.gavel_rounded, size: 14),
              label: Text(l10n.decree43ExemptionChangeBtn, style: const TextStyle(fontSize: 11)),
              onPressed: _showDecree43JustificationDialog,
            ),
          ],
        ),
      );
    }

    // Default: Decision Prompt Card with 2 choices
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.decree43WarningNotRegistered,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.crimson),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.decree43WarningNotRegisteredDesc,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.gavel_rounded, size: 15),
                label: Text(
                  l10n.decree43OptionRequestJustification,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: _showDecree43JustificationDialog,
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.notification_add_rounded, size: 15),
                label: Text(
                  l10n.decree43OptionCreateDashboardTask,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: _createDecree43RegistrationTask,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Adaptive Pillar Alert Banner ──────────────────────────────────────────
  Widget _buildAdaptivePillarAlertBanner() {
    final l10n = context.l10n;
    final currentHs = _hsCodeCtrl.text.trim();
    final currentDesc = _descCtrl.text.trim();

    String mandatoryText;
    String warningText;
    String exemptionText;

    switch (_activePillarIndex) {
      case 0:
        // Pillar 1: Decree 43
        mandatoryText = l10n.compliancePillar1Mandatory;
        warningText = l10n.compliancePillar1Warning;
        exemptionText = l10n.compliancePillar1Exemption;
        break;
      case 1:
        // Pillar 2: Certificate of Origin
        mandatoryText = l10n.compliancePillar2Mandatory;
        warningText = l10n.compliancePillar2Warning;
        exemptionText = l10n.compliancePillar2Exemption;
        break;
      case 2:
        // Pillar 3: Pre-Shipment Inspection
        mandatoryText = l10n.compliancePillar3Mandatory;
        warningText = l10n.compliancePillar3Warning;
        exemptionText = l10n.compliancePillar3Exemption;
        break;
      case 3:
        // Pillar 4: Regulatory Permits
        mandatoryText = l10n.compliancePillar4Mandatory;
        warningText = l10n.compliancePillar4Warning;
        exemptionText = l10n.compliancePillar4Exemption;
        break;
      case 4:
      default:
        // Pillar 5: Technical Certificates & MSDS
        mandatoryText = l10n.compliancePillar5Mandatory;
        warningText = l10n.compliancePillar5Warning;
        exemptionText = l10n.compliancePillar5Exemption;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppTheme.cobalt, size: 18),
              const SizedBox(width: 6),
              Text(
                l10n.complianceBannerTitle(
                  currentHs.isNotEmpty ? currentHs : 'HS-Code',
                  currentDesc.isNotEmpty ? "($currentDesc)" : "",
                ),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildBannerSection(
            icon: Icons.verified_outlined,
            iconColor: AppTheme.cobalt,
            title: l10n.adaptivePillarMandatoryRequirements,
            content: mandatoryText,
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
          ),
          const SizedBox(height: 6),
          _buildBannerSection(
            icon: Icons.warning_amber_rounded,
            iconColor: AppTheme.crimson,
            title: l10n.adaptivePillarComplianceAlert,
            content: warningText,
            bgColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
          ),
          const SizedBox(height: 6),
          _buildBannerSection(
            icon: Icons.lightbulb_outline,
            iconColor: AppTheme.emerald,
            title: l10n.adaptivePillarLegalExemptions,
            content: exemptionText,
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: iconColor),
                  ),
                  TextSpan(
                    text: content,
                    style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
