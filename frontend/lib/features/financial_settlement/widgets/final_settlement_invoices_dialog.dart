import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/invoices_aggregation_model.dart';
import '../providers/financial_settlement_provider.dart';
import '../../auth/providers/auth_provider.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class FinalSettlementInvoicesDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;

  const FinalSettlementInvoicesDialog({
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
      builder: (ctx) => FinalSettlementInvoicesDialog(
        importFileId: importFileId,
        importFileCode: importFileCode,
      ),
    );
  }

  @override
  ConsumerState<FinalSettlementInvoicesDialog> createState() =>
      _FinalSettlementInvoicesDialogState();
}

class _FinalSettlementInvoicesDialogState
    extends ConsumerState<FinalSettlementInvoicesDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  InvoicesAggregationResponseModel? _aggregationData;

  String _selectedPartyFilter = 'ALL';
  final _settledByController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default to the signed-in user (no hard-coded sample name).
    _settledByController.text = ref.read(authProvider).user?.fullName ?? '';
    _loadData();
  }

  @override
  void dispose() {
    _settledByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ref
          .read(financialSettlementProvider.notifier)
          .fetchInvoicesAggregation(widget.importFileId);
      if (mounted) {
        setState(() {
          _aggregationData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل في جلب وتجميع فواتير الشحنة: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleConfirmSettlement() async {
    if (_aggregationData == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final req = ConfirmInvoicesSettlementRequestModel(
        importFileId: widget.importFileId,
        settledBy: _settledByController.text.trim().isNotEmpty
            ? _settledByController.text.trim()
            : 'Cost Accounting Specialist',
        settlementNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      final res = await ref
          .read(financialSettlementProvider.notifier)
          .confirmInvoicesSettlement(req);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppTheme.emerald,
            behavior: SnackBarBehavior.floating,
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
            content: Text('حدث خطأ أثناء اعتماد تسوية الفواتير: $e'),
            backgroundColor: AppTheme.crimson,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.85).clamp(800.0, 1250.0);
    final dialogHeight = (screenSize.height * 0.88).clamp(600.0, 850.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'جاري المسح والتجميع الآلي لكافة فواتير الشحنة من الـ 8 موديولات...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.charcoal,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 48, color: AppTheme.crimson),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppTheme.crimson, fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadData,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildBody(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(12),
          topEnd: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تجميع وتسوية الفواتير الختامية للملف (CLO-01: Multi-Party Invoices Aggregation)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'المرحلة 9: تكلفة الوصول وإغلاق الملف | الشحنة: ${widget.importFileCode}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_aggregationData != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _aggregationData!.financialSettlementStatus ==
                        'INVOICES_SETTLED'
                    ? AppTheme.emerald
                    : AppTheme.cobalt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _aggregationData!.financialSettlementStatus ==
                        'INVOICES_SETTLED'
                    ? 'الفواتير معتمدة ومسواة'
                    : 'بانتظار الاعتماد المالي',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(false),
            tooltip: 'إغلاق',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final data = _aggregationData!;
    final filteredInvoices = _selectedPartyFilter == 'ALL'
        ? data.invoices
        : data.invoices
            .where((inv) => inv.partyType == _selectedPartyFilter)
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. KPI Metric Strip
          _buildKpiMetricStrip(data),
          const SizedBox(height: 16),

          // 2. Unsettled Warnings (if any)
          if (data.unsettledWarnings.isNotEmpty) ...[
            _buildWarningsCard(data.unsettledWarnings),
            const SizedBox(height: 16),
          ],

          // 3. Parties Filter Chips
          _buildPartiesFilterChips(data),
          const SizedBox(height: 16),

          // 4. Invoices Interactive Table
          _buildInvoicesTable(filteredInvoices),
          const SizedBox(height: 20),

          // 5. Settlement Sign-off Form
          _buildSignOffForm(),
        ],
      ),
    );
  }

  Widget _buildKpiMetricStrip(InvoicesAggregationResponseModel data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _buildKpiCard(
            title: 'إجمالي فواتير ومصروفات الشحنة',
            value: '${_formatCurrency(data.totalAmountEgp)} ج.م',
            subtitle: '${data.totalInvoicesCount} فاتورة مسجلة',
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.charcoal,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            title: 'إجمالي المبالغ المسددة',
            value: '${_formatCurrency(data.totalPaidEgp)} ج.م',
            subtitle: 'سدادات مؤكدة بالسندات',
            icon: Icons.check_circle_outline_rounded,
            color: AppTheme.emerald,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            title: 'المتبقي المطلوب سداده',
            value: '${_formatCurrency(data.totalRemainingEgp)} ج.م',
            subtitle: data.totalRemainingEgp > 0 ? 'مستحقات غير مسددة' : 'لا توجد متأخرات',
            icon: Icons.pending_actions_rounded,
            color: data.totalRemainingEgp > 0 ? AppTheme.crimson : AppTheme.emerald,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            title: 'ضريبة الخصم (أ.ت.ص - WHT)',
            value: '${_formatCurrency(data.totalWithholdingTaxEgp)} ج.م',
            subtitle: 'نموذج 41 (1%)',
            icon: Icons.account_balance_outlined,
            color: AppTheme.orange,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            title: 'نسبة مطابقة السداد',
            value: '${data.settlementReadinessPercent.toStringAsFixed(1)}%',
            subtitle: 'جاهزية التسوية',
            icon: Icons.speed_rounded,
            color: AppTheme.cobalt,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningsCard(List<String> warnings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.orange.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تنبيهات الفواتير والمستحقات المتبقية قبل إغلاق الملف:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.orange,
                  ),
                ),
                const SizedBox(height: 4),
                ...warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppTheme.orange)),
                        Expanded(
                          child: Text(
                            w,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartiesFilterChips(InvoicesAggregationResponseModel data) {
    final partyFilters = [
      {'key': 'ALL', 'label': 'كافة الجهات (${data.invoices.length})'},
      {'key': 'SUPPLIER', 'label': 'المورد الأجنبي'},
      {'key': 'CARRIER', 'label': 'الشحن والتوكيل'},
      {'key': 'INSURANCE', 'label': 'التأمين البحري'},
      {'key': 'CUSTOMS', 'label': 'مصلحة الجمارك'},
      {'key': 'BROKER', 'label': 'المخلص والميناء'},
      {'key': 'TRANSPORT', 'label': 'النقل الداخلي'},
      {'key': 'DEMURRAGE', 'label': 'غرامات التأخير'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: partyFilters.map((filter) {
          final isSelected = _selectedPartyFilter == filter['key'];
          return Padding(
            padding: const EdgeInsetsDirectional.only(start: 8.0),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedPartyFilter = filter['key']!;
                });
              },
              selectedColor: AppTheme.charcoal,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppTheme.charcoal,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppTheme.charcoal : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInvoicesTable(List<AggregatedInvoiceItemModel> invoices) {
    if (invoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            'لا توجد فواتير مسجلة ضمن هذه الجهة',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppTheme.charcoal.withOpacity(0.06)),
            columnSpacing: 16,
            horizontalMargin: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 64,
            columns: const [
            DataColumn(label: Text('رقم الفاتورة / المرجع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('الجهة والدائن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('نوع المصروف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('القيمة الأصلية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('الإجمالي (ج.م)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('المسدد (ج.م)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('المتبقي (ج.م)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('حالة السداد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('المصدر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: invoices.map((inv) {
            final isPaid = inv.paymentStatus == 'PAID' || inv.remainingAmountEgp == 0;
            final isPartial = inv.paymentStatus == 'PARTIAL';

            return DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LtrText(
                        inv.invoiceNo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      if (inv.paymentReference != null)
                        Text(
                          inv.paymentReference!,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        inv.partyName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        inv.partyTypeAr,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    inv.categoryAr,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                DataCell(
                  Text(
                    inv.currency == 'EGP'
                        ? '${_formatCurrency(inv.amountEgP(inv))} ج.م'
                        : '${_formatCurrency(inv.amountFc)} ${inv.currency}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
                DataCell(
                  Text(
                    '${_formatCurrency(inv.amountEgp)} ج.م',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${_formatCurrency(inv.paidAmountEgp)} ج.م',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.emerald,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${_formatCurrency(inv.remainingAmountEgp)} ج.م',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: inv.remainingAmountEgp > 0 ? AppTheme.crimson : Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? AppTheme.emerald.withOpacity(0.12)
                          : isPartial
                              ? AppTheme.orange.withOpacity(0.12)
                              : AppTheme.crimson.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPaid
                          ? 'مسدد بالكامل'
                          : isPartial
                              ? 'سداد جزئي'
                              : 'غير مسدد',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPaid
                            ? AppTheme.emerald
                            : isPartial
                                ? AppTheme.orange
                                : AppTheme.crimson,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    inv.sourceModule,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    ),
  );
  }

  Widget _buildSignOffForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.charcoal),
              SizedBox(width: 8),
              Text(
                'بيانات اعتماد ومطابقة التسوية المالية (Audit Sign-Off):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _settledByController,
                  decoration: const InputDecoration(
                    labelText: 'المحاسب المسؤول / أخصائي التكاليف *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات الاعتماد المالي الختامي',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.edit_note, size: 18),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(12),
          bottomEnd: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('إلغاء'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            key: const Key('confirmInvoicesSettlementBtn'),
            onPressed: (_isLoading || _isSubmitting) ? null : _handleConfirmSettlement,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle, size: 18),
            label: Text(
              _isSubmitting ? 'جاري الاعتماد...' : 'اعتماد تسوية الفواتير وتصعيد الملف (CLO-01)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

extension on AggregatedInvoiceItemModel {
  double amountEgP(AggregatedInvoiceItemModel inv) => inv.amountEgp;
}
