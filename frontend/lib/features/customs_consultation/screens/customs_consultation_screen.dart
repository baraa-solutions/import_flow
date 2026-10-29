import '../widgets/widgets.dart';
export '../widgets/widgets.dart';
import '../utils/customs_estimate_payload_builder.dart';
import 'dart:async';
import '../../../core/localization/api_error_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_clearance_quotations/models/customs_clearance_quotation_model.dart';
import '../../customs_clearance_quotations/providers/customs_clearance_quotations_provider.dart';
import '../../customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart';
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
import '../utils/customs_consultation_payload_builder.dart';
import '../../financial_approval/providers/financial_approval_provider.dart';
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
  final TextEditingController _estimatedDutiesController = TextEditingController();

  // Customs Calculator State Controllers
  final TextEditingController _exchangeRateController = TextEditingController();
  /// Optional manual preliminary rate; only offered when the preliminary and final currencies differ.
  final TextEditingController _preliminaryRateController = TextEditingController();
  final TextEditingController _freightForeignController = TextEditingController();
  String _freightCurrency = 'USD';
  final TextEditingController _freightExchangeRateController = TextEditingController();
  final TextEditingController _freightEgpController = TextEditingController();
  final TextEditingController _insuranceEgpController = TextEditingController();
  String _insuranceOption = '0.5%'; // '0.5%', '1.0%', 'Custom'
  String _customsCurrency = 'USD';
  bool _isCustomsCalculatorExpanded = true;
  bool _groupByHsCode = true;

  // Customs Recalculation & Forecast Variance State
  CustomsRecalculationResponseModel? _recalculationResult;
  bool _isRecalculating = false;
  DateTime _studyDate = DateTime.now();

  Timer? _dutyEstimateDebounce;
  bool _isEstimatingDuty = false;
  List<CustomsItemCalcRow> _engineCalculatedLines = [];
  String? _currentEstimateCacheKey;
  int _dutyEstimateRequestId = 0;
  double? _engineGrandTotal;

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
  bool _isDirty = false;

  void _setDirty([bool dirty = true]) {
    if (_isDirty != dirty && mounted) {
      setState(() => _isDirty = dirty);
    }
  }

  void _markDirtyListener() {
    if (!_isDirty) _setDirty(true);
  }

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
    _exchangeRateController.addListener(_triggerDutyEstimateDebounced);
    _freightForeignController.addListener(_triggerDutyEstimateDebounced);
    _freightExchangeRateController.addListener(_triggerDutyEstimateDebounced);
    _freightEgpController.addListener(_triggerDutyEstimateDebounced);
    _insuranceEgpController.addListener(_triggerDutyEstimateDebounced);
    _titleController.addListener(_markDirtyListener);
    _notesController.addListener(_markDirtyListener);
    _estimatedDutiesController.addListener(_markDirtyListener);
    _exchangeRateController.addListener(_markDirtyListener);
    _preliminaryRateController.addListener(_markDirtyListener);
    _freightForeignController.addListener(_markDirtyListener);
    _freightExchangeRateController.addListener(_markDirtyListener);
    _freightEgpController.addListener(_markDirtyListener);
    _insuranceEgpController.addListener(_markDirtyListener);
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
    _dutyEstimateDebounce?.cancel();
    _exchangeRateController.removeListener(_triggerDutyEstimateDebounced);
    _freightForeignController.removeListener(_triggerDutyEstimateDebounced);
    _freightExchangeRateController.removeListener(_triggerDutyEstimateDebounced);
    _freightEgpController.removeListener(_triggerDutyEstimateDebounced);
    _insuranceEgpController.removeListener(_triggerDutyEstimateDebounced);
    _titleController.removeListener(_markDirtyListener);
    _notesController.removeListener(_markDirtyListener);
    _estimatedDutiesController.removeListener(_markDirtyListener);
    _exchangeRateController.removeListener(_markDirtyListener);
    _preliminaryRateController.removeListener(_markDirtyListener);
    _freightForeignController.removeListener(_markDirtyListener);
    _freightExchangeRateController.removeListener(_markDirtyListener);
    _freightEgpController.removeListener(_markDirtyListener);
    _insuranceEgpController.removeListener(_markDirtyListener);
    _tabController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _estimatedDutiesController.dispose();
    _exchangeRateController.dispose();
    _preliminaryRateController.dispose();
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
      _engineCalculatedLines = [];
      _currentEstimateCacheKey = null;
      _engineGrandTotal = null;
      _estimatedDutiesController.text = '';
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
    _triggerDutyEstimateDebounced();
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
      } else {
        _exchangeRateController.text = '';
      }
    } else {
      _exchangeRateController.text = '';
    }
    _triggerDutyEstimateDebounced();
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
      } else {
        _freightExchangeRateController.text = '';
      }
    } else {
      _freightExchangeRateController.text = '';
    }
    _recalculateFreightEgp();
    _triggerDutyEstimateDebounced();
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
        final amount = item.totalQuotationAmount;
        final currency = item.quotationCurrency;
        // A quote without an amount or currency cannot be compared (no invented currency).
        if (amount != null && currency != null && amount > highestQuotation) {
          highestQuotation = amount;
          highestCurrency = currency;
        }
      }
    }
    if (highestQuotation <= 0) return;

    // Convert to EGP using the customs exchange rate
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final matchedCurrency =
        currencies.where((c) => c.currencyCode == highestCurrency).firstOrNull;
    final rate = matchedCurrency?.latestCustomsRate ??
        double.tryParse(_exchangeRateController.text);
    if (rate == null || rate <= 0) return;
    final freightEgp = highestQuotation * rate;

    setState(() {
      _freightForeignController.text = highestQuotation.toStringAsFixed(2);
      _freightCurrency = highestCurrency;
      _freightExchangeRateController.text = rate.toStringAsFixed(4);
      _freightEgpController.text = freightEgp.toStringAsFixed(2);
    });
    _triggerDutyEstimateDebounced();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.freightAutoFetchedDetailsToast(
            highestQuotation.toStringAsFixed(2),
            highestCurrency,
            rate.toStringAsFixed(4),
            freightEgp.toStringAsFixed(2),
          ),
          severity: AppSeverity.info,
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
          AppTheme.snackBar(
            context,
            context.l10n.noPoItemsFoundForFileToast,
            severity: AppSeverity.warning,
          ),
        );
      }
      return;
    }

    final validLines = calcLines.where((l) => !l.isTariffMissing).toList();
    // ── Consolidate: group all HS Codes by document type ────────────────
    // One checklist item per document type, listing unique HS Codes inside.
    final acidHsCodes =
        validLines.where((l) => l.requiresAcid).map((l) => l.hsCode).toSet().toList();
    final cooHsCodes =
        validLines.where((l) => l.requiresCoo).map((l) => l.hsCode).toSet().toList();
    final goeicHsCodes =
        validLines.where((l) => l.requiresInspection).map((l) => l.hsCode).toSet().toList();

    // Group unique HS Codes per regulatory authority
    final Map<String, Set<String>> authHsMap = {};
    for (final line in validLines) {
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
        AppTheme.snackBar(
          context,
          l.hsRequirementsSyncedToast(calcLines.length, addedCount),
          severity: AppSeverity.success,
        ),
      );
    }
  }

  Future<void> _fetchReconciledFinalInvoiceAndRecalculate() async {
    final l = context.l10n;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.selectImportFileFirstToast,
          severity: AppSeverity.warning,
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
        preliminaryExchangeRate: (_recalculationResult?.hasDifferentCurrencies ?? false)
            ? double.tryParse(_preliminaryRateController.text.trim())
            : null,
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
          AppTheme.snackBar(
            context,
            res.isReconciled
                ? '(${res.finalInvoiceNumber ?? ""})'
                : '—',
            severity: res.isReconciled ? AppSeverity.success : AppSeverity.info,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            ApiErrorText.of(context.l10n, e),
            severity: AppSeverity.danger,
            duration: const Duration(seconds: 8),
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
      AppTheme.snackBar(
        context,
        context.l10n.recalculatedTaxesAppliedToast(
          _recalculationResult!.finalTotalTaxesEgp.toStringAsFixed(2),
        ),
        severity: AppSeverity.success,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _buildEstimateCacheKey() {
    return '$_selectedImportFileId|$_selectedPoId|$_customsCurrency|'
        '${_exchangeRateController.text.trim()}|'
        '${_freightForeignController.text.trim()}|$_freightCurrency|'
        '${_freightExchangeRateController.text.trim()}|'
        '${_freightEgpController.text.trim()}|$_insuranceOption|'
        '${_insuranceEgpController.text.trim()}|'
        '${_studyDate.year}-${_studyDate.month}-${_studyDate.day}';
  }

  void _triggerDutyEstimateDebounced() {
    _dutyEstimateDebounce?.cancel();
    _dutyEstimateDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _fetchDutyEstimateFromEngine();
      }
    });
  }

  Future<void> _fetchDutyEstimateFromEngine() async {
    final int reqId = ++_dutyEstimateRequestId;
    final String requestKey = _buildEstimateCacheKey();

    final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
    final tariffsList = ref.read(customsTariffProvider).valueOrNull ?? [];

    ImportFileModel? file;
    List<PurchaseOrderModel> matchingPOs = [];
    if (_selectedImportFileId != null) {
      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
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

    final List<POLineItemModel> allPoLines = [];
    String? defaultOriginCountry;
    for (final po in matchingPOs) {
      if (defaultOriginCountry == null && po.countryOfOrigin != null && po.countryOfOrigin!.trim().isNotEmpty) {
        defaultOriginCountry = po.countryOfOrigin!.trim();
      }
      for (final item in po.items) {
        allPoLines.add(item);
      }
    }

    if (allPoLines.isEmpty) {
      if (mounted && reqId == _dutyEstimateRequestId) {
        setState(() {
          _engineCalculatedLines = [];
          _currentEstimateCacheKey = null;
          _engineGrandTotal = null;
          _isEstimatingDuty = false;
        });
      }
      return;
    }

    final double? exchangeRate = double.tryParse(_exchangeRateController.text.trim());
    if (exchangeRate == null || exchangeRate <= 0) {
      final uncalculated = CustomsEstimatePayloadBuilder.mapEngineResponseToCalcRows(
        engineResponse: {},
        allLines: allPoLines,
        tariffs: tariffsList,
        defaultOriginCountry: defaultOriginCountry,
        exchangeRate: exchangeRate,
      );
      if (mounted && reqId == _dutyEstimateRequestId) {
        setState(() {
          _engineCalculatedLines = uncalculated;
          _currentEstimateCacheKey = null;
          _engineGrandTotal = null;
          _isEstimatingDuty = false;
        });
      }
      return;
    }

    double totalInvoicesForeign = 0.0;
    if (file != null && file.invoicesData.isNotEmpty) {
      for (final inv in file.invoicesData) {
        totalInvoicesForeign += inv.amount;
      }
    }

    final double poItemsFobSum = allPoLines.fold(0.0, (s, l) => s + l.totalPrice);
    final double scaleFactor = (totalInvoicesForeign > 0 && poItemsFobSum > 0)
        ? (totalInvoicesForeign / poItemsFobSum)
        : 1.0;

    final double freightForeign = double.tryParse(_freightForeignController.text.trim()) ?? 0.0;
    final double? freightFxTyped = double.tryParse(_freightExchangeRateController.text.trim());
    final double? freightFxRateForEngine = (freightFxTyped != null && freightFxTyped > 0) ? freightFxTyped : null;
    final double totalFreightEgp = freightForeign > 0 && freightFxRateForEngine != null
        ? (freightForeign * freightFxRateForEngine)
        : (_freightCurrency == _customsCurrency && freightForeign > 0 && exchangeRate > 0)
            ? (freightForeign * exchangeRate)
            : (double.tryParse(_freightEgpController.text.trim()) ?? 0.0);

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

    final payload = CustomsEstimatePayloadBuilder.buildPayload(
      lines: allPoLines,
      tariffs: tariffsList,
      currency: _customsCurrency,
      exchangeRate: exchangeRate,
      freightForeign: freightForeign,
      freightCurrency: _freightCurrency,
      freightExchangeRate: freightFxRateForEngine,
      freightEgp: totalFreightEgp,
      insuranceEgp: totalInsuranceEgp,
      insuranceOption: _insuranceOption,
      estimateDate: _studyDate,
      scaleFactor: scaleFactor,
      defaultOriginCountry: defaultOriginCountry,
    );

    if (payload == null) {
      final uncalculated = CustomsEstimatePayloadBuilder.mapEngineResponseToCalcRows(
        engineResponse: {},
        allLines: allPoLines,
        tariffs: tariffsList,
        defaultOriginCountry: defaultOriginCountry,
        scaleFactor: scaleFactor,
        exchangeRate: exchangeRate,
      );
      if (mounted && reqId == _dutyEstimateRequestId) {
        setState(() {
          _engineCalculatedLines = uncalculated;
          _currentEstimateCacheKey = null;
          _engineGrandTotal = null;
          _isEstimatingDuty = false;
        });
      }
      return;
    }

    if (mounted && reqId == _dutyEstimateRequestId) {
      setState(() => _isEstimatingDuty = true);
    }

    try {
      final res = await ref.read(customsTariffProvider.notifier).estimateMultiItemDuty(payload);
      if (!mounted) return;
      if (reqId != _dutyEstimateRequestId) return; // Ignore out of date responses
      if (res != null) {
        final grandTotal = CustomsEstimatePayloadBuilder.parseToDouble(res['grand_total_payable_egp']) ?? 0.0;
        final rows = CustomsEstimatePayloadBuilder.mapEngineResponseToCalcRows(
          engineResponse: res,
          allLines: allPoLines,
          tariffs: tariffsList,
          defaultOriginCountry: defaultOriginCountry,
          scaleFactor: scaleFactor,
          exchangeRate: exchangeRate,
        );
        setState(() {
          _engineCalculatedLines = rows;
          _engineGrandTotal = grandTotal;
          _currentEstimateCacheKey = requestKey;
          _isEstimatingDuty = false;
          _estimatedDutiesController.text = grandTotal.toStringAsFixed(2);
        });
      } else {
        setState(() {
          _engineCalculatedLines = [];
          _currentEstimateCacheKey = null;
          _engineGrandTotal = null;
          _isEstimatingDuty = false;
        });
      }
    } catch (e) {
      if (mounted && reqId == _dutyEstimateRequestId) {
        setState(() {
          _engineCalculatedLines = [];
          _currentEstimateCacheKey = null;
          _engineGrandTotal = null;
          _isEstimatingDuty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            ApiErrorText.of(context.l10n, e),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  List<CustomsItemCalcRow> _calculateCustomsLines() {
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

    final List<POLineItemModel> allPoLines = [];
    String? defaultOriginCountry;
    for (final po in matchingPOs) {
      if (defaultOriginCountry == null && po.countryOfOrigin != null && po.countryOfOrigin!.trim().isNotEmpty) {
        defaultOriginCountry = po.countryOfOrigin!.trim();
      }
      for (final item in po.items) {
        allPoLines.add(item);
      }
    }

    if (allPoLines.isEmpty) {
      return [];
    }

    final String currentKey = _buildEstimateCacheKey();
    if (_engineCalculatedLines.isNotEmpty && _currentEstimateCacheKey == currentKey) {
      return _engineCalculatedLines;
    }

    final double? exchangeRate = double.tryParse(_exchangeRateController.text.trim());
    return CustomsEstimatePayloadBuilder.mapEngineResponseToCalcRows(
      engineResponse: {},
      allLines: allPoLines,
      tariffs: tariffsList,
      defaultOriginCountry: defaultOriginCountry,
      exchangeRate: exchangeRate,
    );
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
        isTariffMissing: lines.any((l) => l.isTariffMissing),
        status: lines.any((l) => l.isTariffMissing) ? 'TARIFF_MISSING' : first.status,
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
      _engineCalculatedLines = [];
      _currentEstimateCacheKey = null;
      _engineGrandTotal = session.estimatedDutiesEgp;
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

    if (session.importFileId != null) {
      _onImportFileChanged(session.importFileId);
    } else if (session.poId != null) {
      final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
      final po = allPOs.where((p) => p.poId == session.poId).firstOrNull;
      if (po != null && po.currencyCode != null && po.currencyCode!.isNotEmpty) {
        _customsCurrency = po.currencyCode!;
        _updateExchangeRateForCurrency(po.currencyCode!);
      }
      _triggerDutyEstimateDebounced();
    } else {
      _triggerDutyEstimateDebounced();
    }
    _setDirty(false);
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
      AppTheme.snackBar(
        context,
        l.brokerQuoteExtractedToast(extracted['broker_name'] ?? l.defaultCustomsBrokerName),
        severity: AppSeverity.success,
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
    final savedFile = await CustomsExportService.exportCustomsStudyToExcel(
      context: context,
      title: _titleController.text.trim(),
      importFileCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : null,
      brokerName: _selectedBrokerName.isNotEmpty ? _selectedBrokerName : (context.l10n.ccCustomsBroker),
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
        AppTheme.snackBar(
          context,
          savedFile,
          severity: AppSeverity.success,
        ),
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
    await CustomsConsultationPdfService.printOrPreviewCalculationReportPdf(
      context: context,
      title: _titleController.text.trim(),
      importFileCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : null,
      brokerName: _selectedBrokerName.isNotEmpty ? _selectedBrokerName : (context.l10n.ccCustomsBroker),
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
    await CustomsExportService.copyCustomsDutyDossier(
      context: context,
      title: _titleController.text.trim(),
      importFileCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : null,
      brokerName: _selectedBrokerName.isNotEmpty ? _selectedBrokerName : (context.l10n.ccCustomsBroker),
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

    final double? fxRate = double.tryParse(_exchangeRateController.text.trim());
    if (fxRate == null || fxRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.customsFxRateRequired,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    if (_isEstimatingDuty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          'يرجى الانتظار حتى انتهاء حساب الرسوم الجمركية من محرك الجمارك.',
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    final rawCalcLines = _calculateCustomsLines();
    if (rawCalcLines.any((l) => l.isTariffMissing)) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.customsMissingTariffBlockSave,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    if ((_selectedImportFileId != null || _selectedPoId != null) &&
        (_engineGrandTotal == null || _currentEstimateCacheKey == null || rawCalcLines.any((l) => !l.isCalculated))) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          'لم يتم حساب تقدير الرسوم الجمركية بعد بواسطة محرك الجمارك.',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

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
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.customsBrokerFieldIssue,
          severity: AppSeverity.danger,
        ),
      );
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

    final estimatedDuties = _engineGrandTotal ?? (double.tryParse(_estimatedDutiesController.text.trim()) ?? 0.0);
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
      final payload = CustomsConsultationPayloadBuilder.buildSavePayload(
        title: titleToSave,
        brokerId: _selectedBrokerId,
        brokerName: _selectedBrokerName,
        brokerContactPerson: _brokerContactPerson,
        brokerPriceListId: _brokerPriceListId,
        importFileId: _selectedImportFileId,
        poId: _selectedPoId,
        projectId: _selectedProjectId,
        estimatedDutiesEgp: estimatedDuties,
        totalBrokerFeesEgp: totalBrokerFees,
        notes: _notesController.text.trim(),
        checklistItems: _checklist.map((item) => item.toJson()).toList(),
        brokerQuoteItems: _brokerQuoteItems.map((item) => item.toJson()).toList(),
        isTaxReviewMode: widget.isTaxReviewMode,
      );

      if (_editingConsultationId != null) {
        final updated = await ref
            .read(customsConsultationsProvider.notifier)
            .updateConsultation(_editingConsultationId!, payload);
        if (mounted && updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              '${l.customsStudyUpdatedSuccess} (${updated.consultationCode})',
              severity: AppSeverity.success,
            ),
          );
          setState(() {
            _editingConsultationId = null;
            _editingConsultationCode = null;
            _isDirty = false;
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
            AppTheme.snackBar(
              context,
              '${l.customsStudySavedSuccess} (${created.consultationCode})',
              severity: AppSeverity.success,
            ),
          );
          _setDirty(false);
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
          final warningMsg = context.l10n.ccCostLinkageAlertThisImportFile(linkedBudget.budgetCode);
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.snackBar(
                  context,
                  warningMsg,
                  severity: AppSeverity.warning,
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: context.l10n.ccOK,
                    textColor: AppTheme.white,
                    onPressed: () {},
                  ),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted && ApiErrorText.code(e) == ApiErrorCode.consultationExists) {
        // A consultation for this import file already exists: readable message + open it.
        final existingId = ApiErrorText.detail(e)?['consultation_id'];
        final existingCode = ApiErrorText.detail(e)?['consultation_code'];
        showExistingRecordSnack(
          context,
          message: ApiErrorText.of(l, e),
          actionLabel: l.openExistingRecord,
          onOpen: () async {
            bool matches(CustomsConsultationModel c) =>
                c.consultationId == existingId || (existingCode != null && c.consultationCode == existingCode);
            var list = ref.read(customsConsultationsProvider).valueOrNull ?? const <CustomsConsultationModel>[];
            var found = list.where(matches).toList();
            if (found.isEmpty) {
              await ref.read(customsConsultationsProvider.notifier).fetchConsultations();
              list = ref.read(customsConsultationsProvider).valueOrNull ?? const <CustomsConsultationModel>[];
              found = list.where(matches).toList();
            }
            if (found.isNotEmpty && mounted) _loadConsultationForEdit(found.first);
          },
        );
      } else if (mounted) {
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
    final egpLabel = context.l10n.financialSettlementCurrencyEgp;
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
    final double? exchangeRate = double.tryParse(_exchangeRateController.text.trim());
    final double freightForeign = double.tryParse(_freightForeignController.text.trim()) ?? 0.0;
    final double freightFxRate = double.tryParse(_freightExchangeRateController.text.trim()) ?? (exchangeRate ?? 0.0);
    final double totalFreightEgp = freightForeign > 0
        ? (freightForeign * freightFxRate)
        : (double.tryParse(_freightEgpController.text.trim()) ?? 0.0);
    final double totalInsuranceEgp = double.tryParse(_insuranceEgpController.text.trim()) ?? 0.0;
    final validCalcLines = rawCalcLines.where((l) => !l.isTariffMissing).toList();
    final totalFobForeign = validCalcLines.fold(0.0, (s, l) => s + l.foreignPrice);
    final totalFobEgp = validCalcLines.fold(0.0, (s, l) => s + l.fobEgp);
    final totalCandFEgp = totalFobEgp + totalFreightEgp;
    final totalCifEgp = validCalcLines.fold(0.0, (s, l) => s + l.cifEgp);
    final totalCifForeign = (exchangeRate != null && exchangeRate > 0) ? (totalCifEgp / exchangeRate) : 0.0;
    final totalDutyEgp = validCalcLines.fold(0.0, (s, l) => s + l.dutyAmountEgp);
    final totalVatEgp = validCalcLines.fold(0.0, (s, l) => s + l.vatAmountEgp);
    final totalTaxesAndDutiesEgp = validCalcLines.fold(0.0, (s, l) => s + l.totalTaxesAndDutiesEgp);

    bool hasInvoicesWithoutPoLines = false;
    if (_selectedImportFileId != null) {
      final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
      final file = importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
      if (file != null && file.invoicesData.isNotEmpty) {
        final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;
        final matchingPOs = allPOs.where((p) =>
            (p.importFileId != null && p.importFileId == file.importFileId) ||
            (file.importFileCode.isNotEmpty && p.importFileCode != null && p.importFileCode == file.importFileCode) ||
            (file.poIds != null && p.poId != null && file.poIds!.contains(p.poId))).toList();
        hasInvoicesWithoutPoLines = matchingPOs.isEmpty || matchingPOs.every((p) => p.items.isEmpty);
      }
    }

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
                        color: AppTheme.cobalt.withValues(alpha: 0.2),
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
                        color: AppTheme.cobalt.withValues(alpha: 0.2),
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
      isDirty: _isDirty,
      onDiscard: () => _setDirty(false),
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
                      ConsultationMetricBadge(title: l.customsInspectionReadiness, value: '$liveReadinessPct%', color: AppTheme.cobalt),
                      ConsultationMetricBadge(title: l.itemsAndDocsCount, value: '${_checklist.length}', color: AppTheme.textMuted),
                      ConsultationMetricBadge(
                        title: l.blockingIssuesCount,
                        value: '$blockingCount',
                        color: blockingCount > 0 ? AppTheme.crimson : AppTheme.emerald,
                        onTap: () => showBlockingIssuesDialog(context, _checklist, (val) => setState(() { _checklist.clear(); _checklist.addAll(val); })),
                      ),
                      // Broker Quotations Comparison Button (Clearance Mode Only)
                      if (!widget.isTaxReviewMode)
                        AppButton(
                          label: l.clearanceQuotesScreenTitle,
                          icon: Icons.compare_arrows_rounded,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          onPressed: _openBrokerQuotationComparisonDialog,
                        ),
                      // Search & Clone Consultation Button (UX-CLONE-011)
                      Tooltip(
                        message: l.searchAndCloneConsultationBtn,
                        child: AppButton(
                          key: const ValueKey('searchAndCloneConsultationBtn'),
                          label: l.searchAndCloneConsultationBtn,
                          icon: Icons.control_point_duplicate_rounded,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.small,
                          onPressed: () => _openSearchAndCloneConsultationDialog(context, consultationsList),
                        ),
                      ),
                      // 1. Live Refresh
                      AppButton(
                        label: l.liveRefresh,
                        icon: Icons.refresh,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
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

                      // 2. Clear Form & Start New
                      AppButton(
                        label: l.clearAndStartNew,
                        icon: Icons.cleaning_services_outlined,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
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
                            _engineCalculatedLines = [];
                            _currentEstimateCacheKey = null;
                            _engineGrandTotal = null;
                            _estimatedDutiesController.clear();
                            _initializeDefaultChecklist();
                          });
                        },
                      ),

                      // 3. TSV Export/Copy Button
                      AppButton(
                        label: l.customsTaxExportTsvBtn,
                        icon: Icons.table_view_outlined,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: () => _copyCustomsStudyTsv(calcLines),
                      ),

                      // 4. Excel Export Button
                      AppButton(
                        label: l.customsTaxExportExcelBtn,
                        icon: Icons.description_outlined,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: () => _exportCustomsStudyExcel(calcLines, totalFreightEgp, totalInsuranceEgp, exchangeRate ?? 0.0),
                      ),

                      // 5. PDF Print/Preview Button
                      AppButton(
                        label: l.customsTaxPrintPdfBtn,
                        icon: Icons.picture_as_pdf_outlined,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: () => _printOrSaveCustomsStudyPdf(calcLines, totalFreightEgp, totalInsuranceEgp, exchangeRate ?? 0.0),
                      ),

                      // 6. Dossier Copy Button
                      AppButton(
                        label: l.customsTaxCopyDossierBtn,
                        icon: Icons.copy_all_outlined,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: () => _copyCustomsStudyDossier(calcLines, totalFreightEgp, totalInsuranceEgp, exchangeRate ?? 0.0),
                      ),

                      // 7. Smart Clearance Quote Extractor Button (Clearance Mode Only)
                      if (!widget.isTaxReviewMode)
                        AppButton(
                          label: l.smartClearanceQuoteExtractor,
                          icon: Icons.auto_awesome,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.small,
                          onPressed: () {
                            showSmartClearanceExtractorDialog(
                              context,
                              ref,
                              onExtracted: _applyExtractedQuotationToConsultation,
                            );
                          },
                        ),

                      // 8. Save Draft & Continue Later
                      AppButton(
                        label: l.saveDraftContinueLater,
                        icon: Icons.save_outlined,
                        variant: AppButtonVariant.primary,
                        size: AppButtonSize.small,
                        onPressed: _isSaving ? null : _saveConsultation,
                      ),

                      // 9. Final Save / Update
                      AppButton(
                        label: _editingConsultationId != null
                              ? l.saveConsultationChanges
                              : (widget.isTaxReviewMode ? l.saveTaxReviewSession : l.saveCustomsStudy),
                        icon: _editingConsultationId != null ? Icons.save_as : Icons.save,
                        variant: AppButtonVariant.success,
                        size: AppButtonSize.small,
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : _saveConsultation,
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
                        color: AppTheme.orangeLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.orange, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, color: AppTheme.orange, size: 28),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.wcagOrange),
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
                                              color: AppTheme.orangeLight,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppTheme.orange),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _editingConsultationCode!,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.wcagOrange),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.copy, size: 12, color: AppTheme.wcagOrange),
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
                                  style: const TextStyle(fontSize: 12, color: AppTheme.charcoal),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          AppButton(
                            label: l.saveConsultationChanges,
                            icon: Icons.save_as_rounded,
                            variant: AppButtonVariant.warning,
                            size: AppButtonSize.small,
                            onPressed: _isSaving ? null : _saveConsultation,
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: l.saveAsNewCopy,
                            icon: Icons.copy_rounded,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            onPressed: () {
                              setState(() {
                                _editingConsultationId = null;
                                _editingConsultationCode = null;
                                _titleController.text = '${_titleController.text}${TableRowCloneHelper.copySuffix}';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                AppTheme.snackBar(
                                  context,
                                  l.convertedToNewStudyToast,
                                  severity: AppSeverity.info,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.textMuted),
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
                    color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                                  decoration: BoxDecoration(color: AppTheme.orangeLight, borderRadius: BorderRadius.circular(6)),
                                  child: Text('${l.statusCol}: $_editingConsultationCode', style: const TextStyle(color: AppTheme.wcagOrange, fontWeight: FontWeight.bold, fontSize: 12)),
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
                                  color: AppTheme.cobalt.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
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
                                              const Icon(Icons.business, size: 16, color: AppTheme.charcoal),
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
                                              color: AppTheme.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppTheme.cloudWhite),
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
                      referenceUsdExchangeRate: double.tryParse(_exchangeRateController.text.trim()),
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
                  CustomsDutiesCalculatorTab(
                    isTaxReviewMode: widget.isTaxReviewMode,
                    customsCurrency: _customsCurrency,
                    onCustomsCurrencyChanged: (v) {
                      setState(() {
                        _customsCurrency = v;
                        _updateExchangeRateForCurrency(v);
                      });
                    },
                    exchangeRateController: _exchangeRateController,
                    onExchangeRateChanged: () {
                      setState(() {});
                      _triggerDutyEstimateDebounced();
                    },
                    studyDate: _studyDate,
                    onStudyDateChanged: (picked) {
                      setState(() => _studyDate = picked);
                      _triggerDutyEstimateDebounced();
                    },
                    currenciesList: currenciesList,
                    freightForeignController: _freightForeignController,
                    freightCurrency: _freightCurrency,
                    onFreightCurrencyChanged: (v) {
                      setState(() {
                        _freightCurrency = v;
                        _updateFreightExchangeRateForCurrency(v);
                      });
                    },
                    freightExchangeRateController: _freightExchangeRateController,
                    freightEgpController: _freightEgpController,
                    onRecalculateFreightEgp: () => setState(() => _recalculateFreightEgp()),
                    selectedImportFileId: _selectedImportFileId,
                    onAutoFetchFreightFromScenarios: _selectedImportFileId != null
                        ? () => _autoFetchFreightFromScenarios(_selectedImportFileId!)
                        : null,
                    insuranceOption: _insuranceOption,
                    onInsuranceOptionChanged: (opt) {
                      setState(() => _insuranceOption = opt);
                      _triggerDutyEstimateDebounced();
                    },
                    insuranceEgpController: _insuranceEgpController,
                    totalFobForeign: totalFobForeign,
                    totalFobEgp: totalFobEgp,
                    totalCandFEgp: totalCandFEgp,
                    totalFreightEgp: totalFreightEgp,
                    totalInsuranceEgp: totalInsuranceEgp,
                    totalCifEgp: totalCifEgp,
                    totalCifForeign: totalCifForeign,
                    exchangeRate: exchangeRate,
                    calcLines: calcLines,
                    groupByHsCode: _groupByHsCode,
                    onGroupByHsCodeChanged: (val) => setState(() => _groupByHsCode = val),
                    recalculationResult: _recalculationResult,
                    preliminaryRateController: _preliminaryRateController,
                    onApplyNewFees: _applyAndSaveRecalculatedFees,
                    onCloseRecalculation: () => setState(() => _recalculationResult = null),
                    hasInvoicesWithoutPoLines: hasInvoicesWithoutPoLines,
                    isCustomsCalculatorExpanded: _isCustomsCalculatorExpanded,
                    onToggleCustomsCalculatorExpanded: () =>
                        setState(() => _isCustomsCalculatorExpanded = !_isCustomsCalculatorExpanded),
                    isRecalculating: _isRecalculating,
                    onFetchReconciledFinalInvoice: _fetchReconciledFinalInvoiceAndRecalculate,
                    onSyncHsRequirementsToChecklist: () =>
                        _syncHsRequirementsToChecklist(silent: false),
                    totalDutyEgp: totalDutyEgp,
                    totalVatEgp: totalVatEgp,
                    totalTaxesAndDutiesEgp: totalTaxesAndDutiesEgp,
                    engineGrandTotal: _engineGrandTotal,
                    isEstimatingDuty: _isEstimatingDuty,
                    onApplyAndLinkFinancialEstimate: () {
                      final appliedValue = _engineGrandTotal ?? totalTaxesAndDutiesEgp;
                      setState(() {
                        _estimatedDutiesController.text = appliedValue.toStringAsFixed(2);
                      });
                      AppTheme.snackBar(
                        context,
                        '\u2705 ${l.applyAndLinkFinancialEstimate}: ${appliedValue.toStringAsFixed(2)} $egpLabel',
                        severity: AppSeverity.success,
                      );
                    },
                    editingConsultationId: _editingConsultationId,
                    editingConsultationCode: _editingConsultationCode,
                    selectedBrokerId: _selectedBrokerId,
                    selectedBrokerName: _selectedBrokerName,
                    title: _titleController.text.trim(),
                    checklist: _checklist,
                    brokerQuoteItems: _brokerQuoteItems,
                  ),
                  const SizedBox(height: 20),

                  // Checklist Table & Controls
                  Card(
                    elevation: 2,
                    color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                              final btnWidget = AppButton(
                                label: l.addNewChecklistItem,
                                icon: Icons.add,
                                variant: AppButtonVariant.primary,
                                onPressed: _addChecklistItem,
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
                                                  decoration: BoxDecoration(color: AppTheme.cobalt.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                                  child: CopyableText(item.hsCode!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                                ),
                                              CopyableText(_getLocalizedDocType(item.documentType, l), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ],
                                          ),
                                          if (item.regulatoryAgency != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2.0),
                                              child: CopyableText('${l.responsiblePartyLabel}: ${item.regulatoryAgency == 'GOEIC' ? l.goeicAgencyName : item.regulatoryAgency}', style: const TextStyle(fontSize: 11, color: AppTheme.cobalt, fontWeight: FontWeight.bold)),
                                            ),
                                          if (item.remarks != null && item.remarks!.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2.0),
                                              child: CopyableText(_getLocalizedRemarks(item.remarks, l), style: const TextStyle(fontSize: 11, color: AppTheme.textStrong)),
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
                                                icon: Icon(item.isBlockingShipment ? Icons.block : Icons.check_circle_outline, color: item.isBlockingShipment ? AppTheme.crimson : AppTheme.textMuted, size: 20),
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
                                                icon: const Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 20),
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
                                                      decoration: BoxDecoration(color: AppTheme.cobalt.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                                      child: CopyableText(item.hsCode!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                                    ),
                                                  CopyableText(_getLocalizedDocType(item.documentType, l), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                ],
                                              ),
                                              if (item.regulatoryAgency != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2.0),
                                                  child: CopyableText('${l.responsiblePartyLabel}: ${item.regulatoryAgency == 'GOEIC' ? l.goeicAgencyName : item.regulatoryAgency}', style: const TextStyle(fontSize: 11, color: AppTheme.cobalt, fontWeight: FontWeight.bold)),
                                                ),
                                              if (item.remarks != null && item.remarks!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2.0),
                                                  child: CopyableText(_getLocalizedRemarks(item.remarks, l), style: const TextStyle(fontSize: 11, color: AppTheme.textStrong)),
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
                                          icon: Icon(item.isBlockingShipment ? Icons.block : Icons.check_circle_outline, color: item.isBlockingShipment ? AppTheme.crimson : AppTheme.textMuted, size: 20),
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
                                          icon: const Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 20),
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
      AppTheme.snackBar(
        context,
        l.checklistItemClonedSuccess,
        severity: AppSeverity.info,
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
      copiedMap[l.totalTaxesAndDutiesCol] = '${source.estimatedDutiesEgp.toStringAsFixed(2)} ${context.l10n.financialSettlementCurrencyEgp}';
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
          child: SelectionArea(
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
                if (!context.mounted) return;
                _loadConsultationForEdit(cloned);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  AppTheme.snackBar(
                    context,
                    l.cloneConsultationSuccess(cloned.consultationCode),
                    severity: AppSeverity.success,
                  ),
                );
              }
            },
          ),
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


  void _openBrokerQuotationComparisonDialog() {
    final l = context.l10n;
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final rfqsState = ref.read(customsClearanceQuotationsProvider);
    final rfqs = rfqsState.valueOrNull ?? [];

    List<CustomsClearanceQuotationItemModel> comparisonQuotes = [];
    String? rfqCode;
    String? rfqTitle;

    if (_selectedImportFileId != null) {
      final matchingRfqs = rfqs.where((r) => r.importFileId == _selectedImportFileId).toList();
      if (matchingRfqs.isNotEmpty) {
        final rfq = matchingRfqs.first;
        comparisonQuotes = rfq.quotations;
        rfqCode = rfq.rfqCode;
        rfqTitle = rfq.title;
      }
    }

    if (comparisonQuotes.isEmpty) {
      for (final rfq in rfqs) {
        comparisonQuotes.addAll(rfq.quotations);
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SelectionArea(
            child: Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: BrokerQuotationComparisonTable(
                          quotations: comparisonQuotes,
                          rfqCode: rfqCode,
                          rfqTitle: rfqTitle,
                          selectedBrokerId: _selectedBrokerId,
                          onSelectQuote: (quote) {
                            setState(() {
                              _selectedBrokerId = quote.providerId;
                              _loadBrokerPriceList(quote.providerId);
                            });
                            Navigator.of(dialogCtx).pop();
                            AppTheme.snackBar(
                              context,
                              '\u2705 ${l.clearanceQuotesAwardedBannerPrefix}: ${quote.providerName}',
                              severity: AppSeverity.success,
                            );
                          },
                          onAward: (quotationId) async {
                            final matchingRfq = rfqs.firstWhere(
                              (r) => r.quotations.any((q) => q.quotationId == quotationId),
                              orElse: () => rfqs.first,
                            );
                            try {
                              await ref
                                  .read(customsClearanceQuotationsProvider.notifier)
                                  .awardQuotation(matchingRfq.rfqId, quotationId);
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }
                              if (mounted) {
                                AppTheme.snackBar(
                                  context,
                                  '\u2705 ${l.clearanceQuotesStatusAwarded}',
                                  severity: AppSeverity.success,
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                AppTheme.snackBar(
                                  context,
                                  '\u274c ${ApiErrorText.of(context.l10n, e)}',
                                  severity: AppSeverity.danger,
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: AppButton(
                          label: l.close,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
