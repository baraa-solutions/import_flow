import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';

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
      _acidNumberCtrl.text = 'ACID-EG-2026-';
      _selectedImporterId = session.importerId;
      _importerNameCtrl.text = session.importerName;
      _importerTaxIdCtrl.text = session.importerTaxId;
      _importerAddressCtrl.text = session.importerAddress ?? '';
      _selectedSupplierId = session.supplierId;
      _exporterNameCtrl.text = session.exporterName;
      _exporterCountryCtrl.text = session.exporterCountry;
      _exporterCountryCodeCtrl.text = session.exporterCountryCode ?? '';
      _exporterAddressCtrl.text = session.exporterAddress ?? '';
      _exporterPhoneCtrl.text = session.exporterPhone ?? '';
      _cargoxIdCtrl.text = session.cargoxId ?? '';
      _exporterRegIdCtrl.text = session.exporterRegId;
      _exporterRegType = session.exporterRegType ?? 'VAT Number';
      _selectedPoId = session.poId;
      _poNoCtrl.text = session.poNumber ?? '';
      _proformaNoCtrl.text = '${session.proformaInvoiceNo}${TableRowCloneHelper.copySuffix}';
      _proformaDateCtrl.text = session.proformaInvoiceDate ?? DateTime.now().toString().substring(0, 10);
      _invoiceType = session.invoiceType ?? 'Proforma Invoice';
      _polCtrl.text = session.polName;
      _podCtrl.text = session.podName;
      _selectedBrokerId = session.customsBrokerId;
      _brokerNameCtrl.text = session.customsBrokerName ?? '';
      _brokerPhoneCtrl.text = session.customsBrokerPhone ?? '';
      _requestedDateCtrl.text = DateTime.now().toString().substring(0, 10);
    });
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

    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file == null) return;

    // Check if an existing ACID session exists for this import file
    final sessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
    final existingSession = sessions.where((s) => s.importFileId == fileId && s.isActive).firstOrNull;
    if (existingSession != null) {
      _editingAcidSessionId = existingSession.acidId;
      _editingAcidCode = existingSession.acidCode;
      if (existingSession.acidNumber.isNotEmpty && existingSession.acidNumber != 'PENDING') {
        _acidNumberCtrl.text = existingSession.acidNumber;
      }
    } else {
      _editingAcidSessionId = null;
      _editingAcidCode = null;
    }

    // Importer
    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final matchedComp = companies.where((c) => c.companyId == file.companyId).firstOrNull;
    if (matchedComp != null) {
      _selectedImporterId = matchedComp.companyId;
      _importerNameCtrl.text = matchedComp.importerName;
      _importerTaxIdCtrl.text = matchedComp.vatId;
      _importerAddressCtrl.text = matchedComp.address;
    } else {
      _importerNameCtrl.text = file.companyName;
    }

    // Exporter
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final matchedSupp = suppliers.where((s) => s.supplierId == file.supplierId).firstOrNull;
    if (matchedSupp != null) {
      _selectedSupplierId = matchedSupp.supplierId;
      _exporterNameCtrl.text = matchedSupp.companyName;
      _exporterCountryCtrl.text = matchedSupp.foreignExporterCountry;
      _exporterCountryCodeCtrl.text = matchedSupp.foreignExporterCountryCode;
      _exporterAddressCtrl.text = matchedSupp.address;
      _exporterPhoneCtrl.text = matchedSupp.phone ?? '';
      _cargoxIdCtrl.text = matchedSupp.cargoxPlatformId ?? '';
      _exporterRegIdCtrl.text = matchedSupp.foreignExporterId;
      _exporterRegType = matchedSupp.registrationType.isNotEmpty ? matchedSupp.registrationType : 'Company Registration Number';
    } else {
      _exporterNameCtrl.text = file.supplierName;
    }

    // Broker
    final partners = ref.read(partnersProvider).valueOrNull ?? [];
    final matchedBroker = partners.where((p) => p.providerId == file.brokerId).firstOrNull;
    if (matchedBroker != null) {
      _selectedBrokerId = matchedBroker.providerId;
      _brokerNameCtrl.text = matchedBroker.partnerName;
      _brokerPhoneCtrl.text = matchedBroker.phone ?? '';
    }

    // PO & Proforma
    final pos = ref.read(purchaseOrdersProvider).purchaseOrders;
    final matchedPo = pos.where((p) => p.importFileId == fileId).firstOrNull;
    if (matchedPo != null) {
      _selectedPoId = matchedPo.poId;
      _poDateCtrl.text = matchedPo.orderDate != null ? matchedPo.orderDate!.toIso8601String().substring(0, 10) : '';
    } else {
      _selectedPoId = null;
      _poDateCtrl.text = '';
    }

    if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
      _poNoCtrl.text = file.poNumber!.trim();
    } else if (matchedPo != null) {
      _poNoCtrl.text = (matchedPo.poReference != null && matchedPo.poReference!.trim().isNotEmpty)
          ? matchedPo.poReference!.trim()
          : matchedPo.poNumber;
    } else {
      _poNoCtrl.text = '';
    }

    if (file.piNumber != null && file.piNumber!.trim().isNotEmpty) {
      _proformaNoCtrl.text = file.piNumber!.trim();
    } else if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
      _proformaNoCtrl.text = file.poNumber!.trim();
    } else if (matchedPo != null && matchedPo.proformaInvoiceNumber != null && matchedPo.proformaInvoiceNumber!.isNotEmpty) {
      _proformaNoCtrl.text = matchedPo.proformaInvoiceNumber!;
    } else {
      _proformaNoCtrl.text = '';
    }

    if (_polCtrl.text.isEmpty || _polCtrl.text == 'Shanghai Port (CNSHA)') {
      _polCtrl.text = 'CHANGSHU';
    }
    if (_podCtrl.text.isEmpty || _podCtrl.text == 'Alexandria Port (EG ALX)') {
      _podCtrl.text = 'Alexandria';
    }

    _loadAcidGuide(file);
  }

  Future<void> _loadAcidGuide(dynamic file) async {
    try {
      final res = await ref.read(experienceGuideProvider.notifier).matchShipment(
        supplier: file.supplierName,
        hsCode: file.hsCode,
        productCategory: file.productCategory,
        portOfDischarge: file.portOfDischarge,
        shippingLine: file.shippingLine,
        incoterm: file.incotermCode,
        importFileReference: file.importFileCode,
      );
      if (mounted) {
        setState(() => _acidGuideMatchResult = res);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final importCompanies = ref.watch(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];
    final partners = ref.watch(partnersProvider).valueOrNull ?? [];
    final brokers = partners.where((p) => p.partnerType.contains('Broker') || p.partnerType.contains('مخلص')).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;

    return SelectionArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return Form(
            key: _requestFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Smart Experience Guide Alert Banner
                if (_acidGuideMatchResult != null && _acidGuideMatchResult!.matchedEntries.isNotEmpty)
                  ExperienceGuideAlertBanner(
                    matchResult: _acidGuideMatchResult!,
                    supplier: _exporterNameCtrl.text,
                    portOfDischarge: _podCtrl.text,
                    portOfLoading: _polCtrl.text,
                  ),

                // Informational Alert
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cobaltLight : AppTheme.infoBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.5) : AppTheme.cobaltBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.wcagCobalt, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.acidInfoBanner,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkHyperlink : AppTheme.infoForeground,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit Mode Banner
                if (_editingAcidSessionId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.orangeLight : AppTheme.warningBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppTheme.wcagOrange : AppTheme.orange, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note, color: AppTheme.orange, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CopyableText(
                                '${l.activeEditModeBanner}: ${_editingAcidCode ?? ''}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.orange : AppTheme.warningForeground,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.acidSessionLoadedForEdit(_editingAcidCode ?? ''),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppButton(
                          label: l.cancelEdit,
                          onPressed: () {
                            setState(() {
                              _editingAcidSessionId = null;
                              _editingAcidCode = null;
                            });
                            widget.onCancelEdit?.call();
                          },
                          variant: AppButtonVariant.secondary,
                          icon: Icons.close,
                        ),
                      ],
                    ),
                  ),
                ],

                // File Selector Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecorationOf(context),
                  child: SearchableDropdownField<int>(
                    labelText: l.selectImportFileAcidLabel,
                    hintText: l.searchFileOrSupplierHint,
                    value: _selectedImportFileId,
                    isRequired: true,
                    items: importFiles.map((f) => SearchableDropdownItem<int>(
                      value: f.importFileId,
                      label: '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " [PO: ${f.poNumber!}]" : ""} — ${f.supplierName} (${f.companyName})',
                    )).toList(),
                    onChanged: (val) => _handleImportFileChange(val, notifyParent: true),
                  ),
                ),
                const SizedBox(height: 20),

                // Importer & Exporter Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecorationOf(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.importerAndExporterSection,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const Divider(height: 24),
                      if (isMobile) ...[
                        _buildImporterSection(importCompanies),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildExporterSection(suppliers),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildImporterSection(importCompanies)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildExporterSection(suppliers)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Invoice, Ports & Broker Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecorationOf(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.proformaPortsBrokerSection,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const Divider(height: 24),
                      if (isMobile) ...[
                        TextFormField(
                          controller: _proformaNoCtrl,
                          decoration: InputDecoration(
                            labelText: '${l.proformaInvoiceNoLabel} *',
                            prefixIcon: const Icon(Icons.receipt_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? l.proformaInvoiceNoLabel : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _proformaDateCtrl,
                          decoration: InputDecoration(
                            labelText: '${l.proformaInvoiceDateLabel} *',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SearchableDropdownField<String>(
                          value: _invoiceType,
                          labelText: l.invoiceTypeLabel,
                          items: [
                            SearchableDropdownItem(value: 'Proforma Invoice', label: l.proformaInvoiceLabel),
                            SearchableDropdownItem(value: 'Commercial Invoice', label: l.commercialInvoiceLabel),
                          ],
                          onChanged: (val) => setState(() => _invoiceType = val ?? 'Proforma Invoice'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _polCtrl,
                          decoration: InputDecoration(
                            labelText: '${l.portOfLoadingLabel} *',
                            prefixIcon: const Icon(Icons.directions_boat_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? l.portOfLoadingLabel : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _podCtrl,
                          decoration: InputDecoration(
                            labelText: '${l.portOfDischargeLabel} *',
                            prefixIcon: const Icon(Icons.anchor),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? l.portOfDischargeLabel : null,
                        ),
                        const SizedBox(height: 12),
                        SearchableDropdownField<int>(
                          labelText: l.customsBrokerResponsibleLabel,
                          hintText: l.searchFileOrSupplierHint,
                          value: _selectedBrokerId,
                          items: brokers.map((b) => SearchableDropdownItem<int>(
                            value: b.providerId ?? 0,
                            label: '${b.partnerName} (${b.partnerCode})',
                          )).toList(),
                          onChanged: (val) {
                            setState(() => _selectedBrokerId = val);
                            final b = brokers.where((brk) => brk.providerId == val).firstOrNull;
                            if (b != null) {
                              _brokerNameCtrl.text = b.partnerName;
                              _brokerPhoneCtrl.text = b.phone ?? '';
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _brokerPhoneCtrl,
                          decoration: InputDecoration(
                            labelText: l.brokerPhoneLabel,
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _requestedDateCtrl,
                          decoration: InputDecoration(
                            labelText: '${l.acidRequestDateLabel} *',
                            prefixIcon: const Icon(Icons.event_available),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _proformaNoCtrl,
                                decoration: InputDecoration(
                                  labelText: '${l.proformaInvoiceNoLabel} *',
                                  prefixIcon: const Icon(Icons.receipt_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? l.proformaInvoiceNoLabel : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _proformaDateCtrl,
                                decoration: InputDecoration(
                                  labelText: '${l.proformaInvoiceDateLabel} *',
                                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: SearchableDropdownField<String>(
                                value: _invoiceType,
                                labelText: l.invoiceTypeLabel,
                                items: [
                                  SearchableDropdownItem(value: 'Proforma Invoice', label: l.proformaInvoiceLabel),
                                  SearchableDropdownItem(value: 'Commercial Invoice', label: l.commercialInvoiceLabel),
                                ],
                                onChanged: (val) => setState(() => _invoiceType = val ?? 'Proforma Invoice'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _polCtrl,
                                decoration: InputDecoration(
                                  labelText: '${l.portOfLoadingLabel} *',
                                  prefixIcon: const Icon(Icons.directions_boat_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? l.portOfLoadingLabel : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _podCtrl,
                                decoration: InputDecoration(
                                  labelText: '${l.portOfDischargeLabel} *',
                                  prefixIcon: const Icon(Icons.anchor),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? l.portOfDischargeLabel : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SearchableDropdownField<int>(
                                labelText: l.customsBrokerResponsibleLabel,
                                hintText: l.searchFileOrSupplierHint,
                                value: _selectedBrokerId,
                                items: brokers.map((b) => SearchableDropdownItem<int>(
                                  value: b.providerId ?? 0,
                                  label: '${b.partnerName} (${b.partnerCode})',
                                )).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedBrokerId = val);
                                  final b = brokers.where((brk) => brk.providerId == val).firstOrNull;
                                  if (b != null) {
                                    _brokerNameCtrl.text = b.partnerName;
                                    _brokerPhoneCtrl.text = b.phone ?? '';
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _brokerPhoneCtrl,
                                decoration: InputDecoration(
                                  labelText: l.brokerPhoneLabel,
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _requestedDateCtrl,
                                decoration: InputDecoration(
                                  labelText: '${l.acidRequestDateLabel} *',
                                  prefixIcon: const Icon(Icons.event_available),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Submit & Action Buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          AppButton(
                            key: const Key('saveAcidRequestSubmitBtn'),
                            label: _isSaving
                                ? l.loading
                                : (_editingAcidSessionId != null ? l.updateAcidRequestButton : l.saveAcidRequestButton),
                            onPressed: _isSaving ? null : _saveAcidRequest,
                            icon: Icons.save,
                            isLoading: _isSaving,
                          ),
                          AppButton(
                            label: l.goToSmartParserButton,
                            onPressed: widget.onGoToSmartParser,
                            variant: AppButtonVariant.secondary,
                            icon: Icons.smart_toy_outlined,
                          ),
                          AppButton(
                            key: const Key('subtab0SearchAndCloneBtn'),
                            label: l.searchAndCloneAcidBtn,
                            onPressed: widget.onOpenSearchAndClone,
                            variant: AppButtonVariant.secondary,
                            icon: Icons.copy_all,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Live Generated Broker Message Preview Card
                _buildBrokerMessagePreviewCard(context, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImporterSection(List<dynamic> importCompanies) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.importerSectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        SearchableDropdownField<int>(
          labelText: l.importerSectionTitle,
          hintText: l.searchFileOrSupplierHint,
          value: _selectedImporterId,
          isRequired: true,
          items: importCompanies.map((c) => SearchableDropdownItem<int>(
            value: c.companyId ?? 0,
            label: '${c.importerName} (${c.importerId})',
          )).toList(),
          onChanged: (val) {
            setState(() => _selectedImporterId = val);
            final c = importCompanies.where((comp) => comp.companyId == val).firstOrNull;
            if (c != null) {
              _importerNameCtrl.text = c.importerName;
              _importerTaxIdCtrl.text = c.vatId;
              _importerAddressCtrl.text = c.address;
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _importerTaxIdCtrl,
          decoration: InputDecoration(
            labelText: '${l.importerTaxIdLabel} *',
            prefixIcon: const Icon(Icons.badge_outlined),
            border: const OutlineInputBorder(),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? l.importerTaxIdLabel : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _importerAddressCtrl,
          decoration: InputDecoration(
            labelText: l.importerAddressLabel,
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildExporterSection(List<dynamic> suppliers) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.foreignExporterSectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        SearchableDropdownField<int>(
          labelText: l.foreignExporterSectionTitle,
          hintText: l.searchFileOrSupplierHint,
          value: _selectedSupplierId,
          isRequired: true,
          items: suppliers.map((s) => SearchableDropdownItem<int>(
            value: s.supplierId ?? 0,
            label: '${s.companyName} (${s.foreignExporterCountry})',
          )).toList(),
          onChanged: (val) {
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
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _exporterRegIdCtrl,
                decoration: InputDecoration(
                  labelText: '${l.foreignExporterIdLabel} *',
                  helperText: _exporterRegType,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l.foreignExporterIdLabel : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SearchableDropdownField<String>(
                value: _exporterRegType,
                labelText: l.regTypeLabel,
                items: [
                  SearchableDropdownItem(value: 'VAT Number', label: l.vatRegType),
                  SearchableDropdownItem(value: 'Commercial Register', label: l.crRegType),
                  SearchableDropdownItem(value: 'Tax ID', label: l.taxIdRegType),
                  SearchableDropdownItem(value: 'DUNS Number', label: l.dunsRegType),
                ],
                onChanged: (val) => setState(() => _exporterRegType = val ?? 'VAT Number'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _exporterCountryCtrl,
                decoration: InputDecoration(
                  labelText: '${l.countryOfOriginExportLabel} *',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l.countryOfOriginExportLabel : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _cargoxIdCtrl,
                decoration: InputDecoration(
                  labelText: l.cargoxPlatformIdLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrokerMessagePreviewCard(BuildContext context, bool isDark) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.emeraldLight : AppTheme.successBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.wcagEmerald.withValues(alpha: 0.5) : AppTheme.emeraldBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mark_email_read_outlined, color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.brokerDispatchMessageTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.brokerDispatchMessageSub,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: l.copyArabicWhatsApp,
                onPressed: () {
                  CopyHelper.copy(context, _buildWhatsAppMessage(), customMessage: l.whatsAppMessageCopied);
                },
                variant: AppButtonVariant.success,
                icon: Icons.copy,
              ),
              AppButton(
                label: l.copyEnglishRequest,
                onPressed: () {
                  CopyHelper.copy(context, _buildEnglishRequestMessage(), customMessage: l.acidRequestCopied);
                },
                icon: Icons.language,
              ),
              AppButton(
                label: l.emailTemplateButton,
                onPressed: () {
                  CopyHelper.copy(context, _buildEmailMessage(), customMessage: l.emailTemplateCopied);
                },
                variant: AppButtonVariant.secondary,
                icon: Icons.email_outlined,
              ),
            ],
          ),
          const Divider(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.emeraldBorder),
            ),
            child: SelectableText(
              isAr ? _buildWhatsAppMessage() : _buildEnglishRequestMessage(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
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
    try {
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

      final sessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
      final existing = sessions.where((s) => s.importFileId == _selectedImportFileId && s.isActive).firstOrNull;
      final targetAcidId = _editingAcidSessionId ?? existing?.acidId;

      if (targetAcidId != null) {
        await ref.read(acidSessionsProvider.notifier).updateAcidSession(targetAcidId, payload);
        if (mounted) {
          final acidCode = existing?.acidCode ?? _editingAcidCode ?? '';
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.acidRequestUpdatedSuccess(acidCode), severity: AppSeverity.success),
          );
          setState(() {
            _editingAcidSessionId = targetAcidId;
          });
          widget.onSaved?.call(targetAcidId, acidCode);
        }
      } else {
        final created = await ref.read(acidSessionsProvider.notifier).createAcidSession(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.acidRequestSavedSuccess, severity: AppSeverity.success),
          );
          if (created != null) {
            widget.onSaved?.call(created.acidId, created.acidCode);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: l.errorSavingAcid, error: e);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _buildWhatsAppMessage() {
    final impName = _importerNameCtrl.text.trim().isNotEmpty ? _importerNameCtrl.text.trim() : '-';
    final impTax = _importerTaxIdCtrl.text.trim().isNotEmpty ? _importerTaxIdCtrl.text.trim() : '-';
    final impAddr = _importerAddressCtrl.text.trim().isNotEmpty ? _importerAddressCtrl.text.trim() : '-';
    final expName = _exporterNameCtrl.text.trim().isNotEmpty ? _exporterNameCtrl.text.trim() : '-';
    final expId = _exporterRegIdCtrl.text.trim().isNotEmpty ? _exporterRegIdCtrl.text.trim() : '-';
    final expCountry = _exporterCountryCtrl.text.trim().isNotEmpty ? _exporterCountryCtrl.text.trim() : '-';
    final expAddr = _exporterAddressCtrl.text.trim().isNotEmpty ? _exporterAddressCtrl.text.trim() : '-';
    final expPhone = _exporterPhoneCtrl.text.trim().isNotEmpty ? _exporterPhoneCtrl.text.trim() : '-';
    final cargox = _cargoxIdCtrl.text.trim().isNotEmpty ? _cargoxIdCtrl.text.trim() : '-';
    final piNo = _proformaNoCtrl.text.trim().isNotEmpty ? _proformaNoCtrl.text.trim() : '-';
    final piDate = _proformaDateCtrl.text.trim().isNotEmpty ? _proformaDateCtrl.text.trim() : '-';
    final poNo = _poNoCtrl.text.trim().isNotEmpty ? _poNoCtrl.text.trim() : '-';
    final pol = _polCtrl.text.trim().isNotEmpty ? _polCtrl.text.trim() : '-';
    final pod = _podCtrl.text.trim().isNotEmpty ? _podCtrl.text.trim() : '-';
    final reqDate = _requestedDateCtrl.text.trim().isNotEmpty ? _requestedDateCtrl.text.trim() : '-';

    return '''📋 *طلب استخراج رقم ACID جديد*
━━━━━━━━━━━━━━━━━━━━
🏢 *المستورد المصري:* $impName
🔢 *البطاقة الضريبية:* $impTax
📍 *العنوان المسجل:* $impAddr

🌍 *المصدر الأجنبي:* $expName
🆔 *المعرف الضريبي / نوعه:* $expId ($_exporterRegType)
🌐 *دولة المنشأ / التصدير:* $expCountry
📍 *عنوان المصدر:* $expAddr
📞 *هاتف المصدر:* $expPhone
🔑 *حساب كارجو إكس (CargoX ID):* $cargox

📄 *رقم الفاتورة المبدئية:* $piNo
📅 *تاريخ الفاتورة المبدئية:* $piDate
📑 *نوع الفاتورة:* $_invoiceType
📦 *أمر الشراء (PO):* $poNo
🚢 *ميناء الشحن (POL):* $pol
⚓ *ميناء الوصول (POD):* $pod
📅 *تاريخ تقديم الطلب:* $reqDate
━━━━━━━━━━━━━━━━━━━━
⚠️ *ملاحظة:* يرجى مراجعة الفاتورة المبدئية وسرعة موافاتنا برقم الـ ACID فور صدوره مع خالص الشكر.''';
  }

  String _buildEmailMessage() {
    final impName = _importerNameCtrl.text.trim().isNotEmpty ? _importerNameCtrl.text.trim() : 'Import';
    final piNo = _proformaNoCtrl.text.trim().isNotEmpty ? _proformaNoCtrl.text.trim() : '';
    final broker = _brokerNameCtrl.text.trim().isNotEmpty ? _brokerNameCtrl.text.trim() : 'مكتب التخليص الجمركي';

    return '''الموضوع: طلب إصدار رقم ACID - شحنة $impName - فاتورة $piNo

السيد المخلص الجمركي المحترم / $broker
تحية طيبة وبعد،،،

يرجى التكرم ببدء إجراءات طلب واستخراج رقم القيد الجمركي المبدئي (ACID) عبر منظومة نافذة للشحنة الموضحة بياناتها أدناه:

1. بيانات المستورد المصري:
   - اسم المستورد: ${_importerNameCtrl.text.trim()}
   - الرقم الضريبي: ${_importerTaxIdCtrl.text.trim()}
   - العنوان: ${_importerAddressCtrl.text.trim()}

2. بيانات المصدر الأجنبي:
   - اسم المصدر: ${_exporterNameCtrl.text.trim()}
   - نوع التسجيل والمعرف: ${_exporterRegIdCtrl.text.trim()} ($_exporterRegType)
   - دولة المنشأ: ${_exporterCountryCtrl.text.trim()}
   - عنوان المصدر: ${_exporterAddressCtrl.text.trim()}
   - هاتف المصدر: ${_exporterPhoneCtrl.text.trim()}
   - كود كارجو إكس (CargoX): ${_cargoxIdCtrl.text.trim()}

3. بيانات الفاتورة والشحن:
   - رقم الفاتورة المبدئية: ${_proformaNoCtrl.text.trim()}
   - تاريخ الفاتورة المبدئية: ${_proformaDateCtrl.text.trim()}
   - أمر الشراء: ${_poNoCtrl.text.trim()}
   - ميناء الشحن: ${_polCtrl.text.trim()}
   - ميناء الوصول: ${_podCtrl.text.trim()}

تجدون برفقه الفاتورة المبدئية للاطلاع والبدء في الإجراءات.
شاكرين لكم حسن تعاونكم الدائم.

قسم الاستيراد والتخليص الجمركي
Sorour Logistics ERP System''';
  }

  String _buildEnglishRequestMessage() {
    final impName = _importerNameCtrl.text.trim().isNotEmpty ? _importerNameCtrl.text.trim() : '-';
    final impTax = _importerTaxIdCtrl.text.trim().isNotEmpty ? _importerTaxIdCtrl.text.trim() : '-';
    final impAddr = _importerAddressCtrl.text.trim().isNotEmpty ? _importerAddressCtrl.text.trim() : '-';
    final expName = _exporterNameCtrl.text.trim().isNotEmpty ? _exporterNameCtrl.text.trim() : '-';
    final expId = _exporterRegIdCtrl.text.trim().isNotEmpty ? _exporterRegIdCtrl.text.trim() : '-';
    final expCountry = _exporterCountryCtrl.text.trim().isNotEmpty ? _exporterCountryCtrl.text.trim() : '-';
    final expAddr = _exporterAddressCtrl.text.trim().isNotEmpty ? _exporterAddressCtrl.text.trim() : '-';
    final expPhone = _exporterPhoneCtrl.text.trim().isNotEmpty ? _exporterPhoneCtrl.text.trim() : '-';
    final cargox = _cargoxIdCtrl.text.trim().isNotEmpty ? _cargoxIdCtrl.text.trim() : '-';
    final piNo = _proformaNoCtrl.text.trim().isNotEmpty ? _proformaNoCtrl.text.trim() : '-';
    final piDate = _proformaDateCtrl.text.trim().isNotEmpty ? _proformaDateCtrl.text.trim() : '-';
    final poNo = _poNoCtrl.text.trim().isNotEmpty ? _poNoCtrl.text.trim() : '-';
    final pol = _polCtrl.text.trim().isNotEmpty ? _polCtrl.text.trim() : '-';
    final pod = _podCtrl.text.trim().isNotEmpty ? _podCtrl.text.trim() : '-';
    final reqDate = _requestedDateCtrl.text.trim().isNotEmpty ? _requestedDateCtrl.text.trim() : '-';

    return '''📋 *Advance Cargo Information (ACID) Request*
━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏢 *Egyptian Importer:* $impName
🔢 *Tax ID:* $impTax
📍 *Registered Address:* $impAddr

🌍 *Foreign Exporter / Supplier:* $expName
🆔 *Exporter Reg. ID:* $expId ($_exporterRegType)
🌐 *Country of Origin / Export:* $expCountry
📍 *Exporter Address:* $expAddr
📞 *Tel. / Mobile:* $expPhone
🔑 *CargoX Platform ID:* $cargox

📄 *Proforma Invoice No.:* $piNo
📅 *Proforma Invoice Date:* $piDate
📑 *Invoice Type:* $_invoiceType
📦 *Purchase Order (PO):* $poNo
🚢 *Port of Loading (POL):* $pol
⚓ *Port of Discharge (POD):* $pod
📅 *Request Date:* $reqDate
━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ *Important Note:* Please initiate the ACID issuance on the Nafeza (MTS) portal and provide us with the 19-digit ACID number upon generation. Thank you.''';
  }
}
