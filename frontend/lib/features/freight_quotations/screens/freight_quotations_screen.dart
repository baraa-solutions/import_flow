import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/freight_quotation_model.dart';
import '../providers/freight_quotations_provider.dart';
import '../services/freight_quotations_export_service.dart';
import '../widgets/freight_quotations_extractor_dialog.dart';
import '../widgets/freight_ai_extractor_card.dart';
import '../../../core/providers/navigation_provider.dart';
import '../widgets/rfq_benchmark_dialog.dart';

class FreightQuotationsScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final int initialTabIndex;
  const FreightQuotationsScreen({
    super.key,
    this.initialImportFileId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<FreightQuotationsScreen> createState() => _FreightQuotationsScreenState();
}

class _FreightQuotationsScreenState extends ConsumerState<FreightQuotationsScreen> {
  // Form State
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  bool _titleModifiedByUser = false;
  final TextEditingController _cbmController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _crdDate = DateTime.now().add(const Duration(days: 15));
  String _shippingMethod = 'Ocean FCL';
  String _polName = '';
  String _podName = '';
  int? _selectedImportFileId;
  int? _selectedPoId;
  int? _selectedProjectId;

  FreightRFQRequestModel? _matchedExistingRFQ;
  final List<FreightQuotationItemModel> _quotations = [];
  bool _isSaving = false;
  bool _isStackable = true;
  bool _isDirty = false;

  void _setDirty([bool dirty = true]) {
    if (_isDirty != dirty && mounted) {
      setState(() => _isDirty = dirty);
    }
  }

  void _markDirtyListener() {
    if (!_isDirty) _setDirty(true);
  }

@override
  void initState() {
    super.initState();
    _titleController.addListener(_markDirtyListener);
    _cbmController.addListener(_markDirtyListener);
    _weightController.addListener(_markDirtyListener);
    _notesController.addListener(_markDirtyListener);
    if (widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
    }
    Future.microtask(() {
      if (!ref.read(freightQuotationsProvider).isLoading) {
        ref.read(freightQuotationsProvider.notifier).fetchRFQs();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles().then((_) {
          if (widget.initialImportFileId != null && mounted) {
            setState(() {
              _populateFromImportFile(widget.initialImportFileId!);
            });
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(FreightQuotationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != null && widget.initialImportFileId != _selectedImportFileId) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
        _populateFromImportFile(widget.initialImportFileId!);
      });
    }
  }

  void _populateFromImportFile(int fileId) {
    final importFilesList = ref.read(importFilesProvider).valueOrNull ?? [];
    final selectedFile = importFilesList.where((f) => f.importFileId == fileId).firstOrNull;
    if (selectedFile == null) return;

    // 1. Title (عنوان طلب عرض السعر)
    _titleController.text = '${selectedFile.primaryNameWithCode} - ${selectedFile.supplierName}';

    // 2. Shipping Method (وسيلة الشحن)
    final sm = selectedFile.shipmentMode.trim();
    if (sm == 'Sea FCL' || sm == 'Sea') {
      _shippingMethod = 'Ocean FCL';
    } else if (sm == 'Sea LCL') {
      _shippingMethod = 'Ocean LCL';
    } else if (sm == 'Air') {
      _shippingMethod = 'Air Freight';
    } else if (sm == 'Courier') {
      _shippingMethod = 'Courier Express';
    } else if (sm == 'Land') {
      _shippingMethod = 'Inland Trucking';
    } else if (sm == 'Multimodal' || sm == 'Multi-Modal') {
      _shippingMethod = 'Multi-Modal';
    } else if (sm.isNotEmpty) {
      _shippingMethod = sm;
    }

    // 3. Cargo Ready Date (تاريخ جاهزية البضاعة CRD)
    if (selectedFile.cargoReadyDate != null && selectedFile.cargoReadyDate!.trim().isNotEmpty) {
      final parsedDate = DateTime.tryParse(selectedFile.cargoReadyDate!.trim());
      if (parsedDate != null) {
        _crdDate = parsedDate;
      }
    }

    // 4. Port of Loading (ميناء التحميل POL)
    if (selectedFile.portOfLoading != null && selectedFile.portOfLoading!.trim().isNotEmpty) {
      _polName = selectedFile.portOfLoading!.trim();
    }

    // 5. Port of Discharge (ميناء الوصول POD)
    if (selectedFile.portOfDischarge != null && selectedFile.portOfDischarge!.trim().isNotEmpty) {
      _podName = selectedFile.portOfDischarge!.trim();
    }

    // 6. CBM & Weight calculation (إجمالي الحجم والوزن القائم)
    double calcCbm = 0.0;
    double calcWeight = 0.0;
    bool? foundStackable;

    if (selectedFile.packingListsData.isNotEmpty) {
      for (var pl in selectedFile.packingListsData) {
        calcCbm += pl.cbm;
        calcWeight += pl.grossWeightKg;
        foundStackable = pl.isStackable;
      }
    }
    if (calcCbm == 0 && calcWeight == 0) {
      final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
      final filePoIds = selectedFile.poIds ?? [];
      for (var po in allPOs) {
        if (filePoIds.contains(po.poId) || po.importFileId == selectedFile.importFileId) {
          if (po.packingListItems.isNotEmpty) {
            for (var pl in po.packingListItems) {
              calcCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
              calcWeight += (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg));
            }
          } else {
            calcCbm += po.totalCbm;
            calcWeight += po.totalGrossWeightKg;
          }
        }
      }
    }
    if (calcCbm > 0) _cbmController.text = calcCbm.toStringAsFixed(2);
    if (calcWeight > 0) _weightController.text = calcWeight.toStringAsFixed(1);
    if (foundStackable != null) _isStackable = foundStackable;

    // 7. Smart Auto-Fetch of Existing Quotations for this file
    final rfqs = ref.read(freightQuotationsProvider).value ?? [];
    final matching = rfqs.where((r) => r.importFileId == fileId).toList();
    if (matching.isNotEmpty) {
      _matchedExistingRFQ = matching.first;
      if (_quotations.isEmpty && _matchedExistingRFQ!.quotations.isNotEmpty) {
        _loadExistingRFQQuotations(_matchedExistingRFQ!, showSnackbar: false);
      }
    } else {
      _matchedExistingRFQ = null;
    }
  }

  void _loadExistingRFQQuotations(FreightRFQRequestModel rfq, {bool showSnackbar = true}) {
    setState(() {
      _quotations.clear();
      for (var q in rfq.quotations) {
        _quotations.add(
          FreightQuotationItemModel(
            quotationId: q.quotationId,
            rfqId: q.rfqId,
            providerId: q.providerId,
            providerName: q.providerName,
            vesselName: q.vesselName,
            voyageNumber: q.voyageNumber,
            currencyCode: q.currencyCode,
            oceanFreightCost: q.oceanFreightCost,
            localChargesCost: q.localChargesCost,
            inlandCost: q.inlandCost,
            totalCost: q.totalCost,
            sailingDate: q.sailingDate,
            estimatedArrivalDate: q.estimatedArrivalDate,
            transitDays: q.transitDays,
            freeDaysAtPod: q.freeDaysAtPod,
            isAwarded: q.isAwarded,
            isExcludedFromAvg: q.isExcludedFromAvg,
            remarks: q.remarks,
          ),
        );
      }
    });
    if (showSnackbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          'تم استدعاء ${rfq.quotations.length} عروض أسعار مسجلة مسبقاً لهذا الملف (${rfq.rfqCode}) بنجاح!',
          severity: AppSeverity.success,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_markDirtyListener);
    _cbmController.removeListener(_markDirtyListener);
    _weightController.removeListener(_markDirtyListener);
    _notesController.removeListener(_markDirtyListener);
    _titleController.dispose();
    _cbmController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showLoadSavedRFQDialog(List<FreightRFQRequestModel> rfqs) {
    showDialog(
      context: context,
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        String query = '';
        return SelectionArea(child: StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isArabic = Localizations.localeOf(ctx).languageCode == 'ar';
            final filtered = rfqs.where((r) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return r.rfqCode.toLowerCase().contains(q) ||
                  r.title.toLowerCase().contains(q) ||
                  r.polName.toLowerCase().contains(q) ||
                  r.podName.toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.folder_open_outlined, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'استدعاء طلب عرض أسعار مسجل' : 'Load Saved Freight RFQ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 780,
                height: 480,
                child: Column(
                  children: [
                    AppSearchField(
                      controller: searchCtrl,
                      hint: isArabic ? 'البحث برقم الطلب أو العنوان أو الميناء...' : 'Search RFQ Code, Title, or Port...',
                      onChanged: (v) => setDialogState(() => query = v.trim()),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? AppEmptyState(
                              icon: Icons.search_off_rounded,
                              message: isArabic ? 'لا توجد طلبات عروض أسعار مسجلة مطابقة' : 'No matching RFQs found',
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final rfq = filtered[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.cobalt.withValues(alpha: 0.1),
                                    child: const Icon(Icons.directions_boat, color: AppTheme.cobalt, size: 20),
                                  ),
                                  title: Row(
                                    children: [
                                      InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: () => CopyHelper.copy(context, rfq.rfqCode),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(rfq.rfqCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AppStatusBadge.fromStatus(status: rfq.status),
                                      const Spacer(),
                                      Text('\$${rfq.lowestFreightCost}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    ],
                                  ),
                                  subtitle: Text('${rfq.title} • ${rfq.polName} ➔ ${rfq.podName} (${rfq.quotations.length} ${isArabic ? "عروض" : "quotes"})'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                       RowActionsPill(
                                         viewTooltip: isArabic ? 'عرض التفاصيل' : 'View details',
                                         onView: () => _showRFQDetailsDialog(rfq),
                                         cloneTooltip: isArabic ? 'المفاضلة التنافسية وعروض الأسعار' : 'Benchmarking',
                                         onClone: () => showRFQBenchmarkDialog(
                                           context,
                                           ref,
                                           rfqId: rfq.rfqId,
                                           rfqCode: rfq.rfqCode,
                                         ),
                                       ),
                                      const SizedBox(width: 4),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.cobalt,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _loadExistingRFQQuotations(rfq);
                                          setState(() {
                                            _matchedExistingRFQ = rfq;
                                            _selectedImportFileId = rfq.importFileId;
                                            _selectedPoId = rfq.poId;
                                            _selectedProjectId = rfq.projectId;
                                            _titleController.text = rfq.title;
                                            _shippingMethod = rfq.shippingMethod;
                                            _polName = rfq.polName;
                                            _podName = rfq.podName;
                                            _cbmController.text = rfq.totalCbm.toString();
                                            _weightController.text = rfq.totalGrossWeightKg.toString();
                                            _notesController.text = rfq.notes ?? '';
                                            if (rfq.crdDate.isNotEmpty) {
                                              _crdDate = DateTime.tryParse(rfq.crdDate) ?? _crdDate;
                                            }
                                            _isDirty = false;
                                          });
                                        },
                                        child: Text(isArabic ? 'تحميل للمقارنة' : 'Load to Compare', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      },
    );
  }

  Future<void> _resetRFQForm() async {
    final isArabic = context.l10n.isArabic;
    if (_quotations.isNotEmpty || _titleModifiedByUser) {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: isArabic ? 'تأكيد طلب جديد' : 'Confirm New RFQ',
        message: isArabic
            ? 'هل أنت متأكد من تفريغ كافة الحقول وعروض الأسعار المضافة للبدء من جديد؟'
            : 'Are you sure you want to clear all entered data and quotations to start fresh?',
        confirmLabel: isArabic ? 'تفريغ وبدء جديد' : 'Clear & Start New',
        cancelLabel: context.l10n.cancel,
        confirmVariant: AppButtonVariant.warning,
        icon: Icons.refresh_rounded,
      );
      if (!confirmed) return;
    }
    setState(() {
      _titleController.text = 'New Freight RFQ Request';
      _titleModifiedByUser = false;
      _cbmController.text = '0.0';
      _weightController.text = '0.0';
      _notesController.clear();
      _selectedImportFileId = null;
      _selectedPoId = null;
      _selectedProjectId = null;
      _matchedExistingRFQ = null;
      _quotations.clear();
      _crdDate = DateTime.now().add(const Duration(days: 15));
      _isDirty = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isArabic ? 'تم تفريغ الحقول وبدء طلب عرض سعر جديد' : 'Form reset for new RFQ',
          severity: AppSeverity.info,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _addQuotationDialog({
    String? prefillCarrierName,
    int? prefillProviderId,
    double? prefillOceanCost,
    double? prefillLocalCost,
    int? prefillTransitDays,
    int? prefillFreeDays,
    String? prefillRemarks,
  }) {
    final isArabic = context.l10n.isArabic;
    final partnersState = ref.read(partnersProvider);
    final partnersList = partnersState.value ?? [];
    final carriersList = partnersList.where((p) => p.partnerType.contains('Shipping Line') || p.partnerType.contains('Freight')).toList();

    if (carriersList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isArabic ? 'يرجى إضافة ناقلين بحريين وخطوط ملاحية في دليل الشركاء أولاً' : 'Please add ocean carriers and shipping lines in Partners Directory first',
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    // Try to find matching carrier if prefill name provided
    int? matchedProviderId = prefillProviderId;
    String matchedProviderName = carriersList.first.partnerName;
    if (prefillProviderId != null) {
      final found = carriersList.where((c) => c.providerId == prefillProviderId).firstOrNull;
      if (found != null) matchedProviderName = found.partnerName;
    } else if (prefillCarrierName != null && prefillCarrierName.isNotEmpty) {
      final nameLower = prefillCarrierName.toLowerCase();
      final found = carriersList.where((c) => c.partnerName.toLowerCase().contains(nameLower) || nameLower.contains(c.partnerName.toLowerCase())).firstOrNull;
      if (found != null) {
        matchedProviderId = found.providerId;
        matchedProviderName = found.partnerName;
      } else {
        matchedProviderId = carriersList.first.providerId;
      }
    } else {
      matchedProviderId = carriersList.first.providerId;
    }

    final vesselController = TextEditingController();
    final voyageController = TextEditingController();
    final oceanCostController = TextEditingController(text: prefillOceanCost != null ? prefillOceanCost.toStringAsFixed(0) : '');
    final localCostController = TextEditingController(text: prefillLocalCost != null ? prefillLocalCost.toStringAsFixed(0) : '');
    final inlandCostController = TextEditingController();
    final freeDaysController = TextEditingController(text: prefillFreeDays?.toString() ?? '');
    final remarksController = TextEditingController(text: prefillRemarks ?? '');

    showDialog(
      context: context,
      builder: (context) {
        int? selectedProviderId = matchedProviderId;
        String selectedProviderName = matchedProviderName;

        // Calculate arrival from transit days if available
        DateTime sailingDate = _crdDate.add(const Duration(days: 4));
        DateTime arrivalDate = prefillTransitDays != null
            ? sailingDate.add(Duration(days: prefillTransitDays))
            : sailingDate.add(const Duration(days: 24));

        return SelectionArea(child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.directions_boat, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    prefillCarrierName != null
                        ? (isArabic ? 'مراجعة وتأكيد عرض السعر المستخرج' : 'Review & Confirm Extracted Quote')
                        : (isArabic ? 'إضافة عرض سعر ناقل أو شركة شحن' : 'Add Carrier / Shipping Line Quotation'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  )),
                ],
              ),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (prefillCarrierName != null && prefillCarrierName.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(
                                isArabic
                                    ? '🤖 تم استخراج هذا العرض تلقائياً من النص. راجع البيانات قبل الإضافة.'
                                    : '🤖 Auto-extracted from quote text. Please verify fields before adding.',
                                style: TextStyle(fontSize: 12, color: AppTheme.cobalt.withValues(alpha: 0.8)),
                              )),
                            ],
                          ),
                        ),
                      SearchableDropdownField<int?>(
                        value: selectedProviderId,
                        labelText: isArabic ? 'شركة الشحن أو الخط الملاحي *' : 'Shipping Line or Carrier *',
                        searchHintText: isArabic ? 'ابحث عن الشركة...' : 'Search carrier...',
                        items: carriersList.map((c) => SearchableDropdownItem<int?>(value: c.providerId, label: c.partnerName)).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final c = carriersList.firstWhere((p) => p.providerId == val);
                            setDialogState(() {
                              selectedProviderId = val;
                              selectedProviderName = c.partnerName;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: vesselController,
                              decoration: InputDecoration(
                                labelText: isArabic ? 'اسم السفينة الناقلة' : 'Vessel Name',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: voyageController,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: isArabic ? 'رقم الرحلة البحرية' : 'Voyage Number',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: oceanCostController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isArabic ? 'نولون الشحن البحري بالدولار *' : 'Ocean Freight USD *',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: localCostController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isArabic ? 'المصاريف والرسوم المحلية بالدولار' : 'Local Charges USD',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: inlandCostController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isArabic ? 'النقل الداخلي والتعتيق بالدولار' : 'Inland Haulage USD',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppDatePickerField(
                              label: isArabic ? 'تاريخ الإبحار الفعلي' : 'Actual Sailing Date (ETD)',
                              value: sailingDate,
                              allowClear: false,
                              onChanged: (d) {
                                if (d != null) setDialogState(() => sailingDate = d);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppDatePickerField(
                              label: isArabic ? 'تاريخ الوصول المتوقع للميناء' : 'Estimated Arrival Date (ETA)',
                              value: arrivalDate,
                              allowClear: false,
                              onChanged: (d) {
                                if (d != null) setDialogState(() => arrivalDate = d);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: freeDaysController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isArabic ? 'فترة السماح بالجمارك بالأيام' : 'Free Time at POD (Days)',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: remarksController,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'ملاحظات وشروط العرض' : 'Quotation Remarks & Terms',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                  onPressed: () {
                    final oceanCost = double.tryParse(oceanCostController.text.trim()) ?? 0.0;
                    final localCost = double.tryParse(localCostController.text.trim()) ?? 0.0;
                    final inlandCost = double.tryParse(inlandCostController.text.trim()) ?? 0.0;
                    final totalCost = oceanCost + localCost + inlandCost;
                    final transitDays = arrivalDate.difference(sailingDate).inDays;

                    setState(() {
                      _quotations.add(FreightQuotationItemModel(
                        providerId: selectedProviderId!,
                        providerName: selectedProviderName,
                        vesselName: vesselController.text.trim().isNotEmpty ? vesselController.text.trim() : null,
                        voyageNumber: voyageController.text.trim().isNotEmpty ? voyageController.text.trim() : null,
                        oceanFreightCost: oceanCost,
                        localChargesCost: localCost,
                        inlandCost: inlandCost,
                        totalCost: totalCost,
                        sailingDate: sailingDate.toString().substring(0, 10),
                        estimatedArrivalDate: arrivalDate.toString().substring(0, 10),
                        transitDays: transitDays > 0 ? transitDays : 1,
                        freeDaysAtPod: int.tryParse(freeDaysController.text.trim()) ?? 14,
                        remarks: remarksController.text.trim().isNotEmpty ? remarksController.text.trim() : null,
                      ));
                    });
                    Navigator.pop(context);
                  },
                  child: Text(isArabic ? 'إضافة العرض' : 'Add Quote', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      );
      },
    ).then((_) {
      vesselController.dispose();
      voyageController.dispose();
      oceanCostController.dispose();
      localCostController.dispose();
      inlandCostController.dispose();
      freeDaysController.dispose();
      remarksController.dispose();
    });
  }

  void _addExtractedOptionsToQuotations(List<ExtractedQuotationOption> selectedOptions) {
    final partners = ref.read(partnersProvider).valueOrNull ?? [];
    final defaultSailingDate = DateTime.now().add(const Duration(days: 7));

    setState(() {
      for (final opt in selectedOptions) {
        int providerId = 0;
        String providerName = opt.carrierName;

        final matchedPartner = partners.cast<dynamic>().firstWhere(
          (p) {
            final name = (p.name ?? '').toString().toLowerCase();
            final optName = opt.carrierName.toLowerCase();
            return name.contains(optName) || optName.contains(name);
          },
          orElse: () => null,
        );

        if (matchedPartner != null) {
          providerId = matchedPartner.id as int? ?? 0;
          providerName = matchedPartner.name as String? ?? opt.carrierName;
        }

        final transitDays = opt.transitDays ?? 28;
        final arrivalDate = defaultSailingDate.add(Duration(days: transitDays));

        _quotations.add(
          FreightQuotationItemModel(
            providerId: providerId,
            providerName: providerName,
            vesselName: null,
            voyageNumber: opt.containerType,
            oceanFreightCost: opt.oceanFreight,
            localChargesCost: opt.localCharges ?? 0.0,
            inlandCost: opt.exwCharges ?? 0.0,
            totalCost: opt.totalEstimatedCost,
            sailingDate: defaultSailingDate.toString().substring(0, 10),
            estimatedArrivalDate: arrivalDate.toString().substring(0, 10),
            transitDays: transitDays,
            freeDaysAtPod: opt.freeTimeDays ?? 14,
            remarks: [
              if (opt.notes != null && opt.notes!.isNotEmpty) opt.notes,
              if (opt.containerType.isNotEmpty) 'نوع الحاوية: ${opt.containerType}',
              if (!opt.isDirect) 'خط سير غير مباشر (ترانزيت)',
            ].join(' | '),
          ),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        'تمت إضافة ${selectedOptions.length} عرض/عروض أسعار بنجاح إلى المقارنة!',
        severity: AppSeverity.success,
      ),
    );
  }

  /// ─── Freight Quotations Smart Extractor Dialog (Text & OCR) ─────────────
  void _showFreightExtractorDialog() {
    FreightQuotationsExtractorDialog.show(
      context,
      onAddQuotations: _addExtractedOptionsToQuotations,
    );
  }

  Future<void> _saveRFQ() async {
    if (!_formKey.currentState!.validate()) return;
    if (_quotations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          'يرجى إضافة عرض سعر واحد على الأقل للمقارنة',
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'title': _titleController.text.trim(),
        'shipping_method': _shippingMethod,
        'crd_date': _crdDate.toString().substring(0, 10),
        'pol_name': _polName,
        'pod_name': _podName,
        'import_file_id': _selectedImportFileId,
        'po_id': _selectedPoId,
        'project_id': _selectedProjectId,
        'total_cbm': double.tryParse(_cbmController.text.trim()) ?? 0.0,
        'total_gross_weight_kg': double.tryParse(_weightController.text.trim()) ?? 0.0,
        'chargeable_weight_kg': double.tryParse(_weightController.text.trim()) ?? 0.0,
        'notes': _notesController.text.trim(),
        'quotations': _quotations.map((q) => q.toJson()).toList(),
      };

      final created = await ref.read(freightQuotationsProvider.notifier).createRFQ(payload);
      if (mounted && created != null) {
        _setDirty(false);
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            '${isArabic ? "تم حفظ وتثبيت طلب مقارنة أسعار الشحن! كود الطلب:" : "Freight RFQ saved successfully! Code:"} ${created.rfqCode}',
            severity: AppSeverity.success,
            action: SnackBarAction(
              label: isArabic ? 'دراسات النولون' : 'Studies',
              textColor: Colors.white,
              onPressed: () => selectNavigationIndex(ref, 4),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await showErrorDetailsDialog(
          context,
          title: '❌ تعذر حفظ طلب مقارنة أسعار الشحن',
          error: e,
          onRetry: () async {
            await _saveRFQ();
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showRFQDetailsDialog(FreightRFQRequestModel rfq) {
    final isArabic = context.l10n.isArabic;
    showDialog(
      context: context,
      builder: (context) {
        return SelectionArea(child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.directions_boat, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'تفاصيل طلب عرض أسعار الشحن: ${rfq.rfqCode}' : 'Freight RFQ Details: ${rfq.rfqCode}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              AppStatusBadge.fromStatus(status: rfq.status),
            ],
          ),
          content: SizedBox(
            width: 750,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${isArabic ? 'العنوان:' : 'Title:'} ${rfq.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        Text('${isArabic ? 'وسيلة الشحن:' : 'Method:'} ${rfq.shippingMethod} | CRD: ${rfq.crdDate}'),
                        const SizedBox(height: 4),
                        Text('${isArabic ? 'من:' : 'From:'} ${rfq.polName} ➔ ${isArabic ? 'إلى:' : 'To:'} ${rfq.podName}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          data: MetricCardData(
                            title: isArabic ? 'أقل نولون شحن' : 'Lowest Freight',
                            value: '\$${rfq.lowestFreightCost}',
                            icon: Icons.attach_money,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricCard(
                          data: MetricCardData(
                            title: isArabic ? 'متوسط نولون الشحن' : 'Average Freight',
                            value: '\$${rfq.averageFreightCost}',
                            icon: Icons.trending_up,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricCard(
                          data: MetricCardData(
                            title: isArabic ? 'أسرع ترانزيت' : 'Fastest Transit',
                            value: '${rfq.fastestTransitDays} ${isArabic ? 'أيام' : 'Days'}',
                            icon: Icons.speed,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MetricCard(
                          data: MetricCardData(
                            title: isArabic ? 'العرض المعتمد' : 'Awarded Carrier',
                            value: rfq.awardedProviderName ?? (isArabic ? 'لم يعتمد بعد' : 'Not awarded yet'),
                            icon: Icons.verified,
                            color: AppTheme.cobalt,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isArabic ? 'عروض أسعار الناقلين والمقارنة التفصيلية (Quotations List):' : 'Carrier Quotations & Detailed Comparison (Quotations List):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FlexColumnWidth(1.5),
                      1: FlexColumnWidth(2.5),
                      2: FlexColumnWidth(1.2),
                      3: FlexColumnWidth(1.2),
                      4: FlexColumnWidth(1.2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.05)),
                        children: [
                          Padding(padding: const EdgeInsets.all(8.0), child: Text(isArabic ? 'الحالة / القرار' : 'Status / Decision', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8.0), child: Text(isArabic ? 'الخط الملاحي / السفينة' : 'Carrier / Vessel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8.0), child: Text(isArabic ? 'إجمالي التكلفة' : 'Total Cost', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8.0), child: Text(isArabic ? 'الترانزيت' : 'Transit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8.0), child: Text(isArabic ? 'أيام السماح' : 'Free Days', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                      ...rfq.quotations.map(
                        (q) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: q.isAwarded
                                  ? Chip(label: Text(isArabic ? 'المعتمد 🎯' : 'Awarded 🎯', style: const TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: AppTheme.emerald)
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
                                      onPressed: () async {
                                        final nav = Navigator.of(context);
                                        await ref.read(freightQuotationsProvider.notifier).awardQuotation(rfq.rfqId, q.quotationId!);
                                        nav.pop();
                                      },
                                      child: Text(isArabic ? 'اعتماد هذا العرض' : 'Award Quote', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q.providerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  if (q.vesselName != null) Text('${isArabic ? 'السفينة:' : 'Vessel:'} ${q.vesselName}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Padding(padding: const EdgeInsets.all(8.0), child: Text('\$${q.totalCost}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                            Padding(padding: const EdgeInsets.all(8.0), child: Text('${q.transitDays} ${isArabic ? 'يوم' : 'd'}', style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8.0), child: Text('${q.freeDaysAtPod} ${isArabic ? 'يوم' : 'd'}', style: const TextStyle(fontSize: 11))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(isArabic ? 'إغلاق' : 'Close')),
          ],
        ),
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final portsState = ref.watch(transportLocationsProvider);
    final rfqsState = ref.watch(freightQuotationsProvider);

    final portsList = portsState.valueOrNull ?? [];

    final double lowestCost = _quotations.isNotEmpty ? _quotations.map((q) => q.totalCost).reduce((a, b) => a < b ? a : b) : 0.0;
    final int fastestTransit = _quotations.isNotEmpty ? _quotations.map((q) => q.transitDays).reduce((a, b) => a < b ? a : b) : 0;

    final isArabic = context.l10n.isArabic;
    final l10n = context.l10n;

    if (!_titleModifiedByUser &&
        (_titleController.text.isEmpty ||
            _titleController.text == 'طلب عرض سعر شحن حاويات لمعدات وآلات خط الإنتاج' ||
            _titleController.text == 'Container Freight Quotation Request for Production Line Equipment')) {
      _titleController.text = 'Container Freight Quotation Request for Production Line Equipment';
    }

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onDiscard: () => setState(() => _isDirty = false),
      child: Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: PageHeader(
        icon: Icons.request_quote_outlined,
        title: isArabic ? 'طلب ومقارنة عروض أسعار الشحن والترسية' : 'Freight RFQ & Quotations Comparison',
        actions: [
          // Quick Action 1: Load Saved RFQ
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: Text(isArabic ? 'استدعاء طلب مسجل' : 'Load Saved RFQ'),
            onPressed: () => _showLoadSavedRFQDialog(rfqsState.valueOrNull ?? []),
          ),
          const SizedBox(width: 6),
          // Quick Action 2: New RFQ
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: Text(isArabic ? 'طلب جديد' : 'New RFQ'),
            onPressed: _resetRFQForm,
          ),
          const SizedBox(width: 6),
          // Quick Action 3: Go to Freight Studies & Saved Log
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber.shade300,
              side: BorderSide(color: Colors.amber.shade300),
            ),
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: Text(isArabic ? 'دراسات النولون والسجلات' : 'Freight Studies & Log'),
            onPressed: () => selectNavigationIndex(ref, 4),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Metrics Header Bar
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        data: MetricCardData(
                          title: isArabic ? 'أقل سعر شحن متوفر' : 'Lowest Freight Rate',
                          value: '\$$lowestCost',
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        data: MetricCardData(
                          title: isArabic ? 'أسرع زمن ترانزيت' : 'Fastest Transit Time',
                          value: '$fastestTransit ${isArabic ? 'أيام' : 'Days'}',
                          icon: Icons.speed,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        data: MetricCardData(
                          title: isArabic ? 'عدد عروض الناقلين' : 'Carrier Quotes Count',
                          value: '${_quotations.length}',
                          icon: Icons.analytics_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    AppButton(
                      label: isArabic ? 'حفظ وتثبيت طلب مقارنة النولون' : 'Save & Pin Freight RFQ',
                      variant: AppButtonVariant.success,
                      icon: Icons.save,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _saveRFQ,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Smart AI Freight Quotations Extractor (Text & OCR Box) ──
                FreightAiExtractorCard(onAddQuotations: _addExtractedOptionsToQuotations),
const SizedBox(height: 18),

                // RFQ Configuration Header Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'بيانات شحنة طلب عرض الأسعار (Freight RFQ Setup)' : 'Freight RFQ Setup & Cargo Details',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                        ),
                        const Divider(),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: SearchableDropdownField<int?>(
                                value: _selectedImportFileId,
                                labelText: isArabic ? 'ملف الشحنة الاستيرادية (Import File)' : 'Import File',
                                searchHintText: isArabic ? 'ابحث عن ملف الشحنة...' : 'Search import file...',
                                items: [
                                  SearchableDropdownItem<int?>(
                                    value: null,
                                    label: isArabic ? '-- غير مرتبط بملف شحنة / None --' : '-- None / Unlinked --',
                                  ),
                                  ...(ref.watch(importFilesProvider).valueOrNull ?? []).map((f) => SearchableDropdownItem<int?>(
                                        value: f.importFileId,
                                        label: '${f.primaryNameWithCode} - ${f.companyName}',
                                      )),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _selectedImportFileId = v;
                                    if (v != null) {
                                      _populateFromImportFile(v);
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _titleController,
                                onChanged: (v) => _titleModifiedByUser = true,
                                decoration: InputDecoration(
                                  labelText: isArabic ? 'عنوان طلب عرض الأسعار *' : 'RFQ Subject / Title *',
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'يرجى إدخال العنوان' : 'Please enter title') : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: SearchableDropdownField<String>(
                                value: _shippingMethod,
                                labelText: isArabic ? 'وسيلة الشحن (Shipping Method) *' : 'Shipping Method *',
                                searchHintText: isArabic ? 'ابحث عن الوسيلة...' : 'Search shipping method...',
                                items: [
                                  SearchableDropdownItem(value: 'Ocean FCL', label: isArabic ? 'Ocean FCL (شحن بحري كامل)' : 'Ocean FCL (Full Container Load)'),
                                  SearchableDropdownItem(value: 'Ocean LCL', label: isArabic ? 'Ocean LCL (شحن بحري جزئي)' : 'Ocean LCL (Less than Container Load)'),
                                  SearchableDropdownItem(value: 'Air Freight', label: isArabic ? 'Air Freight (شحن جوي)' : 'Air Freight'),
                                  SearchableDropdownItem(value: 'Courier Express', label: isArabic ? 'Courier Express (بريد سريع / شحن سريع)' : 'Courier Express'),
                                  SearchableDropdownItem(value: 'Inland Trucking', label: isArabic ? 'Inland Trucking (شحن بري)' : 'Inland Trucking'),
                                  SearchableDropdownItem(value: 'Multi-Modal', label: isArabic ? 'Multi-Modal (نقل متعدد الوسائط)' : 'Multi-Modal'),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _shippingMethod = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: AppDatePickerField(
                                label: isArabic ? 'تاريخ جاهزية البضاعة (CRD) *' : 'Cargo Ready Date (CRD) *',
                                value: _crdDate,
                                isRequired: true,
                                allowClear: false,
                                onChanged: (d) {
                                  if (d != null) setState(() => _crdDate = d);
                                },
                              ),
                            ),
                          ],
                        ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SearchableDropdownField<String>(
                                  value: _polName.isNotEmpty ? _polName : (portsList.isNotEmpty ? portsList.first.locationName : 'Shanghai Port (CN SHA), China'),
                                  labelText: isArabic ? 'ميناء التحميل (POL) *' : 'Port of Loading (POL) *',
                                  searchHintText: isArabic ? 'ابحث عن ميناء التحميل...' : 'Search port of loading...',
                                  items: [
                                    if (_polName.isNotEmpty && !portsList.any((p) => p.locationName == _polName))
                                      SearchableDropdownItem<String>(value: _polName, label: _polName),
                                    ...portsList.map((p) => SearchableDropdownItem<String>(value: p.locationName, label: p.locationName)),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _polName = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SearchableDropdownField<String>(
                                  value: _podName.isNotEmpty ? _podName : (portsList.length > 1 ? portsList[1].locationName : 'Alexandria Port (EG ALX), Egypt'),
                                  labelText: isArabic ? 'ميناء الوصول (POD) *' : 'Port of Discharge (POD) *',
                                  searchHintText: isArabic ? 'ابحث عن ميناء الوصول...' : 'Search port of discharge...',
                                  items: [
                                    if (_podName.isNotEmpty && !portsList.any((p) => p.locationName == _podName))
                                      SearchableDropdownItem<String>(value: _podName, label: _podName),
                                    ...portsList.map((p) => SearchableDropdownItem<String>(value: p.locationName, label: p.locationName)),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _podName = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _cbmController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: isArabic ? 'إجمالي الحجم (CBM)' : 'Total Volume (CBM)',
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _weightController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: isArabic ? 'الوزن القائم (Gross Wt kg)' : 'Gross Weight (kg)',
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),

                          // Container Recommendation Engine (MD-019.1 Banner)
                          Builder(builder: (context) {
                            final double curCbm = double.tryParse(_cbmController.text.trim()) ?? 0.0;
                            final double curWeight = double.tryParse(_weightController.text.trim()) ?? 0.0;
                            final dualRec = ContainerRequirementEngine.calculateBoth(totalCbm: curCbm, totalWeightKg: curWeight);
                            final containerRec = _isStackable ? dualRec.stackableResult : dualRec.nonStackableResult;

                            return Container(
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 22),
                                      const SizedBox(width: 10),
                                      Text(
                                        isArabic ? '🚚 نوع التحميل والتخزين: ' : '🚚 Cargo Stacking Type: ',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: Text(isArabic ? '📦 بضائع قابلة للرص' : '📦 Stackable Cargo'),
                                        selected: _isStackable,
                                        selectedColor: AppTheme.cobalt,
                                        labelStyle: TextStyle(color: _isStackable ? Colors.white : AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 11),
                                        onSelected: (val) => setState(() => _isStackable = true),
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: Text(isArabic ? '🚫 بضائع غير قابلة للرص' : '🚫 Non-Stackable Cargo'),
                                        selected: !_isStackable,
                                        selectedColor: Colors.orange.shade800,
                                        labelStyle: TextStyle(color: !_isStackable ? Colors.white : AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 11),
                                        onSelected: (val) => setState(() => _isStackable = false),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isArabic ? '🚚 اقتراح أعداد وأنواع الحاويات التلقائي:' : '🚚 Auto Container Recommendation:',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              containerRec.recommendationSummary,
                                              style: TextStyle(fontSize: 12, color: _isStackable ? Colors.blue.shade900 : Colors.orange.shade900, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.cobalt,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.table_chart, size: 14, color: Colors.white),
                                        label: Text(isArabic ? 'مقارنة الحالتين' : 'Compare Cases', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                        onPressed: () => _showContainerComparisonDialog(context, dualRec, curCbm, curWeight),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Smart Auto-Fetch Banner if existing quotations are found for this file
                  if (_matchedExistingRFQ != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade400, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.lightbulb_rounded, color: Colors.amber.shade900, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isArabic
                                      ? '💡 توجد عروض أسعار مسجلة مسبقاً لهذا الملف (${_matchedExistingRFQ!.rfqCode}) — عدد ${_matchedExistingRFQ!.quotations.length} عروض ناقلين مقدمة.'
                                      : '💡 Saved quotations found for this file (${_matchedExistingRFQ!.rfqCode}) — ${_matchedExistingRFQ!.quotations.length} carrier quotes available.',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown.shade900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isArabic
                                      ? 'يمكنك استدعاء هذه العروض في أي وقت بنقرة واحدة لتحديث جدول المقارنة والترسية الفورية:'
                                      : 'You can load these quotations anytime with one click to update the comparison and award immediately:',
                                  style: TextStyle(fontSize: 11, color: Colors.brown.shade700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cobalt,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.download_for_offline_outlined, size: 16, color: Colors.white),
                            label: Text(
                              isArabic ? 'استدعاء العروض الآن للجدول' : 'Load Quotes to Table Now',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            onPressed: () => _loadExistingRFQQuotations(_matchedExistingRFQ!),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Quotations List Table
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runSpacing: 10,
                            spacing: 10,
                            children: [
                              Text(
                                isArabic ? 'عروض أسعار الخطوط الملاحية والشركات المنافسة' : 'Shipping Lines & Carriers Quotations',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (_quotations.isNotEmpty) ...[
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.cobalt,
                                        side: const BorderSide(color: AppTheme.cobalt),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.table_chart_outlined, size: 14),
                                      label: Text(l10n.freightQuotationsExportTsvBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => FreightQuotationsExportService.exportToTsv(
                                        context: context,
                                        quotations: _quotations,
                                        importFileCode: _matchedExistingRFQ?.rfqCode,
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.emerald,
                                        side: const BorderSide(color: AppTheme.emerald),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.file_download_outlined, size: 14),
                                      label: Text(l10n.freightQuotationsExportExcelBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => FreightQuotationsExportService.exportToExcel(
                                        context: context,
                                        quotations: _quotations,
                                        importFileCode: _matchedExistingRFQ?.rfqCode,
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.deepPurple,
                                        side: const BorderSide(color: Colors.deepPurple),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                                      label: Text(l10n.freightQuotationsPrintPdfBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => FreightQuotationsExportService.printOrSavePdf(
                                        context: context,
                                        quotations: _quotations,
                                        importFileCode: _matchedExistingRFQ?.rfqCode,
                                        supplierName: _titleController.text,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.charcoal,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.copy_all_outlined, size: 14),
                                      label: Text(l10n.freightQuotationsCopyDossierBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        final text = FreightQuotationsExportService.buildDossierText(
                                          context: context,
                                          quotations: _quotations,
                                          importFileCode: _matchedExistingRFQ?.rfqCode,
                                          supplierName: _titleController.text,
                                        );
                                        CopyHelper.copy(context, text, customMessage: l10n.freightQuotationsCopyDossierSuccess);
                                      },
                                    ),
                                  ],
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.cobalt,
                                      side: const BorderSide(color: AppTheme.cobalt),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                    onPressed: _showFreightExtractorDialog,
                                    icon: const Icon(Icons.auto_awesome, size: 18),
                                    label: Text(isArabic ? 'استخراج عروض الأسعار الذكي' : 'Extract Freight Quotes (AI & OCR)'),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                                    onPressed: _addQuotationDialog,
                                    icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                                    label: Text(isArabic ? 'إضافة عرض سعر ناقل' : 'Add Carrier Quotation', style: const TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 10),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _quotations.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final q = _quotations[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          InkWell(
                                            borderRadius: BorderRadius.circular(4),
                                            onTap: () => CopyHelper.copy(context, q.providerName),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(child: Text(q.providerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
                                              ],
                                            ),
                                          ),
                                           if (q.vesselName != null)
                                            Text(
                                              '${isArabic ? 'السفينة:' : 'Vessel:'} ${q.vesselName} | ${isArabic ? 'الرحلة:' : 'Voyage:'} ${q.voyageNumber ?? "-"}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                         ],
                                       ),
                                     ),
                                     const SizedBox(width: 8),
                                     Expanded(
                                       flex: 2,
                                       child: Text(
                                         '${isArabic ? 'نولون:' : 'Freight:'} \$${q.oceanFreightCost} + \$${q.localChargesCost}',
                                         style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                       ),
                                     ),
                                     const SizedBox(width: 8),
                                     Expanded(
                                       flex: 2,
                                       child: InkWell(
                                         borderRadius: BorderRadius.circular(4),
                                         onTap: () => CopyHelper.copy(context, '${q.totalCost}'),
                                         child: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             Text(
                                               '${isArabic ? 'الإجمالي:' : 'Total:'} \$${q.totalCost}',
                                               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                                             ),
                                             const SizedBox(width: 4),
                                             const Icon(Icons.copy_rounded, size: 12, color: Colors.green),
                                           ],
                                         ),
                                       ),
                                     ),
                                     const SizedBox(width: 8),
                                     Expanded(
                                       flex: 2,
                                       child: Text(
                                         '${isArabic ? 'ترانزيت:' : 'Transit:'} ${q.transitDays} ${isArabic ? 'يوم' : 'd'} (${q.freeDaysAtPod} ${isArabic ? 'يوم سماح' : 'Free Days'})',
                                         style: const TextStyle(fontSize: 11),
                                       ),
                                    ),
                                     RowActionsPill(
                                       deleteTooltip: isArabic ? 'حذف هذا العرض' : 'Delete quote',
                                       onDelete: () async {
                                         final ok = await AppConfirmDialog.showDelete(
                                           context,
                                           entityName: q.providerName,
                                           title: isArabic ? 'حذف عرض السعر' : 'Delete Quotation',
                                           message: isArabic
                                               ? 'هل أنت متأكد من حذف عرض سعر ${q.providerName}؟'
                                               : 'Are you sure you want to delete quotation for ${q.providerName}?',
                                         );
                                         if (ok) setState(() => _quotations.removeAt(index));
                                       },
                                       confirmDelete: false,
                                     ),
                                  ],
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
          ),
        ),
      ),
    );
  }
void _showContainerComparisonDialog(BuildContext context, ContainerDualRecommendationResult dualRec, double totalCbm, double totalWeightKg) {
    final isArabic = context.l10n.isArabic;
    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.inventory_2, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'تحليل خيارات الحاويات وسيناريوهات التحميل' : 'Container Options & Loading Scenarios Analysis',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${isArabic ? 'إجمالي الشحنة:' : 'Total Cargo:'} ${totalCbm.toStringAsFixed(2)} m³ | ${totalWeightKg.toStringAsFixed(0)} kg',
                        style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 750,
              height: 480,
              child: Column(
                children: [
                  Container(
                    color: AppTheme.charcoal,
                    child: TabBar(
                      indicatorColor: AppTheme.cobalt,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: [
                        Tab(icon: const Icon(Icons.layers), text: isArabic ? '📦 قابل للرص (Stackable)' : '📦 Stackable Cargo'),
                        Tab(icon: const Icon(Icons.view_array), text: isArabic ? '🚫 غير قابل للرص - طبقة واحدة (Non-Stackable)' : '🚫 Non-Stackable (Single Layer)'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildComparisonTable(dualRec.stackableResult, isArabic),
                        _buildComparisonTable(dualRec.nonStackableResult, isArabic),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(isArabic ? 'إغلاق' : 'Close')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComparisonTable(ContainerRecommendationResult rec, bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: rec.isStackable ? AppTheme.emerald.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: rec.isStackable ? AppTheme.emerald : Colors.orange.shade800),
            ),
            child: Text(
              '${isArabic ? 'التوصية المعتمدة:' : 'Approved Recommendation:'} ${rec.recommendationSummary}',
              style: TextStyle(fontWeight: FontWeight.bold, color: rec.isStackable ? AppTheme.emerald : Colors.orange.shade900),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                children: [
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(isArabic ? 'نوع الحاوية (Spec)' : 'Container Spec', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(isArabic ? 'العدد المطلوب' : 'Required Count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(isArabic ? 'استغلال المساحة %' : 'Space Utilization %', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(isArabic ? 'استغلال الوزن %' : 'Weight Utilization %', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(isArabic ? 'التوصية' : 'Recommendation', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
              ...rec.comparisonDetails.map((detail) {
                final spec = detail['spec'] as ContainerSpec;
                final int count = detail['reqCount'] as int;
                final double volUtil = detail['spaceUtil'] as double;
                final double weightUtil = detail['payloadUtil'] as double;
                final isBest = spec.code == rec.recommendedContainerCode;

                return TableRow(
                  decoration: isBest ? BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.12)) : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spec.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isBest ? AppTheme.emerald : AppTheme.charcoal)),
                          Text('${isArabic ? 'السعة:' : 'Capacity:'} ${spec.internalVolumeCbm} CBM | ${isArabic ? 'الحمولة:' : 'Payload:'} ${spec.maxPayloadKg} kg', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('$count x ${spec.code}', style: TextStyle(fontWeight: FontWeight.bold, color: isBest ? AppTheme.emerald : AppTheme.charcoal)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('${volUtil.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: volUtil > 90 ? Colors.green : Colors.orange)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('${weightUtil.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: weightUtil > 90 ? Colors.green : Colors.orange)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: isBest
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.emerald, borderRadius: BorderRadius.circular(4)),
                              child: Text(isArabic ? '🌟 الخيار الأنسب' : '🌟 Best Option', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            )
                          : Text(isArabic ? 'بديل قابل للتطبيق' : 'Viable Alternative', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

