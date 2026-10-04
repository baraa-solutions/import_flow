import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../models/actual_landed_cost_model.dart';
import '../providers/financial_settlement_provider.dart';
import '../../auth/providers/auth_provider.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class ActualLandedCostDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;

  const ActualLandedCostDialog({
    super.key,
    required this.importFileId,
    required this.importFileCode,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int importFileId,
    required String importFileCode,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ActualLandedCostDialog(
        importFileId: importFileId,
        importFileCode: importFileCode,
      ),
    );
  }

  @override
  ConsumerState<ActualLandedCostDialog> createState() => _ActualLandedCostDialogState();
}

class _ActualLandedCostDialogState extends ConsumerState<ActualLandedCostDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  ActualLandedCostCalculationResponseModel? _calcData;

  String _selectedAllocationPreference = 'Value-Based';
  late TabController _tabController;

  final _approvedByController = TextEditingController();
  String _defaultApprovedBy = '';
  final _notesController = TextEditingController();

  final List<Map<String, String>> _allocationOptions = [
    {'value': 'Value-Based', 'label': 'حسب القيمة (Value-Based - FOB)'},
    {'value': 'Weight-Based', 'label': 'حسب الوزن الإجمالي (Gross Weight)'},
    {'value': 'Volume-Based', 'label': 'حسب الحجم بالمتر المكعب (CBM)'},
    {'value': 'Equal', 'label': 'بالتساوي بين بنود الأصناف (Equal)'},
  ];

  @override
  void initState() {
    super.initState();
    // Default to the signed-in user (no hard-coded sample name).
    _defaultApprovedBy = ref.read(authProvider).user?.fullName ?? '';
    _approvedByController.text = _defaultApprovedBy;
    _tabController = TabController(length: 2, vsync: this);
    _loadCalculation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _approvedByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCalculation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ref
          .read(financialSettlementProvider.notifier)
          .calculateActualLandedCost(
            widget.importFileId,
            allocationPreference: _selectedAllocationPreference,
          );
      if (mounted) {
        setState(() {
          _calcData = data;
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

  Future<void> _handleApprove() async {
    if (_approvedByController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد اسم المسؤول المالي المعتمد للتكلفة الفعلية'),
          backgroundColor: AppTheme.flatCrimson,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final res = await ref
          .read(financialSettlementProvider.notifier)
          .approveActualLandedCost(
            importFileId: widget.importFileId,
            approvedBy: _approvedByController.text.trim(),
            allocationPreference: _selectedAllocationPreference,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppTheme.flatEmerald,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في اعتماد تكلفة الوصول الفعلية: $e'),
            backgroundColor: AppTheme.flatCrimson,
          ),
        );
      }
    }
  }

  bool get _isDirty {
    if (_notesController.text.trim().isNotEmpty) return true;
    if (_selectedAllocationPreference != 'Value-Based') return true;
    if (_approvedByController.text.trim() != _defaultApprovedBy) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1200,
          maxHeight: 880,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 3),
                          SizedBox(height: 16),
                          Text(
                            'جاري احتساب تكلفة الوصول الفعلية ومطابقة الانحرافات...',
                            style: TextStyle(color: AppTheme.flatCharcoal),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _buildContent(),
            ),
            if (!_isLoading && _errorMessage == null) _buildFooter(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.flatCobalt.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calculate_outlined,
              color: AppTheme.flatCobalt,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'محرك احتساب تكلفة الوصول الفعلية والانحراف (CLO-02)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.flatCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ملف استيرادي: ${widget.importFileCode} | تسوية فواتير الموردين والجمارك والنولون ومقارنة محاكاة PL-08',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.flatCharcoal.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('actualLandedCostCloseBtn'),
            icon: const Icon(Icons.close, color: AppTheme.flatCharcoal),
            tooltip: 'إغلاق',
            onPressed: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppTheme.flatCrimson),
            const SizedBox(height: 16),
            const Text(
              'تعذر احتساب تكلفة الوصول الفعلية للشحنة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadCalculation,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.flatCobalt,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final calc = _calcData!;
    return Column(
      children: [
        _buildKpiStrip(calc),
        _buildAllocationControlBar(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCategoriesVarianceTab(calc),
              _buildItemsLandedCostTab(calc),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiStrip(ActualLandedCostCalculationResponseModel calc) {
    Color varianceColor = AppTheme.flatEmerald;
    if (calc.varianceStatus == 'UNFAVORABLE') {
      varianceColor = AppTheme.flatCrimson;
    } else if (calc.varianceStatus == 'MATCHED') {
      varianceColor = AppTheme.flatCobalt;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          _buildKpiCard(
            label: 'إجمالي البضاعة FOB',
            value: '${_formatCurrency(calc.totalFobEgp)} ج.م',
            subtext: '${calc.currency} (سعر الصرف ${calc.fxRate.toStringAsFixed(2)})',
            icon: Icons.inventory_2_outlined,
            iconColor: AppTheme.flatCobalt,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            label: 'المصاريف الفعلية المسددة',
            value: '${_formatCurrency(calc.totalActualExpensesEgp)} ج.م',
            subtext: 'نولون، جمارك، تخليص، ونقل',
            icon: Icons.receipt_long_outlined,
            iconColor: AppTheme.flatOrange,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            label: 'تكلفة الوصول الشاملة الفعلية',
            value: '${_formatCurrency(calc.actualTotalLandedCostEgp)} ج.م',
            subtext: 'التقديري: ${_formatCurrency(calc.estimatedTotalLandedCostEgp)} ج.م',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppTheme.flatCharcoal,
            isPrimary: true,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            label: 'معامل التضخيم الفعلي',
            value: '${calc.actualMarkupFactor.toStringAsFixed(3)}x',
            subtext: 'نسبة التكلفة الكلية إلى FOB',
            icon: Icons.trending_up,
            iconColor: AppTheme.flatCobalt,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            label: 'الانحراف المالي الشامل',
            value: '${calc.landedVariancePct >= 0 ? '+' : ''}${calc.landedVariancePct.toStringAsFixed(1)}%',
            subtext: '${_formatCurrency(calc.landedVarianceEgp)} ج.م (${calc.varianceStatusAr})',
            icon: calc.varianceStatus == 'FAVORABLE'
                ? Icons.arrow_downward
                : calc.varianceStatus == 'UNFAVORABLE'
                    ? Icons.arrow_upward
                    : Icons.check,
            iconColor: varianceColor,
            valueColor: varianceColor,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    Color? valueColor,
    bool isPrimary = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.flatCobalt.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary ? AppTheme.flatCobalt.withOpacity(0.3) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.flatCharcoal.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? (isPrimary ? AppTheme.flatCobalt : AppTheme.flatCharcoal),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtext,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 18, color: AppTheme.flatCharcoal),
              const SizedBox(width: 8),
              const Text(
                'قاعدة توزيع المصاريف المشتركة:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.flatCharcoal,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const Key('actualLandedCostAllocationDropdown'),
                    value: _selectedAllocationPreference,
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.flatCobalt),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.flatCharcoal,
                    ),
                    items: _allocationOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt['value'],
                        child: Text(opt['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedAllocationPreference) {
                        setState(() {
                          _selectedAllocationPreference = val;
                        });
                        _loadCalculation();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          Text(
            'عدد بنود الأصناف: ${_calcData?.itemsBreakdown.length ?? 0} | بنود المصروفات: ${_calcData?.categoriesBreakdown.length ?? 0}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.flatCobalt,
        unselectedLabelColor: AppTheme.flatCharcoal.withOpacity(0.7),
        indicatorColor: AppTheme.flatCobalt,
        indicatorWeight: 3,
        tabs: [
          Tab(
            key: const Key('actualLandedCostExpensesTab'),
            icon: const Icon(Icons.pie_chart_outline, size: 18),
            text: 'مقارنة بنود المصروفات والانحرافات (${_calcData?.categoriesBreakdown.length ?? 0})',
          ),
          Tab(
            key: const Key('actualLandedCostItemsTab'),
            icon: const Icon(Icons.view_list_outlined, size: 18),
            text: 'تكلفة وصول الأصناف للوحدة (${_calcData?.itemsBreakdown.length ?? 0})',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesVarianceTab(ActualLandedCostCalculationResponseModel calc) {
    if (calc.categoriesBreakdown.isEmpty) {
      return const Center(
        child: Text('لا توجد بنود مصروفات مسجلة للشحنة'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columnSpacing: 18,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 64,
              columns: const [
              DataColumn(label: Text('بند المصروف', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('التقديري (PL-08)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الفعلي (CLO-01)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الانحراف (ج.م)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('النسبة (%)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الفواتير', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('المصدر والملاحظات', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: calc.categoriesBreakdown.map((cat) {
              Color statusColor = AppTheme.flatEmerald;
              String statusText = 'توفير';
              if (cat.varianceStatus == 'UNFAVORABLE') {
                statusColor = AppTheme.flatCrimson;
                statusText = 'زيادة';
              } else if (cat.varianceStatus == 'MATCHED') {
                statusColor = AppTheme.flatCobalt;
                statusText = 'مطابق';
              }

              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cat.categoryAr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(cat.category, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  DataCell(Text('${_formatCurrency(cat.estimatedAmountEgp)} ج.م', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${_formatCurrency(cat.actualAmountEgp)} ج.م', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(
                    Text(
                      '${cat.varianceEgp >= 0 ? '+' : ''}${_formatCurrency(cat.varianceEgp)} ج.م',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${cat.variancePct >= 0 ? '+' : ''}${cat.variancePct.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ),
                  DataCell(Text('${cat.invoicesCount}', style: const TextStyle(fontSize: 12))),
                  DataCell(
                    SizedBox(
                      width: 220,
                      child: Text(
                        cat.sourceNote,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildItemsLandedCostTab(ActualLandedCostCalculationResponseModel calc) {
    if (calc.itemsBreakdown.isEmpty) {
      return const Center(
        child: Text('لا توجد بنود أصناف مسجلة في أوامر شراء هذه الشحنة'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('كود الصنف', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('اسم الصنف', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('بند التعريفة HS', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('سعر FOB', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('إجمالي FOB (ج.م)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('المصاريف الموزعة', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('إجمالي تكلفة الصنف', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('تكلفة الوحدة الفعلية', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('تكلفة الوحدة التقديرية', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('انحراف الوحدة', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('معامل الزيادة', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: calc.itemsBreakdown.map((item) {
                Color varColor = AppTheme.flatEmerald;
                if (item.varianceStatus == 'UNFAVORABLE') {
                  varColor = AppTheme.flatCrimson;
                } else if (item.varianceStatus == 'MATCHED') {
                  varColor = AppTheme.flatCobalt;
                }

                final totalExpensesAllocated = item.totalActualLandedCostEgp - item.fobTotalEgp;

                return DataRow(
                  cells: [
                    DataCell(Text(item.itemCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Text(
                          item.itemNameAr,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(LtrText(item.hsCode, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                    DataCell(Text('${item.quantity.toStringAsFixed(0)} ${item.unitOfMeasure}', style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${item.fobUnitPriceFc.toStringAsFixed(2)} ${item.currency}', style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${_formatCurrency(item.fobTotalEgp)} ج.م', style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${_formatCurrency(totalExpensesAllocated)} ج.م', style: const TextStyle(fontSize: 12, color: AppTheme.flatOrange))),
                    DataCell(Text('${_formatCurrency(item.totalActualLandedCostEgp)} ج.م', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataCell(
                      Text(
                        '${_formatCurrency(item.actualUnitLandedCostEgp)} ج.م',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.flatCobalt),
                      ),
                    ),
                    DataCell(Text('${_formatCurrency(item.estimatedUnitLandedCostEgp)} ج.م', style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Text(
                        '${item.unitCostVariancePct >= 0 ? '+' : ''}${item.unitCostVariancePct.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: varColor),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.flatCobalt.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.markupFactor.toStringAsFixed(3)}x',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.flatCobalt),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  key: const Key('actualLandedCostApprovedByField'),
                  controller: _approvedByController,
                  decoration: const InputDecoration(
                    labelText: 'المسؤول المالي المعتمد',
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: TextField(
                  key: const Key('actualLandedCostNotesField'),
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات الاعتماد المالي الختامي (اختياري)',
                    prefixIcon: Icon(Icons.notes, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                key: const Key('actualLandedCostCancelBtn'),
                onPressed: _isSubmitting
                    ? null
                    : () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('إلغاء'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.flatCharcoal,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                key: const Key('actualLandedCostApproveBtn'),
                onPressed: _isSubmitting ? null : _handleApprove,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified, size: 18),
                label: Text(
                  _isSubmitting
                      ? 'جاري الاعتماد وحفظ التكاليف...'
                      : 'اعتماد تكلفة الوصول الفعلية للشحنة (CLO-02)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double val) {
    return val.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
