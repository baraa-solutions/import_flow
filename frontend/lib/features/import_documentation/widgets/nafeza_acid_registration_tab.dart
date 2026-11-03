import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/import_documentation_model.dart';
import 'nafeza_acid_reg/acid_broker_message_generator.dart';
import 'nafeza_acid_reg/acid_broker_preview_card.dart';
import 'nafeza_acid_reg/acid_parties_section_card.dart';
import 'nafeza_acid_reg/acid_proforma_shipping_card.dart';
import 'nafeza_acid_reg/acid_registration_form_service.dart';
import 'nafeza_acid_reg/acid_registration_header_section.dart';

/// Nafeza ACID Registration & Request Form Tab
///
/// Contains:
/// - Egyptian Importer company selection & tax identification.
/// - Foreign Exporter / Supplier details, country, CargoX ID, and registration type.
/// - Proforma Invoice / PO data, ports of loading/discharge, customs broker.
/// - Broker dispatch notification generators (WhatsApp, English request, Email template).
/// - Wrapped in [SelectionArea] with [CopyHelper.copy] for Bidi-safe copying.
class NafezaAcidRegistrationTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final int? editingAcidSessionId;
  final String? editingAcidCode;
  final AcidRegistrationModel? clonedSession;
  final ValueChanged<int?>? onImportFileChanged;
  final VoidCallback? onGoToSmartParser;
  final VoidCallback? onOpenSearchAndClone;
  final void Function(int sessionId, String acidCode)? onSaved;
  final VoidCallback? onCancelEdit;

  const NafezaAcidRegistrationTab({
    super.key,
    this.initialImportFileId,
    this.editingAcidSessionId,
    this.editingAcidCode,
    this.clonedSession,
    this.onImportFileChanged,
    this.onGoToSmartParser,
    this.onOpenSearchAndClone,
    this.onSaved,
    this.onCancelEdit,
  });

  @override
  ConsumerState<NafezaAcidRegistrationTab> createState() => _NafezaAcidRegistrationTabState();
}

class _NafezaAcidRegistrationTabState extends ConsumerState<NafezaAcidRegistrationTab> {
  final _requestFormKey = GlobalKey<FormState>();

  int? _selectedImportFileId;
  int? _editingAcidSessionId;
  String? _editingAcidCode;
  GuideMatchResultModel? _acidGuideMatchResult;

  // Importer
  int? _selectedImporterId;
  final TextEditingController _importerNameCtrl = TextEditingController();
  final TextEditingController _importerTaxIdCtrl = TextEditingController();
  final TextEditingController _importerAddressCtrl = TextEditingController();

  // Exporter
  int? _selectedSupplierId;
  final TextEditingController _exporterNameCtrl = TextEditingController();
  String _exporterRegType = 'VAT Number';
  final TextEditingController _exporterRegIdCtrl = TextEditingController();
  final TextEditingController _exporterCountryCtrl = TextEditingController();
  final TextEditingController _exporterCountryCodeCtrl = TextEditingController();
  final TextEditingController _exporterAddressCtrl = TextEditingController();
  final TextEditingController _exporterPhoneCtrl = TextEditingController();
  final TextEditingController _cargoxIdCtrl = TextEditingController();

  // PO & Proforma
  int? _selectedPoId;
  final TextEditingController _poNoCtrl = TextEditingController();
  final TextEditingController _poDateCtrl = TextEditingController();
  final TextEditingController _proformaNoCtrl = TextEditingController();
  final TextEditingController _proformaDateCtrl = TextEditingController(
    text: DateTime.now().toString().substring(0, 10),
  );
  String _invoiceType = 'Proforma Invoice';

  // Ports & Broker
  final TextEditingController _polCtrl = TextEditingController();
  final TextEditingController _podCtrl = TextEditingController();
  int? _selectedBrokerId;
  final TextEditingController _brokerNameCtrl = TextEditingController();
  final TextEditingController _brokerPhoneCtrl = TextEditingController();

  final TextEditingController _requestedDateCtrl = TextEditingController(
    text: DateTime.now().toString().substring(0, 10),
  );
  final TextEditingController _acidNumberCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    _editingAcidSessionId = widget.editingAcidSessionId;
    _editingAcidCode = widget.editingAcidCode;

    if (widget.clonedSession != null) {
      _applyClonedSession(widget.clonedSession!);
    } else if (_selectedImportFileId != null) {
      Future.microtask(() => _handleImportFileChange(_selectedImportFileId, notifyParent: false));
    }
  }

  @override
  void didUpdateWidget(NafezaAcidRegistrationTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != _selectedImportFileId) {
      _handleImportFileChange(widget.initialImportFileId, notifyParent: false);
    }
    if (widget.editingAcidSessionId != oldWidget.editingAcidSessionId || widget.editingAcidCode != oldWidget.editingAcidCode) {
      setState(() {
        _editingAcidSessionId = widget.editingAcidSessionId;
        _editingAcidCode = widget.editingAcidCode;
      });
    }
    if (widget.clonedSession != oldWidget.clonedSession && widget.clonedSession != null) {
      _applyClonedSession(widget.clonedSession!);
    }
  }

  @override
  void dispose() {
    _importerNameCtrl.dispose();
    _importerTaxIdCtrl.dispose();
    _importerAddressCtrl.dispose();
    _exporterNameCtrl.dispose();
    _exporterRegIdCtrl.dispose();
    _exporterCountryCtrl.dispose();
    _exporterCountryCodeCtrl.dispose();
    _exporterAddressCtrl.dispose();
    _exporterPhoneCtrl.dispose();
    _cargoxIdCtrl.dispose();
    _poNoCtrl.dispose();
    _poDateCtrl.dispose();
    _proformaNoCtrl.dispose();
    _proformaDateCtrl.dispose();
    _polCtrl.dispose();
    _podCtrl.dispose();
    _brokerNameCtrl.dispose();
    _brokerPhoneCtrl.dispose();
    _requestedDateCtrl.dispose();
    _acidNumberCtrl.dispose();
    super.dispose();
  }

  void _applyClonedSession(AcidRegistrationModel session) {
    setState(() {
      _editingAcidSessionId = null;
      _editingAcidCode = null;
      _selectedImportFileId = session.importFileId;
      _selectedImporterId = session.importerId;
      _selectedSupplierId = session.supplierId;
      _exporterRegType = session.exporterRegType ?? 'VAT Number';
      _selectedPoId = session.poId;
      _invoiceType = session.invoiceType ?? 'Proforma Invoice';
      _selectedBrokerId = session.customsBrokerId;
    });
    AcidRegistrationFormService.applyClonedSession(
      session: session,
      acidNumberCtrl: _acidNumberCtrl,
      importerNameCtrl: _importerNameCtrl,
      importerTaxIdCtrl: _importerTaxIdCtrl,
      importerAddressCtrl: _importerAddressCtrl,
      exporterNameCtrl: _exporterNameCtrl,
      exporterCountryCtrl: _exporterCountryCtrl,
      exporterCountryCodeCtrl: _exporterCountryCodeCtrl,
      exporterAddressCtrl: _exporterAddressCtrl,
      exporterPhoneCtrl: _exporterPhoneCtrl,
      cargoxIdCtrl: _cargoxIdCtrl,
      exporterRegIdCtrl: _exporterRegIdCtrl,
      poNoCtrl: _poNoCtrl,
      proformaNoCtrl: _proformaNoCtrl,
      proformaDateCtrl: _proformaDateCtrl,
      polCtrl: _polCtrl,
      podCtrl: _podCtrl,
      brokerNameCtrl: _brokerNameCtrl,
      brokerPhoneCtrl: _brokerPhoneCtrl,
      requestedDateCtrl: _requestedDateCtrl,
    );
  }

  void _handleImportFileChange(int? fileId, {bool notifyParent = true}) {
    setState(() => _selectedImportFileId = fileId);
    if (notifyParent) {
      widget.onImportFileChanged?.call(fileId);
    }
    if (fileId == null) {
      setState(() {
        _editingAcidSessionId = null;
        _editingAcidCode = null;
      });
      return;
    }

    final pop = AcidRegistrationFormService.populateFromImportFile(
      fileId: fileId,
      ref: ref,
      acidNumberCtrl: _acidNumberCtrl,
      importerNameCtrl: _importerNameCtrl,
      importerTaxIdCtrl: _importerTaxIdCtrl,
      importerAddressCtrl: _importerAddressCtrl,
      exporterNameCtrl: _exporterNameCtrl,
      exporterCountryCtrl: _exporterCountryCtrl,
      exporterCountryCodeCtrl: _exporterCountryCodeCtrl,
      exporterAddressCtrl: _exporterAddressCtrl,
      exporterPhoneCtrl: _exporterPhoneCtrl,
      cargoxIdCtrl: _cargoxIdCtrl,
      exporterRegIdCtrl: _exporterRegIdCtrl,
      poNoCtrl: _poNoCtrl,
      poDateCtrl: _poDateCtrl,
      proformaNoCtrl: _proformaNoCtrl,
      polCtrl: _polCtrl,
      podCtrl: _podCtrl,
      brokerNameCtrl: _brokerNameCtrl,
      brokerPhoneCtrl: _brokerPhoneCtrl,
    );

    setState(() {
      _selectedImporterId = pop.selectedImporterId;
      _selectedSupplierId = pop.selectedSupplierId;
      _exporterRegType = pop.exporterRegType;
      _selectedBrokerId = pop.selectedBrokerId;
      _selectedPoId = pop.selectedPoId;
      _editingAcidSessionId = pop.editingAcidSessionId;
      _editingAcidCode = pop.editingAcidCode;
    });

    AcidRegistrationFormService.loadAcidGuide(fileId: fileId, ref: ref).then((res) {
      if (mounted) setState(() => _acidGuideMatchResult = res);
    });
  }

  Future<void> _saveAcidRequest() async {
    final l = context.l10n;
    if (!_requestFormKey.currentState!.validate()) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.selectImportFileFirst, severity: AppSeverity.danger),
      );
      return;
    }

    setState(() => _isSaving = true);
    final payload = {
      'import_file_id': _selectedImportFileId,
      'importer_id': _selectedImporterId,
      'importer_name': _importerNameCtrl.text.trim(),
      'importer_tax_id': _importerTaxIdCtrl.text.trim(),
      'importer_address': _importerAddressCtrl.text.trim(),
      'supplier_id': _selectedSupplierId,
      'exporter_name': _exporterNameCtrl.text.trim(),
      'exporter_reg_type': _exporterRegType,
      'exporter_reg_id': _exporterRegIdCtrl.text.trim(),
      'exporter_country': _exporterCountryCtrl.text.trim(),
      'exporter_country_code': _exporterCountryCodeCtrl.text.trim(),
      'exporter_address': _exporterAddressCtrl.text.trim(),
      'exporter_phone': _exporterPhoneCtrl.text.trim(),
      'cargox_id': _cargoxIdCtrl.text.trim(),
      'po_id': _selectedPoId,
      'po_number': _poNoCtrl.text.trim(),
      'proforma_invoice_no': _proformaNoCtrl.text.trim(),
      'proforma_invoice_date': _proformaDateCtrl.text.trim(),
      'invoice_type': _invoiceType,
      'pol_name': _polCtrl.text.trim(),
      'pod_name': _podCtrl.text.trim(),
      'customs_broker_id': _selectedBrokerId,
      'customs_broker_name': _brokerNameCtrl.text.trim(),
      'customs_broker_phone': _brokerPhoneCtrl.text.trim(),
      'requested_date': _requestedDateCtrl.text.trim(),
    };

    final savedId = await AcidRegistrationFormService.submitAcidRequest(
      context: context,
      ref: ref,
      selectedImportFileId: _selectedImportFileId!,
      editingAcidSessionId: _editingAcidSessionId,
      editingAcidCode: _editingAcidCode,
      payload: payload,
      onSaved: widget.onSaved,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (savedId != null) _editingAcidSessionId = savedId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final importCompanies = ref.watch(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];
    final partners = ref.watch(partnersProvider).valueOrNull ?? [];
    final brokers = partners.where((p) => p.partnerType.contains('Broker') || p.partnerType.contains('مخلص')).toList();

    return SelectionArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return Form(
            key: _requestFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AcidRegistrationHeaderSection(
                  acidGuideMatchResult: _acidGuideMatchResult,
                  exporterName: _exporterNameCtrl.text,
                  podName: _podCtrl.text,
                  polName: _polCtrl.text,
                  editingAcidSessionId: _editingAcidSessionId,
                  editingAcidCode: _editingAcidCode,
                  onCancelEdit: () {
                    setState(() {
                      _editingAcidSessionId = null;
                      _editingAcidCode = null;
                    });
                    widget.onCancelEdit?.call();
                  },
                  importFiles: importFiles,
                  selectedImportFileId: _selectedImportFileId,
                  onImportFileChanged: (val) => _handleImportFileChange(val, notifyParent: true),
                ),
                const SizedBox(height: 20),
                AcidPartiesSectionCard(
                  importCompanies: importCompanies,
                  suppliers: suppliers,
                  selectedImporterId: _selectedImporterId,
                  importerTaxIdCtrl: _importerTaxIdCtrl,
                  importerAddressCtrl: _importerAddressCtrl,
                  onImporterChanged: (val) {
                    setState(() => _selectedImporterId = val);
                    final c = importCompanies.where((comp) => comp.companyId == val).firstOrNull;
                    if (c != null) {
                      _importerNameCtrl.text = c.importerName;
                      _importerTaxIdCtrl.text = c.vatId;
                      _importerAddressCtrl.text = c.address;
                    }
                  },
                  selectedSupplierId: _selectedSupplierId,
                  exporterRegIdCtrl: _exporterRegIdCtrl,
                  exporterRegType: _exporterRegType,
                  exporterCountryCtrl: _exporterCountryCtrl,
                  cargoxIdCtrl: _cargoxIdCtrl,
                  onSupplierChanged: (val) {
                    setState(() => _selectedSupplierId = val);
                    final s = suppliers.where((supp) => supp.supplierId == val).firstOrNull;
                    if (s != null) {
                      _exporterNameCtrl.text = s.companyName;
                      _exporterCountryCtrl.text = s.foreignExporterCountry;
                      _exporterCountryCodeCtrl.text = s.foreignExporterCountryCode;
                      _exporterAddressCtrl.text = s.address;
                      _exporterPhoneCtrl.text = s.phone ?? '';
                      _cargoxIdCtrl.text = s.cargoxPlatformId ?? '';
                      _exporterRegIdCtrl.text = s.foreignExporterId;
                    }
                  },
                  onRegTypeChanged: (val) => setState(() => _exporterRegType = val ?? 'VAT Number'),
                  isMobile: isMobile,
                ),
                const SizedBox(height: 20),
                AcidProformaShippingCard(
                  proformaNoCtrl: _proformaNoCtrl,
                  proformaDateCtrl: _proformaDateCtrl,
                  invoiceType: _invoiceType,
                  onInvoiceTypeChanged: (val) => setState(() => _invoiceType = val ?? 'Proforma Invoice'),
                  polCtrl: _polCtrl,
                  podCtrl: _podCtrl,
                  brokers: brokers,
                  selectedBrokerId: _selectedBrokerId,
                  onBrokerChanged: (val) {
                    setState(() => _selectedBrokerId = val);
                    final b = brokers.where((brk) => brk.providerId == val).firstOrNull;
                    if (b != null) {
                      _brokerNameCtrl.text = b.partnerName;
                      _brokerPhoneCtrl.text = b.phone ?? '';
                    }
                  },
                  brokerPhoneCtrl: _brokerPhoneCtrl,
                  requestedDateCtrl: _requestedDateCtrl,
                  isSaving: _isSaving,
                  editingAcidSessionId: _editingAcidSessionId,
                  onSave: _saveAcidRequest,
                  onGoToSmartParser: widget.onGoToSmartParser,
                  onOpenSearchAndClone: widget.onOpenSearchAndClone,
                  isMobile: isMobile,
                ),
                const SizedBox(height: 20),
                AcidBrokerPreviewCard(
                  data: AcidBrokerMessageData(
                    importerName: _importerNameCtrl.text.trim(),
                    importerTaxId: _importerTaxIdCtrl.text.trim(),
                    importerAddress: _importerAddressCtrl.text.trim(),
                    exporterName: _exporterNameCtrl.text.trim(),
                    exporterRegId: _exporterRegIdCtrl.text.trim(),
                    exporterRegType: _exporterRegType,
                    exporterCountry: _exporterCountryCtrl.text.trim(),
                    exporterAddress: _exporterAddressCtrl.text.trim(),
                    exporterPhone: _exporterPhoneCtrl.text.trim(),
                    cargoxId: _cargoxIdCtrl.text.trim(),
                    proformaNo: _proformaNoCtrl.text.trim(),
                    proformaDate: _proformaDateCtrl.text.trim(),
                    invoiceType: _invoiceType,
                    poNo: _poNoCtrl.text.trim(),
                    polName: _polCtrl.text.trim(),
                    podName: _podCtrl.text.trim(),
                    customsBrokerName: _brokerNameCtrl.text.trim(),
                    requestedDate: _requestedDateCtrl.text.trim(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
