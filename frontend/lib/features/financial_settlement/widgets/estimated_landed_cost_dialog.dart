import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../models/estimated_landed_cost_model.dart';
import '../providers/financial_settlement_provider.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
/// Shows the Estimated Landed Cost Simulation Dialog (PL-08).
Future<void> showEstimatedLandedCostDialog(
  BuildContext context,
  WidgetRef ref, {
  required int importFileId,
  EstimatedLandedCostSimulationRequestModel? initialRequest,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => EstimatedLandedCostDialog(
      importFileId: importFileId,
      initialRequest: initialRequest,
    ),
  );
}

class EstimatedLandedCostDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final EstimatedLandedCostSimulationRequestModel? initialRequest;

  const EstimatedLandedCostDialog({
    super.key,
    required this.importFileId,
    this.initialRequest,
  });

  @override
  ConsumerState<EstimatedLandedCostDialog> createState() =>
      _EstimatedLandedCostDialogState();
}

class _EstimatedLandedCostDialogState
    extends ConsumerState<EstimatedLandedCostDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  EstimatedLandedCostSimulationModel? _data;

  // Controllers for overrides
  late final TextEditingController _fxRateController;
  late final TextEditingController _freightController;
  late final TextEditingController _insuranceController;
  late final TextEditingController _clearanceController;
  late final TextEditingController _portController;
  late final TextEditingController _transportController;
  late final TextEditingController _bankFeesController;
  late final TextEditingController _otherFeesController;
  String _selectedAllocation = 'Value-Based';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _fxRateController = TextEditingController();
    _freightController = TextEditingController();
    _insuranceController = TextEditingController();
    _clearanceController = TextEditingController();
    _portController = TextEditingController();
    _transportController = TextEditingController();
    _bankFeesController = TextEditingController();
    _otherFeesController = TextEditingController();

    if (widget.initialRequest != null) {
      _applyRequestToControllers(widget.initialRequest!);
    }

    _loadSimulation();
  }

  void _applyRequestToControllers(
      EstimatedLandedCostSimulationRequestModel req) {
    if (req.exchangeRateOverride != null) {
      _fxRateController.text = req.exchangeRateOverride!.toString();
    }
    if (req.freightAmountEgpOverride != null) {
      _freightController.text = req.freightAmountEgpOverride!.toString();
    }
    if (req.insuranceAmountEgpOverride != null) {
      _insuranceController.text = req.insuranceAmountEgpOverride!.toString();
    }
    if (req.clearanceFeesEgpOverride != null) {
      _clearanceController.text = req.clearanceFeesEgpOverride!.toString();
    }
    if (req.portHandlingEgpOverride != null) {
      _portController.text = req.portHandlingEgpOverride!.toString();
    }
    if (req.inlandTransportEgpOverride != null) {
      _transportController.text = req.inlandTransportEgpOverride!.toString();
    }
    if (req.bankFeesEgpOverride != null) {
      _bankFeesController.text = req.bankFeesEgpOverride!.toString();
    }
    if (req.otherExpensesEgpOverride != null) {
      _otherFeesController.text = req.otherExpensesEgpOverride!.toString();
    }
    _selectedAllocation = req.allocationPreference;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fxRateController.dispose();
    _freightController.dispose();
    _insuranceController.dispose();
    _clearanceController.dispose();
    _portController.dispose();
    _transportController.dispose();
    _bankFeesController.dispose();
    _otherFeesController.dispose();
    super.dispose();
  }

  Future<void> _loadSimulation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final req = _buildRequestFromControllers();
      final result = await ref
          .read(financialSettlementProvider.notifier)
          .simulateEstimatedLandedCost(widget.importFileId, req.toJson());

      if (mounted) {
        setState(() {
          _data = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  EstimatedLandedCostSimulationRequestModel _buildRequestFromControllers() {
    return EstimatedLandedCostSimulationRequestModel(
      exchangeRateOverride: double.tryParse(_fxRateController.text.trim()),
      freightAmountEgpOverride: double.tryParse(_freightController.text.trim()),
      insuranceAmountEgpOverride:
          double.tryParse(_insuranceController.text.trim()),
      clearanceFeesEgpOverride:
          double.tryParse(_clearanceController.text.trim()),
      portHandlingEgpOverride: double.tryParse(_portController.text.trim()),
      inlandTransportEgpOverride:
          double.tryParse(_transportController.text.trim()),
      bankFeesEgpOverride: double.tryParse(_bankFeesController.text.trim()),
      otherExpensesEgpOverride: double.tryParse(_otherFeesController.text.trim()),
      allocationPreference: _selectedAllocation,
    );
  }

  void _copyTsvToClipboard() {
    if (_data == null) return;
    final buffer = StringBuffer();
    buffer.writeln(
        "Line\tItem Code\tItem Name\tHS Code\tQty\tFOB Unit FC\tFOB Unit EGP\tFOB Total EGP\tCustoms Duty EGP\tVAT & Taxes EGP\tFreight EGP\tClearance & Port EGP\tInland Transport EGP\tTotal Landed EGP\tUnit Landed EGP\tUnit Landed FC\tMarkup Factor\tMarkup %");
    for (final itm in _data!.itemsBreakdown) {
      buffer.writeln(
          "${itm.lineNo}\t${itm.itemCode}\t${itm.itemName}\t${itm.hsCode}\t${itm.qty}\t${itm.unitPriceFc}\t${itm.fobUnitEgp}\t${itm.fobTotalEgp}\t${itm.allocatedCustomsDutyEgp}\t${itm.allocatedVatEgp}\t${itm.allocatedFreightEgp}\t${itm.allocatedClearanceAndPortEgp}\t${itm.allocatedInlandTransportEgp}\t${itm.totalLandedCostEgp}\t${itm.unitLandedCostEgp}\t${itm.unitLandedCostFc}\t${itm.markupFactor}\t${itm.markupPercent}%");
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAr
              ? 'تم نسخ بيانات التكلفة التقديرية (TSV) للحافظة بنجاح'
              : 'Estimated landed cost TSV copied to clipboard successfully',
        ),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _exportCsv() async {
    if (_data == null) return;
    final buffer = StringBuffer();
    // UTF-8 BOM for Arabic support in Excel
    buffer.write('\uFEFF');
    buffer.writeln(
        "م,كود الصنف,اسم الصنف,البند الجمركي,الكمية,سعر الوحدة أجنبي,سعر الوحدة ج.م,إجمالي FOB ج.م,ضريبة الوارد ج.م,الضرائب والقيمة المضافة ج.م,النولون ج.م,الموانئ والتخليص ج.م,النقل الداخلي ج.م,إجمالي تكلفة الوصول ج.م,تكلفة الوحدة ج.م,تكلفة الوحدة أجنبي,معامل الزيادة,نسبة الزيادة %");
    for (final itm in _data!.itemsBreakdown) {
      buffer.writeln(
          '${itm.lineNo},"${itm.itemCode}","${itm.itemName}","${itm.hsCode}",${itm.qty},${itm.unitPriceFc},${itm.fobUnitEgp},${itm.fobTotalEgp},${itm.allocatedCustomsDutyEgp},${itm.allocatedVatEgp},${itm.allocatedFreightEgp},${itm.allocatedClearanceAndPortEgp},${itm.allocatedInlandTransportEgp},${itm.totalLandedCostEgp},${itm.unitLandedCostEgp},${itm.unitLandedCostFc},${itm.markupFactor},${itm.markupPercent}%');
    }

    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: utf8.encode(buffer.toString()),
      stageName: 'Landed Cost Simulation',
      importFileNameOrCode: _data!.importFileCode,
      extension: 'csv',
    );
  }

  bool get _isDirty {
    final req = widget.initialRequest;
    if (_fxRateController.text.trim() != (req?.exchangeRateOverride?.toString() ?? '')) return true;
    if (_freightController.text.trim() != (req?.freightAmountEgpOverride?.toString() ?? '')) return true;
    if (_insuranceController.text.trim() != (req?.insuranceAmountEgpOverride?.toString() ?? '')) return true;
    if (_clearanceController.text.trim() != (req?.clearanceFeesEgpOverride?.toString() ?? '')) return true;
    if (_portController.text.trim() != (req?.portHandlingEgpOverride?.toString() ?? '')) return true;
    if (_transportController.text.trim() != (req?.inlandTransportEgpOverride?.toString() ?? '')) return true;
    if (_bankFeesController.text.trim() != (req?.bankFeesEgpOverride?.toString() ?? '')) return true;
    if (_otherFeesController.text.trim() != (req?.otherExpensesEgpOverride?.toString() ?? '')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width - 32).clamp(360.0, 1150.0);
    final dialogHeight = (screenSize.height - 48).clamp(500.0, 850.0);
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              _buildHeader(isDark, isAr),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              isAr
                                  ? 'جاري حساب وتوزيع تكلفة الوصول التقديرية بالربط مع محرك الجمارك...'
                                  : 'Calculating and allocating estimated landed cost with customs engine...',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    isAr
                                        ? 'خطأ في عملية المحاكاة:\n$_errorMessage'
                                        : 'Simulation error:\n$_errorMessage',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _loadSimulation,
                                    icon: const Icon(Icons.refresh),
                                    label: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildContent(isDark, isAr),
              ),
              _buildBottomBar(isDark, isAr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isAr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calculate, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr
                      ? 'محاكاة تكلفة الوصول التقديرية للوحدة قبل الشحن (Estimated Landed Cost)'
                      : 'Pre-Shipment Estimated Landed Cost Simulation',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _data != null
                      ? (isAr
                          ? 'الملف: ${_data!.importFileCode} | العملة: ${_data!.currency} | الصرف: ${_data!.exchangeRate} ج.م | شرط الشحن: ${_data!.incoterm}'
                          : 'File: ${_data!.importFileCode} | Currency: ${_data!.currency} | FX: ${_data!.exchangeRate} EGP | Incoterm: ${_data!.incoterm}')
                      : (isAr
                          ? 'جاري تحميل المعطيات اللوجستية والجمركية...'
                          : 'Loading logistics & customs parameters...'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
            tooltip: isAr ? 'إغلاق' : 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, bool isAr) {
    if (_data == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Executive Summary Banner
          _buildExecutiveSummaryBanner(isDark),
          const SizedBox(height: 12),

          // 2. KPI Cards Strip
          _buildKpiCards(isDark, isAr),
          const SizedBox(height: 12),

          // 3. Overrides & Recalculate Panel (Collapsible)
          _buildOverridesPanel(isDark, isAr),
          const SizedBox(height: 16),

          // 4. Tabs Section
          TabBar(
            controller: _tabController,
            labelColor: isDark ? Colors.tealAccent : Colors.teal.shade800,
            unselectedLabelColor: Colors.grey,
            indicatorColor: isDark ? Colors.tealAccent : Colors.teal.shade700,
            tabs: [
              Tab(
                icon: const Icon(Icons.table_chart_outlined),
                text: isAr
                    ? 'تحليل بنود البضاعة وتكلفة الوحدة (Items Landed Cost)'
                    : 'Items Breakdown & Unit Landed Cost',
              ),
              Tab(
                icon: const Icon(Icons.receipt_long_outlined),
                text: isAr
                    ? 'قائمة المصاريف والنفقات التقديرية (Expenses Breakdown)'
                    : 'Estimated Expenses Breakdown',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildItemsTable(isDark, isAr),
                _buildExpensesTable(isDark, isAr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveSummaryBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.shade900.withOpacity(0.25)
            : const Color(0xFFF0FDFA),
        border: Border.all(
          color: isDark ? Colors.teal.shade700 : Colors.teal.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: isDark ? Colors.tealAccent : Colors.teal.shade700,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _data!.executiveSummaryAr,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.tealAccent.shade100 : Colors.teal.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards(bool isDark, bool isAr) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool isCompact = constraints.maxWidth < 850;

      final cards = [
        _buildKpiItem(
          label: isAr ? 'إجمالي البضاعة FOB' : 'Total Goods FOB',
          valueEgp: '${_data!.totalFobEgp.toStringAsFixed(0)} ${isAr ? 'ج.م' : 'EGP'}',
          valueFc: '${_data!.totalFobFc.toStringAsFixed(0)} ${_data!.currency}',
          icon: Icons.inventory_2,
          color: const Color(0xFF2563EB),
          isDark: isDark,
        ),
        _buildKpiItem(
          label: isAr ? 'النولون والتأمين' : 'Freight & Insurance',
          valueEgp:
              '${(_data!.totalFreightEgp + _data!.totalInsuranceEgp).toStringAsFixed(0)} ${isAr ? 'ج.م' : 'EGP'}',
          valueFc: isAr
              ? 'نولون: ${_data!.totalFreightEgp.toStringAsFixed(0)}'
              : 'Freight: ${_data!.totalFreightEgp.toStringAsFixed(0)}',
          icon: Icons.sailing,
          color: const Color(0xFF0D9488),
          isDark: isDark,
        ),
        _buildKpiItem(
          label: isAr ? 'الجمارك والضرائب' : 'Customs & Taxes',
          valueEgp: '${_data!.totalCustomsAndTaxesEgp.toStringAsFixed(0)} ${isAr ? 'ج.م' : 'EGP'}',
          valueFc: isAr ? 'بند التعريفة MD-008' : 'Tariff Schedule MD-008',
          icon: Icons.account_balance,
          color: const Color(0xFFD97706),
          isDark: isDark,
        ),
        _buildKpiItem(
          label: isAr ? 'الموانئ والتخليص والنقل' : 'Port, Clearance & Inland',
          valueEgp:
              '${(_data!.totalClearanceAndPortEgp + _data!.totalInlandTransportEgp).toStringAsFixed(0)} ${isAr ? 'ج.م' : 'EGP'}',
          valueFc: isAr ? 'لوجستيات وموانئ' : 'Logistics & Ports',
          icon: Icons.local_shipping,
          color: const Color(0xFF7C3AED),
          isDark: isDark,
        ),
        _buildKpiItem(
          label: isAr ? 'تكلفة الوصول الشاملة' : 'Total Landed Cost',
          valueEgp: '${_data!.totalLandedCostEgp.toStringAsFixed(0)} ${isAr ? 'ج.م' : 'EGP'}',
          valueFc:
              '${_data!.totalLandedCostFc.toStringAsFixed(0)} ${_data!.currency}',
          icon: Icons.monetization_on,
          color: const Color(0xFF059669),
          isDark: isDark,
          highlight: true,
        ),
        _buildKpiItem(
          label: isAr ? 'معامل الزيادة الإجمالي' : 'Overall Markup Factor',
          valueEgp: '×${_data!.averageMarkupFactor.toStringAsFixed(3)}',
          valueFc: '+${_data!.averageMarkupPercent.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: const Color(0xFFE11D48),
          isDark: isDark,
          highlight: true,
        ),
      ];

      if (isCompact) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cards
              .map((c) => SizedBox(
                    width: (constraints.maxWidth - 16) / 2,
                    child: c,
                  ))
              .toList(),
        );
      }

      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: c,
                  ),
                ))
            .toList(),
      );
    });
  }

  Widget _buildKpiItem({
    required String label,
    required String valueEgp,
    required String valueFc,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight
            ? (isDark ? color.withOpacity(0.2) : color.withOpacity(0.08))
            : (isDark ? AppTheme.darkElevatedSurface : Colors.white),
        border: Border.all(
          color: highlight ? color : color.withOpacity(isDark ? 0.4 : 0.25),
          width: highlight ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valueEgp,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: highlight
                  ? color
                  : (isDark ? Colors.white : AppTheme.charcoal),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            valueFc,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOverridesPanel(bool isDark, bool isAr) {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.all(12),
      backgroundColor:
          isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF8FAFC),
      collapsedBackgroundColor:
          isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      leading: const Icon(Icons.tune, color: AppTheme.cobalt, size: 20),
      title: Text(
        isAr
            ? 'تعديل معايير ومصاريف المحاكاة (Parameters & Cost Overrides)'
            : 'Simulation Parameters & Cost Overrides',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        isAr
            ? 'يمكنك تعديل أسعار الصرف، نولون الشحن، التأمين، التخليص، وتفضيل التوزيع وإعادة الحساب فورياً'
            : 'Modify exchange rates, freight, insurance, clearance, and allocation rule to recalculate instantly',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildOverrideField(
              isAr ? 'سعر الصرف ج.م' : 'FX Rate (EGP)',
              _fxRateController,
              isAr ? 'مثال: 50.5' : 'e.g. 50.5',
            ),
            _buildOverrideField(
              isAr ? 'نولون الشحن (EGP)' : 'Freight (EGP)',
              _freightController,
              isAr ? 'تعديل النولون' : 'Edit Freight',
            ),
            _buildOverrideField(
              isAr ? 'التأمين البحري (EGP)' : 'Marine Insurance (EGP)',
              _insuranceController,
              isAr ? 'تعديل التأمين' : 'Edit Insurance',
            ),
            _buildOverrideField(
              isAr ? 'أتعاب التخليص (EGP)' : 'Clearance Fees (EGP)',
              _clearanceController,
              '4500',
            ),
            _buildOverrideField(
              isAr ? 'مصاريف الموانئ (EGP)' : 'Port Handling (EGP)',
              _portController,
              '5000',
            ),
            _buildOverrideField(
              isAr ? 'النقل الداخلي (EGP)' : 'Inland Transport (EGP)',
              _transportController,
              '7500',
            ),
            _buildOverrideField(
              isAr ? 'مصاريف بنكية (EGP)' : 'Bank Fees (EGP)',
              _bankFeesController,
              '2500',
            ),
            _buildOverrideField(
              isAr ? 'مصاريف أخرى (EGP)' : 'Other Fees (EGP)',
              _otherFeesController,
              '2000',
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: _selectedAllocation,
                decoration: InputDecoration(
                  labelText: isAr ? 'أساس توزيع المصاريف' : 'Cost Allocation Basis',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                items: [
                  DropdownMenuItem(
                      value: 'Value-Based',
                      child: Text(isAr ? 'حسب القيمة (Value)' : 'Value-Based')),
                  DropdownMenuItem(
                      value: 'Weight-Based',
                      child: Text(isAr ? 'حسب الوزن (Weight)' : 'Weight-Based')),
                  DropdownMenuItem(
                      value: 'Volume-Based',
                      child: Text(isAr ? 'حسب الحجم (Volume)' : 'Volume-Based')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedAllocation = val;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () {
                _fxRateController.clear();
                _freightController.clear();
                _insuranceController.clear();
                _clearanceController.clear();
                _portController.clear();
                _transportController.clear();
                _bankFeesController.clear();
                _otherFeesController.clear();
                _selectedAllocation = 'Value-Based';
                _loadSimulation();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(isAr ? 'استعادة القيم الافتراضية' : 'Reset Defaults'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: _loadSimulation,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(
                isAr ? 'إعادة الحساب والتوزيع' : 'Recalculate & Allocate',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverrideField(
      String label, TextEditingController ctrl, String hint) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildItemsTable(bool isDark, bool isAr) {
    if (_data!.itemsBreakdown.isEmpty) {
      return Center(
        child: Text(isAr ? 'لا توجد بنود متاحة للمحاكاة' : 'No items available for simulation'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF1F5F9),
              ),
              columnSpacing: 16,
              horizontalMargin: 12,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 44,
              columns: [
                DataColumn(label: Text(isAr ? 'م' : '#', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'كود الصنف' : 'Item Code', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'اسم الصنف والوصف' : 'Item Name & Description', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'البند الجمركي' : 'HS Code', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'الكمية' : 'Qty', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'سعر FOB للوحدة' : 'FOB Unit Price', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'إجمالي FOB ج.م' : 'Total FOB (EGP)', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'ضريبة الوارد ج.م' : 'Customs Duty (EGP)', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'الضرائب والقيمة المضافة' : 'VAT & Taxes (EGP)', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'نولون ولوجستيات' : 'Freight & Logistics', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'إجمالي التكلفة ج.م' : 'Total Landed (EGP)', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'تكلفة الوحدة ج.م' : 'Unit Landed (EGP)', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'تكلفة الوحدة أجنبي' : 'Unit Landed (FC)', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'معامل الزيادة' : 'Markup Factor', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'نسبة الزيادة' : 'Markup %', style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _data!.itemsBreakdown.map((itm) {
                return DataRow(cells: [
                  DataCell(Text('${itm.lineNo}')),
                  DataCell(Text(itm.itemCode, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(itm.itemName)),
                  DataCell(LtrText(itm.hsCode, style: const TextStyle(fontFamily: 'monospace'))),
                  DataCell(Text('${itm.qty}')),
                  DataCell(Text('${itm.unitPriceFc.toStringAsFixed(2)} ${_data!.currency}')),
                  DataCell(Text(itm.fobTotalEgp.toStringAsFixed(2))),
                  DataCell(Text(itm.allocatedCustomsDutyEgp.toStringAsFixed(2))),
                  DataCell(Text(itm.allocatedVatEgp.toStringAsFixed(2))),
                  DataCell(Text(
                      (itm.allocatedFreightEgp + itm.allocatedClearanceAndPortEgp + itm.allocatedInlandTransportEgp)
                          .toStringAsFixed(2))),
                  DataCell(Text(
                    itm.totalLandedCostEgp.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                  )),
                  DataCell(Text(
                    itm.unitLandedCostEgp.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                  )),
                  DataCell(Text(
                    '${itm.unitLandedCostFc.toStringAsFixed(2)} ${_data!.currency}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )),
                  DataCell(Text(
                    '×${itm.markupFactor.toStringAsFixed(3)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                  )),
                  DataCell(Text(
                    '+${itm.markupPercent.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
    );
  }

  Widget _buildExpensesTable(bool isDark, bool isAr) {
    if (_data!.expensesBreakdown.isEmpty) {
      return Center(
        child: Text(isAr ? 'لا توجد مصاريف مفصلة' : 'No detailed expenses'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF1F5F9),
              ),
              columns: [
                DataColumn(label: Text(isAr ? 'فئة المصروف' : 'Expense Category', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'البيان والوصف' : 'Description', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'القيمة بالجنيه (EGP)' : 'Amount (EGP)', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'القيمة بالعملة الأجنبية' : 'Amount (FC)', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'مصدر الاحتساب' : 'Source', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isAr ? 'طريقة التوزيع على البنود' : 'Allocation Rule', style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _data!.expensesBreakdown.map((exp) {
                return DataRow(cells: [
                  DataCell(Text(exp.category, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(exp.description)),
                  DataCell(Text(
                    exp.amountEgp.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                  )),
                  DataCell(Text(
                    '${exp.amountFc.toStringAsFixed(2)} ${exp.currency}',
                  )),
                  DataCell(Text(exp.source)),
                  DataCell(Text(exp.allocationRule)),
                ]);
              }).toList(),
            ),
          ),
        ),
    );
  }

  Widget _buildBottomBar(bool isDark, bool isAr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: _data == null ? null : _exportCsv,
                icon: const Icon(Icons.file_download, size: 18),
                label: Text(isAr ? 'تصدير تقرير Excel/CSV' : 'Export Excel/CSV'),
              ),
              OutlinedButton.icon(
                onPressed: _data == null ? null : _copyTsvToClipboard,
                icon: const Icon(Icons.copy, size: 18),
                label: Text(isAr ? 'نسخ جدول النتائج (TSV)' : 'Copy TSV Table'),
              ),
            ],
          ),
          TextButton(
            onPressed: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
            child: Text(isAr ? 'إغلاق' : 'Close', style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
