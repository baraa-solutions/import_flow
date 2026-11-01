import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart';
import '../../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../../external_service_providers/providers/partners_provider.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../projects/providers/projects_provider.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../../models/customs_consultation_model.dart';
import '../../providers/customs_consultation_provider.dart';
import '../../services/customs_consultation_pdf_service.dart';
import '../../services/customs_export_service.dart';
import '../../utils/customs_estimate_payload_builder.dart';
import '../broker_quote_details_card.dart';
import '../dialogs/consultation_clone_dialog.dart';
import '../add_checklist_item_dialog.dart';
import '../add_custom_expense_dialog.dart';
import '../blocking_issues_dialog.dart';
import 'consultation_calc_actions_bar.dart';
import 'consultation_calc_broker_quote_helper.dart';
import 'consultation_calc_checklist_card.dart';
import 'consultation_calc_edit_banner.dart';
import 'consultation_calc_engine_helper.dart';
import 'consultation_calc_header_card.dart';
import 'consultation_calc_items_table.dart';
import 'consultation_calc_logic_helper.dart';
import 'consultation_calc_save_helper.dart';
import 'consultation_calc_scenarios_comparison.dart';
import 'consultation_calc_summary_card.dart';

/// State, controllers, calculations, and layout coordinator for the consultation calculator tab.
class ConsultationCalcCoordinator {
  final WidgetRef ref;
  final bool isTaxReviewMode;
  final ValueChanged<bool>? onDirtyChanged;
  final ValueChanged<int?>? onImportFileChanged;
  final ValueChanged<CustomsConsultationModel>? onSaved;
  final void Function(Object error)? onApiError;
  final void Function(VoidCallback fn) setState;
  final BuildContext Function() getContext;
  final bool Function() isMounted;

  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  final notesController = TextEditingController();
  final estimatedDutiesController = TextEditingController();
  final exchangeRateController = TextEditingController();
  final preliminaryRateController = TextEditingController();
  final freightForeignController = TextEditingController();
  String freightCurrency = 'USD';
  final freightExchangeRateController = TextEditingController();
  final freightEgpController = TextEditingController();
  final insuranceEgpController = TextEditingController();
  String insuranceOption = '0.5%';
  String customsCurrency = 'USD';
  bool isCustomsCalculatorExpanded = true;
  bool groupByHsCode = true;

  CustomsRecalculationResponseModel? recalculationResult;
  bool isRecalculating = false;
  DateTime studyDate = DateTime.now();

  Timer? _dutyEstimateDebounce;
  bool isEstimatingDuty = false;
  List<CustomsItemCalcRow> engineCalculatedLines = [];
  String? currentEstimateCacheKey;
  int _dutyEstimateRequestId = 0;
  double? engineGrandTotal;

  int? editingConsultationId;
  String? editingConsultationCode;
  int? selectedBrokerId;
  String selectedBrokerName = '';
  String? brokerContactPerson;
  int? selectedImportFileId;
  int? selectedPoId;
  int? selectedProjectId;

  final List<CustomsChecklistItemModel> checklist = [];
  final List<CustomsBrokerQuoteItemModel> brokerQuoteItems = [];
  int? brokerPriceListId;
  String? brokerPriceListTitle;
  bool isBrokerQuoteExpanded = true;
  bool isLoadingPriceList = false;
  String brokerExpenseCategoryFilter = 'All';

  bool isSaving = false;
  bool isDirty = false;
  bool hasCustomTitle = false;

  ConsultationCalcCoordinator({
    required this.ref,
    required this.isTaxReviewMode,
    this.onDirtyChanged,
    this.onImportFileChanged,
    this.onSaved,
    this.onApiError,
    required this.setState,
    required this.getContext,
    required this.isMounted,
  });

  void init() {
    titleController = TextEditingController();
    for (final c in [
      exchangeRateController,
      freightForeignController,
      freightExchangeRateController,
      freightEgpController,
      insuranceEgpController,
    ]) {
      c.addListener(triggerDutyEstimateDebounced);
    }
    for (final c in [
      titleController,
      notesController,
      estimatedDutiesController,
      exchangeRateController,
      preliminaryRateController,
      freightForeignController,
      freightExchangeRateController,
      freightEgpController,
      insuranceEgpController,
    ]) {
      c.addListener(_markDirty);
    }
    checklist.addAll(ConsultationCalcLogicHelper.createDefaultChecklist());
    Future.microtask(refreshProviders);
  }

  void _setDirty([bool dirty = true]) {
    if (isDirty != dirty && isMounted()) {
      setState(() => isDirty = dirty);
      onDirtyChanged?.call(dirty);
    }
  }

  void _markDirty() {
    if (!isDirty) _setDirty(true);
  }

  void refreshProviders() {
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
    if (!isTaxReviewMode) {
      if (!ref.read(clearanceExpenseTypesProvider).isLoading) {
        ref.read(clearanceExpenseTypesProvider.notifier).fetchExpenseTypes();
      }
      if (!ref.read(brokerPriceListsProvider).isLoading) {
        ref.read(brokerPriceListsProvider.notifier).fetchPriceLists();
      }
    }
  }

  void didChangeDependencies(BuildContext context) {
    if (!hasCustomTitle && editingConsultationId == null) {
      final l = context.l10n;
      titleController.text = isTaxReviewMode
          ? l.defaultTaxReviewSessionTitle
          : l.defaultCustomsConsultationTitle;
    }
  }

  void didUpdateWidget(
      bool oldTaxReviewMode, bool newTaxReviewMode, BuildContext context) {
    if (oldTaxReviewMode != newTaxReviewMode &&
        !hasCustomTitle &&
        editingConsultationId == null) {
      final l = context.l10n;
      titleController.text = newTaxReviewMode
          ? l.defaultTaxReviewSessionTitle
          : l.defaultCustomsConsultationTitle;
    }
  }

  void dispose() {
    _dutyEstimateDebounce?.cancel();
    titleController.dispose();
    notesController.dispose();
    estimatedDutiesController.dispose();
    exchangeRateController.dispose();
    preliminaryRateController.dispose();
    freightForeignController.dispose();
    freightExchangeRateController.dispose();
    freightEgpController.dispose();
    insuranceEgpController.dispose();
  }

  void handleImportFileChanged(int? fileId) {
    setState(() {
      selectedImportFileId = fileId;
      onImportFileChanged?.call(fileId);
      engineCalculatedLines = [];
      currentEstimateCacheKey = null;
      engineGrandTotal = null;
      estimatedDutiesController.text = '';
      if (fileId != null) {
        final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
        final file =
            importFiles.where((f) => f.importFileId == fileId).firstOrNull;
        if (file != null) {
          final fCode = file.customFileNumber ?? file.importFileCode;
          titleController.text = '[$fCode] ${file.companyName}';
          if (file.brokerId != null) {
            selectedBrokerId = file.brokerId;
            selectedBrokerName = file.brokerName ?? '';
            final partners = ref.read(partnersProvider).valueOrNull ?? [];
            final bPartner =
                partners.where((p) => p.providerId == file.brokerId).firstOrNull;
            brokerContactPerson = bPartner?.contactPerson;
            loadBrokerPriceList(file.brokerId!);
          }
          if (file.poIds != null && file.poIds!.isNotEmpty) {
            selectedPoId = file.poIds!.first;
          }
          if (file.projectIds.isNotEmpty) {
            selectedProjectId = file.projectIds.first;
          }
          final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
          final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
          final detected = ConsultationCalcLogicHelper.detectCurrency(
            file: file,
            allPOs: allPOs,
            currencies: currencies,
          );
          customsCurrency = detected;
          updateExchangeRateForCurrency(detected);
          ConsultationCalcEngineHelper.autoFetchFreightFromScenarios(
            context: getContext(),
            ref: ref,
            fileId: fileId,
            exchangeRateController: exchangeRateController,
            onApplied: ({
              required foreignAmount,
              required currency,
              required fxRate,
              required freightEgp,
            }) {
              setState(() {
                freightForeignController.text = foreignAmount;
                freightCurrency = currency;
                freightExchangeRateController.text = fxRate;
                freightEgpController.text = freightEgp;
              });
            },
          );
        }
      } else {
        selectedBrokerId = null;
        selectedBrokerName = '';
        brokerContactPerson = null;
        brokerPriceListId = null;
        brokerQuoteItems.clear();
      }
    });
    triggerDutyEstimateDebounced();
  }

  void updateExchangeRateForCurrency(String currencyCode) {
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final matched = currencies
        .where((c) => c.currencyCode.toUpperCase() == currencyCode.toUpperCase())
        .firstOrNull;
    final rate = matched?.latestCustomsRate ?? matched?.latestCommercialRate;
    exchangeRateController.text =
        (rate != null && rate > 0) ? rate.toStringAsFixed(4) : '';
    triggerDutyEstimateDebounced();
  }

  void updateFreightExchangeRateForCurrency(String currencyCode) {
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final matched = currencies
        .where((c) => c.currencyCode.toUpperCase() == currencyCode.toUpperCase())
        .firstOrNull;
    final rate = matched?.latestCustomsRate ?? matched?.latestCommercialRate;
    freightExchangeRateController.text =
        (rate != null && rate > 0) ? rate.toStringAsFixed(4) : '';
    recalculateFreightEgp();
    triggerDutyEstimateDebounced();
  }

  void recalculateFreightEgp() {
    final foreignAmt =
        double.tryParse(freightForeignController.text.trim()) ?? 0.0;
    final rate =
        double.tryParse(freightExchangeRateController.text.trim()) ?? 0.0;
    if (foreignAmt > 0 && rate > 0) {
      freightEgpController.text = (foreignAmt * rate).toStringAsFixed(2);
    }
  }

  String buildCacheKey() {
    return ConsultationCalcEngineHelper.buildEstimateCacheKey(
      selectedImportFileId: selectedImportFileId,
      selectedPoId: selectedPoId,
      customsCurrency: customsCurrency,
      exchangeRateText: exchangeRateController.text,
      freightForeignText: freightForeignController.text,
      freightCurrency: freightCurrency,
      freightExchangeRateText: freightExchangeRateController.text,
      freightEgpText: freightEgpController.text,
      insuranceOption: insuranceOption,
      insuranceEgpText: insuranceEgpController.text,
      studyDate: studyDate,
    );
  }

  void triggerDutyEstimateDebounced() {
    _dutyEstimateDebounce?.cancel();
    _dutyEstimateDebounce = Timer(const Duration(milliseconds: 400), () {
      if (isMounted()) fetchDutyEstimate();
    });
  }

  Future<void> fetchDutyEstimate() async {
    final int reqId = ++_dutyEstimateRequestId;
    final String key = buildCacheKey();
    final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
    final tariffsList = ref.read(customsTariffProvider).valueOrNull ?? [];
    ImportFileModel? file;
    List<PurchaseOrderModel> matchingPOs = [];

    if (selectedImportFileId != null) {
      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
      file = importFiles
          .where((f) => f.importFileId == selectedImportFileId)
          .firstOrNull;
      if (file != null) {
        matchingPOs = allPOs
            .where((p) =>
                (p.importFileId != null &&
                    p.importFileId == file!.importFileId) ||
                (file!.importFileCode.isNotEmpty &&
                    p.importFileCode == file.importFileCode) ||
                (file.poIds != null &&
                    p.poId != null &&
                    file.poIds!.contains(p.poId)))
            .toList();
      }
    } else if (selectedPoId != null) {
      matchingPOs = allPOs.where((p) => p.poId == selectedPoId).toList();
    }

    final List<POLineItemModel> allPoLines = [];
    String? defaultOriginCountry;
    for (final po in matchingPOs) {
      if (defaultOriginCountry == null &&
          po.countryOfOrigin?.trim().isNotEmpty == true) {
        defaultOriginCountry = po.countryOfOrigin!.trim();
      }
      allPoLines.addAll(po.items);
    }

    if (allPoLines.isEmpty) {
      if (isMounted() && reqId == _dutyEstimateRequestId) {
        setState(() {
          engineCalculatedLines = [];
          currentEstimateCacheKey = null;
          engineGrandTotal = null;
          isEstimatingDuty = false;
        });
      }
      return;
    }

    final double? fxRate = double.tryParse(exchangeRateController.text.trim());
    if (fxRate == null || fxRate <= 0) return;

    double totalInvoicesForeign = 0.0;
    if (file != null && file.invoicesData.isNotEmpty) {
      for (final inv in file.invoicesData) {
        totalInvoicesForeign += inv.amount;
      }
    }

    final double poItemsFobSum =
        allPoLines.fold(0.0, (s, l) => s + l.totalPrice);
    final double scaleFactor = (totalInvoicesForeign > 0 && poItemsFobSum > 0)
        ? (totalInvoicesForeign / poItemsFobSum)
        : 1.0;
    final double freightForeign =
        double.tryParse(freightForeignController.text.trim()) ?? 0.0;
    final double? freightFxTyped =
        double.tryParse(freightExchangeRateController.text.trim());
    final double totalFreightEgp = freightForeign > 0 &&
            freightFxTyped != null &&
            freightFxTyped > 0
        ? (freightForeign * freightFxTyped)
        : (double.tryParse(freightEgpController.text.trim()) ?? 0.0);
    final double candfBaseEgp =
        ((totalInvoicesForeign > 0 ? totalInvoicesForeign : poItemsFobSum) *
                fxRate) +
            totalFreightEgp;

    double totalInsuranceEgp = 0.0;
    if (insuranceOption == '0.5%') {
      totalInsuranceEgp = candfBaseEgp * 0.005;
      insuranceEgpController.text = totalInsuranceEgp.toStringAsFixed(2);
    } else if (insuranceOption == '1.0%') {
      totalInsuranceEgp = candfBaseEgp * 0.01;
      insuranceEgpController.text = totalInsuranceEgp.toStringAsFixed(2);
    } else {
      totalInsuranceEgp =
          double.tryParse(insuranceEgpController.text.trim()) ?? 0.0;
    }

    final payload = CustomsEstimatePayloadBuilder.buildPayload(
      lines: allPoLines,
      tariffs: tariffsList,
      currency: customsCurrency,
      exchangeRate: fxRate,
      freightForeign: freightForeign,
      freightCurrency: freightCurrency,
      freightExchangeRate: freightFxTyped,
      freightEgp: totalFreightEgp,
      insuranceEgp: totalInsuranceEgp,
      insuranceOption: insuranceOption,
      estimateDate: studyDate,
      scaleFactor: scaleFactor,
      defaultOriginCountry: defaultOriginCountry,
    );

    if (payload == null) return;
    if (isMounted() && reqId == _dutyEstimateRequestId) {
      setState(() => isEstimatingDuty = true);
    }

    try {
      final res = await ref
          .read(customsTariffProvider.notifier)
          .estimateMultiItemDuty(payload);
      if (!isMounted() || reqId != _dutyEstimateRequestId) return;
      if (res != null) {
        final grandTotal =
            CustomsEstimatePayloadBuilder.parseToDouble(
                    res['grand_total_payable_egp']) ??
                0.0;
        final rows = CustomsEstimatePayloadBuilder.mapEngineResponseToCalcRows(
          engineResponse: res,
          allLines: allPoLines,
          tariffs: tariffsList,
          defaultOriginCountry: defaultOriginCountry,
          scaleFactor: scaleFactor,
          exchangeRate: fxRate,
        );
        setState(() {
          engineCalculatedLines = rows;
          engineGrandTotal = grandTotal;
          currentEstimateCacheKey = key;
          isEstimatingDuty = false;
          estimatedDutiesController.text = grandTotal.toStringAsFixed(2);
        });
      }
    } catch (_) {
      if (isMounted() && reqId == _dutyEstimateRequestId) {
        setState(() => isEstimatingDuty = false);
      }
    }
  }

  Future<void> loadBrokerPriceList(int brokerId) async {
    await ConsultationCalcBrokerQuoteHelper.loadBrokerPriceList(
      ref: ref,
      brokerId: brokerId,
      quoteItems: brokerQuoteItems,
      setLoading: (loading) {
        if (isMounted()) setState(() => isLoadingPriceList = loading);
      },
      onPriceListLoaded: ({required priceListId, required priceListTitle}) {
        if (isMounted()) {
          setState(() {
            brokerPriceListId = priceListId;
            brokerPriceListTitle = priceListTitle;
          });
        }
      },
    );
  }

  Future<void> fetchReconciledFinalInvoiceAndRecalculate() async {
    final context = getContext();
    final l = context.l10n;
    if (selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.selectImportFileFirstToast,
            severity: AppSeverity.warning),
      );
      return;
    }
    setState(() => isRecalculating = true);
    try {
      final res = await ref
          .read(customsConsultationsProvider.notifier)
          .recalculateFromReconciliation(
            importFileId: selectedImportFileId!,
            exchangeRate: double.tryParse(exchangeRateController.text.trim()),
            preliminaryExchangeRate:
                (recalculationResult?.hasDifferentCurrencies ?? false)
                    ? double.tryParse(preliminaryRateController.text.trim())
                    : null,
            freightEgp: double.tryParse(freightEgpController.text.trim()),
            insuranceEgp: double.tryParse(insuranceEgpController.text.trim()),
            estimateDate:
                '${studyDate.year}-${studyDate.month.toString().padLeft(2, '0')}-${studyDate.day.toString().padLeft(2, '0')}',
          );
      setState(() {
        recalculationResult = res;
        isCustomsCalculatorExpanded = true;
      });
    } catch (e) {
      onApiError?.call(e);
    } finally {
      if (isMounted()) setState(() => isRecalculating = false);
    }
  }

  void loadConsultation(CustomsConsultationModel session) {
    setState(() {
      editingConsultationId = session.consultationId;
      editingConsultationCode = session.consultationCode;
      titleController.text = session.title;
      selectedBrokerId = session.brokerId;
      selectedBrokerName = session.brokerName;
      brokerContactPerson = session.brokerContactPerson;
      selectedImportFileId = session.importFileId;
      selectedPoId = session.poId;
      selectedProjectId = session.projectId;
      estimatedDutiesController.text =
          session.estimatedDutiesEgp.toStringAsFixed(2);
      engineCalculatedLines = [];
      currentEstimateCacheKey = null;
      engineGrandTotal = session.estimatedDutiesEgp;
      notesController.text = session.notes ?? '';
      checklist.clear();
      checklist.addAll(session.checklistItems);
      brokerQuoteItems.clear();
      brokerQuoteItems.addAll(session.brokerQuoteItems.map((q) => q.copyWith()));
      brokerPriceListId = session.brokerPriceListId;
      final priceLists = ref.read(brokerPriceListsProvider).valueOrNull ?? [];
      final matchedPl = priceLists
          .where((pl) => pl.priceListId == session.brokerPriceListId)
          .firstOrNull;
      brokerPriceListTitle = matchedPl?.title;
    });
    if (session.importFileId != null) {
      handleImportFileChanged(session.importFileId);
    } else {
      triggerDutyEstimateDebounced();
    }
    _setDirty(false);
  }

  void resetForm() {
    final context = getContext();
    final l = context.l10n;
    setState(() {
      editingConsultationId = null;
      editingConsultationCode = null;
      titleController.text = isTaxReviewMode
          ? l.defaultTaxReviewSessionTitle
          : l.defaultCustomsConsultationTitle;
      selectedBrokerId = null;
      selectedBrokerName = '';
      brokerContactPerson = null;
      selectedImportFileId = null;
      selectedPoId = null;
      selectedProjectId = null;
      estimatedDutiesController.clear();
      exchangeRateController.clear();
      freightForeignController.clear();
      freightExchangeRateController.clear();
      freightEgpController.clear();
      insuranceEgpController.clear();
      notesController.clear();
      brokerQuoteItems.clear();
      brokerPriceListId = null;
      brokerPriceListTitle = null;
      engineCalculatedLines = [];
      currentEstimateCacheKey = null;
      engineGrandTotal = null;
      checklist.clear();
      checklist.addAll(ConsultationCalcLogicHelper.createDefaultChecklist());
    });
    _setDirty(false);
    onImportFileChanged?.call(null);
  }

  Future<void> saveConsultation() async {
    final rawCalcLines = ConsultationCalcEngineHelper.calculateCustomsLines(
      ref: ref,
      selectedImportFileId: selectedImportFileId,
      selectedPoId: selectedPoId,
      estimateCacheKey: buildCacheKey(),
      engineCalculatedLines: engineCalculatedLines,
      currentEstimateCacheKey: currentEstimateCacheKey,
      exchangeRate: double.tryParse(exchangeRateController.text.trim()),
    );

    await ConsultationCalcSaveHelper.saveConsultation(
      context: getContext(),
      ref: ref,
      formKey: formKey,
      title: titleController.text.trim(),
      isTaxReviewMode: isTaxReviewMode,
      selectedBrokerId: selectedBrokerId,
      selectedBrokerName: selectedBrokerName,
      brokerContactPerson: brokerContactPerson,
      brokerPriceListId: brokerPriceListId,
      selectedImportFileId: selectedImportFileId,
      selectedPoId: selectedPoId,
      selectedProjectId: selectedProjectId,
      fxRate: double.tryParse(exchangeRateController.text.trim()),
      isEstimatingDuty: isEstimatingDuty,
      rawCalcLines: rawCalcLines,
      engineGrandTotal: engineGrandTotal,
      currentEstimateCacheKey: currentEstimateCacheKey,
      estimatedDutiesController: estimatedDutiesController,
      notesController: notesController,
      checklist: checklist,
      brokerQuoteItems: brokerQuoteItems,
      editingConsultationId: editingConsultationId,
      editingConsultationCode: editingConsultationCode,
      setSaving: (saving) => setState(() => isSaving = saving),
      onSavedSuccess: (saved) {
        setState(() {
          editingConsultationId = null;
          editingConsultationCode = null;
          isDirty = false;
        });
        onSaved?.call(saved);
      },
      loadConsultation: loadConsultation,
    );
  }

  Widget build(BuildContext context) {
    final consultationsList =
        ref.watch(customsConsultationsProvider).valueOrNull ?? [];
    final partnersList = (ref.watch(partnersProvider).valueOrNull ?? [])
        .where((p) =>
            p.partnerType.contains('Customs') ||
            p.partnerType.contains('Broker'))
        .toList();
    final currenciesList = ref.watch(currenciesProvider).valueOrNull ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;

    final totalDocs = checklist.length;
    final approvedDocs = checklist.where((i) => i.status == 'Approved').length;
    final blockingCount = checklist
        .where((i) => i.isBlockingShipment && i.status != 'Approved')
        .length;
    final liveReadinessPct =
        totalDocs > 0 ? ((approvedDocs / totalDocs) * 100).toInt() : 0;

    final rawCalcLines = ConsultationCalcEngineHelper.calculateCustomsLines(
      ref: ref,
      selectedImportFileId: selectedImportFileId,
      selectedPoId: selectedPoId,
      estimateCacheKey: buildCacheKey(),
      engineCalculatedLines: engineCalculatedLines,
      currentEstimateCacheKey: currentEstimateCacheKey,
      exchangeRate: double.tryParse(exchangeRateController.text.trim()),
    );
    final calcLines = ConsultationCalcEngineHelper.getAggregatedCustomsLines(
      rawCalcLines,
      groupByHsCode: groupByHsCode,
    );

    final double? fxRate = double.tryParse(exchangeRateController.text.trim());
    final double freightForeign =
        double.tryParse(freightForeignController.text.trim()) ?? 0.0;
    final double freightFxRate =
        double.tryParse(freightExchangeRateController.text.trim()) ??
            (fxRate ?? 0.0);
    final double totalFreightEgp = freightForeign > 0
        ? (freightForeign * freightFxRate)
        : (double.tryParse(freightEgpController.text.trim()) ?? 0.0);
    final double totalInsuranceEgp =
        double.tryParse(insuranceEgpController.text.trim()) ?? 0.0;
    final validCalcLines =
        rawCalcLines.where((l) => !l.isTariffMissing).toList();
    final totalFobForeign =
        validCalcLines.fold(0.0, (s, l) => s + l.foreignPrice);
    final totalFobEgp = validCalcLines.fold(0.0, (s, l) => s + l.fobEgp);
    final totalCandFEgp = totalFobEgp + totalFreightEgp;
    final totalCifEgp = validCalcLines.fold(0.0, (s, l) => s + l.cifEgp);
    final totalCifForeign =
        (fxRate != null && fxRate > 0) ? (totalCifEgp / fxRate) : 0.0;
    final totalDutyEgp =
        validCalcLines.fold(0.0, (s, l) => s + l.dutyAmountEgp);
    final totalVatEgp = validCalcLines.fold(0.0, (s, l) => s + l.vatAmountEgp);
    final totalScheduleTaxEgp =
        validCalcLines.fold(0.0, (s, l) => s + l.scheduleTaxAmountEgp);
    final totalDevFeeEgp =
        validCalcLines.fold(0.0, (s, l) => s + l.developmentFeeAmountEgp);
    final totalServiceFeeEgp =
        validCalcLines.fold(0.0, (s, l) => s + l.customsServiceFeeAmountEgp);
    final totalTaxesAndDutiesEgp =
        validCalcLines.fold(0.0, (s, l) => s + l.totalTaxesAndDutiesEgp);
    final totalBrokerFees = isTaxReviewMode
        ? 0.0
        : brokerQuoteItems.fold(
            0.0,
            (sum, itm) =>
                sum + (itm.isApplicable ? itm.totalAmount : 0.0));

    bool hasInvoicesWithoutPoLines = false;
    if (selectedImportFileId != null) {
      final file = importFiles
          .where((f) => f.importFileId == selectedImportFileId)
          .firstOrNull;
      if (file != null && file.invoicesData.isNotEmpty) {
        final matchingPOs = allPOs
            .where((p) =>
                (p.importFileId != null &&
                    p.importFileId == file.importFileId) ||
                (file.importFileCode.isNotEmpty &&
                    p.importFileCode == file.importFileCode) ||
                (file.poIds != null &&
                    p.poId != null &&
                    file.poIds!.contains(p.poId)))
            .toList();
        hasInvoicesWithoutPoLines =
            matchingPOs.isEmpty || matchingPOs.every((p) => p.items.isEmpty);
      }
    }

    final nafezaFeeBreakdown = CustomsExportService.computeNafezaFeeBreakdown(
      totalDutyEgp: totalDutyEgp,
      totalVatEgp: totalVatEgp,
      totalServiceFeeEgp: totalServiceFeeEgp,
      totalScheduleTaxEgp: totalScheduleTaxEgp,
    );

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConsultationCalcActionsBar(
                liveReadinessPct: liveReadinessPct,
                itemsAndDocsCount: totalDocs,
                blockingCount: blockingCount,
                onTapBlockingIssues: () => showBlockingIssuesDialog(
                  getContext(),
                  checklist,
                  (val) => setState(() {
                    checklist.clear();
                    checklist.addAll(val);
                  }),
                ),
                isTaxReviewMode: isTaxReviewMode,
                onCompareQuotes: () =>
                    ConsultationCalcBrokerQuoteHelper
                        .openBrokerQuotationComparisonDialog(
                  context: getContext(),
                  ref: ref,
                  selectedImportFileId: selectedImportFileId,
                  selectedBrokerId: selectedBrokerId,
                  onBrokerSelected: (bId) {
                    setState(() => selectedBrokerId = bId);
                    loadBrokerPriceList(bId);
                  },
                ),
                onSearchAndClone: () =>
                    ConsultationCloneDialog.openSearchAndClone(
                  context: getContext(),
                  ref: ref,
                  consultations: consultationsList,
                  onCloned: loadConsultation,
                ),
                onRefresh: refreshProviders,
                onClearForm: resetForm,
                onExportTsv: () => CustomsExportService.exportCustomsLinesTsv(
                  context: getContext(),
                  calcLines: calcLines,
                  currency: customsCurrency,
                ),
                onExportExcel: () =>
                    CustomsExportService.exportCustomsStudyToExcel(
                  context: getContext(),
                  title: titleController.text.trim(),
                  importFileCode: selectedImportFileId != null
                      ? 'IMP-$selectedImportFileId'
                      : null,
                  brokerName: selectedBrokerName.isNotEmpty
                      ? selectedBrokerName
                      : getContext().l10n.ccCustomsBroker,
                  currency: customsCurrency,
                  exchangeRate: fxRate ?? 0.0,
                  totalFreightEgp: totalFreightEgp,
                  totalInsuranceEgp: totalInsuranceEgp,
                  calcLines: calcLines,
                  nafezaResult: nafezaFeeBreakdown,
                  brokerQuoteItems: brokerQuoteItems,
                ),
                onPrintPdf: () =>
                    CustomsConsultationPdfService.printOrPreviewCalculationReportPdf(
                  context: getContext(),
                  title: titleController.text.trim(),
                  importFileCode: selectedImportFileId != null
                      ? 'IMP-$selectedImportFileId'
                      : null,
                  brokerName: selectedBrokerName.isNotEmpty
                      ? selectedBrokerName
                      : getContext().l10n.ccCustomsBroker,
                  currency: customsCurrency,
                  exchangeRate: fxRate ?? 0.0,
                  totalFreightEgp: totalFreightEgp,
                  totalInsuranceEgp: totalInsuranceEgp,
                  calcLines: calcLines,
                  nafezaResult: nafezaFeeBreakdown,
                  brokerQuoteItems: brokerQuoteItems,
                  checklist: checklist,
                ),
                onCopyDossier: () =>
                    CustomsExportService.copyCustomsDutyDossier(
                  context: getContext(),
                  title: titleController.text.trim(),
                  importFileCode: selectedImportFileId != null
                      ? 'IMP-$selectedImportFileId'
                      : null,
                  brokerName: selectedBrokerName.isNotEmpty
                      ? selectedBrokerName
                      : getContext().l10n.ccCustomsBroker,
                  currency: customsCurrency,
                  exchangeRate: fxRate ?? 0.0,
                  totalFreightEgp: totalFreightEgp,
                  totalInsuranceEgp: totalInsuranceEgp,
                  calcLines: calcLines,
                  nafezaResult: nafezaFeeBreakdown,
                ),
                onExtractQuote: () => showSmartClearanceExtractorDialog(
                  getContext(),
                  ref,
                  onExtracted: (extracted) {
                    setState(() {
                      ConsultationCalcLogicHelper.applyExtractedQuotation(
                        extracted: extracted,
                        quoteItems: brokerQuoteItems,
                        partners: partnersList,
                        onBrokerMatched: (bId, bName) {
                          selectedBrokerId = bId;
                          selectedBrokerName = bName;
                        },
                      );
                      isBrokerQuoteExpanded = true;
                    });
                  },
                ),
                onSaveDraft: saveConsultation,
                onSave: saveConsultation,
                isSaving: isSaving,
                isEditing: editingConsultationId != null,
              ),
              const SizedBox(height: 20),
              if (editingConsultationId != null) ...[
                ConsultationCalcEditBanner(
                  editingConsultationCode: editingConsultationCode,
                  onSave: saveConsultation,
                  onSaveAsNewCopy: () {
                    setState(() {
                      editingConsultationId = null;
                      editingConsultationCode = null;
                      titleController.text =
                          '${titleController.text}${TableRowCloneHelper.copySuffix}';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingConsultationId = null;
                      editingConsultationCode = null;
                    });
                  },
                  isSaving: isSaving,
                ),
              ],
              ConsultationCalcHeaderCard(
                isTaxReviewMode: isTaxReviewMode,
                titleController: titleController,
                selectedBrokerId: selectedBrokerId,
                onBrokerChanged: (b) {
                  setState(() {
                    selectedBrokerId = b?.providerId;
                    selectedBrokerName = b?.partnerName ?? '';
                    brokerContactPerson = b?.contactPerson;
                  });
                  if (b?.providerId != null) {
                    loadBrokerPriceList(b!.providerId!);
                  }
                },
                brokersList: partnersList,
                selectedImportFileId: selectedImportFileId,
                onImportFileChanged: handleImportFileChanged,
                importFiles: importFiles,
                allPOs: allPOs,
                currenciesList: currenciesList,
                customsCurrency: customsCurrency,
                onCustomsCurrencyChanged: (v) {
                  setState(() {
                    customsCurrency = v;
                    updateExchangeRateForCurrency(v);
                  });
                },
                exchangeRateController: exchangeRateController,
                onExchangeRateChanged: () {
                  setState(() {});
                  triggerDutyEstimateDebounced();
                },
                studyDate: studyDate,
                onStudyDateChanged: (picked) {
                  setState(() => studyDate = picked);
                  triggerDutyEstimateDebounced();
                },
                freightForeignController: freightForeignController,
                freightCurrency: freightCurrency,
                onFreightCurrencyChanged: (v) {
                  setState(() {
                    freightCurrency = v;
                    updateFreightExchangeRateForCurrency(v);
                  });
                },
                freightExchangeRateController: freightExchangeRateController,
                freightEgpController: freightEgpController,
                onRecalculateFreightEgp: () =>
                    setState(recalculateFreightEgp),
                onAutoFetchFreightFromScenarios: selectedImportFileId != null
                    ? () => ConsultationCalcEngineHelper
                            .autoFetchFreightFromScenarios(
                          context: getContext(),
                          ref: ref,
                          fileId: selectedImportFileId!,
                          exchangeRateController: exchangeRateController,
                          onApplied: ({
                            required foreignAmount,
                            required currency,
                            required fxRate,
                            required freightEgp,
                          }) {
                            setState(() {
                              freightForeignController.text = foreignAmount;
                              freightCurrency = currency;
                              freightExchangeRateController.text = fxRate;
                              freightEgpController.text = freightEgp;
                            });
                          },
                        )
                    : null,
                insuranceOption: insuranceOption,
                onInsuranceOptionChanged: (opt) {
                  setState(() => insuranceOption = opt);
                  triggerDutyEstimateDebounced();
                },
                insuranceEgpController: insuranceEgpController,
                totalFobForeign: totalFobForeign,
                totalCandFEgp: totalCandFEgp,
                totalFreightEgp: totalFreightEgp,
                totalInsuranceEgp: totalInsuranceEgp,
                totalCifEgp: totalCifEgp,
                totalCifForeign: totalCifForeign,
                exchangeRate: fxRate,
                editingConsultationCode: editingConsultationCode,
                isCustomsCalculatorExpanded: isCustomsCalculatorExpanded,
                onToggleExpanded: () => setState(() =>
                    isCustomsCalculatorExpanded =
                        !isCustomsCalculatorExpanded),
              ),
              const SizedBox(height: 20),
              if (!isTaxReviewMode) ...[
                BrokerQuoteDetailsCard(
                  selectedBrokerId: selectedBrokerId,
                  isLoadingPriceList: isLoadingPriceList,
                  brokerQuoteItems: brokerQuoteItems,
                  brokerPriceListTitle: brokerPriceListTitle,
                  categoryFilter: brokerExpenseCategoryFilter,
                  isExpanded: isBrokerQuoteExpanded,
                  currenciesList: currenciesList,
                  referenceUsdExchangeRate: fxRate,
                  onToggleExpanded: () => setState(() =>
                      isBrokerQuoteExpanded = !isBrokerQuoteExpanded),
                  onCategoryChanged: (cat) =>
                      setState(() => brokerExpenseCategoryFilter = cat),
                  onAddCustomExpense: () => showDialog(
                    context: getContext(),
                    builder: (ctx) => AddCustomExpenseDialog(
                      onExpenseAdded: (item) =>
                          setState(() => brokerQuoteItems.add(item)),
                    ),
                  ),
                  onReloadPriceList: selectedBrokerId != null
                      ? () => loadBrokerPriceList(selectedBrokerId!)
                      : null,
                  onApplyAll: () {
                    setState(() {
                      for (int i = 0; i < brokerQuoteItems.length; i++) {
                        final itm = brokerQuoteItems[i];
                        brokerQuoteItems[i] = itm.copyWith(
                            isApplicable: true,
                            totalAmount: itm.unitPrice * itm.qty);
                      }
                    });
                  },
                  onDisableAll: () {
                    setState(() {
                      for (int i = 0; i < brokerQuoteItems.length; i++) {
                        brokerQuoteItems[i] = brokerQuoteItems[i].copyWith(
                            isApplicable: false, totalAmount: 0.0);
                      }
                    });
                  },
                  onUpdateItem: (index, updated) {
                    setState(() {
                      final lineTotal = updated.isApplicable
                          ? (updated.unitPrice * updated.qty)
                          : 0.0;
                      brokerQuoteItems[index] =
                          updated.copyWith(totalAmount: lineTotal);
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],
              ConsultationCalcScenariosComparison(
                calcLines: calcLines,
                recalculationResult: recalculationResult,
                preliminaryRateController: preliminaryRateController,
                onApplyNewFees: () {
                  if (recalculationResult != null) {
                    setState(() {
                      estimatedDutiesController.text = recalculationResult!
                          .finalTotalTaxesEgp
                          .toStringAsFixed(2);
                    });
                  }
                },
                onCloseRecalculation: () =>
                    setState(() => recalculationResult = null),
                onFetchReconciledFinalInvoice:
                    fetchReconciledFinalInvoiceAndRecalculate,
                isRecalculating: isRecalculating,
                isTaxReviewMode: isTaxReviewMode,
                customsCurrency: customsCurrency,
              ),
              const SizedBox(height: 20),
              ConsultationCalcItemsTable(
                calcLines: calcLines,
                customsCurrency: customsCurrency,
                groupByHsCode: groupByHsCode,
                onGroupByHsCodeChanged: (val) =>
                    setState(() => groupByHsCode = val),
                hasInvoicesWithoutPoLines: hasInvoicesWithoutPoLines,
                onSyncHsRequirementsToChecklist: () =>
                    ConsultationCalcEngineHelper.syncHsRequirementsToChecklist(
                  context: getContext(),
                  calcLines: calcLines,
                  checklist: checklist,
                  estimatedDutiesController: estimatedDutiesController,
                  silent: false,
                ),
              ),
              const SizedBox(height: 20),
              ConsultationCalcSummaryCard(
                totalFobForeign: totalFobForeign,
                totalFobEgp: totalFobEgp,
                totalCifForeign: totalCifForeign,
                totalCifEgp: totalCifEgp,
                totalDutyEgp: totalDutyEgp,
                totalVatEgp: totalVatEgp,
                totalScheduleTaxEgp: totalScheduleTaxEgp,
                totalDevFeeEgp: totalDevFeeEgp,
                totalServiceFeeEgp: totalServiceFeeEgp,
                totalTaxesAndDutiesEgp: totalTaxesAndDutiesEgp,
                totalBrokerFeesEgp: totalBrokerFees,
                customsCurrency: customsCurrency,
                engineGrandTotal: engineGrandTotal,
                isEstimatingDuty: isEstimatingDuty,
                onApplyAndLinkFinancialEstimate: () {
                  final applied =
                      engineGrandTotal ?? totalTaxesAndDutiesEgp;
                  setState(() =>
                      estimatedDutiesController.text =
                          applied.toStringAsFixed(2));
                  ScaffoldMessenger.of(getContext()).showSnackBar(
                    AppTheme.snackBar(
                      getContext(),
                      '✅ ${getContext().l10n.applyAndLinkFinancialEstimate}: ${applied.toStringAsFixed(2)} ${getContext().l10n.financialSettlementCurrencyEgp}',
                      severity: AppSeverity.success,
                    ),
                  );
                },
                calcLines: calcLines,
                totalFreightEgp: totalFreightEgp,
                totalInsuranceEgp: totalInsuranceEgp,
                exchangeRate: fxRate ?? 0.0,
                editingConsultationId: editingConsultationId,
                editingConsultationCode: editingConsultationCode,
                selectedBrokerId: selectedBrokerId,
                selectedBrokerName: selectedBrokerName,
                title: titleController.text.trim(),
                checklist: checklist,
                brokerQuoteItems: brokerQuoteItems,
                selectedImportFileId: selectedImportFileId,
              ),
              const SizedBox(height: 20),
              ConsultationCalcChecklistCard(
                checklist: checklist,
                onAddChecklistItem: () => showDialog(
                  context: getContext(),
                  builder: (context) => AddChecklistItemDialog(
                    onItemAdded: (item) => setState(() => checklist.add(item)),
                  ),
                ),
                onUpdateItem: (index, item) =>
                    setState(() => checklist[index] = item),
                onCloneItem: (index) {
                  if (index < 0 || index >= checklist.length) return;
                  final orig = checklist[index];
                  final cloned = orig.copyWith(
                    itemId: null,
                    remarks: orig.remarks != null && orig.remarks!.isNotEmpty
                        ? '${orig.remarks}${TableRowCloneHelper.copySuffix}'
                        : TableRowCloneHelper.copySuffix.trim(),
                    status: 'Pending',
                  );
                  setState(() => checklist.insert(index + 1, cloned));
                },
                onDeleteItem: (index) =>
                    setState(() => checklist.removeAt(index)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
