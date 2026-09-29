import '../widgets/broker_quote_details_card.dart';
import '../widgets/blocking_issues_dialog.dart';
import '../widgets/broker_price_lists_tab.dart';
import '../widgets/saved_consultations_tab.dart';
import '../widgets/nafeza_fee_breakdown_card.dart';
import '../widgets/consultation_details_dialog.dart';
import '../widgets/post_save_status_dialog.dart';
import '../widgets/consultation_metric_badge.dart';
import '../widgets/add_checklist_item_dialog.dart';
import '../widgets/add_custom_expense_dialog.dart';
import '../widgets/recalculation_variance_comparison_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/change_diff_dialog.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/customs_consultation_model.dart';
import '../providers/customs_consultation_provider.dart';
import '../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../services/customs_export_service.dart';
import '../services/customs_consultation_pdf_service.dart';
import '../widgets/search_and_clone_consultation_dialog.dart';
export '../widgets/search_and_clone_consultation_dialog.dart';
import '../../financial_approval/providers/financial_approval_provider.dart';
import '../../../core/widgets/table_row_clone_helper.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/localization/stored_text.dart';

class CustomsConsultationScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final bool isTaxReviewMode;
  const CustomsConsultationScreen({
    super.key,
    this.initialIndex = 0,
    this.isTaxReviewMode = false,
  });

  @override
  ConsumerState<CustomsConsultationScreen> createState() => _CustomsConsultationScreenState();
}

class _CustomsConsultationScreenState extends ConsumerState<CustomsConsultationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form State
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _estimatedDutiesController = TextEditingController(text: '0.0');

  // Customs Calculator State Controllers
  final TextEditingController _exchangeRateController = TextEditingController(text: '50.0');
  final TextEditingController _freightForeignController = TextEditingController(text: '0.0');
  String _freightCurrency = 'USD';
  final TextEditingController _freightExchangeRateController = TextEditingController(text: '50.0');
  final TextEditingController _freightEgpController = TextEditingController(text: '0.0');
  final TextEditingController _insuranceEgpController = TextEditingController(text: '0.0');
  String _insuranceOption = '0.5%'; // '0.5%', '1.0%', 'Custom'
  String _customsCurrency = 'USD';
  bool _isCustomsCalculatorExpanded = true;
  bool _groupByHsCode = true;

  // Customs Recalculation & Forecast Variance State
  CustomsRecalculationResponseModel? _recalculationResult;
  bool _isRecalculating = false;
  DateTime _studyDate = DateTime.now();

  int? _editingConsultationId;
  String? _editingConsultationCode;

  int? _selectedBrokerId;
  String _selectedBrokerName = '';
  String? _brokerContactPerson;
  int? _selectedImportFileId;
  int? _selectedPoId;
  int? _selectedProjectId;

  final List<CustomsChecklistItemModel> _checklist = [];
  final List<CustomsBrokerQuoteItemModel> _brokerQuoteItems = [];
  int? _brokerPriceListId;
  String? _brokerPriceListTitle;
  bool _isBrokerQuoteExpanded = true;
  bool _isLoadingPriceList = false;
  String _brokerExpenseCategoryFilter = 'All';

  bool _isSaving = false;

  // History Tab Filter State

  final bool _hasCustomTitle = false;
  late final Set<int> _visitedTabs = {widget.initialIndex};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    final tabCount = widget.isTaxReviewMode ? 2 : 4;
    final initialIdx = widget.initialIndex < tabCount ? widget.initialIndex : 0;
    _visitedTabs.add(initialIdx);
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: initialIdx);
    _tabController.addListener(() {
      if (!_visitedTabs.contains(_tabController.index)) {
        setState(() => _visitedTabs.add(_tabController.index));
      }
    });
    _initializeDefaultChecklist();
    Future.microtask(() {
      if (!ref.read(customsConsultationsProvider).isLoading) {
        ref.read(customsConsultationsProvider.notifier).fetchConsultations();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(purchaseOrdersProvider).isLoading) {
        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }
      if (!ref.read(customsTariffProvider).isLoading) {
        ref.read(customsTariffProvider.notifier).fetchTariffs();
      }
      if (!ref.read(currenciesProvider).isLoading) {
        ref.read(currenciesProvider.notifier).fetchCurrencies();
      }
      if (!ref.read(shippingScenariosProvider).isLoading) {
        ref.read(shippingScenariosProvider.notifier).fetchSessions();
      }
      if (!ref.read(partnersProvider).isLoading) {
        ref.read(partnersProvider.notifier).fetchPartners();
      }
      if (!ref.read(projectsProvider).isLoading) {
        ref.read(projectsProvider.notifier).fetchProjects();
      }
      if (!widget.isTaxReviewMode) {
        if (!ref.read(clearanceExpenseTypesProvider).isLoading) {
          ref.read(clearanceExpenseTypesProvider.notifier).fetchExpenseTypes();
        }
        if (!ref.read(brokerPriceListsProvider).isLoading) {
          ref.read(brokerPriceListsProvider.notifier).fetchPriceLists();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCustomTitle && _editingConsultationId == null) {
      final l = context.l10n;
      _titleController.text = widget.isTaxReviewMode
          ? l.defaultTaxReviewSessionTitle
          : l.defaultCustomsConsultationTitle;
    }
  }

  @override
  void didUpdateWidget(CustomsConsultationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _tabController.animateTo(widget.initialIndex);
      _visitedTabs.add(widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _estimatedDutiesController.dispose();
    _exchangeRateController.dispose();
    _freightForeignController.dispose();
    _freightExchangeRateController.dispose();
    _freightEgpController.dispose();
    _insuranceEgpController.dispose();
    super.dispose();
  }

  void _initializeDefaultChecklist() {
    _checklist.clear();
    _checklist.addAll([
      CustomsChecklistItemModel(
        documentType: 'Proforma Invoice',
        isRequired: true,
        isBlockingShipment: true,
        responsibleParty: 'Supplier / Exporter',
        status: 'Approved',
        remarks: 'الفاتورة المبدئية معتمدة ومطابقة للبند الجمركي.',
      ),
      CustomsChecklistItemModel(
        documentType: 'Packing List',
        isRequired: true,
        isBlockingShipment: true,
        responsibleParty: 'Supplier / Exporter',
        status: 'Approved',
        remarks: 'محدثة بإجمالي الأوزان الأحجام والطرود.',
      ),
      CustomsChecklistItemModel(
        documentType: 'Certificate of Origin',
        isRequired: true,
        isBlockingShipment: true,
        responsibleParty: 'Customs Broker',
        status: 'Pending',
        remarks: 'مطلوب توثيق السفارة والغرفة التجارية.',
      ),
      CustomsChecklistItemModel(
        documentType: 'GOEIC Inspection',
        isRequired: true,
        isBlockingShipment: true,
        responsibleParty: 'Customs Broker',
        regulatoryAgency: 'GOEIC',
        status: 'Pending',
        remarks: 'يتطلب فحص ظاهري وعينات المعمل فور الوصول.',
      ),
      CustomsChecklistItemModel(
        documentType: 'NTRA Telecommunications Approval',
        isRequired: false,
        isBlockingShipment: false,
        responsibleParty: 'Importer Team',
        regulatoryAgency: 'NTRA',
        status: 'Pending',
        remarks: 'تنطبق في حال وجود وحدات تحكم لاسلكية.',
      ),
    ]);
  }

  String _getLocalizedDocType(String docType, AppLocalizations l) {
    if (docType == 'Proforma Invoice' || docType == 'الفاتورة المبدئية') {
      return l.proformaInvoiceDoc;
    }
    if (docType == 'Packing List' || docType == 'بيان التعبئة') {
      return l.packingListDoc;
    }
    if (docType == 'Certificate of Origin' || docType == 'شهادة المنشأ') {
      return l.certificateOfOriginDoc;
    }
    if (docType == 'GOEIC Inspection' || docType == 'فحص هيئة الرقابة على الصادرات والواردات (GOEIC)') {
      return l.goeicInspectionDoc;
    }
    if (docType == 'NTRA Telecommunications Approval' || docType == 'موافقة الجهاز القومي لتنظيم الاتصالات (NTRA)') {
      return l.ntraApprovalDoc;
    }
    if (docType.contains('ACID') || docType.contains('قيد رقم ACID')) {
      return l.acidShipmentDoc;
    }
    if (docType.contains('COO') || docType.contains('شهادة المنشأ الموثقة') || docType.contains('Certificate of Origin')) {
      return l.cooShipmentDoc;
    }
    if (docType.contains('GOEIC') || docType.contains('عرض وفحص هيئة الرقابة')) {
      return l.goeicShipmentDoc;
    }
    if (docType.contains('موافقة') && docType.contains('الفنية المسبقة')) {
      final authority = docType.replaceAll('موافقة', '').replaceAll('الفنية المسبقة', '').trim();
      return l.priorAuthorityApprovalDoc(authority);
    }
    if (docType.startsWith('Prior Technical Approval from ')) {
      final authority = docType.replaceFirst('Prior Technical Approval from ', '').trim();
      return l.priorAuthorityApprovalDoc(authority);
    }
    return docType;
  }

  String _getLocalizedRemarks(String? remarks, AppLocalizations l) {
    if (remarks == null || remarks.isEmpty) return '';
    if (remarks.contains('الفاتورة المبدئية') || remarks.contains('Proforma invoice approved')) {
      return l.proformaInvoiceApprovedRemark;
    }
    if (remarks.contains('محدثة بإجمالي') || remarks.contains('Updated with total weights')) {
      return l.packingListUpdatedRemark;
    }
    if (remarks.contains('توثيق السفارة') || remarks.contains('Embassy and chamber of commerce')) {
      return l.embassyLegalizationRemark;
    }
    if (remarks.contains('فحص ظاهري وعينات المعمل') || remarks.contains('Visual inspection and laboratory')) {
      return l.visualLabInspectionRemark;
    }
    if (remarks.contains('وحدات تحكم لاسلكية') || remarks.contains('wireless remote control')) {
      return l.wirelessModuleRemark;
    }
    return remarks;
  }

  void _onImportFileChanged(int? fileId) {
    setState(() {
      _selectedImportFileId = fileId;
      if (fileId != null) {
        final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
        final file = importFiles.where((f) => f.importFileId == fileId).firstOrNull;
        if (file != null) {
          final fCode = file.customFileNumber ?? file.importFileCode;
          _titleController.text = '[$fCode] ${file.companyName}';

          // Auto-fetch broker from file
          if (file.brokerId != null) {
            _selectedBrokerId = file.brokerId;
            _selectedBrokerName = file.brokerName ?? '';
            final partners = ref.read(partnersProvider).valueOrNull ?? [];
            final bPartner = partners.where((p) => p.providerId == file.brokerId).firstOrNull;
            if (bPartner != null) {
              _brokerContactPerson = bPartner.contactPerson;
            }
            _loadBrokerPriceList(file.brokerId!);
          }
          if (file.poIds != null && file.poIds!.isNotEmpty) {
            _selectedPoId = file.poIds!.first;
          }
          if (file.projectIds.isNotEmpty) {
            _selectedProjectId = file.projectIds.first;
          }

          // ── Auto-fetch Currency & Exchange Rate ──────────────────────
          final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
          final currencies = ref.read(currenciesProvider).valueOrNull ?? [];

          final matchingPOs = allPOs.where((p) =>
              (p.importFileId != null && p.importFileId == file.importFileId) ||
              (file.importFileCode.isNotEmpty && p.importFileCode != null && p.importFileCode == file.importFileCode) ||
              (file.poIds != null && p.poId != null && file.poIds!.contains(p.poId))).toList();

          String? detectedCurrency;

          // 1. Try matching POs first (PO currency_id or currency_code)
          for (final po in matchingPOs) {
            if (po.currencyId > 0) {
              final c = currencies.where((c) => c.currencyId == po.currencyId).firstOrNull;
              if (c != null && c.currencyCode.isNotEmpty) {
                detectedCurrency = c.currencyCode;
                break;
              }
            }
            if (po.currencyCode != null && po.currencyCode!.isNotEmpty) {
              detectedCurrency = po.currencyCode;
              break;
            }
          }

          // 2. Fallback to Import File's primary invoice currency
          if (detectedCurrency == null || detectedCurrency.isEmpty) {
            if (file.invoicesData.isNotEmpty) {
              final firstInv = file.invoicesData.first;
              if (firstInv.currency.isNotEmpty) {
                detectedCurrency = firstInv.currency;
              }
            } else if (file.estimatedCostCurrency.isNotEmpty) {
              detectedCurrency = file.estimatedCostCurrency;
            }
          }

          // 3. Fallback to latest Customs Declaration rate currency or default USD
          detectedCurrency ??= 'USD';

          _customsCurrency = detectedCurrency;
          _updateExchangeRateForCurrency(detectedCurrency);

          // 4. Also try auto-fetching ocean freight from shipping scenarios
          _autoFetchFreightFromScenarios(fileId);
        }
      } else {
        _selectedBrokerId = null;
        _selectedBrokerName = '';
        _brokerContactPerson = null;
        _brokerPriceListId = null;
        _brokerQuoteItems.clear();
      }
    });

    _autoCalculateDutiesFromImportFile();
  }

  void _autoCalculateDutiesFromImportFile() {
    final calcLines = _calculateCustomsLines();
    final double totalTaxes = calcLines.fold(0.0, (s, l) => s + l.totalTaxesAndDutiesEgp);
    if (totalTaxes > 0) {
      _estimatedDutiesController.text = totalTaxes.toStringAsFixed(2);
    }
  }

  void _updateExchangeRateForCurrency(String currencyCode) {
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final matchedCurrency = currencies
        .where((c) => c.currencyCode.toUpperCase() == currencyCode.toUpperCase())
        .firstOrNull;
    if (matchedCurrency != null) {
      final rate = matchedCurrency.latestCustomsRate ??
          matchedCurrency.latestCommercialRate;
      if (rate != null && rate > 0) {
        _exchangeRateController.text = rate.toStringAsFixed(4);
      }
    }
  }

  void _updateFreightExchangeRateForCurrency(String currencyCode) {
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final matchedCurrency = currencies
        .where((c) => c.currencyCode.toUpperCase() == currencyCode.toUpperCase())
        .firstOrNull;
    if (matchedCurrency != null) {
      final rate = matchedCurrency.latestCustomsRate ??
          matchedCurrency.latestCommercialRate;
      if (rate != null && rate > 0) {
        _freightExchangeRateController.text = rate.toStringAsFixed(4);
      }
    }
    _recalculateFreightEgp();
  }

  void _recalculateFreightEgp() {
    final foreignAmt = double.tryParse(_freightForeignController.text.trim()) ?? 0.0;
    final rate = double.tryParse(_freightExchangeRateController.text.trim()) ?? 0.0;
    if (foreignAmt > 0 && rate > 0) {
      _freightEgpController.text = (foreignAmt * rate).toStringAsFixed(2);
    }
  }

  /// Finds the highest totalQuotationAmount across all shipping scenario items
  /// linked to [fileId], converts it to EGP using the customs exchange rate,
  /// and auto-populates the freight field.
  void _autoFetchFreightFromScenarios(int fileId) {
    final allSessions = ref.read(shippingScenariosProvider).sessions;
    final linkedSessions =
        allSessions.where((s) => s.importFileId == fileId).toList();
    if (linkedSessions.isEmpty) return;

    double highestQuotation = 0.0;
    String highestCurrency = 'USD';
    for (final session in linkedSessions) {
      for (final item in session.items) {
        if (item.totalQuotationAmount > highestQuotation) {
          highestQuotation = item.totalQuotationAmount;
          highestCurrency = item.quotationCurrency;
        }
      }
    }
    if (highestQuotation <= 0) return;

    // Convert to EGP using the customs exchange rate
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final matchedCurrency =
        currencies.where((c) => c.currencyCode == highestCurrency).firstOrNull;
    final rate = matchedCurrency?.latestCustomsRate ??
        (double.tryParse(_exchangeRateController.text) ?? 50.0);
    final freightEgp = highestQuotation * rate;

    setState(() {
      _freightForeignController.text = highestQuotation.toStringAsFixed(2);
      _freightCurrency = highestCurrency;
      _freightExchangeRateController.text = rate.toStringAsFixed(4);
      _freightEgpController.text = freightEgp.toStringAsFixed(2);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.freightAutoFetchedDetailsToast(
              highestQuotation.toStringAsFixed(2),
              highestCurrency,
              rate.toStringAsFixed(4),
              freightEgp.toStringAsFixed(2),
            ),
          ),
          backgroundColor: AppTheme.cobalt,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _syncHsRequirementsToChecklist({bool silent = false}) {
    final calcLines = _calculateCustomsLines();
    if (calcLines.isEmpty) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.noPoItemsFoundForFileToast),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // ── Consolidate: group all HS Codes by document type ────────────────
    // One checklist item per document type, listing unique HS Codes inside.
    final acidHsCodes =
        calcLines.where((l) => l.requiresAcid).map((l) => l.hsCode).toSet().toList();
    final cooHsCodes =
        calcLines.where((l) => l.requiresCoo).map((l) => l.hsCode).toSet().toList();
    final goeicHsCodes =
        calcLines.where((l) => l.requiresInspection).map((l) => l.hsCode).toSet().toList();

    // Group unique HS Codes per regulatory authority
    final Map<String, Set<String>> authHsMap = {};
    for (final line in calcLines) {
      if (line.regulatoryAuthority != null &&
          line.regulatoryAuthority!.trim().isNotEmpty) {
        authHsMap
            .putIfAbsent(line.regulatoryAuthority!, () => <String>{})
            .add(line.hsCode);
      }
    }

    int addedCount = 0;

    // Helper to format HS Codes nicely for display
    String formatHsCodeList(List<String> list) {
      if (list.isEmpty) return '';
      if (list.length <= 2) return list.join(' | ');
      return '${list.take(2).join(" | ")} (+${list.length - 2})';
    }

    // 1. ACID — one consolidated item for the entire shipment
    if (acidHsCodes.isNotEmpty) {
      const docName = 'Advance ACID Filing (Nafeza / CargoX)';
      final hasExisting = _checklist.any((c) => c.documentType.contains('ACID'));
      if (!hasExisting) {
        _checklist.add(CustomsChecklistItemModel(
          documentType: docName,
          hsCode: formatHsCodeList(acidHsCodes),
          isRequired: true,
          isBlockingShipment: true,
          responsibleParty: 'Importer Team',
          regulatoryAgency: 'Nafeza / CargoX',
          status: 'Approved',
          remarks:
              'يشمل بنود: ${acidHsCodes.join(" ، ")} — رقم القيد الجمركي المبدئي إلزامي لإصدار بوليصة الشحن.',
        ));
        addedCount++;
      }
    }

    // 2. COO — one consolidated item for the entire shipment
    if (cooHsCodes.isNotEmpty) {
      const docName = 'Certificate of Origin (COO)';
      final hasExisting = _checklist.any((c) => c.documentType.contains('COO') || c.documentType.contains('شهادة المنشأ'));
      if (!hasExisting) {
        _checklist.add(CustomsChecklistItemModel(
          documentType: docName,
          hsCode: formatHsCodeList(cooHsCodes),
          isRequired: true,
          isBlockingShipment: true,
          responsibleParty: 'Supplier / Exporter',
          regulatoryAgency: 'Chamber of Commerce / Embassy',
          status: 'Pending',
          remarks:
              'يشمل بنود: ${cooHsCodes.join(" ، ")} — شهادة منشأ واحدة لكامل الشحنة، تصدر من الغرفة التجارية وتُوثق بالسفارة المصرية.',
        ));
        addedCount++;
      }
    }

    // 3. GOEIC — one consolidated item for the entire shipment
    if (goeicHsCodes.isNotEmpty) {
      const docName = 'GOEIC Inspection';
      final hasExisting = _checklist.any((c) => c.documentType.contains('GOEIC') || c.documentType.contains('الصادرات والواردات'));
      if (!hasExisting) {
        _checklist.add(CustomsChecklistItemModel(
          documentType: docName,
          hsCode: formatHsCodeList(goeicHsCodes),
          isRequired: true,
          isBlockingShipment: true,
          responsibleParty: 'Customs Broker',
          regulatoryAgency: 'GOEIC',
          status: 'Pending',
          remarks:
              'يشمل بنود: ${goeicHsCodes.join(" ، ")} — فحص ظاهري وسحب عينات معمل لكامل الشحنة.',
        ));
        addedCount++;
      }
    }

    // 4. Per regulatory authority — one consolidated item per authority
    for (final entry in authHsMap.entries) {
      final authority = entry.key;
      final hsList = entry.value.toList();
      final docName = 'Prior Technical Approval from $authority';
      final hasExisting = _checklist.any((c) => c.documentType == docName || c.documentType == 'موافقة $authority الفنية المسبقة');
      if (!hasExisting) {
        final priorNote = calcLines
            .where((l) => l.regulatoryAuthority == authority)
            .map((l) => l.priorApprovalNote)
            .where((n) => n != null)
            .firstOrNull;
        _checklist.add(CustomsChecklistItemModel(
          documentType: docName,
          hsCode: formatHsCodeList(hsList),
          isRequired: true,
          isBlockingShipment: true,
          responsibleParty: 'Importer Team',
          regulatoryAgency: authority,
          status: 'Pending',
          remarks:
              'يشمل بنود: ${hsList.join(" ، ")} — ${priorNote ?? "يتطلب موافقة فنية مسبقة واستخراج تصريح الإفراج الجمركي."}',
        ));
        addedCount++;
      }
    }

    // Recalculate estimated duties and update field
    final grandTotal =
        calcLines.fold(0.0, (s, l) => s + l.totalTaxesAndDutiesEgp);
    _estimatedDutiesController.text = grandTotal.toStringAsFixed(2);

    setState(() {});

    if (!silent && mounted) {
      final l = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${l.hsRequirementsSyncedToast(calcLines.length, addedCount)}',
          ),
          backgroundColor: AppTheme.emerald,
        ),
      );
    }
  }

  Future<void> _fetchReconciledFinalInvoiceAndRecalculate() async {
    final l = context.l10n;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${l.selectImportFileFirstToast}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isRecalculating = true);
    try {
      final fx = double.tryParse(_exchangeRateController.text.trim());
      final freight = double.tryParse(_freightEgpController.text.trim());
      final ins = double.tryParse(_insuranceEgpController.text.trim());
      final dateStr = '${_studyDate.year}-${_studyDate.month.toString().padLeft(2, '0')}-${_studyDate.day.toString().padLeft(2, '0')}';

      final res = await ref.read(customsConsultationsProvider.notifier).recalculateFromReconciliation(
        importFileId: _selectedImportFileId!,
        exchangeRate: fx,
        freightEgp: freight,
        insuranceEgp: ins,
        estimateDate: dateStr,
      );

      setState(() {
        _recalculationResult = res;
        _isCustomsCalculatorExpanded = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    res.isReconciled
                        ? '✅ (${res.finalInvoiceNumber ?? ""})'
                        : 'ℹ️',
                  ),
                ),
              ],
            ),
            backgroundColor: res.isReconciled ? AppTheme.emerald : AppTheme.cobalt,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecalculating = false);
      }
    }
  }

  void _applyAndSaveRecalculatedFees() {
    if (_recalculationResult == null) return;
    setState(() {
      _estimatedDutiesController.text = _recalculationResult!.finalTotalTaxesEgp.toStringAsFixed(2);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.recalculatedTaxesAppliedToast(
            _recalculationResult!.finalTotalTaxesEgp.toStringAsFixed(2),
          ),
        ),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  List<CustomsItemCalcRow> _calculateCustomsLines() {
    final loc = context.l10n;
    final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final tariffsList = ref.watch(customsTariffProvider).valueOrNull ?? [];

    ImportFileModel? file;
    List<PurchaseOrderModel> matchingPOs = [];
    if (_selectedImportFileId != null) {
      final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
      file = importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
      if (file != null) {
        matchingPOs = allPOs.where((p) =>
            (p.importFileId != null && p.importFileId == file!.importFileId) ||
            (file!.importFileCode.isNotEmpty && p.importFileCode != null && p.importFileCode == file.importFileCode) ||
            (file.poIds != null && p.poId != null && file.poIds!.contains(p.poId))).toList();
      }
    } else if (_selectedPoId != null) {
      matchingPOs = allPOs.where((p) => p.poId == _selectedPoId).toList();
    }

    final double exchangeRate = double.tryParse(_exchangeRateController.text.trim()) ?? 50.0;
    final double freightForeign = double.tryParse(_freightForeignController.text.trim()) ?? 0.0;
    final double freightFxRate = double.tryParse(_freightExchangeRateController.text.trim()) ?? exchangeRate;
    final double totalFreightEgp = freightForeign > 0
        ? (freightForeign * freightFxRate)
        : (double.tryParse(_freightEgpController.text.trim()) ?? 0.0);

    // 1. Calculate Aggregate Total of ALL Invoices attached to the Import File
    double totalInvoicesForeign = 0.0;
    if (file != null && file.invoicesData.isNotEmpty) {
      for (final inv in file.invoicesData) {
        totalInvoicesForeign += inv.amount;
      }
    }

    // 2. Collect all line items paired with their parent PO
    final List<Map<String, dynamic>> flatLineEntries = [];
    for (final po in matchingPOs) {
      for (final item in po.items) {
        flatLineEntries.add({
          'item': item,
          'po': po,
        });
      }
    }

    // Pre-calculate FOB and Insurance
    final double poItemsFobSum = flatLineEntries.fold(0.0, (s, e) => s + (e['item'] as POLineItemModel).totalPrice);
    final double effectiveFobForeign = totalInvoicesForeign > 0 ? totalInvoicesForeign : poItemsFobSum;
    final double totalFobEgp = effectiveFobForeign * exchangeRate;
    final double candfBaseEgp = totalFobEgp + totalFreightEgp;

    double totalInsuranceEgp = 0.0;
    if (_insuranceOption == '0.5%') {
      totalInsuranceEgp = candfBaseEgp * 0.005;
      final formatted = totalInsuranceEgp.toStringAsFixed(2);
      if (_insuranceEgpController.text != formatted) {
        _insuranceEgpController.text = formatted;
      }
    } else if (_insuranceOption == '1.0%') {
      totalInsuranceEgp = candfBaseEgp * 0.01;
      final formatted = totalInsuranceEgp.toStringAsFixed(2);
      if (_insuranceEgpController.text != formatted) {
        _insuranceEgpController.text = formatted;
      }
    } else {
      totalInsuranceEgp = double.tryParse(_insuranceEgpController.text.trim()) ?? 0.0;
    }

    // Pre-index tariffs for instant O(1) lookups
    final Map<int, CustomsTariffModel> tariffById = {
      for (final t in tariffsList) t.tariffId: t,
    };
    final Map<String, CustomsTariffModel> tariffByNormalizedHs = {
      for (final t in tariffsList) t.hsCode.replaceAll('.', '').trim(): t,
    };

    // Case A: No PO Line items, but Invoices exist on the Import File
    if (flatLineEntries.isEmpty) {
      if (totalInvoicesForeign > 0 && file != null) {
        final List<CustomsItemCalcRow> result = [];
        final int invCount = file.invoicesData.length;
        for (int i = 0; i < invCount; i++) {
          final inv = file.invoicesData[i];
          final double invForeign = inv.amount;
          final double fobEgp = invForeign * exchangeRate;
          final double freightShare = invCount > 0 ? (totalFreightEgp / invCount) : 0.0;
          final double insuranceShare = invCount > 0 ? (totalInsuranceEgp / invCount) : 0.0;
          final double cifEgp = fobEgp + freightShare + insuranceShare;

          const double effectiveDutyRate = 5.0;
          final double dutyAmountEgp = cifEgp * (effectiveDutyRate / 100.0);
          const double vatRate = 14.0;
          final double vatBaseEgp = cifEgp + dutyAmountEgp;
          final double vatAmountEgp = vatBaseEgp * (vatRate / 100.0);
          const double svcRate = 1.0;
          final double svcAmountEgp = cifEgp * (svcRate / 100.0);
          final double totalLineTaxes = dutyAmountEgp + vatAmountEgp + svcAmountEgp;

          result.add(CustomsItemCalcRow(
            hsCode: '8479.89.90',
            description: 'Commercial Invoice #${inv.invoiceNo} (${file.supplierName})',
            qty: 1,
            unit: 'SET',
            foreignPrice: invForeign,
            fobEgp: fobEgp,
            freightEgp: freightShare,
            insuranceEgp: insuranceShare,
            cifEgp: cifEgp,
            dutyRate: effectiveDutyRate,
            baseDutyRate: effectiveDutyRate,
            dutyAmountEgp: dutyAmountEgp,
            vatRate: vatRate,
            vatBaseEgp: vatBaseEgp,
            vatAmountEgp: vatAmountEgp,
            scheduleTaxRate: 0.0,
            scheduleTaxAmountEgp: 0.0,
            developmentFeeRate: 0.0,
            developmentFeeAmountEgp: 0.0,
            customsServiceFeeRate: svcRate,
            customsServiceFeeAmountEgp: svcAmountEgp,
            totalTaxesAndDutiesEgp: totalLineTaxes,
            requiresCoo: true,
            requiresInspection: false,
            requiresAcid: true,
            regulatoryAuthority: null,
            priorApprovalNote: null,
            countryOfOrigin: null,
            appliedAgreementName: null,
            hasExemption: false,
            exemptionConditionsNote: null,
            requiredDocument: null,
          ));
        }
        return result;
      }
      return [];
    }

    // Case B: PO Line items exist -> Scale proportionally to Total Invoices if Invoices exist
    final double scaleFactor = (totalInvoicesForeign > 0 && poItemsFobSum > 0) ? (totalInvoicesForeign / poItemsFobSum) : 1.0;

    // Known Agreement Origin Sets
    const euCountries = {
      'DE', 'FR', 'IT', 'ES', 'NL', 'BE', 'AT', 'PL', 'SE', 'DK',
      'FI', 'IE', 'PT', 'GR', 'CZ', 'HU', 'RO', 'BG', 'SK', 'HR',
      'SI', 'LT', 'LV', 'EE', 'CY', 'MT', 'LU'
    };
    const mercosurCountries = {'BR', 'AR', 'UY', 'PY'};
    const gaftaCountries = {
      'SA', 'AE', 'JO', 'KW', 'OM', 'QA', 'BH', 'LB', 'IQ', 'SY',
      'YE', 'SD', 'LY', 'TN', 'DZ', 'MA', 'PS', 'EG'
    };

    final List<CustomsItemCalcRow> result = [];
    for (final entry in flatLineEntries) {
      final POLineItemModel l = entry['item'] as POLineItemModel;
      final PurchaseOrderModel po = entry['po'] as PurchaseOrderModel;
      final hs = (l.hsCode != null && l.hsCode!.trim().isNotEmpty) ? l.hsCode!.trim() : 'UNASSIGNED';
      
      // Match tariff via O(1) lookup
      CustomsTariffModel? matchedTariff;
      if (l.tariffId != null) {
        matchedTariff = tariffById[l.tariffId];
      }
      if (matchedTariff == null && hs != 'UNASSIGNED') {
        matchedTariff = tariffByNormalizedHs[hs.replaceAll('.', '').trim()];
      }

      // Country of origin resolution
      final String rawOrigin = (l.countryOfOrigin != null && l.countryOfOrigin!.trim().isNotEmpty)
          ? l.countryOfOrigin!.trim()
          : (po.countryOfOrigin != null && po.countryOfOrigin!.trim().isNotEmpty ? po.countryOfOrigin!.trim() : '');

      String originCode = '';
      if (rawOrigin.isNotEmpty) {
        if (rawOrigin.contains(' - ')) {
          originCode = rawOrigin.split(' - ').first.trim().toUpperCase();
        } else if (rawOrigin.length >= 2) {
          originCode = rawOrigin.substring(0, 2).toUpperCase();
        } else {
          originCode = rawOrigin.toUpperCase();
        }
      }

      final double baseDutyRate = matchedTariff?.customsDutyRate ?? (l.dutyRate ?? 5.0);
      double effectiveDutyRate = baseDutyRate;
      bool hasExemption = false;
      String? appliedAgreementName;
      String? requiredDocument;
      String? exemptionConditionsNote;

      if (originCode.isNotEmpty) {
        if (euCountries.contains(originCode)) {
          hasExemption = true;
          appliedAgreementName = loc.agreementEur1;
          requiredDocument = loc.agreementEur1Doc;
          effectiveDutyRate = 0.0;
          exemptionConditionsNote = loc.agreementEur1Exemption(baseDutyRate);
        } else if (mercosurCountries.contains(originCode)) {
          hasExemption = true;
          appliedAgreementName = loc.agreementMercosur;
          requiredDocument = loc.agreementMercosurDoc;
          effectiveDutyRate = 0.0;
          exemptionConditionsNote = loc.agreementMercosurExemption(baseDutyRate);
        } else if (gaftaCountries.contains(originCode)) {
          hasExemption = true;
          appliedAgreementName = loc.agreementGafta;
          requiredDocument = loc.agreementGaftaDoc;
          effectiveDutyRate = 0.0;
          exemptionConditionsNote = loc.agreementGaftaExemption(baseDutyRate);
        } else if (originCode == 'TR') {
          hasExemption = true;
          appliedAgreementName = loc.agreementTurkey;
          requiredDocument = loc.agreementTurkeyDoc;
          effectiveDutyRate = 0.0;
          exemptionConditionsNote = loc.agreementTurkeyExemption(baseDutyRate);
        } else if (originCode == 'GB' || originCode == 'UK') {
          hasExemption = true;
          appliedAgreementName = loc.agreementUk;
          requiredDocument = loc.agreementUkDoc;
          effectiveDutyRate = 0.0;
          exemptionConditionsNote = loc.agreementUkExemption(baseDutyRate);
        }
      }

      final double vatRate = matchedTariff?.vatRate ?? (l.vatRate ?? 14.0);
      final double scheduleTaxRate = matchedTariff?.scheduleTaxRate ?? 0.0;
      final double devRate = matchedTariff?.developmentFeeRate ?? 0.0;
      final double svcRate = matchedTariff?.customsServiceFeeRate ?? 1.0;

      final double lineForeignPrice = l.totalPrice * scaleFactor;
      final double fobEgp = lineForeignPrice * exchangeRate;
      final double freightShare = totalFobEgp > 0 ? (fobEgp / totalFobEgp * totalFreightEgp) : 0.0;
      final double insuranceShare = totalFobEgp > 0 ? (fobEgp / totalFobEgp * totalInsuranceEgp) : 0.0;
      final double cifEgp = fobEgp + freightShare + insuranceShare;

      final double dutyAmountEgp = cifEgp * (effectiveDutyRate / 100.0);
      final double vatBaseEgp = cifEgp + dutyAmountEgp;
      final double vatAmountEgp = vatBaseEgp * (vatRate / 100.0);
      final double scheduleTaxAmountEgp = cifEgp * (scheduleTaxRate / 100.0);
      final double devFeeAmountEgp = cifEgp * (devRate / 100.0);
      final double svcAmountEgp = cifEgp * (svcRate / 100.0);

      final double totalLineTaxes = dutyAmountEgp + vatAmountEgp + scheduleTaxAmountEgp + devFeeAmountEgp + svcAmountEgp;

      result.add(CustomsItemCalcRow(
        hsCode: hs,
        description: l.descriptionAr.isNotEmpty ? l.descriptionAr : (matchedTariff?.hsDescription ?? loc.defaultImportItemDescription),
        qty: l.quantity,
        unit: l.unitOfMeasure,
        foreignPrice: lineForeignPrice,
        fobEgp: fobEgp,
        freightEgp: freightShare,
        insuranceEgp: insuranceShare,
        cifEgp: cifEgp,
        dutyRate: effectiveDutyRate,
        baseDutyRate: baseDutyRate,
        dutyAmountEgp: dutyAmountEgp,
        vatRate: vatRate,
        vatBaseEgp: vatBaseEgp,
        vatAmountEgp: vatAmountEgp,
        scheduleTaxRate: scheduleTaxRate,
        scheduleTaxAmountEgp: scheduleTaxAmountEgp,
        developmentFeeRate: devRate,
        developmentFeeAmountEgp: devFeeAmountEgp,
        customsServiceFeeRate: svcRate,
        customsServiceFeeAmountEgp: svcAmountEgp,
        totalTaxesAndDutiesEgp: totalLineTaxes,
        requiresCoo: matchedTariff?.requiresCoo ?? true,
        requiresInspection: matchedTariff?.requiresInspection ?? false,
        requiresAcid: matchedTariff?.requiresAcid ?? true,
        regulatoryAuthority: matchedTariff?.regulatoryAuthority,
        priorApprovalNote: matchedTariff?.priorApprovalNote,
        countryOfOrigin: rawOrigin.isNotEmpty ? rawOrigin : null,
        appliedAgreementName: appliedAgreementName,
        hasExemption: hasExemption,
        exemptionConditionsNote: exemptionConditionsNote,
        requiredDocument: requiredDocument,
      ));
    }

    return result;
  }

  List<CustomsItemCalcRow> _getAggregatedCustomsLines(List<CustomsItemCalcRow> rawLines) {
    if (!_groupByHsCode) return rawLines;

    final Map<String, List<CustomsItemCalcRow>> grouped = {};
    for (final line in rawLines) {
      grouped.putIfAbsent(line.hsCode, () => []).add(line);
    }

    final List<CustomsItemCalcRow> aggregated = [];
    for (final entry in grouped.entries) {
      final hs = entry.key;
      final lines = entry.value;
      if (lines.length == 1) {
        aggregated.add(lines.first);
        continue;
      }

      // Merge descriptions cleanly
      final distinctDescriptions = lines.map((l) => l.description.trim()).toSet().toList();
      final String mergedDesc = distinctDescriptions.length == 1
          ? distinctDescriptions.first
          : distinctDescriptions.join(' • ');

      final double totalQty = lines.fold(0.0, (s, l) => s + l.qty);
      final String unit = lines.first.unit;
      final double totalForeignPrice = lines.fold(0.0, (s, l) => s + l.foreignPrice);
      final double totalFobEgp = lines.fold(0.0, (s, l) => s + l.fobEgp);
      final double totalFreightEgp = lines.fold(0.0, (s, l) => s + l.freightEgp);
      final double totalInsuranceEgp = lines.fold(0.0, (s, l) => s + l.insuranceEgp);
      final double totalCifEgp = lines.fold(0.0, (s, l) => s + l.cifEgp);
      
      final first = lines.first;
      final double totalDutyAmountEgp = lines.fold(0.0, (s, l) => s + l.dutyAmountEgp);
      final double totalVatBaseEgp = lines.fold(0.0, (s, l) => s + l.vatBaseEgp);
      final double totalVatAmountEgp = lines.fold(0.0, (s, l) => s + l.vatAmountEgp);
      final double totalScheduleTaxAmountEgp = lines.fold(0.0, (s, l) => s + l.scheduleTaxAmountEgp);
      final double totalDevFeeAmountEgp = lines.fold(0.0, (s, l) => s + l.developmentFeeAmountEgp);
      final double totalSvcAmountEgp = lines.fold(0.0, (s, l) => s + l.customsServiceFeeAmountEgp);
      final double totalTaxes = lines.fold(0.0, (s, l) => s + l.totalTaxesAndDutiesEgp);

      final distinctOrigins = lines
          .map((l) => l.countryOfOrigin)
          .where((o) => o != null && o.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      aggregated.add(CustomsItemCalcRow(
        hsCode: hs,
        description: mergedDesc,
        qty: totalQty,
        unit: unit,
        foreignPrice: totalForeignPrice,
        fobEgp: totalFobEgp,
        freightEgp: totalFreightEgp,
        insuranceEgp: totalInsuranceEgp,
        cifEgp: totalCifEgp,
        dutyRate: first.dutyRate,
        baseDutyRate: first.baseDutyRate,
        dutyAmountEgp: totalDutyAmountEgp,
        vatRate: first.vatRate,
        vatBaseEgp: totalVatBaseEgp,
        vatAmountEgp: totalVatAmountEgp,
        scheduleTaxRate: first.scheduleTaxRate,
        scheduleTaxAmountEgp: totalScheduleTaxAmountEgp,
        developmentFeeRate: first.developmentFeeRate,
        developmentFeeAmountEgp: totalDevFeeAmountEgp,
        customsServiceFeeRate: first.customsServiceFeeRate,
        customsServiceFeeAmountEgp: totalSvcAmountEgp,
        totalTaxesAndDutiesEgp: totalTaxes,
        requiresCoo: lines.any((l) => l.requiresCoo),
        requiresInspection: lines.any((l) => l.requiresInspection),
        requiresAcid: lines.any((l) => l.requiresAcid),
        regulatoryAuthority: first.regulatoryAuthority,
        priorApprovalNote: first.priorApprovalNote,
        countryOfOrigin: distinctOrigins.isNotEmpty ? distinctOrigins.join(' / ') : null,
        appliedAgreementName: first.appliedAgreementName,
        hasExemption: lines.any((l) => l.hasExemption),
        exemptionConditionsNote: first.exemptionConditionsNote,
        requiredDocument: first.requiredDocument,
      ));
    }
    return aggregated;
  }

  void _addChecklistItem() {
    showDialog(
      context: context,
      builder: (context) => AddChecklistItemDialog(
        onItemAdded: (item) {
          setState(() => _checklist.add(item));
        },
      ),
    );
  }

  void _loadConsultationForEdit(CustomsConsultationModel session) {
    setState(() {
      _editingConsultationId = session.consultationId;
      _editingConsultationCode = session.consultationCode;
      _titleController.text = session.title;
      _selectedBrokerId = session.brokerId;
      _selectedBrokerName = session.brokerName;
      _brokerContactPerson = session.brokerContactPerson;
      _selectedImportFileId = session.importFileId;
      _selectedPoId = session.poId;
      _selectedProjectId = session.projectId;
      _estimatedDutiesController.text = session.estimatedDutiesEgp.toStringAsFixed(2);
      _notesController.text = session.notes ?? '';
      _checklist.clear();
      _checklist.addAll(session.checklistItems);
      _brokerQuoteItems.clear();
      _brokerQuoteItems.addAll(session.brokerQuoteItems.map((q) => q.copyWith()));
      _brokerPriceListId = session.brokerPriceListId;
      final priceLists = ref.read(brokerPriceListsProvider).valueOrNull ?? [];
      final matchedPl = priceLists.where((pl) => pl.priceListId == session.brokerPriceListId).firstOrNull;
      _brokerPriceListTitle = matchedPl?.title;
      _visitedTabs.add(0);
      _tabController.animateTo(0);
    });
  }


  Future<void> _loadBrokerPriceList(int brokerId, {bool preserveExisting = false}) async {
    if (preserveExisting && _brokerQuoteItems.isNotEmpty) return;

    setState(() => _isLoadingPriceList = true);
    try {
      final activePl = await ref
          .read(brokerPriceListsProvider.notifier)
          .getActivePriceListForBroker(brokerId);

      if (!mounted) return;
      if (activePl != null && activePl.items.isNotEmpty) {
        setState(() {
          _brokerPriceListId = activePl.priceListId;
          _brokerPriceListTitle = activePl.title;
          _brokerQuoteItems.clear();
          for (final itm in activePl.items) {
            final isApplicable = itm.standardPrice > 0;
            _brokerQuoteItems.add(CustomsBrokerQuoteItemModel(
              expenseTypeId: itm.expenseTypeId,
              expenseName: itm.expenseName,
              category: itm.category,
              unitType: itm.unitType,
              unitPrice: itm.standardPrice,
              currency: itm.currency,
              qty: 1.0,
              isApplicable: isApplicable,
              totalAmount: isApplicable ? (itm.standardPrice * 1.0) : 0.0,
              notes: itm.notes,
            ));
          }
        });
      } else {
        // Fallback to Master Expense Catalog
        final catalog = ref.read(clearanceExpenseTypesProvider).valueOrNull ?? [];
        setState(() {
          _brokerPriceListId = null;
          _brokerPriceListTitle = storedText.customPriceListNoRegisteredTitle;
          _brokerQuoteItems.clear();
          for (final exp in catalog) {
            _brokerQuoteItems.add(CustomsBrokerQuoteItemModel(
              expenseTypeId: exp.expenseId,
              expenseName: exp.nameAr,
              // Quote items keep English category/unit names; the catalog stores codes.
              category: DomainEnums.isCode(DomainEnumType.brokerExpenseCategory, exp.category)
                  ? DomainEnums.englishLabel(DomainEnumType.brokerExpenseCategory, exp.category)
                  : exp.category,
              unitType: DomainEnums.isCode(DomainEnumType.brokerUnit, exp.defaultUnit)
                  ? DomainEnums.englishLabel(DomainEnumType.brokerUnit, exp.defaultUnit)
                  : exp.defaultUnit,
              unitPrice: 0.0, // defaults to 0.0 as requested
              currency: exp.defaultCurrency,
              qty: 1.0,
              isApplicable: false,
              totalAmount: 0.0,
            ));
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading broker price list: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPriceList = false);
    }
  }

  void _updateBrokerQuoteItem(int index, CustomsBrokerQuoteItemModel updated) {
    setState(() {
      final lineTotal = updated.isApplicable ? (updated.unitPrice * updated.qty) : 0.0;
      _brokerQuoteItems[index] = updated.copyWith(totalAmount: lineTotal);
    });
  }

  void _addCustomBrokerExpenseRow() {
    showDialog(
      context: context,
      builder: (ctx) => AddCustomExpenseDialog(
        onExpenseAdded: (item) {
          setState(() => _brokerQuoteItems.add(item));
        },
      ),
    );
  }

  void _applyExtractedQuotationToConsultation(Map<String, dynamic> extracted) {
    final l = context.l10n;
    setState(() {
      // 1. Try to match and select broker if name matches partners
      final brokerName = extracted['broker_name']?.toString().toLowerCase() ?? '';
      if (brokerName.isNotEmpty) {
        final partners = ref.read(partnersProvider).valueOrNull ?? [];
        final matchedPartner = partners.where((p) =>
            p.partnerName.toLowerCase().contains(brokerName) ||
            brokerName.contains(p.partnerName.toLowerCase())).firstOrNull;
        if (matchedPartner != null) {
          _selectedBrokerId = matchedPartner.partnerId;
          _selectedBrokerName = matchedPartner.partnerName;
        }
      }

      // 2. Add or update items in _brokerQuoteItems
      void upsertQuoteItem(String name, String category, double amount, {String currency = 'EGP'}) {
        if (amount <= 0) return;
        final existingIdx = _brokerQuoteItems.indexWhere((i) =>
            i.expenseName.toLowerCase().trim() == name.toLowerCase().trim() ||
            i.category.toLowerCase().trim() == category.toLowerCase().trim());
        if (existingIdx != -1) {
          final itm = _brokerQuoteItems[existingIdx];
          _brokerQuoteItems[existingIdx] = itm.copyWith(
            unitPrice: amount,
            currency: currency,
            qty: 1.0,
            isApplicable: true,
            totalAmount: amount,
          );
        } else {
          _brokerQuoteItems.insert(0, CustomsBrokerQuoteItemModel(
            expenseName: name,
            category: category,
            unitType: 'Fixed',
            unitPrice: amount,
            currency: currency,
            qty: 1.0,
            isApplicable: true,
            totalAmount: amount,
          ));
        }
      }

      // 3. Process dynamic expenses_catalog from AI extractor
      if (extracted['expenses_catalog'] is List && (extracted['expenses_catalog'] as List).isNotEmpty) {
        for (final item in (extracted['expenses_catalog'] as List)) {
          if (item is Map) {
            final name = item['expense_name']?.toString() ?? '';
            final cat = item['category']?.toString() ?? 'Other Fees';
            final amt = (item['amount'] is num) ? (item['amount'] as num).toDouble() : (double.tryParse(item['amount']?.toString() ?? '') ?? 0.0);
            final curr = item['currency']?.toString() ?? 'EGP';
            if (name.isNotEmpty && amt > 0) {
              upsertQuoteItem(name, cat, amt, currency: curr);
            }
          }
        }
      }

      final clearanceFee = (extracted['clearance_fee'] is num) ? (extracted['clearance_fee'] as num).toDouble() : (double.tryParse(extracted['clearance_fee']?.toString() ?? '') ?? 0.0);
      final inlandFee = (extracted['inland_transport_fee'] is num) ? (extracted['inland_transport_fee'] as num).toDouble() : (double.tryParse(extracted['inland_transport_fee']?.toString() ?? '') ?? 0.0);
      final inspectionFee = (extracted['inspection_fee'] is num) ? (extracted['inspection_fee'] as num).toDouble() : (double.tryParse(extracted['inspection_fee']?.toString() ?? '') ?? 0.0);
      final portExp = (extracted['port_expenses'] is num) ? (extracted['port_expenses'] as num).toDouble() : (double.tryParse(extracted['port_expenses']?.toString() ?? '') ?? 0.0);
      final miscFee = (extracted['miscellaneous_fee'] is num) ? (extracted['miscellaneous_fee'] as num).toDouble() : (double.tryParse(extracted['miscellaneous_fee']?.toString() ?? '') ?? 0.0);

      if (clearanceFee > 0) upsertQuoteItem('Clearance Fees', 'Clearance Agency Fees', clearanceFee);
      if (inlandFee > 0) upsertQuoteItem('Inland Transport', 'Inland Transportation', inlandFee);
      if (inspectionFee > 0) upsertQuoteItem('Customs Inspection', 'Customs Inspection', inspectionFee);
      if (portExp > 0) upsertQuoteItem('Port & Handling', 'Port & Terminal', portExp);
      if (miscFee > 0) upsertQuoteItem('Other Fees', 'Miscellaneous', miscFee);

      // Auto-expand broker quote details card to show extracted expenses immediately
      _isBrokerQuoteExpanded = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✔ ${l.brokerQuoteExtractedToast(extracted['broker_name'] ?? l.defaultCustomsBrokerName)}'),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  Future<void> _copyCustomsStudyTsv(List<CustomsItemCalcRow> calcLines) async {
    await CustomsExportService.exportCustomsLinesTsv(
      context: context,
      calcLines: calcLines,
      currency: _customsCurrency,
    );
  }

  Future<void> _exportCustomsStudyExcel(
    List<CustomsItemCalcRow> calcLines,
    double totalFreightEgp,
    double totalInsuranceEgp,
    double exchangeRate,
  ) async {
    final nafezaResult = CustomsExportService.computeNafezaFeeBreakdown(
      totalDutyEgp: calcLines.fold(0.0, (s, l) => s + l.dutyAmountEgp),
      totalVatEgp: calcLines.fold(0.0, (s, l) => s + l.vatAmountEgp),
      totalServiceFeeEgp: calcLines.fold(0.0, (s, l) => s + l.customsServiceFeeAmountEgp),
      totalScheduleTaxEgp: calcLines.fold(0.0, (s, l) => s + l.scheduleTaxAmountEgp),
    );
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final savedFile = await CustomsExportService.exportCustomsStudyToExcel(
      context: context,
      title: _titleController.text.trim(),
      importFileCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : null,
      brokerName: _selectedBrokerName.isNotEmpty ? _selectedBrokerName : (isArabic ? 'مكتب تخليص' : 'Customs Broker'),
      currency: _customsCurrency,
      exchangeRate: exchangeRate,
      totalFreightEgp: totalFreightEgp,
      totalInsuranceEgp: totalInsuranceEgp,
      calcLines: calcLines,
      nafezaResult: nafezaResult,
      brokerQuoteItems: _brokerQuoteItems,
    );
    if (savedFile != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ $savedFile'), backgroundColor: AppTheme.emerald),
      );
    }
  }

  Future<void> _printOrSaveCustomsStudyPdf(
    List<CustomsItemCalcRow> calcLines,
    double totalFreightEgp,
    double totalInsuranceEgp,
    double exchangeRate,
  ) async {
    final nafezaResult = CustomsExportService.computeNafezaFeeBreakdown(
      totalDutyEgp: calcLines.fold(0.0, (s, l) => s + l.dutyAmountEgp),
      totalVatEgp: calcLines.fold(0.0, (s, l) => s + l.vatAmountEgp),
      totalServiceFeeEgp: calcLines.fold(0.0, (s, l) => s + l.customsServiceFeeAmountEgp),
      totalScheduleTaxEgp: calcLines.fold(0.0, (s, l) => s + l.scheduleTaxAmountEgp),
    );
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    await CustomsConsultationPdfService.printOrPreviewCalculationReportPdf(
      context: context,
      title: _titleController.text.trim(),
      importFileCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : null,
      brokerName: _selectedBrokerName.isNotEmpty ? _selectedBrokerName : (isArabic ? 'مكتب تخليص' : 'Customs Broker'),
      currency: _customsCurrency,
      exchangeRate: exchangeRate,
      totalFreightEgp: totalFreightEgp,
      totalInsuranceEgp: totalInsuranceEgp,
      calcLines: calcLines,
      nafezaResult: nafezaResult,
      brokerQuoteItems: _brokerQuoteItems,
      checklist: _checklist,
    );
  }

  Future<void> _copyCustomsStudyDossier(
    List<CustomsItemCalcRow> calcLines,
    double totalFreightEgp,
    double totalInsuranceEgp,
    double exchangeRate,
  ) async {
    final nafezaResult = CustomsExportService.computeNafezaFeeBreakdown(
      totalDutyEgp: calcLines.fold(0.0, (s, l) => s + l.dutyAmountEgp),
      totalVatEgp: calcLines.fold(0.0, (s, l) => s + l.vatAmountEgp),
      totalServiceFeeEgp: calcLines.fold(0.0, (s, l) => s + l.customsServiceFeeAmountEgp),
      totalScheduleTaxEgp: calcLines.fold(0.0, (s, l) => s + l.scheduleTaxAmountEgp),
    );
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    await CustomsExportService.copyCustomsDutyDossier(
      context: context,
      title: _titleController.text.trim(),
      importFileCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : null,
      brokerName: _selectedBrokerName.isNotEmpty ? _selectedBrokerName : (isArabic ? 'مكتب تخليص' : 'Customs Broker'),
      currency: _customsCurrency,
      exchangeRate: exchangeRate,
      totalFreightEgp: totalFreightEgp,
      totalInsuranceEgp: totalInsuranceEgp,
      calcLines: calcLines,
      nafezaResult: nafezaResult,
    );
  }

  Future<void> _saveConsultation() async {
    final l = context.l10n;
    final validationErrors = <ValidationIssueItem>[];

    final titleToSave = _titleController.text.trim();
    if (titleToSave.isEmpty) {
      validationErrors.add(ValidationIssueItem(
        fieldName: l.consultationTitleFieldValidation,
        issueDescription: l.consultationTitleFieldIssue,
        recommendation: l.consultationTitleFieldRec,
        isBlocking: true,
      ));
    }

    if (!widget.isTaxReviewMode && _selectedBrokerId == null) {
      validationErrors.add(ValidationIssueItem(
        fieldName: l.customsBrokerFieldValidation,
        issueDescription: l.customsBrokerFieldIssue,
        recommendation: l.customsBrokerFieldRec,
        isBlocking: true,
      ));
    }

    if (!widget.isTaxReviewMode && _checklist.isEmpty) {
      validationErrors.add(ValidationIssueItem(
        fieldName: l.checklistFieldValidation,
        issueDescription: l.checklistFieldIssue,
        recommendation: l.checklistFieldRec,
        isBlocking: true,
      ));
    }

    if (validationErrors.isNotEmpty) {
      await showErrorDetailsDialog(
        context,
        title: '⚠️ ${l.customsStudyValidationAlertsTitle}',
        error: l.completeRequiredDataErrorMsg,
        validationIssues: validationErrors,
      );
      return;
    }

    final estimatedDuties = double.tryParse(_estimatedDutiesController.text.trim()) ?? 0.0;
    final totalBrokerFees = widget.isTaxReviewMode ? 0.0 : _brokerQuoteItems.fold(0.0, (sum, itm) => sum + (itm.isApplicable ? itm.totalAmount : 0.0));

    // Change Diff Confirmation Dialog for Edits
    if (_editingConsultationId != null) {
      final oldConsultation = (ref.read(customsConsultationsProvider).valueOrNull ?? [])
          .where((c) => c.consultationId == _editingConsultationId)
          .firstOrNull;

      if (oldConsultation != null) {
        final List<FieldChangeItem> changes = [];

        if (FieldChangeItem.isDifferent(oldConsultation.title, titleToSave)) {
          changes.add(FieldChangeItem(
            section: l.diffSectionGeneralData,
            fieldName: l.titleField,
            oldValue: oldConsultation.title,
            newValue: titleToSave,
          ));
        }

        if (FieldChangeItem.isDifferent(oldConsultation.brokerName, _selectedBrokerName)) {
          changes.add(FieldChangeItem(
            section: l.diffSectionCustomsBroker,
            fieldName: l.customsBrokerFieldValidation,
            oldValue: oldConsultation.brokerName,
            newValue: _selectedBrokerName,
          ));
        }

        if (FieldChangeItem.isDifferent(oldConsultation.estimatedDutiesEgp, estimatedDuties)) {
          changes.add(FieldChangeItem(
            section: l.diffSectionFinancialEstimates,
            fieldName: l.diffFieldEstimatedDuties,
            oldValue: '${oldConsultation.estimatedDutiesEgp.toStringAsFixed(2)} EGP',
            newValue: '${estimatedDuties.toStringAsFixed(2)} EGP',
          ));
        }

        if (FieldChangeItem.isDifferent(oldConsultation.importFileId, _selectedImportFileId)) {
          changes.add(FieldChangeItem(
            section: l.diffSectionOperationalLink,
            fieldName: l.diffFieldLinkedImportFile,
            oldValue: oldConsultation.importFileCode ?? (oldConsultation.importFileId != null ? 'ID: ${oldConsultation.importFileId}' : null),
            newValue: _selectedImportFileId != null ? 'ID: $_selectedImportFileId' : null,
          ));
        }

        if (FieldChangeItem.isDifferent(oldConsultation.checklistItems.length, _checklist.length)) {
          changes.add(FieldChangeItem(
            section: l.diffSectionChecklist,
            fieldName: l.diffFieldTotalChecklistDocs,
            oldValue: '${oldConsultation.checklistItems.length}',
            newValue: '${_checklist.length}',
          ));
        }

        if (changes.isNotEmpty) {
          final confirmed = await showChangeDiffConfirmationDialog(
            context,
            title: l.reviewCustomsStudyDiffTitle,
            itemReference: _editingConsultationCode ?? titleToSave,
            changes: changes,
          );
          if (!confirmed) return;
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'title': titleToSave,
        'broker_id': _selectedBrokerId ?? 1,
        'broker_name': _selectedBrokerName.isNotEmpty ? _selectedBrokerName : 'Customs Review',
        'broker_contact_person': _brokerContactPerson,
        if (_selectedImportFileId != null) 'import_file_id': _selectedImportFileId,
        if (_selectedPoId != null) 'po_id': _selectedPoId,
        if (_selectedProjectId != null) 'project_id': _selectedProjectId,
        'estimated_duties_egp': estimatedDuties,
        'total_broker_fees_egp': totalBrokerFees,
        if (_brokerPriceListId != null && !widget.isTaxReviewMode) 'broker_price_list_id': _brokerPriceListId,
        'notes': _notesController.text.trim(),
        'checklist_items': _checklist.map((item) => item.toJson()).toList(),
        'broker_quote_items': widget.isTaxReviewMode ? [] : _brokerQuoteItems.map((item) => item.toJson()).toList(),
      };

      if (_editingConsultationId != null) {
        final updated = await ref
            .read(customsConsultationsProvider.notifier)
            .updateConsultation(_editingConsultationId!, payload);
        if (mounted && updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ ${l.customsStudyUpdatedSuccess} (${updated.consultationCode})'),
              backgroundColor: AppTheme.emerald,
            ),
          );
          setState(() {
            _editingConsultationId = null;
            _editingConsultationCode = null;
          });
          _tabController.animateTo(1);
          // Show post-save checklist status summary
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) showDialog(context: context, builder: (ctx) => PostSaveStatusDialog(saved: updated));
          });
        }
      } else {
        final created = await ref
            .read(customsConsultationsProvider.notifier)
            .createConsultation(payload);
        if (mounted && created != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ ${l.customsStudySavedSuccess} (${created.consultationCode})'),
              backgroundColor: AppTheme.emerald,
            ),
          );
          _tabController.animateTo(1);
          // Show post-save checklist status summary
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) showDialog(context: context, builder: (ctx) => PostSaveStatusDialog(saved: created));
          });
        }
      }

      // Upstream Notification: Check if linked import file has an existing budget that will be affected
      if (_selectedImportFileId != null && mounted) {
        final budgets = ref.read(importBudgetsProvider).valueOrNull ?? [];
        final linkedBudget = budgets.where((b) => b.importFileId == _selectedImportFileId && b.isActive).firstOrNull;
        if (linkedBudget != null && mounted) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          final warningMsg = isArabic
              ? '⚠️ تنبيه ترابط التكاليف: ملف الاستيراد هذا مرتبط بميزانية تقديرية (${linkedBudget.budgetCode}). تم تحديث مصاريف التخليص الجمركي والرسوم، يُرجى مراجعة وتحديث اعتماد الميزانية لمطابقة التكاليف الحية.'
              : '⚠️ Cost Linkage Alert: This import file is linked to budget (${linkedBudget.budgetCode}). Clearance expenses were updated, please review and update the Budget Approval screen to match live costs.';
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text(warningMsg, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  backgroundColor: AppTheme.orange,
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: isArabic ? 'حسناً' : 'OK',
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        await showErrorDetailsDialog(
          context,
          title: '❌ ${l.unableToSaveCustomsStudy}',
          error: e,
          onRetry: () async {
            await _saveConsultation();
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final egpLabel = isArabic ? 'ج.م' : 'EGP';
    final consultationsState = ref.watch(customsConsultationsProvider);
    final consultationsList = consultationsState.valueOrNull ?? [];
    final partnersState = ref.watch(partnersProvider);
    final partnersList = partnersState.valueOrNull ?? [];
    final brokersList = partnersList.where((p) => p.partnerType.contains('Customs') || p.partnerType.contains('Broker')).toList();
    ref.watch(projectsProvider);
    ref.watch(purchaseOrdersProvider);
    final List<CurrencyModel> currenciesList = ref.watch(currenciesProvider).valueOrNull ?? [];

    // Live Checklist Statistics
    final totalDocs = _checklist.length;
    final approvedDocs = _checklist.where((i) => i.status == 'Approved').length;
    final blockingCount = _checklist.where((i) => i.isBlockingShipment && i.status != 'Approved').length;
    final liveReadinessPct = totalDocs > 0 ? ((approvedDocs / totalDocs) * 100).toInt() : 0;

    // Calculation Lines & Totals
    final rawCalcLines = _calculateCustomsLines();
    final calcLines = _getAggregatedCustomsLines(rawCalcLines);
    final double exchangeRate = double.tryParse(_exchangeRateController.text.trim()) ?? 50.0;
    final double freightForeign = double.tryParse(_freightForeignController.text.trim()) ?? 0.0;
    final double freightFxRate = double.tryParse(_freightExchangeRateController.text.trim()) ?? exchangeRate;
    final double totalFreightEgp = freightForeign > 0
        ? (freightForeign * freightFxRate)
        : (double.tryParse(_freightEgpController.text.trim()) ?? 0.0);
    final double totalInsuranceEgp = double.tryParse(_insuranceEgpController.text.trim()) ?? 0.0;
    final totalFobForeign = rawCalcLines.fold(0.0, (s, l) => s + l.foreignPrice);
    final totalFobEgp = rawCalcLines.fold(0.0, (s, l) => s + l.fobEgp);
    final totalCandFEgp = totalFobEgp + totalFreightEgp;
    final totalCifEgp = rawCalcLines.fold(0.0, (s, l) => s + l.cifEgp);
    final totalCifForeign = exchangeRate > 0 ? (totalCifEgp / exchangeRate) : 0.0;
    final totalDutyEgp = rawCalcLines.fold(0.0, (s, l) => s + l.dutyAmountEgp);
    final totalVatEgp = rawCalcLines.fold(0.0, (s, l) => s + l.vatAmountEgp);
    final totalTaxesAndDutiesEgp = rawCalcLines.fold(0.0, (s, l) => s + l.totalTaxesAndDutiesEgp);

    final tabs = widget.isTaxReviewMode
        ? [
            VerticalNavTabItem(
              icon: Icons.calculate_outlined,
              titleEn: 'Customs Duty Workspace',
              titleAr: l.taxReviewWorkspaceTab,
            ),
            VerticalNavTabItem(
              icon: Icons.history_edu_outlined,
              titleEn: 'Tax Review Log',
              titleAr: l.taxReviewLogTab,
              badge: consultationsList.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${consultationsList.where((s) => s.estimatedDutiesEgp > 0).length}',
                        style: const TextStyle(color: AppTheme.cobalt, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
            ),
          ]
        : [
            VerticalNavTabItem(
              icon: Icons.gavel_outlined,
              titleEn: 'Customs Workspace',
              titleAr: l.customsWorkspaceTab,
            ),
            VerticalNavTabItem(
              icon: Icons.history_edu_outlined,
              titleEn: 'Consultations Log',
              titleAr: l.consultationsLogTab,
              badge: consultationsList.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${consultationsList.length}',
                        style: const TextStyle(color: AppTheme.cobalt, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
            ),
            VerticalNavTabItem(
              icon: Icons.price_change_outlined,
              titleEn: 'Broker Price Lists & Catalog',
              titleAr: l.brokerPriceListsTab,
            ),
            VerticalNavTabItem(
              icon: Icons.request_quote_rounded,
              titleEn: 'Clearance Quotes & AI Extractor',
              titleAr: l.clearanceQuotesTab,
            ),
          ];

    return VerticalStageScaffold(
      stageCode: widget.isTaxReviewMode ? 'PHASE-1: STEP_02-TAX' : 'PHASE-1: STEP_02',
      titleEn: widget.isTaxReviewMode
          ? 'Customs Duty Review & Tax Calculation Workspace'
          : 'Customs Broker Consultation & Inspection Workspace',
      titleAr: widget.isTaxReviewMode
          ? l.customsDutyReviewTitle
          : l.customsStudiesTitle,
      headerIcon: widget.isTaxReviewMode ? Icons.calculate_outlined : Icons.gavel_outlined,
      headerColor: widget.isTaxReviewMode ? AppTheme.emerald : AppTheme.cobalt,
      tabs: tabs,
      selectedIndex: _tabController.index,
      onTabSelected: (index) {
        _visitedTabs.add(index);
        setState(() => _tabController.index = index);
      },
      selectedImportFileId: _selectedImportFileId,
      onShipmentStatusChanged: () {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      },
      headerActions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          tooltip: l.liveRefresh,
          onPressed: () {
            if (!ref.read(customsConsultationsProvider).isLoading) {
              ref.read(customsConsultationsProvider.notifier).fetchConsultations();
            }
            if (!ref.read(importFilesProvider).isLoading) {
              ref.read(importFilesProvider.notifier).fetchImportFiles();
            }
            if (!ref.read(purchaseOrdersProvider).isLoading) {
              ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
            }
            if (!ref.read(customsTariffProvider).isLoading) {
              ref.read(customsTariffProvider.notifier).fetchTariffs();
            }
            if (!ref.read(currenciesProvider).isLoading) {
              ref.read(currenciesProvider.notifier).fetchCurrencies();
            }
            if (!ref.read(shippingScenariosProvider).isLoading) {
              ref.read(shippingScenariosProvider.notifier).fetchSessions();
            }
            if (!ref.read(partnersProvider).isLoading) {
              ref.read(partnersProvider.notifier).fetchPartners();
            }
            if (!ref.read(projectsProvider).isLoading) {
              ref.read(projectsProvider.notifier).fetchProjects();
            }
            if (!widget.isTaxReviewMode) {
              if (!ref.read(clearanceExpenseTypesProvider).isLoading) {
                ref.read(clearanceExpenseTypesProvider.notifier).fetchExpenseTypes();
              }
              if (!ref.read(brokerPriceListsProvider).isLoading) {
                ref.read(brokerPriceListsProvider.notifier).fetchPriceLists();
              }
            }
          },
        ),
      ],
      body: SelectionArea(
        child: IndexedStack(
          index: _tabController.index,
          children: [
          // TAB 1: CUSTOMS CONSULTATION / DUTY WORKSPACE
          _visitedTabs.contains(0)
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live Metrics Bar & Actions (Responsive Wrap)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConsultationMetricBadge(title: l.customsInspectionReadiness, value: '$liveReadinessPct%', color: Colors.blue),
                      ConsultationMetricBadge(title: l.itemsAndDocsCount, value: '${_checklist.length}', color: Colors.grey),
                      ConsultationMetricBadge(
                        title: l.blockingIssuesCount,
                        value: '$blockingCount',
                        color: blockingCount > 0 ? Colors.red : Colors.green,
                        onTap: () => showBlockingIssuesDialog(context, _checklist, (val) => setState(() { _checklist.clear(); _checklist.addAll(val); })),
                      ),
                      // Search & Clone Consultation Button (UX-CLONE-011)
                      Tooltip(
                        message: l.searchAndCloneConsultationBtn,
                        child: ElevatedButton.icon(
                          key: const ValueKey('searchAndCloneConsultationBtn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.wcagCobalt,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _openSearchAndCloneConsultationDialog(context, consultationsList),
                          icon: const Icon(Icons.control_point_duplicate_rounded, size: 16),
                          label: Text(l.searchAndCloneConsultationBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      // 1. Live Refresh
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.charcoal,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: () {
                          if (!ref.read(customsConsultationsProvider).isLoading) {
                            ref.read(customsConsultationsProvider.notifier).fetchConsultations();
                          }
                          if (!ref.read(importFilesProvider).isLoading) {
                            ref.read(importFilesProvider.notifier).fetchImportFiles();
                          }
                          if (!ref.read(purchaseOrdersProvider).isLoading) {
                            ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
                          }
                          if (!ref.read(customsTariffProvider).isLoading) {
                            ref.read(customsTariffProvider.notifier).fetchTariffs();
                          }
                          if (!ref.read(currenciesProvider).isLoading) {
                            ref.read(currenciesProvider.notifier).fetchCurrencies();
                          }
                          if (!ref.read(shippingScenariosProvider).isLoading) {
                            ref.read(shippingScenariosProvider.notifier).fetchSessions();
                          }
                          if (!ref.read(partnersProvider).isLoading) {
                            ref.read(partnersProvider.notifier).fetchPartners();
                          }
                          if (!ref.read(projectsProvider).isLoading) {
                            ref.read(projectsProvider.notifier).fetchProjects();
                          }
                          if (!widget.isTaxReviewMode) {
                            if (!ref.read(clearanceExpenseTypesProvider).isLoading) {
                              ref.read(clearanceExpenseTypesProvider.notifier).fetchExpenseTypes();
                            }
                            if (!ref.read(brokerPriceListsProvider).isLoading) {
                              ref.read(brokerPriceListsProvider.notifier).fetchPriceLists();
                            }
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 16, color: AppTheme.cobalt),
                        label: Text(l.liveRefresh, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                      // 2. Clear Form & Start New
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade800,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            _editingConsultationId = null;
                            _editingConsultationCode = null;
                            _titleController.text = widget.isTaxReviewMode
                                ? l.defaultTaxReviewSessionTitle
                                : l.defaultCustomsConsultationTitle;
                            _selectedImportFileId = null;
                            _selectedPoId = null;
                            _selectedProjectId = null;
                            _selectedBrokerId = null;
                            _initializeDefaultChecklist();
                          });
                        },
                        icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: Colors.blueGrey),
                        label: Text(l.clearAndStartNew, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                      // 3. TSV Export/Copy Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.charcoal,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: () => _copyCustomsStudyTsv(calcLines),
                        icon: const Icon(Icons.table_view_outlined, size: 16, color: Colors.blueGrey),
                        label: Text(l.customsTaxExportTsvBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                      // 4. Excel Export Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.charcoal,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: () => _exportCustomsStudyExcel(calcLines, totalFreightEgp, totalInsuranceEgp, exchangeRate),
                        icon: const Icon(Icons.description_outlined, size: 16, color: AppTheme.emerald),
                        label: Text(l.customsTaxExportExcelBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                      // 5. PDF Print/Preview Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.charcoal,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: () => _printOrSaveCustomsStudyPdf(calcLines, totalFreightEgp, totalInsuranceEgp, exchangeRate),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppTheme.crimson),
                        label: Text(l.customsTaxPrintPdfBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                      // 6. Dossier Copy Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.charcoal,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: () => _copyCustomsStudyDossier(calcLines, totalFreightEgp, totalInsuranceEgp, exchangeRate),
                        icon: const Icon(Icons.copy_all_outlined, size: 16, color: AppTheme.cobalt),
                        label: Text(l.customsTaxCopyDossierBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                      // 7. Smart Clearance Quote Extractor Button (Clearance Mode Only)
                      if (!widget.isTaxReviewMode)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: Text(l.smartClearanceQuoteExtractor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            showSmartClearanceExtractorDialog(
                              context,
                              ref,
                              onExtracted: _applyExtractedQuotationToConsultation,
                            );
                          },
                        ),

                      // 8. Save Draft & Continue Later
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEFF6FF),
                          foregroundColor: AppTheme.cobalt,
                          elevation: 0,
                          side: const BorderSide(color: AppTheme.cobalt),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: _isSaving ? null : _saveConsultation,
                        icon: const Icon(Icons.save_outlined, size: 16, color: AppTheme.cobalt),
                        label: Text(l.saveDraftContinueLater, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                      // 9. Final Save / Update
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _editingConsultationId != null ? Colors.orange.shade700 : AppTheme.emerald,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onPressed: _isSaving ? null : _saveConsultation,
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(_editingConsultationId != null ? Icons.save_as : Icons.save, color: Colors.white),
                        label: Text(
                          _editingConsultationId != null
                              ? l.saveConsultationChanges
                              : (widget.isTaxReviewMode ? l.saveTaxReviewSession : l.saveCustomsStudy),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Active Edit Mode Banner
                  if (_editingConsultationId != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade400, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    Text(
                                      l.activeEditModeBannerTitle(_editingConsultationCode ?? ''),
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange.shade900),
                                    ),
                                    if (_editingConsultationCode != null)
                                      Tooltip(
                                        message: l.copyTooltip,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(4),
                                          onTap: () => CopyHelper.copy(context, _editingConsultationCode!),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.orange.shade300),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _editingConsultationCode!,
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange.shade900),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.copy, size: 12, color: Colors.orange.shade900),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l.activeEditModeBannerSub,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.save_as_rounded, size: 16),
                            label: Text(l.saveConsultationChanges, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: _isSaving ? null : _saveConsultation,
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade800,
                              side: BorderSide(color: Colors.blue.shade400),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: Text(l.saveAsNewCopy, style: const TextStyle(fontSize: 12)),
                            onPressed: () {
                              setState(() {
                                _editingConsultationId = null;
                                _editingConsultationCode = null;
                                _titleController.text = '${_titleController.text}${TableRowCloneHelper.copySuffix}';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('📋 ${l.convertedToNewStudyToast}'), backgroundColor: Colors.blue),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            tooltip: l.cancelEditTooltip,
                            onPressed: () {
                              setState(() {
                                _editingConsultationId = null;
                                _editingConsultationCode = null;
                                _titleController.text = widget.isTaxReviewMode
                                    ? l.defaultTaxReviewSessionTitle
                                    : l.defaultCustomsConsultationTitle;
                                _initializeDefaultChecklist();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Session Setup Header Card
                  Card(
                    elevation: 2,
                    color: isDark ? AppTheme.darkCardBackground : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Text(
                                widget.isTaxReviewMode
                                    ? l.taxReviewWorkspaceTab
                                    : l.customsWorkspaceTab,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                ),
                              ),
                              if (_editingConsultationCode != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(6)),
                                  child: Text('${l.statusCol}: $_editingConsultationCode', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 700;
                              final titleField = TextFormField(
                                controller: _titleController,
                                decoration: InputDecoration(labelText: '${l.titleField} *', border: const OutlineInputBorder()),
                                validator: (v) => (v == null || v.trim().isEmpty) ? l.requiredField : null,
                              );
                              final brokerField = !widget.isTaxReviewMode
                                  ? SearchableDropdownField<int?>(
                                      value: _selectedBrokerId,
                                      labelText: '${l.customsBrokerLabel} *',
                                      searchHintText: '${l.search} ${l.customsBrokerLabel}...',
                                      items: brokersList
                                          .map((b) => SearchableDropdownItem<int?>(
                                                value: b.providerId,
                                                label: b.partnerName,
                                                subtitle: b.contactPerson,
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          final b = brokersList.where((element) => element.providerId == val).firstOrNull;
                                          setState(() {
                                            _selectedBrokerId = val;
                                            _selectedBrokerName = b?.partnerName ?? '';
                                            _brokerContactPerson = b?.contactPerson;
                                          });
                                          _loadBrokerPriceList(val);
                                        } else {
                                          setState(() {
                                            _selectedBrokerId = null;
                                            _selectedBrokerName = '';
                                            _brokerContactPerson = null;
                                            _brokerPriceListId = null;
                                            _brokerPriceListTitle = null;
                                            _brokerQuoteItems.clear();
                                          });
                                        }
                                      },
                                      validator: (v) => v == null ? l.requiredField : null,
                                    )
                                  : null;

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    titleField,
                                    if (brokerField != null) ...[
                                      const SizedBox(height: 12),
                                      brokerField,
                                    ],
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(flex: 3, child: titleField),
                                  if (brokerField != null) ...[
                                    const SizedBox(width: 12),
                                    Expanded(flex: 2, child: brokerField),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 700;
                              final importFileField = SearchableDropdownField<int?>(
                                value: _selectedImportFileId,
                                labelText: l.linkImportFile,
                                searchHintText: '${l.search} ${l.linkImportFile}...',
                                items: [
                                  SearchableDropdownItem<int?>(
                                    value: null,
                                    label: '-- ${l.allFiles} --',
                                  ),
                                  ...(ref.watch(importFilesProvider).valueOrNull ?? []).map((f) => SearchableDropdownItem<int?>(
                                        value: f.importFileId,
                                        label: '${f.primaryNameWithCode} - ${f.companyName}',
                                        subtitle: '${f.companyName} | ${l.customsBrokerLabel}: ${f.brokerName ?? ""} | ${f.invoicesData.length} Invoices',
                                      )),
                                ],
                                onChanged: _onImportFileChanged,
                              );
                              final dutiesField = TextFormField(
                                controller: _estimatedDutiesController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '${l.totalTaxesAndDutiesCol} ($egpLabel)',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.calculate, color: AppTheme.cobalt),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    tooltip: l.copyTooltip,
                                    onPressed: () {
                                      if (_estimatedDutiesController.text.isNotEmpty) {
                                        CopyHelper.copy(context, _estimatedDutiesController.text);
                                      }
                                    },
                                  ),
                                ),
                              );

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    importFileField,
                                    const SizedBox(height: 12),
                                    dutiesField,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(flex: 3, child: importFileField),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 2, child: dutiesField),
                                ],
                              );
                            },
                          ),
                          if (_selectedImportFileId != null) ...[
                            Builder(builder: (context) {
                              final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
                              final selFile = importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
                              if (selFile == null) return const SizedBox.shrink();

                              final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;
                              final matchingPOs = allPOs.where((p) =>
                                  (p.importFileId != null && p.importFileId == selFile.importFileId) ||
                                  (selFile.importFileCode.isNotEmpty && p.importFileCode != null && p.importFileCode == selFile.importFileCode) ||
                                  (selFile.poIds != null && p.poId != null && selFile.poIds!.contains(p.poId))).toList();

                              // Group PO totals by currency
                              final Map<String, double> poTotalsByCur = {};
                              for (final po in matchingPOs) {
                                final cur = po.currencyCode?.isNotEmpty == true
                                    ? po.currencyCode!
                                    : (currenciesList.where((c) => c.currencyId == po.currencyId).firstOrNull?.currencyCode ?? _customsCurrency);
                                poTotalsByCur[cur] = (poTotalsByCur[cur] ?? 0.0) + po.totalAmountFob;
                              }
                              final poSummaryText = poTotalsByCur.entries
                                  .map((e) => '${e.value.toStringAsFixed(2)} ${e.key}')
                                  .join(' + ');

                              // Group Invoices totals by currency
                              final invCount = selFile.invoicesData.length;
                              final Map<String, double> invTotalsByCur = {};
                              for (final inv in selFile.invoicesData) {
                                final cur = inv.currency.isNotEmpty ? inv.currency : _customsCurrency;
                                invTotalsByCur[cur] = (invTotalsByCur[cur] ?? 0.0) + inv.amount;
                              }
                              final invSummaryText = invTotalsByCur.entries
                                  .map((e) => '${e.value.toStringAsFixed(2)} ${e.key}')
                                  .join(' + ');

                              return Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.cobalt.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.cobalt.withOpacity(0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 8,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        // 1. Purchase Orders Summary
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.shopping_cart, size: 16, color: AppTheme.emerald),
                                            const SizedBox(width: 6),
                                            Text(
                                              l.linkedPurchaseOrdersSummary(
                                                matchingPOs.length,
                                                poSummaryText.isNotEmpty ? " — ($poSummaryText)" : "",
                                              ),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                                            ),
                                          ],
                                        ),
                                        // 2. Invoices Summary
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.receipt_long, size: 16, color: AppTheme.cobalt),
                                            const SizedBox(width: 6),
                                            Text(
                                              l.approvedInvoicesSummary(
                                                invCount,
                                                invSummaryText.isNotEmpty
                                                    ? " — ($invSummaryText)"
                                                    : (invCount > 0 ? " — (${invTotalsByCur.values.fold(0.0, (s, a) => s + a).toStringAsFixed(2)} $_customsCurrency)" : ""),
                                              ),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                                            ),
                                          ],
                                        ),
                                        if (selFile.projectNames != null && selFile.projectNames!.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.business, size: 16, color: Colors.blueGrey),
                                              const SizedBox(width: 6),
                                              CopyableText(l.projectNamedSummary(selFile.projectNames!), style: const TextStyle(fontSize: 12, color: AppTheme.charcoal)),
                                            ],
                                          ),
                                      ],
                                    ),
                                    if (matchingPOs.length > 1) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: matchingPOs.map((po) {
                                          final cur = po.currencyCode ?? _customsCurrency;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: Text(
                                              '${po.displayName} (${po.poNumber}): ${po.totalAmountFob.toStringAsFixed(2)} $cur',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // BROKER CLEARANCE & LOGISTICS QUOTE DETAILS CARD (Clearance Mode Only)
                  if (!widget.isTaxReviewMode) ...[
                    BrokerQuoteDetailsCard(
                      selectedBrokerId: _selectedBrokerId,
                      isLoadingPriceList: _isLoadingPriceList,
                      brokerQuoteItems: _brokerQuoteItems,
                      brokerPriceListTitle: _brokerPriceListTitle,
                      categoryFilter: _brokerExpenseCategoryFilter,
                      isExpanded: _isBrokerQuoteExpanded,
                      currenciesList: currenciesList,
                      onToggleExpanded: () => setState(() => _isBrokerQuoteExpanded = !_isBrokerQuoteExpanded),
                      onCategoryChanged: (cat) => setState(() => _brokerExpenseCategoryFilter = cat),
                      onAddCustomExpense: _addCustomBrokerExpenseRow,
                      onReloadPriceList: _selectedBrokerId != null ? () => _loadBrokerPriceList(_selectedBrokerId!) : null,
                      onApplyAll: () {
                        setState(() {
                          for (int i = 0; i < _brokerQuoteItems.length; i++) {
                            final itm = _brokerQuoteItems[i];
                            final lineTotal = itm.unitPrice * itm.qty;
                            _brokerQuoteItems[i] = itm.copyWith(isApplicable: true, totalAmount: lineTotal);
                          }
                        });
                      },
                      onDisableAll: () {
                        setState(() {
                          for (int i = 0; i < _brokerQuoteItems.length; i++) {
                            _brokerQuoteItems[i] = _brokerQuoteItems[i].copyWith(isApplicable: false, totalAmount: 0.0);
                          }
                        });
                      },
                      onUpdateItem: _updateBrokerQuoteItem,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // CUSTOMS CALCULATION ENGINE CARD (MD-008 Customs Engine)
                  Card(
                    elevation: 3,
                    color: isDark ? AppTheme.darkCardBackground : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 750;
                              final titleWidget = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calculate, color: AppTheme.cobalt, size: 22),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.customsCalculationEngine,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                          ),
                                        ),
                                        Text(l.customsCalculationEngineSub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              );

                              final actionButtons = <Widget>[
                                if (widget.isTaxReviewMode) ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.emerald,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                    onPressed: _isRecalculating ? null : _fetchReconciledFinalInvoiceAndRecalculate,
                                    icon: _isRecalculating
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.flash_on, color: Colors.white, size: 16),
                                    label: Text(
                                      l.fetchReconciledFinalInvoice,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                                  onPressed: () => _syncHsRequirementsToChecklist(silent: false),
                                  icon: const Icon(Icons.sync_alt, color: Colors.white, size: 16),
                                  label: Text(l.syncHsRequirementsToChecklist, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                IconButton(
                                  icon: Icon(_isCustomsCalculatorExpanded ? Icons.expand_less : Icons.expand_more, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  tooltip: l.view,
                                  onPressed: () => setState(() => _isCustomsCalculatorExpanded = !_isCustomsCalculatorExpanded),
                                ),
                              ];

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    titleWidget,
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: actionButtons,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: titleWidget),
                                  ...actionButtons.map((w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: w)),
                                ],
                              );
                            },
                          ),
                          if (_isCustomsCalculatorExpanded) ...[
                            const Divider(height: 24),
                            // Row 1: Valuation Currency, Customs Official FX Rate, Study Date
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 700;
                                final currField = SearchableDropdownField<String>(
                                  value: _customsCurrency,
                                  labelText: l.invoiceCurrencyLabel,
                                  items: currenciesList.isNotEmpty
                                      ? currenciesList
                                          .map((c) => SearchableDropdownItem<String>(
                                                value: c.currencyCode,
                                                label: '${c.currencyCode} - ${c.currencyName}',
                                              ))
                                          .toList()
                                      : const [
                                          SearchableDropdownItem(value: 'USD', label: 'USD'),
                                          SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                                          SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                                          SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                                          SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                                        ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _customsCurrency = v;
                                        _updateExchangeRateForCurrency(v);
                                      });
                                    }
                                  },
                                );
                                final fxField = TextFormField(
                                  controller: _exchangeRateController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: l.customsFxRateLabel,
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.currency_exchange, color: AppTheme.cobalt, size: 18),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      tooltip: l.copyTooltip,
                                      onPressed: () {
                                        if (_exchangeRateController.text.isNotEmpty) {
                                          CopyHelper.copy(context, _exchangeRateController.text);
                                        }
                                      },
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                );
                                final dateField = InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _studyDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setState(() => _studyDate = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: l.studyDateLabel,
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.calendar_today, color: AppTheme.cobalt, size: 18),
                                    ),
                                    child: Text(
                                      '${_studyDate.year}-${_studyDate.month.toString().padLeft(2, '0')}-${_studyDate.day.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                      ),
                                    ),
                                  ),
                                );

                                if (isNarrow) {
                                  return Column(
                                    children: [
                                      currField,
                                      const SizedBox(height: 10),
                                      fxField,
                                      const SizedBox(height: 10),
                                      dateField,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(flex: 2, child: currField),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 2, child: fxField),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 2, child: dateField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Row 2: Ocean Freight Data in a dedicated separate row
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.cobalt.withOpacity(0.12) : Colors.blue.shade50.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppTheme.cobalt.withOpacity(0.3) : Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_boat, color: AppTheme.cobalt, size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          l.freightDataHeader,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                          ),
                                        ),
                                      ),
                                      if (_selectedImportFileId != null)
                                        TextButton.icon(
                                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                          icon: const Icon(Icons.download, size: 16, color: AppTheme.cobalt),
                                          label: Text(l.fetchHighestFreightFromStudy, style: const TextStyle(fontSize: 11)),
                                          onPressed: () => _autoFetchFreightFromScenarios(_selectedImportFileId!),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isNarrow = constraints.maxWidth < 700;
                                      final fAmount = TextFormField(
                                        controller: _freightForeignController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: l.foreignFreightAmountLabel,
                                          border: const OutlineInputBorder(),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy, size: 16),
                                            tooltip: l.copyTooltip,
                                            onPressed: () {
                                              if (_freightForeignController.text.isNotEmpty) {
                                                CopyHelper.copy(context, _freightForeignController.text);
                                              }
                                            },
                                          ),
                                        ),
                                        onChanged: (_) => setState(() => _recalculateFreightEgp()),
                                      );
                                      final fCurr = SearchableDropdownField<String>(
                                        value: _freightCurrency,
                                        labelText: l.freightCurrencyLabel,
                                        items: currenciesList.isNotEmpty
                                            ? currenciesList
                                                .map((c) => SearchableDropdownItem<String>(
                                                      value: c.currencyCode,
                                                      label: '${c.currencyCode} - ${c.currencyName}',
                                                    ))
                                                .toList()
                                            : const [
                                                SearchableDropdownItem(value: 'USD', label: 'USD'),
                                                SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                                                SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                                                SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                                              ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _freightCurrency = v;
                                              _updateFreightExchangeRateForCurrency(v);
                                            });
                                          }
                                        },
                                      );
                                      final fFx = TextFormField(
                                        controller: _freightExchangeRateController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: l.freightFxRateLabel,
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(Icons.currency_exchange, color: AppTheme.cobalt, size: 16),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy, size: 16),
                                            tooltip: l.copyTooltip,
                                            onPressed: () {
                                              if (_freightExchangeRateController.text.isNotEmpty) {
                                                CopyHelper.copy(context, _freightExchangeRateController.text);
                                              }
                                            },
                                          ),
                                        ),
                                        onChanged: (_) => setState(() => _recalculateFreightEgp()),
                                      );
                                      final fEgp = TextFormField(
                                        controller: _freightEgpController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: '${l.freightEgpLabel} ($egpLabel)',
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(Icons.attach_money, color: AppTheme.emerald, size: 18),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy, size: 16),
                                            tooltip: l.copyTooltip,
                                            onPressed: () {
                                              if (_freightEgpController.text.isNotEmpty) {
                                                CopyHelper.copy(context, _freightEgpController.text);
                                              }
                                            },
                                          ),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      );

                                      if (isNarrow) {
                                        return Column(
                                          children: [
                                            fAmount,
                                            const SizedBox(height: 8),
                                            fCurr,
                                            const SizedBox(height: 8),
                                            fFx,
                                            const SizedBox(height: 8),
                                            fEgp,
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          Expanded(flex: 2, child: fAmount),
                                          const SizedBox(width: 10),
                                          Expanded(flex: 2, child: fCurr),
                                          const SizedBox(width: 10),
                                          Expanded(flex: 2, child: fFx),
                                          const SizedBox(width: 10),
                                          Expanded(flex: 2, child: fEgp),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Row 3: Marine Insurance calculation (التأمين البحري التقديري 0.5% أو 1.0%)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.orange.withOpacity(0.12) : Colors.orange.shade50.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppTheme.orange.withOpacity(0.3) : Colors.orange.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.security, color: AppTheme.orange, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          l.estimatedCustomsInsuranceRateLabel,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 10,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      SegmentedButton<String>(
                                        segments: [
                                          ButtonSegment(value: '0.5%', label: Text(l.standardCustomsInsuranceRate)),
                                          const ButtonSegment(value: '1.0%', label: Text('1.0%')),
                                          ButtonSegment(value: 'Custom', label: Text(l.customInsuranceRate)),
                                        ],
                                        selected: {_insuranceOption},
                                        onSelectionChanged: (set) {
                                          setState(() {
                                            _insuranceOption = set.first;
                                          });
                                        },
                                        style: const ButtonStyle(
                                          visualDensity: VisualDensity.compact,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 320,
                                        child: TextFormField(
                                          controller: _insuranceEgpController,
                                          readOnly: _insuranceOption != 'Custom',
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: '${l.insuranceEgpLabel} ($egpLabel)',
                                            border: const OutlineInputBorder(),
                                            filled: _insuranceOption != 'Custom',
                                            fillColor: _insuranceOption != 'Custom' ? (isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100) : null,
                                            helperText: _insuranceOption != 'Custom' ? l.autoCalculatedCandFInsuranceHelper(_insuranceOption) : null,
                                            suffixIcon: IconButton(
                                              icon: const Icon(Icons.copy, size: 16),
                                              tooltip: l.copyTooltip,
                                              onPressed: () {
                                                if (_insuranceEgpController.text.isNotEmpty) {
                                                  CopyHelper.copy(context, _insuranceEgpController.text);
                                                }
                                              },
                                            ),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Row 4: Highlighted Declared Customs CIF Value Box
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal.withOpacity(0.04),
                                    AppTheme.emerald.withOpacity(isDark ? 0.15 : 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.emerald.withOpacity(0.4), width: 1.2),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isNarrow = constraints.maxWidth < 600;
                                  final infoCol = Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.verified, color: AppTheme.emerald, size: 18),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              l.declaredCifBaseLabel,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l.cifFormulaBreakdown(
                                          totalFobForeign.toStringAsFixed(2),
                                          _customsCurrency,
                                          totalFreightEgp.toStringAsFixed(2),
                                          totalCandFEgp.toStringAsFixed(2),
                                          totalInsuranceEgp.toStringAsFixed(2),
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  );

                                  final numbersCol = Column(
                                    crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                    children: [
                                      CopyableText(
                                        '${totalCifEgp.toStringAsFixed(2)} $egpLabel',
                                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                      ),
                                      if (exchangeRate > 0)
                                        CopyableText(
                                          '≈ ${totalCifForeign.toStringAsFixed(2)} $_customsCurrency',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.cobalt),
                                        ),
                                    ],
                                  );

                                  if (isNarrow) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        infoCol,
                                        const SizedBox(height: 10),
                                        numbersCol,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: infoCol),
                                      numbersCol,
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Row 5: Table Header Controls & Toolbar
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                LayoutBuilder(
                                  builder: (ctx, constraints) => ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: constraints.maxWidth > 40 ? constraints.maxWidth : 320),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.table_chart, color: AppTheme.cobalt, size: 18),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            l.tariffDetailsTableTitle(
                                              calcLines.length,
                                              _groupByHsCode ? l.groupedHsCodeItems : l.detailedItems,
                                            ),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                FilterChip(
                                  selected: _groupByHsCode,
                                  label: Text(
                                    _groupByHsCode ? l.groupByHsCodeOption : l.detailedItemViewOption,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: _groupByHsCode ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    ),
                                  ),
                                  selectedColor: AppTheme.cobalt,
                                  checkmarkColor: Colors.white,
                                  onSelected: (val) {
                                    setState(() {
                                      _groupByHsCode = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (_recalculationResult != null) ...[
                              const SizedBox(height: 16),
                              RecalculationVarianceComparisonCard(
                                recalculationResult: _recalculationResult!,
                                onApplyNewFees: _applyAndSaveRecalculatedFees,
                                onClose: () => setState(() => _recalculationResult = null),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // HS Code Line Items Calculation Table
                            if (calcLines.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: AppTheme.cobalt),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(l.noResultsFound, style: const TextStyle(color: AppTheme.charcoal, fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              )
                            else ...[
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 14,
                                  headingRowColor: WidgetStateProperty.all(AppTheme.charcoal.withOpacity(0.06)),
                                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal, fontSize: 12),
                                  columns: [
                                    DataColumn(label: Text(l.actionsCol)),
                                    DataColumn(label: Text(l.customsTariffItemCol)),
                                    DataColumn(label: Text(l.itemDescriptionAndOriginCol)),
                                    DataColumn(label: Text(l.quantityAndUnitCol)),
                                    DataColumn(label: Text(l.valueInCurrencyCol(_customsCurrency))),
                                    DataColumn(label: Text(l.fobEgpCol)),
                                    DataColumn(label: Text(l.cifEgpCol)),
                                    DataColumn(label: Text(l.customsDutyCol)),
                                    DataColumn(label: Text(l.vatCol)),
                                    DataColumn(label: Text(l.otherTaxesCol)),
                                    DataColumn(label: Text(l.totalTaxesAndDutiesCol)),
                                    DataColumn(label: Text(l.regulatoryRequirementsCol)),
                                  ],
                                  rows: calcLines.map((line) {
                                    final rowSummary = isArabic
                                        ? '${line.hsCode} | ${line.description} | ${l.quantityAndUnitCol}: ${line.qty.toStringAsFixed(0)} ${line.unit} | ${l.fobEgpCol}: ${line.fobEgp.toStringAsFixed(2)} $egpLabel | ${l.cifEgpCol}: ${line.cifEgp.toStringAsFixed(2)} $egpLabel | ${l.customsDutyCol}: ${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)} $egpLabel) | ${l.vatCol}: ${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)} $egpLabel) | ${l.totalTaxesAndDutiesCol}: ${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel'
                                        : '${line.hsCode} | ${line.description} | Qty: ${line.qty.toStringAsFixed(0)} ${line.unit} | FOB: ${line.fobEgp.toStringAsFixed(2)} $egpLabel | CIF: ${line.cifEgp.toStringAsFixed(2)} $egpLabel | Duty: ${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)} $egpLabel) | VAT: ${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)} $egpLabel) | Total: ${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel';
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                                            tooltip: l.copyTooltip,
                                            onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.customsTaxCopyRowSuccess),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: line.hsCode,
                                            rowSummary: rowSummary,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: AppTheme.cobalt.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                              child: Text(line.hsCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${line.description}${line.countryOfOrigin != null ? " (${line.countryOfOrigin})" : ""}',
                                            rowSummary: rowSummary,
                                            child: SizedBox(
                                              width: 190,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(line.description, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                  if (line.countryOfOrigin != null && line.countryOfOrigin!.isNotEmpty)
                                                    Container(
                                                      margin: const EdgeInsets.only(top: 2),
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.shade50,
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: Colors.blue.shade200),
                                                      ),
                                                      child: Text(
                                                        line.countryOfOrigin!,
                                                        style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${line.qty.toStringAsFixed(0)} ${line.unit}',
                                            rowSummary: rowSummary,
                                            child: Text('${line.qty.toStringAsFixed(0)} ${line.unit}'),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${line.foreignPrice.toStringAsFixed(2)} $_customsCurrency',
                                            rowSummary: rowSummary,
                                            child: Text('${line.foreignPrice.toStringAsFixed(2)} $_customsCurrency', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.cobalt)),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${line.fobEgp.toStringAsFixed(2)} $egpLabel',
                                            rowSummary: rowSummary,
                                            child: Text(line.fobEgp.toStringAsFixed(2)),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${line.cifEgp.toStringAsFixed(2)} $egpLabel',
                                            rowSummary: rowSummary,
                                            child: Text(line.cifEgp.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)} $egpLabel)',
                                            rowSummary: rowSummary,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (line.hasExemption) ...[
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        '${line.baseDutyRate}%',
                                                        style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 11),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)})',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                                      ),
                                                    ],
                                                  ),
                                                  Container(
                                                    margin: const EdgeInsets.only(top: 2),
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.green.shade300),
                                                    ),
                                                    child: Text(
                                                      line.appliedAgreementName ?? (isArabic ? 'إعفاء' : 'Exemption'),
                                                      style: TextStyle(fontSize: 9.5, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ] else ...[
                                                  Text('${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)})'),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)} $egpLabel)',
                                            rowSummary: rowSummary,
                                            child: Text('${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)})'),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${(line.scheduleTaxAmountEgp + line.developmentFeeAmountEgp + line.customsServiceFeeAmountEgp).toStringAsFixed(2)} $egpLabel',
                                            rowSummary: rowSummary,
                                            child: Text('${(line.scheduleTaxAmountEgp + line.developmentFeeAmountEgp + line.customsServiceFeeAmountEgp).toStringAsFixed(2)} $egpLabel'),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel',
                                            rowSummary: rowSummary,
                                            child: Text('${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson)),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              if (line.requiresAcid)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                                                  child: Text(isArabic ? 'تسجيل مسبق' : 'ACID', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                                ),
                                              if (line.requiresCoo)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                                  child: Text(isArabic ? 'شهادة منشأ' : 'COO', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                                                ),
                                              if (line.requiresInspection)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                                  child: Text(isArabic ? 'رقابة صادرات' : 'GOEIC', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                                ),
                                              if (line.regulatoryAuthority != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(4)),
                                                  child: Text(line.regulatoryAuthority!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Exemption & Documentary Requirements Alerts for applicable HS Codes
                              ...calcLines.where((l) => l.hasExemption || l.priorApprovalNote != null || (l.regulatoryAuthority != null && l.regulatoryAuthority!.isNotEmpty)).map((line) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade700, width: 1.2),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${isArabic ? "⚠️ بند جمركي" : "⚠️ HS Code"}: ${line.hsCode}${line.countryOfOrigin != null ? " - ${line.countryOfOrigin}" : ""}',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                                            ),
                                          ),
                                          if (line.hasExemption)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.green.shade700),
                                              ),
                                              child: Text(
                                                line.appliedAgreementName ?? (isArabic ? 'إعفاء' : 'Exemption'),
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (line.exemptionConditionsNote != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          line.exemptionConditionsNote!,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                                        ),
                                      ],
                                      if (line.requiredDocument != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          line.requiredDocument!,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                        ),
                                      ],
                                      if (line.priorApprovalNote != null && line.priorApprovalNote!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          line.priorApprovalNote!,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal, height: 1.3),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),

                              // Calculation Financial Summary Matrix
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.charcoal.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                                ),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    ConsultationMetricBadge(
                                      title: l.fobEgpCol,
                                      value: '${totalFobForeign.toStringAsFixed(2)} $_customsCurrency\n(${totalFobEgp.toStringAsFixed(2)} $egpLabel)',
                                      color: Colors.grey.shade800,
                                    ),
                                    ConsultationMetricBadge(
                                      title: l.cifEgpCol,
                                      value: '${totalCifForeign.toStringAsFixed(2)} $_customsCurrency\n(${totalCifEgp.toStringAsFixed(2)} $egpLabel)',
                                      color: AppTheme.cobalt,
                                    ),
                                    ConsultationMetricBadge(title: l.customsDutyCol, value: '${totalDutyEgp.toStringAsFixed(2)} $egpLabel', color: Colors.indigo),
                                    ConsultationMetricBadge(title: l.vatCol, value: '${totalVatEgp.toStringAsFixed(2)} $egpLabel', color: Colors.teal),
                                    ConsultationMetricBadge(title: l.totalTaxesAndDutiesCol, value: '${totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel', color: AppTheme.crimson),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                                      onPressed: () {
                                        setState(() {
                                          _estimatedDutiesController.text = totalTaxesAndDutiesEgp.toStringAsFixed(2);
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('✅ ${l.applyAndLinkFinancialEstimate}: ${totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel'), backgroundColor: AppTheme.emerald),
                                        );
                                      },
                                      icon: const Icon(Icons.done_all, color: Colors.white, size: 16),
                                      label: Text(l.applyAndLinkFinancialEstimate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                              const SizedBox(height: 16),

                              // NAFEZA STATEMENT FEE BREAKDOWN CARD (تفاصيل بنود التحصيل والإقرارات الرسمية)
                              NafezaFeeBreakdownCard(
                                calcLines: calcLines,
                                totalDutyEgp: totalDutyEgp,
                                totalVatEgp: totalVatEgp,
                                totalServiceFeeEgp: calcLines.fold(0.0, (s, l) => s + l.customsServiceFeeAmountEgp),
                                totalScheduleTaxEgp: calcLines.fold(0.0, (s, l) => s + l.scheduleTaxAmountEgp),
                                totalFreightEgp: totalFreightEgp,
                                totalInsuranceEgp: totalInsuranceEgp,
                                exchangeRate: exchangeRate,
                                editingConsultationId: _editingConsultationId,
                                editingConsultationCode: _editingConsultationCode,
                                selectedBrokerId: _selectedBrokerId,
                                selectedBrokerName: _selectedBrokerName,
                                title: _titleController.text.trim(),
                                checklist: _checklist,
                                brokerQuoteItems: _brokerQuoteItems,
                                selectedImportFileId: _selectedImportFileId,
                                customsCurrency: _customsCurrency,
                              ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Checklist Table & Controls
                  Card(
                    elevation: 2,
                    color: isDark ? AppTheme.darkCardBackground : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 600;
                              final titleWidget = Text(
                                l.customsChecklistTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                ),
                              );
                              final btnWidget = ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                                onPressed: _addChecklistItem,
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: Text(l.addNewChecklistItem, style: const TextStyle(color: Colors.white)),
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    titleWidget,
                                    const SizedBox(height: 10),
                                    btnWidget,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: titleWidget),
                                  btnWidget,
                                ],
                              );
                            },
                          ),
                          const Divider(),
                          const SizedBox(height: 10),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _checklist.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _checklist[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isNarrow = constraints.maxWidth < 850;
                                    if (isNarrow) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              if (item.hsCode != null && item.hsCode!.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: AppTheme.cobalt.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                                  child: CopyableText(item.hsCode!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                                ),
                                              CopyableText(_getLocalizedDocType(item.documentType, l), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ],
                                          ),
                                          if (item.regulatoryAgency != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2.0),
                                              child: CopyableText('${l.responsiblePartyLabel}: ${item.regulatoryAgency == 'GOEIC' ? l.goeicAgencyName : item.regulatoryAgency}', style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold)),
                                            ),
                                          if (item.remarks != null && item.remarks!.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2.0),
                                              child: CopyableText(_getLocalizedRemarks(item.remarks, l), style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                            ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: SearchableDropdownField<String>(
                                                  value: item.responsibleParty,
                                                  labelText: l.responsiblePartyLabel,
                                                  items: [
                                                    SearchableDropdownItem(value: 'Customs Broker', label: l.partyCustomsBroker),
                                                    SearchableDropdownItem(value: 'Supplier / Exporter', label: l.partySupplierExporter),
                                                    SearchableDropdownItem(value: 'Importer Team', label: l.partyImporterTeam),
                                                    SearchableDropdownItem(value: 'Freight Forwarder', label: l.partyFreightForwarder),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setState(() {
                                                        _checklist[index] = item.copyWith(responsibleParty: val);
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: SearchableDropdownField<String>(
                                                  value: item.status,
                                                  labelText: l.statusCol,
                                                  items: [
                                                      SearchableDropdownItem(value: 'Pending', label: l.statusPending),
                                                      SearchableDropdownItem(value: 'Received', label: l.statusReceived),
                                                      SearchableDropdownItem(value: 'Verified', label: l.statusVerified),
                                                      SearchableDropdownItem(value: 'Approved', label: l.statusApproved),
                                                      SearchableDropdownItem(value: 'Rejected', label: l.statusRejected),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setState(() {
                                                        _checklist[index] = item.copyWith(status: val);
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(item.isBlockingShipment ? Icons.block : Icons.check_circle_outline, color: item.isBlockingShipment ? Colors.red : Colors.grey, size: 20),
                                                tooltip: item.isBlockingShipment ? l.blockingConditionTooltip : l.nonBlockingConditionTooltip,
                                                onPressed: () {
                                                  setState(() {
                                                    _checklist[index] = item.copyWith(isBlockingShipment: !item.isBlockingShipment);
                                                  });
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
                                                tooltip: l.cloneChecklistItemTooltip,
                                                onPressed: () => _cloneChecklistItem(index),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                                onPressed: () {
                                                  setState(() {
                                                    _checklist.removeAt(index);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    }

                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  if (item.hsCode != null && item.hsCode!.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: AppTheme.cobalt.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                                      child: CopyableText(item.hsCode!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                                    ),
                                                  CopyableText(_getLocalizedDocType(item.documentType, l), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                ],
                                              ),
                                              if (item.regulatoryAgency != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2.0),
                                                  child: CopyableText('${l.responsiblePartyLabel}: ${item.regulatoryAgency == 'GOEIC' ? l.goeicAgencyName : item.regulatoryAgency}', style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold)),
                                                ),
                                              if (item.remarks != null && item.remarks!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2.0),
                                                  child: CopyableText(_getLocalizedRemarks(item.remarks, l), style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 190,
                                          child: SearchableDropdownField<String>(
                                            value: item.responsibleParty,
                                            labelText: l.responsiblePartyLabel,
                                            items: [
                                              SearchableDropdownItem(value: 'Customs Broker', label: l.partyCustomsBroker),
                                              SearchableDropdownItem(value: 'Supplier / Exporter', label: l.partySupplierExporter),
                                              SearchableDropdownItem(value: 'Importer Team', label: l.partyImporterTeam),
                                              SearchableDropdownItem(value: 'Freight Forwarder', label: l.partyFreightForwarder),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _checklist[index] = item.copyWith(responsibleParty: val);
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 160,
                                          child: SearchableDropdownField<String>(
                                            value: item.status,
                                            labelText: l.statusCol,
                                            items: [
                                              SearchableDropdownItem(value: 'Pending', label: l.statusPending),
                                              SearchableDropdownItem(value: 'Received', label: l.statusReceived),
                                              SearchableDropdownItem(value: 'Verified', label: l.statusVerified),
                                              SearchableDropdownItem(value: 'Approved', label: l.statusApproved),
                                              SearchableDropdownItem(value: 'Rejected', label: l.statusRejected),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _checklist[index] = item.copyWith(status: val);
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(item.isBlockingShipment ? Icons.block : Icons.check_circle_outline, color: item.isBlockingShipment ? Colors.red : Colors.grey, size: 20),
                                          tooltip: item.isBlockingShipment ? l.blockingConditionTooltip : l.nonBlockingConditionTooltip,
                                          onPressed: () {
                                            setState(() {
                                              _checklist[index] = item.copyWith(isBlockingShipment: !item.isBlockingShipment);
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
                                          tooltip: l.cloneChecklistItemTooltip,
                                          onPressed: () => _cloneChecklistItem(index),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _checklist.removeAt(index);
                                            });
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink(),

        _visitedTabs.contains(1)
            ? SavedConsultationsTab(
                isTaxReviewOnly: widget.isTaxReviewMode,
                onEdit: _loadConsultationForEdit,
                onViewDetails: showConsultationDetailsDialog,
              )
            : const SizedBox.shrink(),
        if (!widget.isTaxReviewMode) ...[
          // TAB 3: BROKER PRICE LISTS & CATALOG MANAGEMENT
          _visitedTabs.contains(2)
              ? const BrokerPriceListsTab()
              : const SizedBox.shrink(),
          // TAB 4: CLEARANCE QUOTATIONS & SMART AI EXTRACTOR
          _visitedTabs.contains(3)
              ? const CustomsClearanceQuotationsScreen(embedded: true)
              : const SizedBox.shrink(),
        ],
      ],
        ),
      ),
    );
  }

  void _cloneChecklistItem(int index) {
    if (index < 0 || index >= _checklist.length) return;
    final l = context.l10n;
    final orig = _checklist[index];
    final cloned = orig.copyWith(
      itemId: null,
      remarks: orig.remarks != null && orig.remarks!.isNotEmpty
          ? '${orig.remarks}${TableRowCloneHelper.copySuffix}'
          : TableRowCloneHelper.copySuffix.trim(),
      status: 'Pending',
    );
    setState(() {
      _checklist.insert(index + 1, cloned);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ ${l.checklistItemClonedSuccess}'),
        backgroundColor: AppTheme.wcagCobalt,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openCloneConsultationReviewDialog(BuildContext context, CustomsConsultationModel source) {
    final l = context.l10n;
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final initialTitle = '${source.title}${TableRowCloneHelper.copySuffix}';

    final copiedMap = <String, String>{
      l.customsBrokerLabel: source.brokerName.isNotEmpty ? source.brokerName : '—',
      l.customsInspectionReadiness: '${source.checklistItems.length} ${l.itemsAndDocsCount}',
    };
    if (source.estimatedDutiesEgp > 0) {
      copiedMap[l.totalTaxesAndDutiesCol] = '${source.estimatedDutiesEgp.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}';
    }
    if (source.brokerQuoteItems.isNotEmpty) {
      copiedMap[l.clearanceBrokerFeeItem] = '${source.brokerQuoteItems.length}';
    }

    final mandatorilyReset = <String>[
      l.cloneFieldConsultationCodeGenerated,
      l.cloneFieldImportFileReset,
      l.cloneFieldChecklistReset,
      l.cloneFieldStatusDraftBadge,
    ];

    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: CloneEntityReviewDialog(
            entityType: l.cloneConsultationDialogTitle,
            sourceCode: source.consultationCode,
            sourceTitle: initialTitle,
            suggestedNewCode: '${source.consultationCode}-CLONE',
            copiedFieldsSummary: copiedMap,
            mandatorilyResetFields: mandatorilyReset,
            allowCopyLineItems: true,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final messenger = ScaffoldMessenger.of(context);
              final payload = {
                'new_consultation_code': newCode,
                'new_title': newTitle,
                'copy_checklist_items': copyLineItems,
                'copy_broker_quote_items': copyLineItems,
                'notes': notes,
              };
              final cloned = await ref.read(customsConsultationsProvider.notifier).cloneConsultation(
                source.consultationId,
                payload,
              );
              if (cloned != null) {
                _loadConsultationForEdit(cloned);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('✨ ${l.cloneConsultationSuccess(cloned.consultationCode)}'),
                    backgroundColor: AppTheme.wcagEmerald,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _openSearchAndCloneConsultationDialog(BuildContext context, List<CustomsConsultationModel> consultations) {
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SearchAndCloneConsultationDialog(
            consultations: consultations,
            onSelectConsultation: (consultation) {
              Navigator.of(dialogCtx).pop();
              _openCloneConsultationReviewDialog(context, consultation);
            },
          ),
        ),
      ),
    );
  }

}
