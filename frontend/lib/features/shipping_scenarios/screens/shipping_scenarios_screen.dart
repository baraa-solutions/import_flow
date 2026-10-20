import 'dart:math' as math;
import '../widgets/saved_scenarios_registry_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';

import '../../external_service_providers/models/partner_model.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../freight_quotations/widgets/freight_quotations_extractor_dialog.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/shipping_scenario_model.dart';
import '../providers/shipping_scenarios_provider.dart';
import '../utils/shipping_scenario_calculator.dart';
import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/performance/dispose_tracker.dart';
import '../../../core/localization/api_error_text.dart';


class ShippingScenariosScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final int? initialImportFileId;
  final bool isEmbedded;

  const ShippingScenariosScreen({
    super.key,
    this.initialIndex = 0,
    this.initialImportFileId,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<ShippingScenariosScreen> createState() => _ShippingScenariosScreenState();
}

class _ShippingScenariosScreenState extends ConsumerState<ShippingScenariosScreen>
    with SingleTickerProviderStateMixin, DisposeTrackerMixin<ShippingScenariosScreen> {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Evaluator Form State
  int? _editingSessionId;
  String? _editingSessionCode;
  int _editFormVersion = 0;
  String _title = '';
  DateTime _cargoReadyDate = DateTime.now().add(const Duration(days: 5));
  String _pickUpAddress = '';
  int _avgForm4Days = 5;
  int _avgClearanceDays = 7;
  int? _selectedImportFileId;
  int? _selectedPoId;
  int? _selectedProjectId;
  final String _sessionNotes = '';

  // Carrier Options List
  final List<ShippingScenarioItemModel> _evalItems = [];
  bool _isSaving = false;
  bool _isStackable = true;

  // ── Smart AI Extractor State (Text & OCR) ──────────────────────────────
  bool _isFreightExtractorExpanded = true;
  final bool _isFreightExtracting = false;
  final TextEditingController _rawFreightQuoteController = TextEditingController();
  List<ExtractedQuotationOption> _extractedOptions = [];
  Map<String, dynamic>? _extractedFreightMetadata;
  PlatformFile? _pickedFreightFile;
  String? _extractorError;

  // Track expanded quotes in UI
  final Map<int, bool> _expandedQuotes = {};
  bool _hasVisitedTab0 = false;
  bool _hasVisitedTab1 = false;

  
  void _cloneCarrierOption(int idx) {
    if (idx < 0 || idx >= _evalItems.length) return;
    final source = _evalItems[idx];
    final l = context.l10n;
    // The vessel name is a real-world name and is kept as is on the clone.
    final clonedItem = source.copyWith(
      isRecommended: false,
      isSelected: false,
    );
    setState(() {
      _evalItems.insert(idx + 1, clonedItem);
      _expandedQuotes[idx + 1] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.carrierOptionClonedSuccess),
        backgroundColor: AppTheme.wcagEmerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showCloneStudyReviewDialog(BuildContext context, ShippingEvaluationModel source) {
    final l = context.l10n;
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final initialName = '${source.title ?? source.sessionCode}${TableRowCloneHelper.copySuffix}';

    final copiedMap = <String, String>{
      l.shippingCarrierOptions: '${source.items.length}',
      l.crdLabel: source.cargoReadyDate,
    };
    if (source.recommendedScenarioProvider != null) {
      copiedMap[l.recommendedLineMetric] = source.recommendedScenarioProvider!;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: CloneEntityReviewDialog(
            entityType: l.cloneStudyDialogTitle,
            sourceCode: source.sessionCode,
            suggestedNewCode: '${source.sessionCode}-CLONE',
            sourceTitle: initialName,
            copiedFieldsSummary: copiedMap,
            mandatorilyResetFields: [
              l.cloneFieldStudyCodeGenerated,
              l.cloneFieldImportFileReset,
              l.cloneFieldPoReset,
              l.cloneFieldSelectionReset,
            ],
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final sId = source.sessionId;
              if (sId == null) return;
              final messenger = ScaffoldMessenger.of(context);
              final cloned = await ref.read(shippingScenariosProvider.notifier).cloneSession(
                sId,
                newTitle: newTitle,
                remarks: notes,
                unlinkImportFile: true,
                unlinkPo: true,
                copyCarrierOptions: copyLineItems,
              );
              if (cloned != null) {
                _loadSessionForEditing(cloned, showLoadedSnackbar: false);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l.cloneStudySuccess(cloned.sessionCode)),
                    backgroundColor: AppTheme.wcagEmerald,
                  ),
                );
              } else {
                // The clone failed: show the (localized) reason instead of staying silent.
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(ApiErrorText.of(l, ref.read(shippingScenariosProvider).error, fallback: l.operationFailed)),
                    backgroundColor: AppTheme.crimson,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _openSearchAndCloneStudyDialog(BuildContext context) {
    final state = ref.read(shippingScenariosProvider);
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SearchAndCloneStudyDialog(
            sessions: state.sessions,
            onSelectStudy: (session) {
              Navigator.of(dialogCtx).pop();
              _showCloneStudyReviewDialog(context, session);
            },
          ),
        ),
      ),
    );
  }

  void _loadSessionForEditing(ShippingEvaluationModel sess, {bool showLoadedSnackbar = true}) {
    setState(() {
      _hasVisitedTab0 = true;
      _editFormVersion++;
      _editingSessionId = sess.sessionId;
      _editingSessionCode = sess.sessionCode;
      _title = sess.title ?? '';
      _cargoReadyDate = DateTime.tryParse(sess.cargoReadyDate) ?? DateTime.now();
      _pickUpAddress = sess.pickUpAddress ?? '';
      _avgForm4Days = sess.avgForm4Days;
      _avgClearanceDays = sess.avgClearanceDays;
      _selectedImportFileId = sess.importFileId;
      _selectedPoId = sess.poId;
      _selectedProjectId = sess.projectId;
      _evalItems.clear();
      _evalItems.addAll(sess.items);
      _expandedQuotes.clear();
      for (int i = 0; i < sess.items.length; i++) {
        _expandedQuotes[i] = true;
      }
    });
    _tabController.animateTo(0);
    if (showLoadedSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.sessionLoadedMsg(sess.sessionCode)),
          backgroundColor: AppTheme.cobalt,
        ),
      );
    }
  }

  void _resetFormForNewStudy() {
    setState(() {
      _hasVisitedTab0 = true;
      _editFormVersion++;
      _editingSessionId = null;
      _editingSessionCode = null;
      _title = '';
      _cargoReadyDate = DateTime.now().add(const Duration(days: 5));
      _pickUpAddress = '';
      _avgForm4Days = 5;
      _avgClearanceDays = 7;
      _selectedImportFileId = null;
      _selectedPoId = null;
      _selectedProjectId = null;
      _expandedQuotes.clear();
      _initDefaultItems();
    });
  }

  @override
  void initState() {
    super.initState();
    _hasVisitedTab0 = widget.initialIndex == 0;
    _hasVisitedTab1 = widget.initialIndex == 1;
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
    _tabController.addListener(() {
      if (_tabController.index == 0 && !_hasVisitedTab0) {
        setState(() => _hasVisitedTab0 = true);
      } else if (_tabController.index == 1 && !_hasVisitedTab1) {
        setState(() => _hasVisitedTab1 = true);
      }
    });
    if (widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
    }
    _initDefaultItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData(force: false);
    });
  }

  @override
  void didUpdateWidget(ShippingScenariosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _tabController.animateTo(widget.initialIndex);
      if (widget.initialIndex == 0) _hasVisitedTab0 = true;
      if (widget.initialIndex == 1) _hasVisitedTab1 = true;
    }
    if (widget.initialImportFileId != null && widget.initialImportFileId != _selectedImportFileId) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
      });
    }
  }

  void _refreshData({bool force = false}) {
    if (!ref.read(shippingScenariosProvider).isLoading) {
      ref.read(shippingScenariosProvider.notifier).fetchSessions();
    }
    if (!ref.read(allPartnersProvider).isLoading) {
      ref.read(allPartnersProvider.notifier).fetchPartners();
    }
    if (!ref.read(partnersProvider).isLoading) {
      ref.read(partnersProvider.notifier).fetchPartners();
    }
    if (!ref.read(projectsProvider).isLoading) {
      ref.read(projectsProvider.notifier).fetchProjects();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
    if (!ref.read(transportLocationsProvider).isLoading) {
      ref.read(transportLocationsProvider.notifier).fetchLocations();
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(currenciesProvider).isLoading) {
      ref.read(currenciesProvider.notifier).fetchCurrencies();
    }
  }

  void _initDefaultItems() {
    final crd = _cargoReadyDate;
    _evalItems.clear();
    _evalItems.addAll([
      ShippingScenarioItemModel(
        providerName: 'COSCO Shipping',
        vesselName: 'COSCO UNIVERSE',
        voyageNumber: '042E',
        polName: 'Shanghai Port',
        podName: 'El Dekheila Port',
        sailingDate: crd.add(const Duration(days: 2)).toString().substring(0, 10),
        estimatedArrivalDate: crd.add(const Duration(days: 26)).toString().substring(0, 10),
        expectedLineDelayDays: 2,
        isRecommended: true,
        riskLevel: 'Low',
        notes: 'أقرب موعد إبحار وتوافر حاويات HQ في ميناء شانغهاي',
      ),
      ShippingScenarioItemModel(
        providerName: 'Maersk Line',
        vesselName: 'MAERSK MC-KINNEY MOLLER',
        voyageNumber: '2608W',
        polName: 'Ningbo-Zhoushan Port',
        podName: 'Damietta Port',
        sailingDate: crd.add(const Duration(days: 5)).toString().substring(0, 10),
        estimatedArrivalDate: crd.add(const Duration(days: 32)).toString().substring(0, 10),
        expectedLineDelayDays: 4,
        isRecommended: false,
        riskLevel: 'Medium',
        notes: r'ترانزيت في بيرايوس مع تكلفة شحن أقل بمقدار $300',
      ),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _rawFreightQuoteController.dispose();
    super.dispose();
  }

  double? _calculateTotalQuoteValue(ShippingScenarioItemModel item, List<CurrencyModel> currencies) {
    return ShippingScenarioCalculator.calculateTotalQuoteValue(item: item, currencies: currencies).total;
  }

  void _updateItem(int idx, ShippingScenarioItemModel updatedItem, List<CurrencyModel> currencies) {
    final rawTotal = _calculateTotalQuoteValue(updatedItem, currencies);
    final totalAmount = rawTotal?.roundToDouble();
    setState(() {
      _evalItems[idx] = updatedItem.copyWith(
        totalQuotationAmount: totalAmount,
        clearTotalQuotationAmount: totalAmount == null,
      );
    });
  }

  static const String _sampleFreightQuoteText = '''
Dear Ahmed,
Please find below our best rates for your shipment:

Route: Shanghai – Alexandria
Local charges: Approx. USD 880/40HQ
Ocean freight:
• WHL: USD 6,700/40HQ  ETD: 28/AUG
  Transit time: 29 days, DIRECT
  Free time: 21 days FT

• YML: USD 6,180/40HQ  ETD: 27/AUG
  Transit time: 48 days, INDIRECT
  Free time: 21 days FT

• MSC: USD 6,950/40HQ  ETD: 30/AUG
  Transit time: 27 days, DIRECT
  Free time: 14 days FT (INCL OWS)

Cancellation fee: \$100/cntr
Best regards,
''';

  void _loadSampleFreightQuote() {
    setState(() {
      _rawFreightQuoteController.text = _sampleFreightQuoteText.trim();
      _extractorError = null;
    });
  }

  void _openFreightSmartExtractorDialog([String? initialText]) {
    FreightQuotationsExtractorDialog.show(
      context,
      onAddQuotations: (selectedOptions) {
        final crd = _cargoReadyDate;
        final partners = ref.read(allPartnersProvider).valueOrNull ?? ref.read(partnersProvider).valueOrNull ?? [];
        final portsList = ref.read(transportLocationsProvider).valueOrNull ?? [];

        setState(() {
          for (int i = 0; i < selectedOptions.length; i++) {
            final opt = selectedOptions[i];
            final scenario = _mapExtractedOptionToScenarioItem(
              opt: opt,
              crd: crd,
              partners: partners,
              portsList: portsList,
              isRecommended: i == 0 && _evalItems.isEmpty,
            );
            _evalItems.add(scenario);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.freightQuotesAddedMsg(selectedOptions.length)),
            backgroundColor: AppTheme.emerald,
          ),
        );
      },
    );
  }

  Future<void> _extractFreightFromText() async {
    _openFreightSmartExtractorDialog(_rawFreightQuoteController.text.trim());
  }

  Future<void> _extractFreightFromFile() async {
    _openFreightSmartExtractorDialog();
  }


  dynamic _matchPortSmart(String rawPortText, List portsList) {
    if (rawPortText.trim().isEmpty) return null;
    final raw = rawPortText.toLowerCase();

    // 1. Direct UN/LOCODE exact or substring match e.g. "CNNGB", "EGDKH", "EGALX", "EGEDK"
    for (final p in portsList) {
      final unloc = (p.unLocode ?? '').toString().toLowerCase();
      if (unloc.isNotEmpty && (raw.contains(unloc) || unloc.contains(raw))) {
        return p;
      }
    }

    // 2. Tokenized word matching (e.g. "ningbo", "dekheila", "alexandria", "shanghai", "sokhna", "damietta", "port said", "cairo")
    // and Arabic keywords ("نينغبو", "الدخيلة", "الإسكندرية", "السخنة", "دمياط", "بورسعيد", "شنغهاي")
    final portKeywords = [
      'ningbo', 'dekheila', 'dek', 'alexandria', 'alex', 'shanghai', 'sokhna', 'damietta',
      'port said', 'cairo', 'qingdao', 'shenzhen', 'guangzhou', 'xiamen',
      'tianjin', 'yantian', 'busan', 'rotterdam', 'hamburg', 'antwerp',
      'genoa', 'valencia', 'istanbul', 'mersin', 'jebel ali', 'jeddah', 'adabiya',
      'نينغبو', 'الدخيلة', 'الإسكندرية', 'السخنة', 'دمياط', 'بورسعيد', 'شنغهاي', 'القاهرة'
    ];

    for (final kw in portKeywords) {
      if (raw.contains(kw)) {
        for (final p in portsList) {
          final pName = (p.locationName ?? '').toString().toLowerCase();
          if (pName.contains(kw)) {
            return p;
          }
        }
      }
    }

    // 3. Fallback: pName contains raw or raw contains pName
    for (final p in portsList) {
      final pName = (p.locationName ?? '').toString().toLowerCase();
      if (pName.isNotEmpty && (raw.contains(pName) || pName.contains(raw))) {
        return p;
      }
    }

    return null;
  }

  ShippingScenarioItemModel _mapExtractedOptionToScenarioItem({
    required ExtractedQuotationOption opt,
    required DateTime crd,
    required List<PartnerModel> partners,
    required List portsList,
    required bool isRecommended,
  }) {
    final rawCarrier = opt.carrierName;
    final cntrType = opt.containerType;
    final rate = opt.oceanFreight;
    final localCharges = opt.localCharges;
    final cancelFee = opt.exwCharges;
    final freeDays = opt.freeTimeDays ?? 21;
    final transitDays = opt.transitDays ?? 28;
    final isDirect = opt.isDirect;
    final notes = opt.notes;
    final curr = opt.currency;

    // 1. Match Shipping Line (الخط الملاحي)
    final shippingLines = partners.where((p) => p.partnerType.contains('Shipping Line') || p.partnerType.contains('Carrier')).toList();
    final matchedLine = shippingLines.where((p) =>
      p.partnerName.toLowerCase().contains(rawCarrier.toLowerCase()) ||
      rawCarrier.toLowerCase().contains(p.partnerName.toLowerCase()) ||
      (p.scacCode != null && rawCarrier.toLowerCase().contains(p.scacCode!.toLowerCase())) ||
      (rawCarrier.toLowerCase().contains('whl') && (p.partnerName.toLowerCase().contains('wan hai') || (p.scacCode ?? '').toLowerCase() == 'whl')) ||
      (rawCarrier.toLowerCase().contains('yml') && (p.partnerName.toLowerCase().contains('yang ming') || (p.scacCode ?? '').toLowerCase() == 'yml')) ||
      (rawCarrier.toLowerCase().contains('msc') && (p.partnerName.toLowerCase().contains('msc') || (p.scacCode ?? '').toLowerCase() == 'msc')) ||
      (rawCarrier.toLowerCase().contains('msk') && (p.partnerName.toLowerCase().contains('maersk') || (p.scacCode ?? '').toLowerCase() == 'msk')) ||
      (rawCarrier.toLowerCase().contains('cma') && (p.partnerName.toLowerCase().contains('cma') || (p.scacCode ?? '').toLowerCase() == 'cma')) ||
      (rawCarrier.toLowerCase().contains('cosco') && (p.partnerName.toLowerCase().contains('cosco') || (p.scacCode ?? '').toLowerCase() == 'cosco')) ||
      (rawCarrier.toLowerCase().contains('emc') && (p.partnerName.toLowerCase().contains('evergreen') || (p.scacCode ?? '').toLowerCase() == 'emc')) ||
      (rawCarrier.toLowerCase().contains('one') && (p.partnerName.toLowerCase().contains('ocean network') || (p.scacCode ?? '').toLowerCase() == 'one')) ||
      (rawCarrier.toLowerCase().contains('hapag') && (p.partnerName.toLowerCase().contains('hapag') || (p.scacCode ?? '').toLowerCase() == 'hapag'))
    ).firstOrNull;
    final effectiveCarrierName = matchedLine != null ? matchedLine.partnerName : rawCarrier;

    // 2. Match Freight Forwarder (وكيل الشحن / الناقل)
    final freightForwarders = partners.where((p) => p.partnerType.contains('Freight Forwarder') || p.partnerType.contains('Carrier')).toList();
    final rawForwarder = opt.forwarderName ?? _extractedFreightMetadata?['forwarder_name']?.toString() ?? '';
    final matchedForwarder = rawForwarder.isNotEmpty
        ? freightForwarders.where((p) =>
            p.partnerName.toLowerCase().contains(rawForwarder.toLowerCase()) ||
            rawForwarder.toLowerCase().contains(p.partnerName.toLowerCase())).firstOrNull
        : null;

    // 3. Match Port of Loading POL (ميناء السفر / التحميل)
    final rawPol = (opt.originPort ?? _extractedFreightMetadata?['origin_port']?.toString() ?? '').toLowerCase();
    final dynamic matchedPol = _matchPortSmart(rawPol, portsList);

    // 4. Match Port of Discharge POD (ميناء الوصول / التفريغ)
    final rawPod = (opt.destinationPort ?? _extractedFreightMetadata?['destination_port']?.toString() ?? '').toLowerCase();
    final dynamic matchedPod = _matchPortSmart(rawPod, portsList);

    // 5. Vessel & Voyage (اسم الباخرة ورقم الرحلة)
    final effectiveVessel = (opt.vesselName != null && opt.vesselName!.isNotEmpty)
        ? opt.vesselName!
        : (_extractedFreightMetadata?['vessel_name']?.toString() ?? (isDirect ? 'Direct Line Service' : 'Transshipment Service'));
    final effectiveVoyage = (opt.voyageNumber != null && opt.voyageNumber!.isNotEmpty)
        ? opt.voyageNumber!
        : (_extractedFreightMetadata?['voyage_number']?.toString() ?? '');

    // 6. Sailing Date ETD & Estimated Arrival ETA (تاريخ الإبحار وتاريخ الوصول)
    DateTime sDate = crd.add(const Duration(days: 2));
    if (opt.etdDate != null && opt.etdDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(opt.etdDate!);
      if (parsed != null) sDate = parsed;
    }

    DateTime arrDate = sDate.add(Duration(days: transitDays));
    if (opt.etaDate != null && opt.etaDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(opt.etaDate!);
      if (parsed != null) arrDate = parsed;
    }

    final is40 = cntrType.contains('40');
    final is20 = cntrType.contains('20');

    // Check for additional unmapped expenses / Free Time Extension fees in notes or localCharges
    double extraFeeAmount = (localCharges != null && localCharges > 0) ? localCharges : 0.0;
    if (notes != null && notes.isNotEmpty) {
      final m = RegExp(r'(?:USD|\$|EUR|EGP)\s*([0-9,]+(?:\.\d+)?)', caseSensitive: false).firstMatch(notes);
      if (m != null) {
        final parsed = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (parsed != null && parsed > 0 && extraFeeAmount == 0.0) {
          extraFeeAmount = parsed;
        }
      }
    }

    return ShippingScenarioItemModel(
      providerId: matchedForwarder?.providerId,
      providerName: effectiveCarrierName,
      vesselName: effectiveVessel,
      voyageNumber: effectiveVoyage,
      portOfLoadingId: matchedPol?.locationId,
      polName: matchedPol != null ? matchedPol.locationName : (opt.originPort ?? 'Shanghai Port'),
      portOfDischargeId: matchedPod?.locationId,
      podName: matchedPod != null ? matchedPod.locationName : (opt.destinationPort ?? 'El Dekheila Port'),
      sailingDate: sDate.toString().substring(0, 10),
      estimatedArrivalDate: arrDate.toString().substring(0, 10),
      expectedLineDelayDays: isDirect ? 2 : 5,
      isRecommended: isRecommended,
      riskLevel: isDirect ? 'Low' : 'Medium',
      quotationCurrency: curr,
      freeTimeDays: freeDays,
      container40ftApplicable: is40,
      container40ftPrice: is40 ? rate : 0.0,
      container40ftQty: is40 ? 1 : 0,
      container40ftCurrency: curr,
      container20ftApplicable: is20,
      container20ftPrice: is20 ? rate : 0.0,
      container20ftQty: is20 ? 1 : 0,
      container20ftCurrency: curr,
      bookingCancellationApplicable: cancelFee != null && cancelFee > 0,
      bookingCancellationPrice: cancelFee ?? 0.0,
      bookingCancellationCurrency: curr,
      othersFeeApplicable: extraFeeAmount > 0,
      othersFeePrice: extraFeeAmount,
      othersFeeCurrency: curr,
      notes: [
        if (!isDirect) 'رحلة غير مباشرة',
        if (notes != null && notes.isNotEmpty) notes,
        if (localCharges != null && localCharges > 0) 'مصاريف محلية / EXW: \$$localCharges',
      ].join(' — '),
    );
  }

  void _addAllExtractedQuotationsToScenarios() {
    if (_extractedOptions.isEmpty) return;
    final crd = _cargoReadyDate;
    final partners = ref.read(allPartnersProvider).valueOrNull ?? ref.read(partnersProvider).valueOrNull ?? [];
    final portsList = ref.read(transportLocationsProvider).valueOrNull ?? [];
    final List<ShippingScenarioItemModel> newItems = [];

    for (int i = 0; i < _extractedOptions.length; i++) {
      final opt = _extractedOptions[i];
      newItems.add(_mapExtractedOptionToScenarioItem(
        opt: opt,
        crd: crd,
        partners: partners,
        portsList: portsList,
        isRecommended: _evalItems.isEmpty && i == 0,
      ));
    }

    setState(() {
      _editFormVersion++;
      _evalItems.addAll(newItems);
      _extractedOptions = [];
      for (int i = 0; i < _evalItems.length; i++) {
        _expandedQuotes[i] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.extractedAndAddedMsg(newItems.length)),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  void _addSingleExtractedQuotationToScenarios(ExtractedQuotationOption opt) {
    final crd = _cargoReadyDate;
    final partners = ref.read(allPartnersProvider).valueOrNull ?? ref.read(partnersProvider).valueOrNull ?? [];
    final portsList = ref.read(transportLocationsProvider).valueOrNull ?? [];

    final newItem = _mapExtractedOptionToScenarioItem(
      opt: opt,
      crd: crd,
      partners: partners,
      portsList: portsList,
      isRecommended: _evalItems.isEmpty,
    );

    setState(() {
      _editFormVersion++;
      _evalItems.add(newItem);
      _expandedQuotes[_evalItems.length - 1] = true;
      _extractedOptions.removeWhere((o) => o.optionId == opt.optionId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.freightQuotesAddedMsg(1)),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  /// ─── Smart Inline Freight Quotation Extractor Card (SWIFT MT103 Style) ────
  Widget _buildInlineFreightQuotationsExtractorWidget() {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.charcoal),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Cobalt Gradient & Icons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.cobalt, AppTheme.wcagCobalt],
                begin: AlignmentDirectional.centerEnd,
                end: AlignmentDirectional.centerStart,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.orange, size: 20),
                      const SizedBox(width: 6),
                      const Icon(Icons.bolt, color: AppTheme.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.freightExtractorTitle,
                          style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isFreightExtractorExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppTheme.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _isFreightExtractorExpanded ? l.collapseExtractor : l.expandExtractor,
                  onPressed: () => setState(() => _isFreightExtractorExpanded = !_isFreightExtractorExpanded),
                ),
              ],
            ),
          ),

          // Collapsible Body
          if (_isFreightExtractorExpanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;

                      // Text Area with bottom Action Overlay
                      final textArea = Stack(
                        children: [
                          TextField(
                            controller: _rawFreightQuoteController,
                            maxLines: 5,
                            minLines: 4,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                            decoration: InputDecoration(
                              hintText: 'لصق نص رسالة أو إيميل عرض السعر من الخط الملاحي أو شركة الشحن...\n(مثال: Route: Shanghai - Alexandria | WHL: USD 6700/40HQ | Transit: 29 days, DIRECT | Free time: 21 days FT)',
                              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 40),
                            ),
                          ),
                          PositionedDirectional(
                            start: 8,
                            bottom: 8,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () async {
                                    final d = await Clipboard.getData(Clipboard.kTextPlain);
                                    if (d != null && d.text != null && d.text!.isNotEmpty) {
                                      _rawFreightQuoteController.text = d.text!;
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cloudWhite,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.paste, size: 12, color: AppTheme.charcoal),
                                        const SizedBox(width: 4),
                                        Text(l.pasteQuoteText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    _rawFreightQuoteController.clear();
                                    setState(() {
                                      _extractedOptions = [];
                                      _extractedFreightMetadata = null;
                                      _extractorError = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoalSurface,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.clear, size: 12, color: AppTheme.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(l.clearField, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _loadSampleFreightQuote,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.orangeLight,
                                      border: Border.all(color: AppTheme.orange),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lightbulb_outline, size: 12, color: AppTheme.orange),
                                        const SizedBox(width: 4),
                                        Text(l.sampleQuoteBtn, style: const TextStyle(fontSize: 11, color: AppTheme.wcagOrange, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      // Action Buttons
                      final actionButtons = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppButton(
                            label: l.uploadQuoteDocument,
                            icon: Icons.upload_file,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            onPressed: _isFreightExtracting ? null : _extractFreightFromFile,
                          ),
                          const SizedBox(height: 8),
                          AppButton(
                            label: l.extractQuotesBtn,
                            icon: Icons.bolt,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            isLoading: _isFreightExtracting,
                            onPressed: _isFreightExtracting ? null : _extractFreightFromText,
                          ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            textArea,
                            const SizedBox(height: 10),
                            actionButtons,
                          ],
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: textArea),
                            const SizedBox(width: 14),
                            SizedBox(width: 220, child: actionButtons),
                          ],
                        );
                      }
                    },
                  ),

                  // Error Banner
                  if (_extractorError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.crimsonLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.crimsonBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.crimson, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_extractorError!, style: const TextStyle(color: AppTheme.crimson, fontSize: 11))),
                        ],
                      ),
                    ),
                  ],

                  // Extracted Options Live Results Card
                  if (_extractedOptions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.emeraldBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.extractedQuotesBanner(_extractedOptions.length),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                ),
                              ),
                              AppButton(
                                label: l.addAllQuotes(_extractedOptions.length),
                                icon: Icons.add_task,
                                variant: AppButtonVariant.success,
                                size: AppButtonSize.small,
                                onPressed: _addAllExtractedQuotationsToScenarios,
                              ),
                            ],
                          ),
                          if (_pickedFreightFile != null || _extractedFreightMetadata != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (_pickedFreightFile != null)
                                  Chip(
                                    avatar: const Icon(Icons.attach_file, size: 14, color: AppTheme.cobalt),
                                    label: Text('${l.attachedFileChip}: ${_pickedFreightFile!.name}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    backgroundColor: AppTheme.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                if (_extractedFreightMetadata?['origin_port'] != null)
                                  Chip(
                                    avatar: const Icon(Icons.flight_takeoff, size: 14, color: AppTheme.cobalt),
                                    label: Text('${l.originPortChip}: ${_extractedFreightMetadata!['origin_port']}', style: const TextStyle(fontSize: 10.5)),
                                    backgroundColor: AppTheme.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                if (_extractedFreightMetadata?['destination_port'] != null)
                                  Chip(
                                    avatar: const Icon(Icons.flight_land, size: 14, color: AppTheme.emerald),
                                    label: Text('${l.destinationPortChip}: ${_extractedFreightMetadata!['destination_port']}', style: const TextStyle(fontSize: 10.5)),
                                    backgroundColor: AppTheme.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                if (_extractedFreightMetadata?['local_charges'] != null)
                                  Chip(
                                    avatar: const Icon(Icons.monetization_on, size: 14, color: AppTheme.orange),
                                    label: Text('${l.localExpensesChip}: \$${_extractedFreightMetadata!['local_charges']}', style: const TextStyle(fontSize: 10.5)),
                                    backgroundColor: AppTheme.white,
                                    padding: EdgeInsets.zero,
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _extractedOptions.map((opt) {
                              return Container(
                                width: 340,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.cloudWhite),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${opt.carrierName} (${opt.containerType})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: opt.isDirect ? AppTheme.emeraldLight : AppTheme.orangeLight,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: opt.isDirect ? AppTheme.emeraldBorder : AppTheme.orange),
                                          ),
                                          child: Text(
                                            opt.isDirect ? l.directRoute : l.transitRoute,
                                            style: TextStyle(fontSize: 10, color: opt.isDirect ? AppTheme.wcagEmerald : AppTheme.wcagOrange, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${l.oceanFreightLabel}: \$${opt.oceanFreight.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                        if (opt.localCharges != null && opt.localCharges! > 0)
                                          Text('${l.localChargesLabel}: \$${opt.localCharges!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                        Text('${l.totalLabel}: \$${opt.totalEstimatedCost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('⏱️ ${l.transitDaysLabel}: ${opt.transitDays ?? "-"}', style: const TextStyle(fontSize: 10.5, color: AppTheme.charcoal)),
                                        Text('⏳ ${l.freeTimeDaysLabel}: ${opt.freeTimeDays ?? 14}', style: const TextStyle(fontSize: 10.5, color: AppTheme.charcoal)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: AppButton(
                                        label: l.addThisQuoteBtn,
                                        icon: Icons.add,
                                        variant: AppButtonVariant.secondary,
                                        size: AppButtonSize.small,
                                        onPressed: () => _addSingleExtractedQuotationToScenarios(opt),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _applySmartExtractedFreightQuotes(Map<String, dynamic> fields) {
    final crd = _cargoReadyDate;
    final List<dynamic> options = (fields['rate_options'] is List && (fields['rate_options'] as List).isNotEmpty)
        ? fields['rate_options'] as List
        : [fields];

    final List<ShippingScenarioItemModel> newItems = [];
    final partners = ref.read(allPartnersProvider).valueOrNull ?? ref.read(partnersProvider).valueOrNull ?? [];
    final portsList = ref.read(transportLocationsProvider).valueOrNull ?? [];

    for (int i = 0; i < options.length; i++) {
      final optMap = Map<String, dynamic>.from(options[i] as Map);
      final opt = ExtractedQuotationOption.fromMap(optMap, i + 1);
      newItems.add(_mapExtractedOptionToScenarioItem(
        opt: opt,
        crd: crd,
        partners: partners,
        portsList: portsList,
        isRecommended: i == 0,
      ));
    }

    setState(() {
      _editFormVersion++;
      _evalItems.clear();
      _evalItems.addAll(newItems);
      _expandedQuotes.clear();
      for (int i = 0; i < newItems.length; i++) {
        _expandedQuotes[i] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.extractedAndAddedMsg(newItems.length)),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(shippingScenariosProvider);
    final projectsState = ref.watch(projectsProvider);
    final poState = ref.watch(purchaseOrdersProvider);
    final partnersState = ref.watch(allPartnersProvider);
    final portsState = ref.watch(transportLocationsProvider);
    final currenciesAsync = ref.watch(currenciesProvider);

    final poList = poState.purchaseOrders;
    final projectsList = projectsState.valueOrNull ?? [];
    final List<PartnerModel> partnersList = partnersState.valueOrNull ?? [];
    final List<CurrencyModel> currenciesList = currenciesAsync.valueOrNull ?? [];

    final List<PartnerModel> freightForwarders = partnersList.where((p) {
      final t = p.partnerType.toLowerCase();
      return t.contains('freight forwarder') || t.contains('forwarder') || t.contains('شحن') || t.contains('لوجستي');
    }).toList();

    final List<PartnerModel> shippingLines = partnersList.where((p) {
      final t = p.partnerType.toLowerCase();
      return t.contains('shipping line') ||
          t.contains('carrier') ||
          t.contains('liner') ||
          t.contains('ملاحي') ||
          t.contains('خط شحن') ||
          t.contains('خطوط ملاحية');
    }).toList();

    final List<PartnerModel> customsBrokers = partnersList.where((p) {
      final t = p.partnerType.toLowerCase();
      return t.contains('customs broker') || t.contains('broker') || t.contains('تخليص') || t.contains('مخلص');
    }).toList();
    final portsList = portsState.valueOrNull ?? [];

    if (widget.isEmbedded) {
      return _buildEvaluatorTab(state, poList, projectsList, freightForwarders, shippingLines, customsBrokers, portsList, currenciesList);
    }

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.analytics_outlined,
        titleEn: 'Scenarios Evaluator',
        titleAr: 'دراسة وسيناريوهات الشحن',
      ),

      VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'Saved Evaluations Log',
        titleAr: 'سجل الدراسات المحفوظة',
        badge: state.sessions.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.sessions.length}',
                  style: const TextStyle(color: AppTheme.cobalt, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    ];

    return VerticalStageScaffold(
      stageCode: 'STEP_01',
      titleEn: 'Freight Shipping Scenarios & Carrier Evaluation',
      titleAr: 'دراسات وسيناريوهات الشحن والمفاضلة',
      headerIcon: Icons.alt_route_outlined,
      headerColor: AppTheme.cobalt,
      tabs: tabs,
      selectedIndex: _tabController.index,
      onTabSelected: (index) => setState(() {
        _tabController.index = index;
        if (index == 0) _hasVisitedTab0 = true;
        if (index == 1) _hasVisitedTab1 = true;
      }),
      selectedImportFileId: _selectedImportFileId,
      onShipmentStatusChanged: () => _refreshData(force: true),
      headerActions: [
        AppButton(
          key: const ValueKey('searchAndCloneStudyBtn'),
          label: l.searchAndCloneStudyBtn,
          icon: Icons.copy_all_rounded,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () => _openSearchAndCloneStudyDialog(context),
        ),
        const SizedBox(width: 8),
        SmartUploadButton(
          module: SmartUploadModule.freightQuotation,
          label: '🚀 ${l.extractFreightQuotes}',
          onDataExtracted: (result) {
            _applySmartExtractedFreightQuotes(result.extractedFields);
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          tooltip: l.liveRefresh,
          onPressed: () => _refreshData(force: true),
        ),
      ],
      body: IndexedStack(
        index: _tabController.index,
        children: [
          _hasVisitedTab0
              ? _buildEvaluatorTab(state, poList, projectsList, freightForwarders, shippingLines, customsBrokers, portsList, currenciesList)
              : const SizedBox.shrink(),
          _hasVisitedTab1
              ? _buildHistoryRegistryTab(state, poList, projectsList)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }


  Widget _buildEvaluatorTab(
    ShippingScenariosState state,
    List<PurchaseOrderModel> poList,
    List projectsList,
    List<PartnerModel> freightForwarders,
    List<PartnerModel> shippingLines,
    List<PartnerModel> customsBrokers,
    List portsList,
    List<CurrencyModel> currenciesList,
  ) {
    final crd = _cargoReadyDate;
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate Scenario lead times

    final calculatedScenarios = _evalItems.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;

      final sDate = DateTime.tryParse(item.sailingDate) ?? crd;
      final etaDate = DateTime.tryParse(item.estimatedArrivalDate) ?? sDate.add(const Duration(days: 20));

      final vesselLeadTime = etaDate.difference(sDate).inDays;
      final readyDays = sDate.difference(crd).inDays;
      final totalDays = vesselLeadTime + readyDays + _avgForm4Days + _avgClearanceDays + item.expectedLineDelayDays;

      final expectedWhDate = crd.add(Duration(days: totalDays)).toString().substring(0, 10);

      return {
        'index': idx,
        'item': item,
        'vesselLeadTime': vesselLeadTime,
        'readyDays': readyDays,
        'totalDays': totalDays,
        'expectedWhDate': expectedWhDate,
      };
    }).toList();

    final validScenarios = calculatedScenarios.where((c) => !(c['item'] as ShippingScenarioItemModel).isExcludedFromAverage).toList();
    final avgTotalDays = validScenarios.isNotEmpty
        ? (validScenarios.fold<int>(0, (sum, c) => sum + (c['totalDays'] as int)) / validScenarios.length).round()
        : 0;
    final avgArrivalDate = validScenarios.isNotEmpty
        ? crd.add(Duration(days: avgTotalDays)).toString().substring(0, 10)
        : 'N/A';

    final recItemMap = calculatedScenarios.where((c) {
      final it = c['item'] as ShippingScenarioItemModel;
      return it.isRecommended && it.totalQuotationAmount != null;
    }).firstOrNull;
    final recItem = recItemMap != null ? (recItemMap['item'] as ShippingScenarioItemModel) : null;

    final earliestItemMap = validScenarios.isNotEmpty
        ? validScenarios.reduce((a, b) => (a['totalDays'] as int) < (b['totalDays'] as int) ? a : b)
        : null;
    final latestItemMap = validScenarios.isNotEmpty
        ? validScenarios.reduce((a, b) => (a['totalDays'] as int) > (b['totalDays'] as int) ? a : b)
        : null;

    // Linked PO packing list metrics
    double totalCargoCbm = 0.0;
    double totalCargoWeightKg = 0.0;
    int linkedPlCount = 0;
    bool hasNonStackableItems = false;
    bool hasExplicitPackingList = false;

    List<PurchaseOrderModel> filteredPOs = [];
    if (_selectedImportFileId != null) {
      final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
      final selectedFile = importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
      if (selectedFile != null) {
        final filePoIds = selectedFile.poIds ?? [];
        filteredPOs = poList.where((p) =>
            (p.poId != null && filePoIds.contains(p.poId)) ||
            (p.importFileId != null && p.importFileId == selectedFile.importFileId) ||
            (selectedFile.importFileCode.isNotEmpty && p.importFileCode != null && p.importFileCode == selectedFile.importFileCode)).toList();
      }
    } else if (_selectedPoId != null) {
      filteredPOs = poList.where((p) => p.poId == _selectedPoId).toList();
    }

    for (var po in filteredPOs) {
      if (po.packingListItems.isNotEmpty) {
        hasExplicitPackingList = true;
        linkedPlCount += po.packingListItems.length;
        for (var pl in po.packingListItems) {
          totalCargoCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
          totalCargoWeightKg += (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg));
          if (!pl.isStackable) hasNonStackableItems = true;
        }
      }
    }

    final containerRec = ContainerRequirementEngine.calculate(
      totalCbm: totalCargoCbm,
      totalWeightKg: totalCargoWeightKg,
      isStackable: _isStackable,
    );

    final dualRec = ContainerRequirementEngine.calculateBoth(
      totalCbm: totalCargoCbm,
      totalWeightKg: totalCargoWeightKg,
    );

    return Form(
      key: _formKey,
      child: Stack(
        children: [
          Positioned.fill(
            child: KeyedSubtree(
              key: ValueKey('evaluator_form_${_editingSessionId ?? "new"}_$_editFormVersion'),
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 16, top: 16, bottom: 85),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_editingSessionId != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.orange),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_note, color: AppTheme.orange, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '⚠️ ${l.activeEditStudyBanner}: $_editingSessionCode (${_title.isNotEmpty ? _title : l.noDataFound}). ${l.activeEditStudyHint}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.wcagOrange, fontSize: 13),
                            ),
                          ),
                          AppButton(
                            label: l.cancelEditAndStartNew,
                            icon: Icons.cancel_outlined,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            onPressed: () {
                              _resetFormForNewStudy();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.cancelEditModeMsg),
                                  backgroundColor: AppTheme.charcoal,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Top Metrics Cards Responsive Layout
                  LayoutBuilder(
                    builder: (context, metricConstraints) {
                      final card1 = _buildMetricCard(
                        l.avgWarehouseArrivalMetric,
                        avgArrivalDate,
                        Icons.date_range,
                        AppTheme.wcagEmerald,
                        subtitle: l.avgDaysFromReadiness(avgTotalDays),
                      );
                      final card2 = _buildMetricCard(
                        l.earliestLineMetric,
                        earliestItemMap != null ? (earliestItemMap["item"] as ShippingScenarioItemModel).providerName : 'N/A',
                        Icons.speed,
                        AppTheme.wcagCobalt,
                        subtitle: earliestItemMap != null ? '${l.estimatedArrivalDateCol}: ${earliestItemMap["expectedWhDate"]}' : null,
                      );
                      final card3 = _buildMetricCard(
                        l.latestLineMetric,
                        latestItemMap != null ? (latestItemMap["item"] as ShippingScenarioItemModel).providerName : 'N/A',
                        Icons.warning_amber_rounded,
                        AppTheme.wcagOrange,
                        subtitle: latestItemMap != null ? '${l.estimatedArrivalDateCol}: ${latestItemMap["expectedWhDate"]}' : null,
                      );
                      final card4 = _buildMetricCard(
                        l.recommendedLineMetric,
                        recItem != null ? '${recItem.providerName} (${recItem.vesselName})' : l.unassigned,
                        Icons.stars_rounded,
                        AppTheme.cobalt,
                        subtitle: recItemMap != null ? '${l.avgWarehouseArrivalMetric}: ${recItemMap["expectedWhDate"]} (${recItemMap["totalDays"]} d)' : null,
                      );

                      if (metricConstraints.maxWidth < 600) {
                        return Column(
                          children: [
                            card1,
                            const SizedBox(height: 8),
                            card2,
                            const SizedBox(height: 8),
                            card3,
                            const SizedBox(height: 8),
                            card4,
                          ],
                        );
                      } else if (metricConstraints.maxWidth < 1050) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: card1),
                                const SizedBox(width: 12),
                                Expanded(child: card2),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: card3),
                                const SizedBox(width: 12),
                                Expanded(child: card4),
                              ],
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Expanded(child: card1),
                            const SizedBox(width: 12),
                            Expanded(child: card2),
                            const SizedBox(width: 12),
                            Expanded(child: card3),
                            const SizedBox(width: 12),
                            Expanded(child: card4),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Smart AI Freight Quotations Extractor (Text & OCR Box) ──
                  _buildInlineFreightQuotationsExtractorWidget(),

                  // Study Main Settings Card
                  Card(
                    elevation: 2,
                    color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, paramConstraints) {
                          final isNarrowParam = paramConstraints.maxWidth < 768;

                          final titleWidget = TextFormField(
                            key: ValueKey('title_${_editingSessionId ?? "new"}_$_editFormVersion'),
                            initialValue: _title,
                            decoration: InputDecoration(labelText: '${l.studyTitleLabel} *', hintText: l.studyTitleLabel, isDense: true),
                            validator: (v) => v == null || v.trim().isEmpty ? l.requiredField : null,
                            onChanged: (v) => _title = v.trim(),
                          );

                          final crdWidget = InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _cargoReadyDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  _cargoReadyDate = picked;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(labelText: '${l.crdLabel} *', isDense: true),
                              child: Text(_cargoReadyDate.toString().substring(0, 10), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          );

                          final importFileWidget = SearchableDropdownField<int?>(
                            value: _selectedImportFileId,
                            labelText: l.linkImportFile,
                            items: [
                              SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                              ...(ref.watch(importFilesProvider).valueOrNull ?? []).map((f) => SearchableDropdownItem<int?>(
                                    value: f.importFileId,
                                    label: '${f.primaryNameWithCode} - ${f.companyName}',
                                  )),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _selectedImportFileId = v;
                                if (v != null) {
                                  final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
                                  final f = importFiles.where((file) => file.importFileId == v).firstOrNull;
                                  if (f != null) {
                                    final fCode = f.displayName;
                                    _title = '[$fCode] ${f.companyName}';
                                  }
                                }
                              });
                            },
                          );

                          final poWidget = SearchableDropdownField<int?>(
                            value: _selectedPoId,
                            labelText: l.linkPurchaseOrder,
                            items: [
                              SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                              ...poList.map((po) => SearchableDropdownItem<int?>(
                                    value: po.poId,
                                    label: '${po.displayName} (${po.poNumber}) (${po.supplierName ?? "Supplier"})',
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedPoId = v),
                          );

                          final projectWidget = SearchableDropdownField<int?>(
                            value: _selectedProjectId,
                            labelText: l.linkProject,
                            items: [
                              SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                              ...projectsList.map((p) => SearchableDropdownItem<int?>(
                                    value: p.projectId,
                                    label: '${p.projectCode} - ${p.projectName}',
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedProjectId = v),
                          );

                          final form4Widget = TextFormField(
                            key: ValueKey('avg_form4_${_editingSessionId ?? "new"}_$_editFormVersion'),
                            initialValue: _avgForm4Days.toString(),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: l.avgForm4DaysLabel, isDense: true, suffixText: 'd'),
                            onChanged: (v) => _avgForm4Days = int.tryParse(v) ?? 5,
                          );

                          final clearanceWidget = TextFormField(
                            key: ValueKey('avg_clearance_${_editingSessionId ?? "new"}_$_editFormVersion'),
                            initialValue: _avgClearanceDays.toString(),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: l.avgClearanceDaysLabel, isDense: true, suffixText: 'd'),
                            onChanged: (v) => _avgClearanceDays = int.tryParse(v) ?? 7,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.tune, color: AppTheme.cobalt, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l.studySetupAndParameters,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Parameters Row 1
                              if (isNarrowParam) ...[
                                titleWidget,
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: crdWidget),
                                    const SizedBox(width: 10),
                                    Expanded(child: importFileWidget),
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: titleWidget,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: crdWidget),
                                    const SizedBox(width: 12),
                                    Expanded(child: importFileWidget),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),

                              // Parameters Row 2 (Pick-up Address)
                              TextFormField(
                                key: ValueKey('pickup_addr_${_editingSessionId ?? "new"}_$_editFormVersion'),
                                initialValue: _pickUpAddress,
                                decoration: InputDecoration(
                                  labelText: l.pickupAddressLabel,
                                  hintText: 'Factory / Industrial Zone, Origin Country',
                                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.cobalt),
                                  isDense: true,
                                ),
                                onChanged: (v) => _pickUpAddress = v.trim(),
                              ),
                              const SizedBox(height: 12),

                              // Parameters Row 3 (PO Link & Project Link)
                              if (isNarrowParam) ...[
                                Row(
                                  children: [
                                    Expanded(child: poWidget),
                                    const SizedBox(width: 10),
                                    Expanded(child: projectWidget),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: form4Widget),
                                    const SizedBox(width: 10),
                                    Expanded(child: clearanceWidget),
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(child: poWidget),
                                    const SizedBox(width: 12),
                                    Expanded(child: projectWidget),
                                    const SizedBox(width: 12),
                                    Expanded(child: form4Widget),
                                    const SizedBox(width: 12),
                                    Expanded(child: clearanceWidget),
                                  ],
                                ),
                              ],

                          // Linked Packing List & Container Engine Section
                          if (_selectedImportFileId != null || _selectedPoId != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.cobaltLight.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.cobaltBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${l.totalShipmentSummary}: ',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                      ),
                                      Text(
                                        '${totalCargoCbm.toStringAsFixed(3)} m³ | ${totalCargoWeightKg.toStringAsFixed(0)} kg (${filteredPOs.length} POs | $linkedPlCount items)',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  if (hasExplicitPackingList) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: hasNonStackableItems ? AppTheme.orangeLight : AppTheme.emeraldLight,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: hasNonStackableItems ? AppTheme.orange : AppTheme.emeraldBorder),
                                      ),
                                      child: Text(
                                        hasNonStackableItems
                                            ? '⚠️ ${l.nonStackableOption}'
                                            : '✅ ${l.stackableOption}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: hasNonStackableItems ? AppTheme.wcagOrange : AppTheme.wcagEmerald,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('${l.cargoStackingType}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: Text('📦 ${l.stackableOption}'),
                                        selected: _isStackable,
                                        selectedColor: AppTheme.cobalt,
                                        labelStyle: TextStyle(color: _isStackable ? AppTheme.white : AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 11),
                                        onSelected: (val) => setState(() => _isStackable = true),
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: Text('🚫 ${l.nonStackableOption}'),
                                        selected: !_isStackable,
                                        selectedColor: AppTheme.wcagOrange,
                                        labelStyle: TextStyle(color: !_isStackable ? AppTheme.white : AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 11),
                                        onSelected: (val) => setState(() => _isStackable = false),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Text('${l.approvedRecommendation}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (_isStackable ? AppTheme.emerald : AppTheme.wcagOrange).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _isStackable ? AppTheme.emerald : AppTheme.wcagOrange),
                                        ),
                                        child: Text(
                                          containerRec.recommendationSummary,
                                          style: TextStyle(fontWeight: FontWeight.bold, color: _isStackable ? AppTheme.emerald : AppTheme.wcagOrange, fontSize: 12),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: AppTheme.cloudWhite, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.textMuted)),
                                        child: Text(
                                          _isStackable
                                              ? '${l.nonStackableOption}: ${dualRec.nonStackableResult.requiredContainersCount}x ${dualRec.nonStackableResult.recommendedContainerCode}'
                                              : '${l.stackableOption}: ${dualRec.stackableResult.requiredContainersCount}x ${dualRec.stackableResult.recommendedContainerCode}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal, fontSize: 11),
                                        ),
                                      ),
                                      AppButton(
                                        label: l.compareContainersMatrix,
                                        icon: Icons.table_chart,
                                        variant: AppButtonVariant.secondary,
                                        size: AppButtonSize.small,
                                        onPressed: () => _showContainerComparisonDialog(context, dualRec, totalCargoCbm, totalCargoWeightKg),
                                      ),
                                      const SizedBox(width: 8),
                                      AppButton(
                                        label: l.visualLoadPlanSimulator,
                                        icon: Icons.view_in_ar,
                                        variant: AppButtonVariant.success,
                                        size: AppButtonSize.small,
                                        onPressed: () => _showVisualLoadPlanDialog(context, filteredPOs, totalCargoCbm, totalCargoWeightKg),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

                  // Carrier Options Section Header
                  LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isNarrowHeader = headerConstraints.maxWidth < 650;
                      final titleWidget = Text(
                        l.shippingCarrierOptions,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      );
                      final addBtn = AppButton(
                        label: l.addNewShippingOption,
                        icon: Icons.add,
                        variant: AppButtonVariant.primary,
                        onPressed: () {
                          setState(() {
                            final defaultLineName = shippingLines.isNotEmpty ? shippingLines.first.partnerName : 'COSCO Shipping';
                            _evalItems.add(ShippingScenarioItemModel(
                              providerName: defaultLineName,
                              vesselName: 'VESSEL NEW',
                              polName: 'Shanghai Port',
                              podName: 'El Dekheila Port',
                              sailingDate: crd.add(const Duration(days: 3)).toString().substring(0, 10),
                              estimatedArrivalDate: crd.add(const Duration(days: 28)).toString().substring(0, 10),
                              expectedLineDelayDays: 2,
                            ));
                          });
                        },
                      );
                      if (isNarrowHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            titleWidget,
                            const SizedBox(height: 8),
                            addBtn,
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: titleWidget),
                          const SizedBox(width: 8),
                          addBtn,
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Carrier Option Cards List
                  ..._evalItems.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final calc = calculatedScenarios.firstWhere((c) => c['index'] == idx, orElse: () => {});

                    final isExpanded = _expandedQuotes[idx] ?? false;

                    // Automatically compute containers total count for displays
                    final currentContainersCount = (item.container40ftApplicable ? item.container40ftQty : 0) + 
                                                   (item.container20ftApplicable ? item.container20ftQty : 0);

                    return Card(
                      elevation: 1.5,
                      color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: item.isRecommended 
                              ? AppTheme.emerald 
                              : (item.isExcludedFromAverage ? (isDark ? AppTheme.textStrong : AppTheme.textMuted) : (isDark ? AppTheme.darkBorder : AppTheme.cobaltBorder)), 
                          width: item.isRecommended ? 2 : 1
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, cardConstraints) {
                            final isNarrowCard = cardConstraints.maxWidth < 800;

                            final avatarWidget = CircleAvatar(
                              radius: 14,
                              backgroundColor: item.isRecommended ? AppTheme.emerald : AppTheme.cobalt,
                              child: Text('${idx + 1}', style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            );

                            final forwarderDropdown = SearchableDropdownField<int?>(
                              value: item.providerId,
                              labelText: l.freightForwarderCol,
                              searchHintText: l.forwarderSearchHint,
                              items: [
                                SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                                ...freightForwarders.map((p) => SearchableDropdownItem<int?>(
                                      value: p.providerId,
                                      label: '${p.partnerName}${p.partnerCode.isNotEmpty ? " (${p.partnerCode})" : ""}',
                                      searchValue: '${p.partnerName} ${p.partnerCode} ${p.partnerType}',
                                    )),
                              ],
                              onChanged: (val) {
                                final partner = freightForwarders.where((p) => p.providerId == val).firstOrNull;
                                _updateItem(idx, item.copyWith(
                                  providerId: val,
                                  providerName: partner != null ? partner.partnerName : item.providerName,
                                ), currenciesList);
                              },
                            );

                            final shippingLineDropdown = SearchableDropdownField<String>(
                              value: shippingLines.any((p) => p.partnerName == item.providerName)
                                  ? item.providerName
                                  : (item.providerName.isNotEmpty ? item.providerName : ''),
                              labelText: '${l.shippingLineCol} *',
                              searchHintText: l.shippingLineSearchHint,
                              items: [
                                SearchableDropdownItem<String>(value: '', label: l.unassigned),
                                if (item.providerName.isNotEmpty && !shippingLines.any((p) => p.partnerName == item.providerName))
                                  SearchableDropdownItem<String>(
                                    value: item.providerName,
                                    label: '★ ${item.providerName} (${l.suggestedSuffix})',
                                    searchValue: item.providerName,
                                  ),
                                ...shippingLines.map((p) => SearchableDropdownItem<String>(
                                      value: p.partnerName,
                                      label: '${p.partnerName}${p.scacCode != null && p.scacCode!.isNotEmpty ? " (${p.scacCode})" : ""}',
                                      searchValue: '${p.partnerName} ${p.partnerCode} ${p.scacCode ?? ""} ${p.partnerType}',
                                      subtitle: p.scacCode != null && p.scacCode!.isNotEmpty ? 'SCAC: ${p.scacCode}' : p.partnerCode,
                                    )),
                              ],
                              onChanged: (val) {
                                if (val != null && val.isNotEmpty) {
                                  _updateItem(idx, item.copyWith(providerName: val), currenciesList);
                                }
                              },
                            );

                            final addShippingLineBtn = IconButton(
                              icon: const Icon(Icons.add_business_outlined, color: AppTheme.emerald, size: 20),
                              tooltip: l.addNewLineTooltip,
                              onPressed: () => UniversalEntityExtractorDialog.showShippingLineExtractor(
                                context,
                                onSaved: () => _refreshData(force: true),
                              ),
                            );

                            final vesselField = TextFormField(
                              key: ValueKey('vessel_${_editingSessionId ?? "new"}_${idx}_$_editFormVersion'),
                              initialValue: item.vesselName,
                              decoration: InputDecoration(labelText: '${l.vesselNameCol} *', isDense: true),
                              validator: (v) => v == null || v.trim().isEmpty ? l.requiredField : null,
                              onChanged: (v) => _updateItem(idx, item.copyWith(vesselName: v.trim()), currenciesList),
                            );

                            final voyageField = TextFormField(
                              key: ValueKey('voyage_${_editingSessionId ?? "new"}_${idx}_$_editFormVersion'),
                              initialValue: item.voyageNumber ?? '',
                              decoration: InputDecoration(labelText: l.voyageCol, isDense: true),
                              onChanged: (v) => _updateItem(idx, item.copyWith(voyageNumber: v.trim()), currenciesList),
                            );

                            final cloneCarrierBtn = IconButton(
                              icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
                              tooltip: l.cloneCarrierOptionTooltip,
                              onPressed: () => _cloneCarrierOption(idx),
                            );

                            final deleteCarrierBtn = IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.crimson),
                              onPressed: _evalItems.length <= 1
                                  ? null
                                  : () {
                                      setState(() {
                                        _evalItems.removeAt(idx);
                                        _expandedQuotes.remove(idx);
                                      });
                                    },
                            );

                            final polDropdown = SearchableDropdownField<int?>(
                              value: item.portOfLoadingId,
                              labelText: l.portOfLoadingCol,
                              items: [
                                SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                                ...portsList.map((p) => SearchableDropdownItem<int?>(
                                      value: p.locationId,
                                      label: '${p.unLocode} - ${p.locationName} (${p.country})',
                                    )),
                              ],
                              onChanged: (val) {
                                final selectedPort = portsList.where((p) => p.locationId == val).firstOrNull;
                                _updateItem(idx, item.copyWith(
                                  portOfLoadingId: val,
                                  polName: selectedPort != null ? selectedPort.locationName : item.polName,
                                ), currenciesList);
                              },
                            );

                            final podDropdown = SearchableDropdownField<int?>(
                              value: item.portOfDischargeId,
                              labelText: l.portOfDischargeCol,
                              items: [
                                SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                                ...portsList.map((p) => SearchableDropdownItem<int?>(
                                      value: p.locationId,
                                      label: '${p.unLocode} - ${p.locationName} (${p.country})',
                                    )),
                              ],
                              onChanged: (val) {
                                final selectedPort = portsList.where((p) => p.locationId == val).firstOrNull;
                                _updateItem(idx, item.copyWith(
                                  portOfDischargeId: val,
                                  podName: selectedPort != null ? selectedPort.locationName : item.podName,
                                ), currenciesList);
                              },
                            );

                            final brokerDropdown = SearchableDropdownField<int?>(
                              value: item.customsBrokerId,
                              labelText: l.customsBrokerLabel,
                              items: [
                                SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                                ...customsBrokers.map((p) => SearchableDropdownItem<int?>(
                                      value: p.providerId,
                                      label: p.partnerName,
                                    )),
                              ],
                              onChanged: (val) {
                                final partner = customsBrokers.where((p) => p.providerId == val).firstOrNull;
                                final hasClearance = item.clearanceFeePrice > 0;
                                _updateItem(idx, item.copyWith(
                                  customsBrokerId: val,
                                  customsBrokerName: partner?.partnerName,
                                  clearanceFeeApplicable: val != null ? true : item.clearanceFeeApplicable,
                                  clearanceFeePrice: (!hasClearance && val != null) ? 2500.0 : item.clearanceFeePrice,
                                  clearanceFeeCurrency: "EGP",
                                  inspectionFeeApplicable: val != null ? true : item.inspectionFeeApplicable,
                                  inspectionFeePrice: (!hasClearance && val != null) ? 3500.0 : item.inspectionFeePrice,
                                  inspectionFeeCurrency: "EGP",
                                  inlandTransportFeeApplicable: val != null ? true : item.inlandTransportFeeApplicable,
                                  inlandTransportFeePrice: (!hasClearance && val != null) ? 14800.0 : item.inlandTransportFeePrice,
                                  inlandTransportFeeCurrency: "EGP",
                                  portExpensesApplicable: val != null ? true : item.portExpensesApplicable,
                                  portExpensesPrice: (!hasClearance && val != null) ? 4750.0 : item.portExpensesPrice,
                                  portExpensesCurrency: "EGP",
                                ), currenciesList);
                              },
                            );

                            final sailingDatePicker = InkWell(
                              onTap: () async {
                                final sDate = DateTime.tryParse(item.sailingDate) ?? DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: sDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  _updateItem(idx, item.copyWith(sailingDate: picked.toString().substring(0, 10)), currenciesList);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(labelText: '${l.sailingDateCol} *', isDense: true),
                                child: Text(item.sailingDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            );

                            final etaDatePicker = InkWell(
                              onTap: () async {
                                final etaDate = DateTime.tryParse(item.estimatedArrivalDate) ?? DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: etaDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  _updateItem(idx, item.copyWith(estimatedArrivalDate: picked.toString().substring(0, 10)), currenciesList);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(labelText: '${l.estimatedArrivalDateCol} *', isDense: true),
                                child: Text(item.estimatedArrivalDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            );

                            final delayField = TextFormField(
                              key: ValueKey('delay_${_editingSessionId ?? "new"}_${idx}_$_editFormVersion'),
                              initialValue: item.expectedLineDelayDays.toString(),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: l.expectedDelayCol, isDense: true),
                              onChanged: (v) {
                                final delay = int.tryParse(v) ?? 0;
                                _updateItem(idx, item.copyWith(expectedLineDelayDays: delay), currenciesList);
                              },
                            );

                            final riskDropdown = SearchableDropdownField<String>(
                              value: item.riskLevel,
                              labelText: l.riskLevelCol,
                              items: const [
                                SearchableDropdownItem(value: 'Low', label: 'Low Risk 🟢'),
                                SearchableDropdownItem(value: 'Medium', label: 'Medium Risk 🟠'),
                                SearchableDropdownItem(value: 'High', label: 'High Risk 🔴'),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  _updateItem(idx, item.copyWith(riskLevel: v), currenciesList);
                                }
                              },
                            );

                            final excludedChip = FilterChip(
                              label: Text(item.isExcludedFromAverage ? l.excludedFromAvg : l.includedInAvg, style: TextStyle(fontSize: 11, color: item.isExcludedFromAverage ? AppTheme.crimson : AppTheme.cobalt)),
                              selected: item.isExcludedFromAverage,
                              onSelected: (val) {
                                _updateItem(idx, item.copyWith(isExcludedFromAverage: val), currenciesList);
                              },
                            );

                            return Column(
                              children: [
                                if (isNarrowCard) ...[
                                  // Header Row for Narrow Viewports
                                  Row(
                                    children: [
                                      avatarWidget,
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.providerName.isNotEmpty ? item.providerName : '${l.carrierOptionHeader} #${idx + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      cloneCarrierBtn,
                                      deleteCarrierBtn,
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Forwarder & Shipping Line
                                  Row(
                                    children: [
                                      Expanded(child: forwarderDropdown),
                                      const SizedBox(width: 8),
                                      Expanded(child: shippingLineDropdown),
                                      addShippingLineBtn,
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Vessel & Voyage
                                  Row(
                                    children: [
                                      Expanded(flex: 2, child: vesselField),
                                      const SizedBox(width: 8),
                                      Expanded(child: voyageField),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Ports & Broker
                                  Row(
                                    children: [
                                      Expanded(child: polDropdown),
                                      const SizedBox(width: 8),
                                      Expanded(child: podDropdown),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  brokerDropdown,
                                  const SizedBox(height: 10),

                                  // Sailing Date & ETA
                                  Row(
                                    children: [
                                      Expanded(child: sailingDatePicker),
                                      const SizedBox(width: 8),
                                      Expanded(child: etaDatePicker),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Delays, Risk & Average exclusion
                                  Row(
                                    children: [
                                      Expanded(child: delayField),
                                      const SizedBox(width: 8),
                                      Expanded(child: riskDropdown),
                                      const SizedBox(width: 8),
                                      excludedChip,
                                    ],
                                  ),
                                ] else ...[
                                  // Full Desktop Layout
                                  // Row 1: Freight Forwarder, Shipping Line, Vessel & Voyage
                                  Row(
                                    children: [
                                      avatarWidget,
                                      const SizedBox(width: 10),
                                      Expanded(flex: 2, child: forwarderDropdown),
                                      const SizedBox(width: 10),
                                      Expanded(flex: 2, child: shippingLineDropdown),
                                      const SizedBox(width: 4),
                                      addShippingLineBtn,
                                      const SizedBox(width: 6),
                                      Expanded(flex: 2, child: vesselField),
                                      const SizedBox(width: 10),
                                      Expanded(child: voyageField),
                                      const SizedBox(width: 4),
                                      cloneCarrierBtn,
                                      const SizedBox(width: 4),
                                      deleteCarrierBtn,
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Row 2: POL, POD & Customs Broker Selector
                                  Row(
                                    children: [
                                      Expanded(child: polDropdown),
                                      const SizedBox(width: 12),
                                      Expanded(child: podDropdown),
                                      const SizedBox(width: 12),
                                      Expanded(child: brokerDropdown),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Row 3: Sailing Date, ETA, Delays & Risk
                                  Row(
                                    children: [
                                      Expanded(child: sailingDatePicker),
                                      const SizedBox(width: 10),
                                      Expanded(child: etaDatePicker),
                                      const SizedBox(width: 10),
                                      Expanded(child: delayField),
                                      const SizedBox(width: 10),
                                      Expanded(child: riskDropdown),
                                      const SizedBox(width: 10),
                                      excludedChip,
                                    ],
                                  ),
                                ],

                            // Live Calculation & Expand Quote buttons
                            if (calc.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.cobaltMedium : AppTheme.cobaltLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        l.polToPodLeadTimeStrip(item.polName ?? '-', item.podName ?? '-', calc["vesselLeadTime"] as int, calc["totalDays"] as int),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                      ),
                                      const SizedBox(width: 16),
                                      Row(
                                        children: [
                                          AppButton(
                                            label: isExpanded 
                                                  ? l.hideQuote 
                                                  : (item.totalQuotationAmount != null
                                                      ? '${l.quoteDetails} [${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? "—"}]'
                                                      : '${l.quoteDetails} [—]'),
                                            icon: isExpanded ? Icons.expand_less : Icons.expand_more,
                                            variant: AppButtonVariant.secondary,
                                            size: AppButtonSize.small,
                                            onPressed: () => setState(() => _expandedQuotes[idx] = !isExpanded),
                                          ),
                                          if (item.totalQuotationAmount == null) ...[
                                            const SizedBox(width: 6),
                                            Builder(
                                              builder: (context) {
                                                final missing = ShippingScenarioCalculator.calculateTotalQuoteValue(item: item, currencies: currenciesList).missingCurrencies;
                                                final missingStr = missing.isNotEmpty ? missing.join(', ') : (item.quotationCurrency ?? '—');
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.wcagOrange.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: AppTheme.wcagOrange, width: 0.8),
                                                  ),
                                                  child: Text(
                                                    l.rateMissingWarning(missingStr),
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                          const SizedBox(width: 10),
                                          Text('${l.avgWarehouseArrivalMetric}: ${calc["expectedWhDate"]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            // Expandable Quotation Cost Form Section (BP-008 Integration)
                            if (isExpanded) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkInputBackground : AppTheme.charcoalSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.request_quote, color: AppTheme.cobalt, size: 18),
                                        const SizedBox(width: 6),
                                        Text(l.quoteDetails, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    
                                    // Row A: Free time & Main Quote Currency
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            key: ValueKey('freetime_${_editingSessionId ?? "new"}_${idx}_$_editFormVersion'),
                                            initialValue: item.freeTimeDays.toString(),
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(labelText: l.freeTimeDaysCol, isDense: true, suffixText: 'd'),
                                            onChanged: (v) {
                                              final ft = int.tryParse(v) ?? 14;
                                              _updateItem(idx, item.copyWith(freeTimeDays: ft), currenciesList);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: SearchableDropdownField<String>(
                                            value: currenciesList.any((c) => c.currencyCode == item.quotationCurrency) ? item.quotationCurrency : (currenciesList.isNotEmpty ? currenciesList.first.currencyCode : 'USD'),
                                            labelText: l.quoteCurrencyCol,
                                            items: currenciesList.map((c) => SearchableDropdownItem(
                                                  value: c.currencyCode,
                                                  label: '${c.currencyCode} - ${c.currencySymbol}',
                                                )).toList(),
                                            onChanged: (v) {
                                              if (v != null) {
                                                _updateItem(idx, item.copyWith(quotationCurrency: v), currenciesList);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Table/Grid of Cost Items (Redesigned: inputs always visible, toggles at the right side)
                                    _buildCostRow(
                                      rowKey: 'container40ft_$idx',
                                      title: '1. ${l.container40ftItem}',
                                      applicable: item.container40ftApplicable,
                                      price: item.container40ftPrice,
                                      currency: item.container40ftCurrency,
                                      qty: item.container40ftQty.toDouble(),
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(container40ftApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(container40ftPrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(container40ftCurrency: v), currenciesList),
                                      onQtyChanged: (v) => _updateItem(idx, item.copyWith(container40ftQty: v.toInt()), currenciesList),
                                      showQty: true,
                                      isIntegerQty: true,
                                      currenciesList: currenciesList,
                                    ),
                                    _buildCostRow(
                                      rowKey: 'container20ft_$idx',
                                      title: '2. ${l.container20ftItem}',
                                      applicable: item.container20ftApplicable,
                                      price: item.container20ftPrice,
                                      currency: item.container20ftCurrency,
                                      qty: item.container20ftQty.toDouble(),
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(container20ftApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(container20ftPrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(container20ftCurrency: v), currenciesList),
                                      onQtyChanged: (v) => _updateItem(idx, item.copyWith(container20ftQty: v.toInt()), currenciesList),
                                      showQty: true,
                                      isIntegerQty: true,
                                      currenciesList: currenciesList,
                                    ),
                                    _buildCostRow(
                                      rowKey: 'lclCbm_$idx',
                                      title: '3. ${l.lclCbmItem}',
                                      applicable: item.lclCbmApplicable,
                                      price: item.lclCbmPrice,
                                      currency: item.lclCbmCurrency,
                                      qty: item.lclCbmQty,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(lclCbmApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(lclCbmPrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(lclCbmCurrency: v), currenciesList),
                                      onQtyChanged: (v) => _updateItem(idx, item.copyWith(lclCbmQty: v), currenciesList),
                                      showQty: true,
                                      isIntegerQty: false,
                                      currenciesList: currenciesList,
                                    ),
                                    
                                    // Total containers label
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      child: Text(
                                        l.totalContainersCount(currentContainersCount, item.container40ftApplicable ? item.container40ftQty : 0, item.container20ftApplicable ? item.container20ftQty : 0),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.wcagCobalt),
                                      ),
                                    ),

                                    _buildCostRow(
                                      rowKey: 'expressCourier_$idx',
                                      title: '4. ${l.expressCourierItem}',
                                      applicable: item.expressCourierApplicable,
                                      price: item.expressCourierPrice,
                                      currency: item.expressCourierCurrency,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(expressCourierApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(expressCourierPrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(expressCourierCurrency: v), currenciesList),
                                      currenciesList: currenciesList,
                                    ),
                                    _buildCostRow(
                                      rowKey: 'eurAtr_$idx',
                                      title: '5. ${l.eurAtrItem}',
                                      applicable: item.eurAtrApplicable,
                                      price: item.eurAtrPrice,
                                      currency: item.eurAtrCurrency,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(eurAtrApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(eurAtrPrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(eurAtrCurrency: v), currenciesList),
                                      currenciesList: currenciesList,
                                    ),
                                    _buildCostRow(
                                      rowKey: 'solasVgm_$idx',
                                      title: '6. ${l.solasVgmItem}',
                                      applicable: item.solasVgmApplicable,
                                      price: item.solasVgmPrice,
                                      currency: item.solasVgmCurrency,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(solasVgmApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(solasVgmPrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(solasVgmCurrency: v), currenciesList),
                                      currenciesList: currenciesList,
                                    ),
                                    _buildCostRow(
                                      rowKey: 'vgmNotification_$idx',
                                      title: '7. ${l.vgmNotificationItem}',
                                      applicable: item.vgmNotificationApplicable,
                                      price: item.vgmNotificationPrice,
                                      currency: item.vgmNotificationCurrency,
                                      qty: currentContainersCount.toDouble(),
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(vgmNotificationApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(vgmNotificationPrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(vgmNotificationCurrency: v), currenciesList),
                                      showQty: true,
                                      qtyReadOnly: true,
                                      currenciesList: currenciesList,
                                    ),
                                    _buildCostRow(
                                      rowKey: 'telexRelease_$idx',
                                      title: '8. ${l.telexReleaseItem}',
                                      applicable: item.telexReleaseApplicable,
                                      price: item.telexReleasePrice,
                                      currency: item.telexReleaseCurrency,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(telexReleaseApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(telexReleasePrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(telexReleaseCurrency: v), currenciesList),
                                      currenciesList: currenciesList,
                                    ),
                                    _buildCostRow(
                                      rowKey: 'insurance_$idx',
                                      title: '9. ${l.insuranceItem}',
                                      applicable: item.insuranceApplicable,
                                      price: item.insurancePrice,
                                      currency: item.insuranceCurrency,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(insuranceApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(insurancePrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(insuranceCurrency: v), currenciesList),
                                      currenciesList: currenciesList,
                                    ),

                                    _buildCostRow(
                                      rowKey: 'bookingCancellation_$idx',
                                      title: '10. ${l.bookingCancellationItem}',
                                      applicable: item.bookingCancellationApplicable,
                                      price: item.bookingCancellationPrice,
                                      currency: item.bookingCancellationCurrency,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(bookingCancellationApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(bookingCancellationPrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(bookingCancellationCurrency: v), currenciesList),
                                      currenciesList: currenciesList,
                                    ),

                                    // New Cost Rows
                                    _buildCostRow(
                                      rowKey: 'ics2FilingFee_$idx',
                                      title: '11. ${l.ics2FilingFeeItem}',
                                      applicable: item.ics2FilingFeeApplicable,
                                      price: item.ics2FilingFeePrice,
                                      currency: item.ics2FilingFeeCurrency,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(ics2FilingFeeApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(ics2FilingFeePrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(ics2FilingFeeCurrency: v), currenciesList),
                                      currenciesList: currenciesList,
                                    ),
                                    _buildCostRow(
                                      rowKey: 'documentFees_$idx',
                                      title: '12. ${l.documentFeesItem}',
                                      applicable: item.documentFeesApplicable,
                                      price: item.documentFeesPrice,
                                      currency: item.documentFeesCurrency,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(documentFeesApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(documentFeesPrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(documentFeesCurrency: v), currenciesList),
                                      currenciesList: currenciesList,
                                    ),
                                    _buildCostRow(
                                      rowKey: 'waiverLetterFee_$idx',
                                      title: '13. ${l.waiverLetterFeeItem}',
                                      applicable: item.waiverLetterFeeApplicable,
                                      price: item.waiverLetterFeePrice,
                                      currency: item.waiverLetterFeeCurrency,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(waiverLetterFeeApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(waiverLetterFeePrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(waiverLetterFeeCurrency: v), currenciesList),
                                      currenciesList: currenciesList,
                                    ),
                                    _buildCostRow(
                                      rowKey: 'othersFee_$idx',
                                      title: '14. ${l.othersFeeItem}',
                                      applicable: item.othersFeeApplicable,
                                      price: item.othersFeePrice,
                                      currency: item.othersFeeCurrency,
                                      onApplicableChanged: (v) => _updateItem(idx, item.copyWith(othersFeeApplicable: v), currenciesList),
                                      onPriceChanged: (v) => _updateItem(idx, item.copyWith(othersFeePrice: v), currenciesList),
                                      onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(othersFeeCurrency: v), currenciesList),
                                      currenciesList: currenciesList,
                                    ),
                                     _buildCostRow(
                                       rowKey: 'dthc_$idx',
                                       title: '15. ${l.dthcItem}',
                                       applicable: item.dthcApplicable,
                                       price: item.dthcPrice,
                                       currency: item.dthcCurrency,
                                       onApplicableChanged: (v) => _updateItem(idx, item.copyWith(dthcApplicable: v), currenciesList),
                                       onPriceChanged: (v) => _updateItem(idx, item.copyWith(dthcPrice: v), currenciesList),
                                       onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(dthcCurrency: v), currenciesList),
                                       currenciesList: currenciesList,
                                     ),
                                     _buildCostRow(
                                       rowKey: 'storagePerWeek_$idx',
                                       title: '16. ${l.storagePerWeekItem}',
                                       applicable: item.storagePerWeekApplicable,
                                       price: item.storagePerWeekPrice,
                                       currency: item.storagePerWeekCurrency,
                                       onApplicableChanged: (v) => _updateItem(idx, item.copyWith(storagePerWeekApplicable: v), currenciesList),
                                       onPriceChanged: (v) => _updateItem(idx, item.copyWith(storagePerWeekPrice: v), currenciesList),
                                       onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(storagePerWeekCurrency: v), currenciesList),
                                       currenciesList: currenciesList,
                                     ),
                                     _buildCostRow(
                                       rowKey: 'extraDayStorage_$idx',
                                       title: '17. ${l.extraDayStorageItem}',
                                       applicable: item.extraDayStorageApplicable,
                                       price: item.extraDayStoragePrice,
                                       currency: item.extraDayStorageCurrency,
                                       onApplicableChanged: (v) => _updateItem(idx, item.copyWith(extraDayStorageApplicable: v), currenciesList),
                                       onPriceChanged: (v) => _updateItem(idx, item.copyWith(extraDayStoragePrice: v), currenciesList),
                                       onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(extraDayStorageCurrency: v), currenciesList),
                                       currenciesList: currenciesList,
                                     ),
                                     _buildCostRow(
                                       rowKey: 'clearanceFee_$idx',
                                       title: '18. ${l.clearanceBrokerFeeItem}',
                                       applicable: item.clearanceFeeApplicable,
                                       price: item.clearanceFeePrice,
                                       currency: item.clearanceFeeCurrency,
                                       onApplicableChanged: (v) => _updateItem(idx, item.copyWith(clearanceFeeApplicable: v), currenciesList),
                                       onPriceChanged: (v) => _updateItem(idx, item.copyWith(clearanceFeePrice: v), currenciesList),
                                       onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(clearanceFeeCurrency: v), currenciesList),
                                       currenciesList: currenciesList,
                                     ),
                                     _buildCostRow(
                                       rowKey: 'inspectionFee_$idx',
                                       title: '19. ${l.inspectionFeeItem}',
                                       applicable: item.inspectionFeeApplicable,
                                       price: item.inspectionFeePrice,
                                       currency: item.inspectionFeeCurrency,
                                       onApplicableChanged: (v) => _updateItem(idx, item.copyWith(inspectionFeeApplicable: v), currenciesList),
                                       onPriceChanged: (v) => _updateItem(idx, item.copyWith(inspectionFeePrice: v), currenciesList),
                                       onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(inspectionFeeCurrency: v), currenciesList),
                                       currenciesList: currenciesList,
                                     ),
                                     _buildCostRow(
                                       rowKey: 'inlandTransport_$idx',
                                       title: '20. ${l.inlandTransportFeeItem}',
                                       applicable: item.inlandTransportFeeApplicable,
                                       price: item.inlandTransportFeePrice,
                                       currency: item.inlandTransportFeeCurrency,
                                       onApplicableChanged: (v) => _updateItem(idx, item.copyWith(inlandTransportFeeApplicable: v), currenciesList),
                                       onPriceChanged: (v) => _updateItem(idx, item.copyWith(inlandTransportFeePrice: v), currenciesList),
                                       onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(inlandTransportFeeCurrency: v), currenciesList),
                                       currenciesList: currenciesList,
                                     ),
                                     _buildCostRow(
                                       rowKey: 'portExpenses_$idx',
                                       title: '21. ${l.portClearanceExpensesItem}',
                                       applicable: item.portExpensesApplicable,
                                       price: item.portExpensesPrice,
                                       currency: item.portExpensesCurrency,
                                       onApplicableChanged: (v) => _updateItem(idx, item.copyWith(portExpensesApplicable: v), currenciesList),
                                       onPriceChanged: (v) => _updateItem(idx, item.copyWith(portExpensesPrice: v), currenciesList),
                                       onCurrencyChanged: (v) => _updateItem(idx, item.copyWith(portExpensesCurrency: v), currenciesList),
                                       currenciesList: currenciesList,
                                     ),
                                    
                                    const Divider(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${l.totalQuoteValue}:',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                          ),
                                          if (item.totalQuotationAmount != null)
                                            Text(
                                              '${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? "—"}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.cobalt),
                                            )
                                          else
                                            Builder(
                                              builder: (context) {
                                                final missing = ShippingScenarioCalculator.calculateTotalQuoteValue(item: item, currencies: currenciesList).missingCurrencies;
                                                final missingStr = missing.isNotEmpty ? missing.join(', ') : (item.quotationCurrency ?? '—');
                                                return Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.wcagOrange.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: AppTheme.wcagOrange, width: 0.8),
                                                      ),
                                                      child: Text(
                                                        l.rateMissingWarning(missingStr),
                                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Text(
                                                      '—',
                                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.wcagOrange),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                );
              }),
                  const SizedBox(height: 20),

                  // Comparison Summary Table
                  Card(
                    elevation: 2,
                    color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.sideBySideComparison, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkScaffoldBackground : AppTheme.charcoal),
                              headingTextStyle: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
                              columns: [
                                const DataColumn(label: Text('#')),
                                DataColumn(label: Text(l.shippingLineCol)),
                                DataColumn(label: Text(l.totalQuoteValue)),
                                DataColumn(label: Text(l.avgWarehouseArrivalMetric)),
                                DataColumn(label: Text(l.avgTransitMetric)),
                                DataColumn(label: Text(l.customsBrokerLabel)),
                                DataColumn(label: Text('${l.portOfLoadingCol} / ${l.portOfDischargeCol}')),
                                DataColumn(label: Text(l.vesselNameCol)),
                                DataColumn(label: Text(l.sailingDateCol)),
                                DataColumn(label: Text(l.estimatedArrivalDateCol)),
                                DataColumn(label: Text(l.avgTransitMetric)),
                                DataColumn(label: Text(l.freeTimeDaysCol)),
                                DataColumn(label: Text(l.expectedDelayCol)),
                                DataColumn(label: Text(l.riskLevelCol)),
                                DataColumn(label: Text(l.statusCol)),
                              ],
                              rows: calculatedScenarios.map((c) {
                                final idx = c['index'] as int;
                                final item = c['item'] as ShippingScenarioItemModel;
                                final totalStr = item.totalQuotationAmount != null
                                    ? '${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? ""}'
                                    : '—';
                                final rowSummary = '${item.providerName} | $totalStr | WH: ${c["expectedWhDate"]} (${c["totalDays"]}d) | ${item.polName ?? "-"} ➔ ${item.podName ?? "-"} | ${item.vesselName}';
                                return DataRow(
                                  cells: [
                                    DataCell(CopyableTableCell(value: '${idx + 1}', rowSummary: rowSummary, child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)))),
                                    DataCell(CopyableTableCell(value: item.providerName, rowSummary: rowSummary, child: Text(item.providerName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                                    DataCell(CopyableTableCell(
                                      value: totalStr,
                                      rowSummary: rowSummary,
                                      child: item.totalQuotationAmount != null
                                          ? Text(totalStr, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson))
                                          : Builder(
                                              builder: (context) {
                                                final missing = ShippingScenarioCalculator.calculateTotalQuoteValue(item: item, currencies: currenciesList).missingCurrencies;
                                                final missingStr = missing.isNotEmpty ? missing.join(', ') : (item.quotationCurrency ?? '—');
                                                return Tooltip(
                                                  message: l.rateMissingWarning(missingStr),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.wcagOrange.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: AppTheme.wcagOrange, width: 0.8),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.wcagOrange),
                                                        SizedBox(width: 4),
                                                        Text('—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.wcagOrange)),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    )),
                                    DataCell(CopyableTableCell(value: '${c["expectedWhDate"]}', rowSummary: rowSummary, child: Text('${c["expectedWhDate"]}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)))),
                                    DataCell(CopyableTableCell(value: '${c["totalDays"]} d', rowSummary: rowSummary, child: Text('${c["totalDays"]} d', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                                    DataCell(CopyableTableCell(
                                      value: '${item.customsBrokerName ?? "-"} (${item.clearanceFeeCurrency})',
                                      rowSummary: rowSummary,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.customsBrokerName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                                          if (item.clearanceFeePrice > 0 || item.inlandTransportFeePrice > 0)
                                            Text(
                                              l.clearanceCostSummary(((item.clearanceFeeApplicable ? item.clearanceFeePrice : 0) + (item.inspectionFeeApplicable ? item.inspectionFeePrice : 0) + (item.inlandTransportFeeApplicable ? item.inlandTransportFeePrice : 0) + (item.portExpensesApplicable ? item.portExpensesPrice : 0)).toStringAsFixed(0), item.clearanceFeeCurrency),
                                              style: const TextStyle(fontSize: 10, color: AppTheme.wcagEmerald, fontWeight: FontWeight.bold),
                                            ),
                                        ],
                                      ),
                                    )),
                                    DataCell(CopyableTableCell(value: '${item.polName ?? "-"} ➔ ${item.podName ?? "-"}', rowSummary: rowSummary, child: Row(mainAxisSize: MainAxisSize.min, children: [Text(item.polName ?? '-', style: const TextStyle(fontSize: 11)), const SizedBox(width: 4), const DirectionalIcon(Icons.arrow_forward, size: 12), const SizedBox(width: 4), Text(item.podName ?? '-', style: const TextStyle(fontSize: 11))]))),
                                    DataCell(CopyableTableCell(value: '${item.vesselName} (${item.voyageNumber ?? "-"})', rowSummary: rowSummary, child: Text('${item.vesselName} (${item.voyageNumber ?? "-"})'))),
                                    DataCell(CopyableTableCell(value: item.sailingDate, rowSummary: rowSummary, child: Text(item.sailingDate))),
                                    DataCell(CopyableTableCell(value: item.estimatedArrivalDate, rowSummary: rowSummary, child: Text(item.estimatedArrivalDate))),
                                    DataCell(CopyableTableCell(value: '${c["vesselLeadTime"]} d', rowSummary: rowSummary, child: Text('${c["vesselLeadTime"]} d'))),
                                    DataCell(CopyableTableCell(value: '${item.freeTimeDays} d', rowSummary: rowSummary, child: Text('${item.freeTimeDays} d', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                                    DataCell(CopyableTableCell(value: '${item.expectedLineDelayDays} d', rowSummary: rowSummary, child: Text('${item.expectedLineDelayDays} d'))),
                                    DataCell(CopyableTableCell(
                                      value: item.riskLevel,
                                      rowSummary: rowSummary,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: item.riskLevel == 'High' ? AppTheme.crimsonBorder : item.riskLevel == 'Medium' ? AppTheme.orangeLight : AppTheme.emeraldBorder,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(item.riskLevel, style: TextStyle(color: item.riskLevel == 'High' ? AppTheme.crimson : item.riskLevel == 'Medium' ? AppTheme.wcagOrange : AppTheme.wcagEmerald, fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    )),
                                    DataCell(CopyableTableCell(value: item.isExcludedFromAverage ? l.excludedFromAvg : l.includedInAvg, rowSummary: rowSummary, child: Text(item.isExcludedFromAverage ? l.excludedFromAvg : l.includedInAvg, style: TextStyle(color: item.isExcludedFromAverage ? AppTheme.crimson : AppTheme.cobalt, fontSize: 11)))),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

          // Bottom Fixed Action Bar with 3 Standard ERP Action Buttons (WCAG AA & Dark Mode)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite)),
                boxShadow: [BoxShadow(color: isDark ? Colors.black26 : AppTheme.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Live Refresh Button
                              AppButton(
                                label: '${l.liveRefresh} 🔄',
                                icon: Icons.refresh,
                                variant: AppButtonVariant.secondary,
                                size: AppButtonSize.small,
                                onPressed: () => _refreshData(force: true),
                              ),
                              const SizedBox(width: 8),

                              // 2. Clear Form & Start New
                              AppButton(
                                label: '${l.clearAndStartNew} 🔄',
                                icon: Icons.cleaning_services_outlined,
                                variant: AppButtonVariant.secondary,
                                size: AppButtonSize.small,
                                onPressed: _resetFormForNewStudy,
                              ),
                              const SizedBox(width: 8),

                              // 3. Save Draft & Continue Later
                              AppButton(
                                label: '${l.saveDraftContinueLater} 💾',
                                icon: Icons.save_outlined,
                                variant: AppButtonVariant.primary,
                                size: AppButtonSize.small,
                                onPressed: _isSaving ? null : () => _saveEvaluationSession(context, currenciesList),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // 4. Final Submit / Save Study
                          AppButton(
                            label: _editingSessionId != null ? '${l.saveChanges} 💾' : '${l.saveAndSubmitStudy} ✅',
                            icon: Icons.check_circle_outline,
                            variant: AppButtonVariant.success,
                            size: AppButtonSize.small,
                            isLoading: _isSaving,
                            onPressed: _isSaving ? null : () => _saveEvaluationSession(context, currenciesList),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow({
    required String rowKey,
    required String title,
    required bool applicable,
    required double price,
    required String currency,
    double qty = 1.0,
    required ValueChanged<bool> onApplicableChanged,
    required ValueChanged<double> onPriceChanged,
    required ValueChanged<String> onCurrencyChanged,
    ValueChanged<double>? onQtyChanged,
    bool showQty = false,
    bool qtyReadOnly = false,
    bool isIntegerQty = true,
    required List<CurrencyModel> currenciesList,
  }) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, costConstraints) {
        final isNarrow = costConstraints.maxWidth < 650;

        final priceField = TextFormField(
          key: ValueKey('price_${rowKey}_${_editingSessionId ?? "new"}_$_editFormVersion'),
          initialValue: price == 0.0 ? '' : price.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.itemPriceCol, isDense: true),
          onChanged: (v) {
            final p = double.tryParse(v) ?? 0.0;
            onPriceChanged(p);
          },
        );

        final currencyField = SearchableDropdownField<String>(
          value: currenciesList.any((c) => c.currencyCode == currency) ? currency : (currenciesList.isNotEmpty ? currenciesList.first.currencyCode : 'USD'),
          labelText: l.currency,
          items: currenciesList.map((c) => SearchableDropdownItem(
                value: c.currencyCode,
                label: '${c.currencyCode} (${c.currencySymbol})',
              )).toList(),
          onChanged: (v) {
            if (v != null) {
              onCurrencyChanged(v);
            }
          },
        );

        final qtyField = showQty
            ? TextFormField(
                key: qtyReadOnly
                    ? ValueKey('readonly_qty_${rowKey}_$qty')
                    : ValueKey('qty_${rowKey}_${_editingSessionId ?? "new"}_$_editFormVersion'),
                readOnly: qtyReadOnly,
                initialValue: qty == 0.0 ? '' : (isIntegerQty ? qty.toInt().toString() : qty.toString()),
                keyboardType: TextInputType.numberWithOptions(decimal: !isIntegerQty),
                decoration: InputDecoration(labelText: l.quantity, isDense: true),
                onChanged: qtyReadOnly
                    ? null
                    : (v) {
                        final q = double.tryParse(v) ?? 0.0;
                        if (onQtyChanged != null) {
                          onQtyChanged(q);
                        }
                      },
              )
            : null;

        final switchWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: applicable,
              activeThumbColor: AppTheme.cobalt,
              onChanged: onApplicableChanged,
            ),
            Text(
              applicable ? l.applicable : l.notApplicable,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: applicable ? AppTheme.emerald : AppTheme.crimson,
              ),
            ),
          ],
        );

        final totalDisplay = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: applicable 
                ? (AppTheme.emeraldLight)
                : (AppTheme.crimsonLight),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: applicable 
                  ? (isDark ? AppTheme.emerald : AppTheme.emeraldBorder)
                  : (isDark ? AppTheme.crimson : AppTheme.crimsonBorder),
            ),
          ),
          child: Text(
            applicable 
                ? '${(price * qty).toStringAsFixed(0)} $currency'
                : '0.0 $currency',
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 11, 
              color: applicable ? AppTheme.emerald : AppTheme.crimson,
            ),
            textAlign: TextAlign.center,
          ),
        );

        if (isNarrow) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    switchWidget,
                    const SizedBox(width: 8),
                    totalDisplay,
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(flex: 2, child: priceField),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: currencyField),
                    if (showQty && qtyField != null) ...[
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: qtyField),
                    ],
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: priceField),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: currencyField),
              if (showQty && qtyField != null) ...[
                const SizedBox(width: 8),
                Expanded(flex: 2, child: qtyField),
              ],
              const SizedBox(width: 12),
              switchWidget,
              const SizedBox(width: 12),
              Expanded(flex: 2, child: totalDisplay),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color, {String? subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : AppTheme.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          CopyableText(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            CopyableText(subtitle, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Future<void> _saveEvaluationSession(BuildContext context, List<CurrencyModel> currenciesList) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.completeRequiredDataMsg),
          backgroundColor: AppTheme.crimson,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Client-side validation of shipping scenarios items
    final seen = <String>{};
    for (int i = 0; i < _evalItems.length; i++) {
      final item = _evalItems[i];
      if (item.providerName.isEmpty || item.providerName == 'Select Line') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shippingLineRequiredMsg(i + 1)),
            backgroundColor: AppTheme.crimson,
          ),
        );
        return;
      }

      final sDate = DateTime.tryParse(item.sailingDate);
      final etaDate = DateTime.tryParse(item.estimatedArrivalDate);

      if (sDate == null || etaDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.datesRequiredMsg(i + 1, item.providerName)),
            backgroundColor: AppTheme.crimson,
          ),
        );
        return;
      }

      // Check date constraints: sailing date must be on or after CRD
      final crdDateOnly = DateTime(_cargoReadyDate.year, _cargoReadyDate.month, _cargoReadyDate.day);
      final sailingDateOnly = DateTime(sDate.year, sDate.month, sDate.day);
      if (sailingDateOnly.isBefore(crdDateOnly)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.sailingBeforeCrdError(i + 1, item.providerName, item.sailingDate, crdDateOnly.toString().substring(0, 10))),
            backgroundColor: AppTheme.crimson,
          ),
        );
        return;
      }

      // Check date constraints: ETA must be after sailing date
      if (!etaDate.isAfter(sDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.etaAfterSailingError(i + 1, item.providerName, item.estimatedArrivalDate, item.sailingDate)),
            backgroundColor: AppTheme.crimson,
          ),
        );
        return;
      }

      if (item.expectedLineDelayDays < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.negativeDaysError(i + 1, item.providerName)),
            backgroundColor: AppTheme.crimson,
          ),
        );
        return;
      }

      // Check duplicates (same Freight Forwarder, Shipping Line, Vessel, and Sailing Date)
      final key = '${item.providerId}_${item.providerName.trim().toLowerCase()}_${item.vesselName.trim().toLowerCase()}_${item.sailingDate}';
      if (seen.contains(key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.duplicateQuoteError(i + 1, item.providerName)),
            backgroundColor: AppTheme.crimson,
          ),
        );
        return;
      }

      if (item.totalQuotationAmount == null) {
        final currenciesList = ref.read(currenciesProvider).valueOrNull ?? [];
        final missing = ShippingScenarioCalculator.calculateTotalQuoteValue(item: item, currencies: currenciesList).missingCurrencies;
        final missingStr = missing.isNotEmpty ? missing.join(', ') : (item.quotationCurrency ?? '—');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.scenarioSaveRateMissingError(i + 1, item.providerName, missingStr)),
            backgroundColor: AppTheme.crimson,
          ),
        );
        return;
      }

      seen.add(key);
    }

    _formKey.currentState!.save();

    String titleToSave = _title.trim();
    if (_selectedImportFileId != null) {
      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
      final f = importFiles.where((file) => file.importFileId == _selectedImportFileId).firstOrNull;
      if (f != null) {
        final fCode = f.displayName;
        if (!titleToSave.startsWith('[$fCode]')) {
          titleToSave = '[$fCode] ${f.companyName}';
        }
      }
    }
    if (titleToSave.isEmpty) {
      titleToSave = context.l10n.defaultStudyTitle(DateTime.now().toString().substring(0, 10));
    }

    setState(() => _isSaving = true);

    bool ok = false;
    if (_editingSessionId != null) {
      final oldSession = ref.read(shippingScenariosProvider).sessions.where((s) => s.sessionId == _editingSessionId).firstOrNull;
      if (oldSession != null) {
        final List<FieldChangeItem> changes = [];

        // 1. General & Header Data
        if (FieldChangeItem.isDifferent(oldSession.title, titleToSave)) {
          changes.add(FieldChangeItem(
            section: 'البيانات العامة للدراسة',
            fieldName: 'عنوان دراسة الشحن',
            oldValue: oldSession.title,
            newValue: titleToSave,
          ));
        }

        final newCrd = _cargoReadyDate.toString().substring(0, 10);
        if (FieldChangeItem.isDifferent(oldSession.cargoReadyDate, newCrd)) {
          changes.add(FieldChangeItem(
            section: 'البيانات العامة للدراسة',
            fieldName: 'تاريخ جاهزية البضاعة',
            oldValue: oldSession.cargoReadyDate,
            newValue: newCrd,
          ));
        }

        final newPickup = _pickUpAddress.trim().isNotEmpty ? _pickUpAddress.trim() : null;
        if (FieldChangeItem.isDifferent(oldSession.pickUpAddress, newPickup)) {
          changes.add(FieldChangeItem(
            section: 'البيانات العامة للدراسة',
            fieldName: 'موقع وعنوان الاستلام',
            oldValue: oldSession.pickUpAddress,
            newValue: newPickup,
          ));
        }

        if (FieldChangeItem.isDifferent(oldSession.avgForm4Days, _avgForm4Days)) {
          changes.add(FieldChangeItem(
            section: 'البيانات العامة للدراسة',
            fieldName: 'أيام إصدار نموذج 4 المتوقعة',
            oldValue: '${oldSession.avgForm4Days} يوم',
            newValue: '$_avgForm4Days يوم',
          ));
        }

        if (FieldChangeItem.isDifferent(oldSession.avgClearanceDays, _avgClearanceDays)) {
          changes.add(FieldChangeItem(
            section: 'البيانات العامة للدراسة',
            fieldName: 'أيام التخليص الجمركي المتوقعة',
            oldValue: '${oldSession.avgClearanceDays} يوم',
            newValue: '$_avgClearanceDays يوم',
          ));
        }

        if (FieldChangeItem.isDifferent(oldSession.importFileId, _selectedImportFileId)) {
          changes.add(FieldChangeItem(
            section: 'الربط التشغيلي',
            fieldName: 'ملف الاستيراد المرتبط',
            oldValue: oldSession.importFileCode ?? (oldSession.importFileId != null ? 'ID: ${oldSession.importFileId}' : null),
            newValue: _selectedImportFileId != null ? 'ID: $_selectedImportFileId' : null,
          ));
        }

        if (FieldChangeItem.isDifferent(oldSession.poId, _selectedPoId)) {
          changes.add(FieldChangeItem(
            section: 'الربط التشغيلي',
            fieldName: 'أمر الشراء المرتبط',
            oldValue: oldSession.poNumber ?? (oldSession.poId != null ? 'ID: ${oldSession.poId}' : null),
            newValue: _selectedPoId != null ? 'ID: $_selectedPoId' : null,
          ));
        }

        // 2. Shipping Options / Quotation Items
        if (oldSession.items.length != _evalItems.length) {
          changes.add(FieldChangeItem(
            section: 'عروض أسعار الشحن المقارنة',
            fieldName: 'عدد عروض الشحن المدرجة',
            oldValue: '${oldSession.items.length} عرض',
            newValue: '${_evalItems.length} عرض',
          ));
        } else {
          for (int i = 0; i < _evalItems.length; i++) {
            final o = oldSession.items[i];
            final n = _evalItems[i];
            final defaultCarrier = context.l10n.ssCarrier;
            final quotePrefix = context.l10n.ssQuote;
            final quoteTitle = '$quotePrefix #${i + 1} (${n.providerName.isNotEmpty ? n.providerName : defaultCarrier})';

            if (FieldChangeItem.isDifferent(o.providerName, n.providerName)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - وكيل الشحن',
                oldValue: o.providerName,
                newValue: n.providerName,
              ));
            }
            if (FieldChangeItem.isDifferent(o.vesselName, n.vesselName)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - الخط الملاحي / الباخرة',
                oldValue: o.vesselName,
                newValue: n.vesselName,
              ));
            }
            if (FieldChangeItem.isDifferent(o.sailingDate, n.sailingDate)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - تاريخ الإبحار',
                oldValue: o.sailingDate,
                newValue: n.sailingDate,
              ));
            }
            if (FieldChangeItem.isDifferent(o.estimatedArrivalDate, n.estimatedArrivalDate)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - تاريخ الوصول المتوقع',
                oldValue: o.estimatedArrivalDate,
                newValue: n.estimatedArrivalDate,
              ));
            }
            if (FieldChangeItem.isDifferent(o.freeTimeDays, n.freeTimeDays)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - أيام السماح',
                oldValue: '${o.freeTimeDays} يوم',
                newValue: '${n.freeTimeDays} يوم',
              ));
            }
            if (FieldChangeItem.isDifferent(o.totalQuotationAmount, n.totalQuotationAmount)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - إجمالي قيمة العرض (${n.quotationCurrency ?? ""})',
                oldValue: o.totalQuotationAmount != null ? '${o.totalQuotationAmount!.toStringAsFixed(2)} ${o.quotationCurrency ?? ""}' : '—',
                newValue: n.totalQuotationAmount != null ? '${n.totalQuotationAmount!.toStringAsFixed(2)} ${n.quotationCurrency ?? ""}' : '—',
              ));
            }
            if (FieldChangeItem.isDifferent(o.isExcludedFromAverage, n.isExcludedFromAverage)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - استبعاد من المتوسط الحسابي',
                oldValue: o.isExcludedFromAverage ? 'مستبعد' : 'محتسب',
                newValue: n.isExcludedFromAverage ? 'مستبعد' : 'محتسب',
              ));
            }
          }
        }

        if (changes.isNotEmpty) {
          if (!context.mounted) return;
          final confirmed = await showChangeDiffConfirmationDialog(
            context,
            title: 'مراجعة وتأكيد تعديلات دراسة وعروض الشحن',
            itemReference: oldSession.sessionCode.isNotEmpty ? oldSession.sessionCode : titleToSave,
            changes: changes,
          );
          if (!confirmed) {
            setState(() => _isSaving = false);
            return;
          }
        }
      }

      final data = {
        'title': titleToSave,
        'cargo_ready_date': _cargoReadyDate.toString().substring(0, 10),
        if (_pickUpAddress.trim().isNotEmpty) 'pick_up_address': _pickUpAddress.trim(),
        'avg_form4_days': _avgForm4Days,
        'avg_clearance_days': _avgClearanceDays,
        if (_selectedImportFileId != null) 'import_file_id': _selectedImportFileId,
        if (_selectedPoId != null) 'po_id': _selectedPoId,
        if (_selectedProjectId != null) 'project_id': _selectedProjectId,
        'is_active': true,
        'items': _evalItems.map((i) => i.toCreateJson()).toList(),
      };
      ok = await ref.read(shippingScenariosProvider.notifier).updateSession(_editingSessionId!, data);
    } else {
      final session = ShippingEvaluationModel(
        sessionCode: '',
        title: titleToSave,
        cargoReadyDate: _cargoReadyDate.toString().substring(0, 10),
        pickUpAddress: _pickUpAddress.trim().isNotEmpty ? _pickUpAddress.trim() : null,
        avgForm4Days: _avgForm4Days,
        avgClearanceDays: _avgClearanceDays,
        importFileId: _selectedImportFileId,
        poId: _selectedPoId,
        projectId: _selectedProjectId,
        notes: _sessionNotes,
        items: _evalItems,
      );
      ok = await ref.read(shippingScenariosProvider.notifier).createSession(session);
    }

    setState(() => _isSaving = false);

    if (ok && context.mounted) {
      // Find the newly saved study from provider state
      final freshState = ref.read(shippingScenariosProvider);
      final savedSess = freshState.sessions.firstWhere(
        (s) => s.title == titleToSave || s.sessionCode == _editingSessionCode,
        orElse: () => ShippingEvaluationModel(
          sessionCode: _editingSessionCode ?? 'NEW',
          title: titleToSave,
          cargoReadyDate: _cargoReadyDate.toString().substring(0, 10),
          items: _evalItems,
          recommendedScenarioProvider: _evalItems.firstWhere((i) => i.isRecommended, orElse: () => _evalItems.first).providerName,
        ),
      );

      _resetFormForNewStudy();
      _tabController.animateTo(1);

      // Instantly pop up the detailed Arabic/English results summary dialog per user instructions
      _showSaveSuccessReportDialog(context, savedSess);
    } else if (!ok && context.mounted) {
      final failure = ref.read(shippingScenariosProvider).error;
      if (ApiErrorText.code(failure) == ApiErrorCode.scenarioSessionExists) {
        // A study for this import file already exists: readable message + open it.
        final l = context.l10n;
        final existingId = ApiErrorText.detail(failure)?['session_id'];
        final existingCode = ApiErrorText.detail(failure)?['session_code'];
        showExistingRecordSnack(
          context,
          message: ApiErrorText.of(l, failure),
          actionLabel: l.openExistingRecord,
          onOpen: () {
            final match = ref.read(shippingScenariosProvider).sessions.where(
                  (s) => s.sessionId == existingId || (existingCode != null && s.sessionCode == existingCode),
                );
            if (match.isNotEmpty && mounted) _loadSessionForEditing(match.first);
          },
        );
        return;
      }
      final err = ApiErrorText.of(context.l10n, failure, fallback: context.l10n.saveFailed);
      await showErrorDetailsDialog(
        context,
        title: context.l10n.saveFailedTitle,
        error: err,
        onRetry: () async {
          await _saveEvaluationSession(context, currenciesList);
        },
      );
    }
  }

  void _showSaveSuccessReportDialog(BuildContext context, ShippingEvaluationModel sess) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final l = dialogCtx.l10n;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.emerald, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.saveSuccessReportTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: SizedBox(
            width: 850,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emeraldBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CopyableText('${l.studyCodeLabel} ${sess.sessionCode}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 13)),
                        const SizedBox(height: 4),
                        CopyableText('${l.studyTitleDetailLabel} ${sess.title ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        CopyableText('${l.crdLabel}: ${sess.cargoReadyDate} | ${l.pickupAddressLabel}: ${sess.pickUpAddress ?? l.unassigned}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l.comparativeReportLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: AppTheme.cloudWhite),
                    columnWidths: const {
                      0: FlexColumnWidth(1.5),
                      1: FlexColumnWidth(1.1),
                      2: FlexColumnWidth(1.1),
                      3: FlexColumnWidth(1.1),
                      4: FlexColumnWidth(1.2),
                      5: FlexColumnWidth(1.5),
                      6: FlexColumnWidth(1.0),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                        children: [
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.carrierLineCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.sailingDateCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.portArrivalCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.totalDaysCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.whDateCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.totalQuoteCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(l.recommendationCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        ],
                      ),
                      ...sess.items.map((item) {
                        return TableRow(
                          decoration: BoxDecoration(color: item.isRecommended ? AppTheme.emeraldLight.withValues(alpha: 0.5) : null),
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: CopyableText(item.providerName, style: TextStyle(fontWeight: item.isRecommended ? FontWeight.bold : FontWeight.normal, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: CopyableText(item.sailingDate, style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: CopyableText(item.estimatedArrivalDate, style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: CopyableText(l.avgTransitDays(item.expectedTotalDaysToWarehouse.toString()), style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: CopyableText(item.expectedWarehouseArrivalDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            Padding(padding: const EdgeInsets.all(8), child: CopyableText(item.totalQuotationAmount != null ? '${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? ""}' : '—', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.crimson))),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: CopyableText(
                                item.isRecommended ? l.recommendedBadge(item.providerName) : (item.isExcludedFromAverage ? l.excludedBadge : l.normalBadge),
                                style: TextStyle(fontWeight: FontWeight.bold, color: item.isRecommended ? AppTheme.emerald : AppTheme.textMuted, fontSize: 10),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.cobaltLight, borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      children: [
                        const Icon(Icons.stars, color: AppTheme.cobalt),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CopyableText(
                            '${l.recommendedLineContractLabel} ${sess.recommendedScenarioProvider ?? l.unassigned}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AppButton(
              label: l.copySummaryBtn,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () {
                CopyHelper.copy(
                  dialogCtx,
                  '${l.freightStudiesTitle} ${sess.sessionCode}: ${sess.title}\n${l.recommendedLineMetric}: ${sess.recommendedScenarioProvider}\n${l.avgWarehouseArrivalMetric}: ${sess.avgExpectedWarehouseArrivalDate}',
                );
              },
            ),
            AppButton(
              label: l.saveDoneBtn,
              variant: AppButtonVariant.success,
              onPressed: () => Navigator.pop(dialogCtx),
            ),
          ],
        );
      },
    );
  }


  void _showContainerComparisonDialog(
    BuildContext context,
    ContainerDualRecommendationResult dualRec,
    double cbm,
    double weightKg,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final l = dialogCtx.l10n;
        return AlertDialog(
          title: Text(l.containerDualMatrixTitle),
          content: SizedBox(
            width: 650,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CopyableText(
                  l.totalCbmAndWeight(cbm.toStringAsFixed(3), weightKg.toStringAsFixed(0)),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(color: AppTheme.cloudWhite),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.statusCol, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('📦 ${l.stackableOption}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('🚫 ${l.nonStackableOption}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange))),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.containerTypeCol)),
                        Padding(padding: const EdgeInsets.all(8), child: CopyableText(dualRec.stackableResult.recommendedContainerCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(8), child: CopyableText(dualRec.nonStackableResult.recommendedContainerCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.containersRequiredCol)),
                        Padding(padding: const EdgeInsets.all(8), child: CopyableText('${dualRec.stackableResult.requiredContainersCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                        Padding(padding: const EdgeInsets.all(8), child: CopyableText('${dualRec.nonStackableResult.requiredContainersCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.spaceUtilizationLabel)),
                        Padding(padding: const EdgeInsets.all(8), child: CopyableText('${dualRec.stackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%')),
                        Padding(padding: const EdgeInsets.all(8), child: CopyableText('${dualRec.nonStackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            AppButton(
              label: l.close,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(dialogCtx),
            ),
          ],
        );
      },
    );
  }

  void _showVisualLoadPlanDialog(BuildContext context, List<PurchaseOrderModel> pos, double totalCbm, double totalWeight) {
    final List<CargoItem> baseCargoItems = [];
    int itemCounter = 1;

    for (final po in pos) {
      final hasPalletPlan = po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0);
      final hasSinglePallet = po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0;

      if (hasPalletPlan) {
        final double totalGross = po.packingListItems.fold<double>(
          0.0,
          (sum, p) => sum + (p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.qtyPkg * p.grossWeightUnitKg)),
        );
        final int totalPallets = po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount);
        final double defaultPalletWeight = totalPallets > 0 && totalGross > 0 ? (totalGross / totalPallets) : 137.5;

        for (final pLine in po.palletPlanItems) {
          final pL = pLine.lengthCm > 0 ? pLine.lengthCm : 120.0;
          final pW = pLine.widthCm > 0 ? pLine.widthCm : 80.0;
          final pH = pLine.heightCm > 0 ? pLine.heightCm : 150.0;
          final pWt = pLine.grossWeightPerPalletKg > 0 ? pLine.grossWeightPerPalletKg : defaultPalletWeight;

          for (int i = 0; i < pLine.palletCount; i++) {
            baseCargoItems.add(CargoItem(
              itemId: 'PLT-$itemCounter',
              length: pL,
              width: pW,
              height: pH,
              weight: pWt,
              isStackable: pLine.isStackable,
              rotate: true,
              packageType: pLine.palletType,
              description: 'بالتة #$itemCounter (${pLine.palletType})${pLine.isStackable ? "" : " [Floor Only]"}',
            ));
            itemCounter++;
          }
        }
      } else if (hasSinglePallet) {
        final double pWt = po.totalGrossWeightKg > 0 ? (po.totalGrossWeightKg / po.palletCount) : 137.5;
        for (int i = 0; i < po.palletCount; i++) {
          baseCargoItems.add(CargoItem(
            itemId: 'PLT-$itemCounter',
            length: po.palletLengthCm,
            width: po.palletWidthCm,
            height: po.palletHeightCm,
            weight: pWt,
            isStackable: po.isPalletStackable,
            rotate: true,
            packageType: po.palletType,
            description: 'بالتة #$itemCounter (${po.palletType})${po.isPalletStackable ? "" : " [Floor Only]"}',
          ));
          itemCounter++;
        }
      } else if (po.packingListItems.isNotEmpty) {
        for (final pl in po.packingListItems) {
          for (int q = 0; q < pl.qtyPkg.toInt(); q++) {
            double lCm = pl.lengthCm;
            double wCm = pl.widthCm;
            double hCm = pl.heightCm;
            if (pl.unit == 'mm') {
              lCm /= 10;
              wCm /= 10;
              hCm /= 10;
            } else if (pl.unit == 'm') {
              lCm *= 100;
              wCm *= 100;
              hCm *= 100;
            }

            baseCargoItems.add(CargoItem(
              itemId: '$itemCounter',
              length: lCm > 0 ? lCm : 100.0,
              width: wCm > 0 ? wCm : 80.0,
              height: hCm > 0 ? hCm : 60.0,
              weight: pl.grossWeightUnitKg > 0 ? pl.grossWeightUnitKg : (pl.totalGrossWeightKg / (pl.qtyPkg > 0 ? pl.qtyPkg : 1)),
              rotate: true,
              isStackable: pl.isStackable,
              packageType: pl.packageType,
            ));
            itemCounter++;
          }
        }
      }
    }

    if (baseCargoItems.isEmpty && totalCbm > 0) {
      final double targetCbm = totalCbm;
      final double targetWeight = totalWeight > 0 ? totalWeight : 1000.0;
      final int numPallets = (targetCbm / 2.0).ceil().clamp(1, 50);
      final double perPalletCbm = targetCbm / numPallets;
      final double perPalletWeight = targetWeight / numPallets;

      double palletHeightCm = (perPalletCbm * 1000000.0) / 12000.0;
      if (palletHeightCm > 260) palletHeightCm = 260;

      for (int i = 0; i < numPallets; i++) {
        baseCargoItems.add(CargoItem(
          itemId: 'PLT-$itemCounter',
          length: 120,
          width: 100,
          height: palletHeightCm.clamp(30.0, 260.0),
          weight: perPalletWeight,
          rotate: true,
          isStackable: true,
          packageType: 'Pallet',
        ));
        itemCounter++;
      }
    }

    if (baseCargoItems.isEmpty) {
      baseCargoItems.add(CargoItem(
        itemId: '1',
        length: 120,
        width: 80,
        height: 100,
        weight: totalWeight > 0 ? totalWeight : 500.0,
        rotate: true,
        isStackable: true,
      ));
    }

    // Default active view mode: null = Actual/Mixed, true = All Stackable, false = All Non-Stackable
    bool? activeStackingMode = baseCargoItems.any((i) => !i.isStackable) ? null : true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            // Compute plan dynamically based on the selected mode
            final plan = ContainerRequirementEngine.planShipment(
              baseCargoItems,
              forceStackable: activeStackingMode,
            );

            // Compute summary metrics for active plan
            final totalPkgs = baseCargoItems.length;
            final stackableInActive = activeStackingMode == true
                ? totalPkgs
                : (activeStackingMode == false ? 0 : baseCargoItems.where((c) => c.isStackable).length);
            final nonStackableInActive = totalPkgs - stackableInActive;

            final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
            final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);
            final l = dialogCtx.l10n;

            // Determine container fleet text (e.g. 2 x 40HC or 2 x 40HC + 1 x 20GP)
            final Map<String, int> containerCounts = {};
            for (final p in plan) {
              if (p.containerCode != 'FAILED') {
                containerCounts[p.containerCode] = (containerCounts[p.containerCode] ?? 0) + 1;
              }
            }
            final fleetSummaryText = containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.view_in_ar, color: AppTheme.cobalt, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.visualLoadPlanTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cobalt),
                    ),
                    child: Text(
                      l.requiredFleetLabel(fleetSummaryText, plan.length),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 980,
                height: 640,
                child: Column(
                  children: [
                    // 1. Scenario / Stacking Mode Switcher (All 3 required states)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoalSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cloudWhite),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l.selectStackingScenarioLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                          ),
                          Row(
                            children: [
                              ChoiceChip(
                                label: Text(l.allStackableOption),
                                selected: activeStackingMode == true,
                                selectedColor: AppTheme.emerald,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == true ? AppTheme.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => activeStackingMode = true);
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text(l.allNonStackableOption),
                                selected: activeStackingMode == false,
                                selectedColor: AppTheme.wcagOrange,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == false ? AppTheme.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => activeStackingMode = false);
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text(l.mixedStackingOption),
                                selected: activeStackingMode == null,
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == null ? AppTheme.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => activeStackingMode = null);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 2. Metrics Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoal.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cloudWhite),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildLoadMetricPill(l.totalPackagesMetricLabel, '$totalPkgs', AppTheme.cobalt),
                              const SizedBox(width: 8),
                              _buildLoadMetricPill(l.totalWeightMetricLabel, '${totalPlanWeight.toStringAsFixed(0)} kg', AppTheme.charcoal),
                              const SizedBox(width: 8),
                              _buildLoadMetricPill(l.totalVolumeMetricLabel, '${totalPlanVolume.toStringAsFixed(3)} m³', AppTheme.wcagOrange),
                            ],
                          ),
                          Row(
                            children: [
                              _buildLoadMetricPill(l.stackableMetricLabel, '$stackableInActive', AppTheme.wcagEmerald),
                              const SizedBox(width: 8),
                              _buildLoadMetricPill(l.nonStackableMetricLabel, '$nonStackableInActive', AppTheme.crimson),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 3. Table summary of container loads
                    Table(
                      border: TableBorder.all(color: AppTheme.cloudWhite),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.8),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(2.4),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                          children: [
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(l.containerCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(l.itemsAndPackagesCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(l.loadedWeightCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(l.spaceUtilizationCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(l.safetyDistributionCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          ],
                        ),
                        ...plan.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final res = entry.value;
                          final placedIds = res.placedItems.map((p) => p.item.itemId).join(', ');

                          String statusText = '';
                          if (res.containerCode == 'FAILED') {
                            statusText = l.loadingFailedStatus(res.unplacedItems.map((u) => u.itemId).join(', '));
                          } else {
                            final nonStackInThis = res.placedItems.where((p) => !p.item.isStackable).length;
                            if (nonStackInThis > 0) {
                              statusText = l.nonStackableFloorCount(nonStackInThis);
                            } else {
                              statusText = l.multiLayerCompliant((res.totalVolume / res.spec.internalVolumeCbm * 100).toStringAsFixed(1));
                            }
                          }

                          final double spaceUtil = res.spec.internalVolumeCbm > 0 ? (res.totalVolume / res.spec.internalVolumeCbm) * 100 : 0.0;

                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CopyableText(
                                  res.containerCode == 'FAILED' ? l.failedStackLabel : '$idx: ${res.spec.code}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CopyableText(placedIds.isEmpty ? '-' : placedIds, style: const TextStyle(fontSize: 11)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CopyableText(res.containerCode == 'FAILED' ? '-' : '${res.totalWeight.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 11)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CopyableText('${spaceUtil.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: CopyableText(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: res.containerCode == 'FAILED'
                                        ? AppTheme.crimson
                                        : (res.placedItems.any((p) => !p.item.isStackable) ? AppTheme.wcagOrange : AppTheme.wcagEmerald),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 4. Tab view or list for visual container layout drawings
                    Expanded(
                      child: ListView.builder(
                        itemCount: plan.length,
                        itemBuilder: (ctx, pIdx) {
                          final res = plan[pIdx];
                          if (res.containerCode == 'FAILED') {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppTheme.crimsonLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.crimsonBorder)),
                              child: CopyableText(
                                l.itemsExceedCapacity(res.unplacedItems.map((u) => u.itemId).join(', ')),
                                style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold),
                              ),
                            );
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      CopyableText(
                                        l.containerLayoutTitle(pIdx + 1, res.spec.name, res.spec.code),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                      ),
                                      Row(
                                        children: [
                                          Text(l.woodenFloorPalletsLabel, style: const TextStyle(fontSize: 10, color: AppTheme.wcagOrange, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: AppTheme.cobaltLight, borderRadius: BorderRadius.circular(4)),
                                            child: CopyableText(
                                              l.internalDimsLabel(res.spec.internalLength.toStringAsFixed(0), res.spec.internalWidth.toStringAsFixed(0), res.spec.internalHeight.toStringAsFixed(0)),
                                              style: const TextStyle(fontSize: 10, color: AppTheme.cobalt),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Side View (Left Wall Removed) - High Fidelity Realistic Container
                                  Container(
                                    height: 190,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoal,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: CustomPaint(
                                      painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                                      child: Container(),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Top View (Roof Removed)
                                  Container(
                                    height: 140,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoal,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: CustomPaint(
                                      painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                                      child: Container(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                AppButton(
                  label: l.closePlanBtn,
                  icon: Icons.close,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildLoadMetricPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHistoryRegistryTab(ShippingScenariosState state, List poList, List projectsList) {
    return SavedScenariosRegistryTab(
      onEditSession: _loadSessionForEditing,
      onSwitchToEvaluator: () => _tabController.animateTo(0),
    );
  }
}

// ==================================================
// Dedicated Search & Clone Dialog for Shipping Scenarios (UX-CLONE-012)
// ==================================================
class SearchAndCloneStudyDialog extends StatefulWidget {
  final List<ShippingEvaluationModel> sessions;
  final ValueChanged<ShippingEvaluationModel> onSelectStudy;

  const SearchAndCloneStudyDialog({
    super.key,
    required this.sessions,
    required this.onSelectStudy,
  });

  @override
  State<SearchAndCloneStudyDialog> createState() => _SearchAndCloneStudyDialogState();
}

class _SearchAndCloneStudyDialogState extends State<SearchAndCloneStudyDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<ShippingEvaluationModel> _filteredStudies;

  @override
  void initState() {
    super.initState();
    _filteredStudies = widget.sessions;
    _queryController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _queryController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudies = widget.sessions;
      } else {
        _filteredStudies = widget.sessions.where((s) {
          final code = s.sessionCode.toLowerCase();
          final title = (s.title ?? '').toLowerCase();
          final imp = (s.importFileCode ?? '').toLowerCase();
          final po = (s.poNumber ?? '').toLowerCase();
          final prj = (s.projectName ?? '').toLowerCase();
          final rec = (s.recommendedScenarioProvider ?? '').toLowerCase();
          return code.contains(query) ||
              title.contains(query) ||
              imp.contains(query) ||
              po.contains(query) ||
              prj.contains(query) ||
              rec.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      child: SelectionArea(
        child: Container(
          width: math.min(720.0, screenWidth - 32),
          height: math.min(600.0, screenHeight - 64),
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.copy_all_rounded, color: AppTheme.cobalt, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.searchAndCloneStudyDialogTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.searchAndCloneStudySubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search input
            TextField(
              controller: _queryController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l.searchByStudyCodeOrTitleHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _queryController.clear(),
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 14),

            // Results list
            Expanded(
              child: _filteredStudies.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            l.noMatchingStudiesFound,
                            style: TextStyle(
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredStudies.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final study = _filteredStudies[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.cobalt.withValues(alpha: 0.15),
                            child: const Icon(Icons.alt_route, color: AppTheme.cobalt, size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(
                                study.sessionCode,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                              ),
                              if (study.title != null && study.title!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    study.title!,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text('${l.crdLabel}: ${study.cargoReadyDate}', style: const TextStyle(fontSize: 11)),
                                Text('• ${study.items.length} ${l.shippingCarrierOptions}', style: const TextStyle(fontSize: 11)),
                                if (study.recommendedScenarioProvider != null)
                                  Text('• 🏆 ${study.recommendedScenarioProvider}', style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                                if (study.importFileCode != null)
                                  Text('• 📁 ${study.importFileCode}', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                          trailing: AppButton(
                            label: l.cloneRowTooltip,
                            icon: Icons.copy_rounded,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            onPressed: () => widget.onSelectStudy(study),
                          ),
                          onTap: () => widget.onSelectStudy(study),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
