import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';

/// Modal dialog for CL-02: Final Duty & Tax Assessment
/// احتساب الرسوم والضرائب الجمركية النهائية ومطابقة مطالبة نافذة MTS
class FinalDutyAssessmentDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final CustomsClearanceModel? clearanceRecord;

  const FinalDutyAssessmentDialog({
    super.key,
    required this.file,
    this.clearanceRecord,
  });

  static Future<bool?> show(
    BuildContext context,
    ImportFileModel file, {
    CustomsClearanceModel? clearanceRecord,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FinalDutyAssessmentDialog(
        file: file,
        clearanceRecord: clearanceRecord,
      ),
    );
  }

  @override
  ConsumerState<FinalDutyAssessmentDialog> createState() =>
      _FinalDutyAssessmentDialogState();
}

class _FinalDutyAssessmentDialogState
    extends ConsumerState<FinalDutyAssessmentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _claimNumberController;
  late TextEditingController _cifBaseController;
  late TextEditingController _exchangeRateController;
  late TextEditingController _importDutyController;
  late TextEditingController _vatController;
  late TextEditingController _scheduleTaxController;
  late TextEditingController _devFeeController;
  late TextEditingController _serviceFeesController;
  late TextEditingController _whtController;
  late TextEditingController _labFeesController;
  late TextEditingController _varianceReasonController;
  late TextEditingController _assessmentNotesController;

  DateTime _claimDate = DateTime.now();
  bool _isSubmitting = false;

  double get _cifBase => double.tryParse(_cifBaseController.text.trim()) ?? 0.0;
  double get _importDuty =>
      double.tryParse(_importDutyController.text.trim()) ?? 0.0;
  double get _vat => double.tryParse(_vatController.text.trim()) ?? 0.0;
  double get _scheduleTax =>
      double.tryParse(_scheduleTaxController.text.trim()) ?? 0.0;
  double get _devFee => double.tryParse(_devFeeController.text.trim()) ?? 0.0;
  double get _serviceFees =>
      double.tryParse(_serviceFeesController.text.trim()) ?? 0.0;
  double get _wht => double.tryParse(_whtController.text.trim()) ?? 0.0;
  double get _labFees => double.tryParse(_labFeesController.text.trim()) ?? 0.0;

  double get _calculatedTotal =>
      _importDuty +
      _vat +
      _scheduleTax +
      _devFee +
      _serviceFees +
      _wht +
      _labFees;

  double get _estimatedTotal {
    if (widget.clearanceRecord != null &&
        widget.clearanceRecord!.estimatedDutyTotal > 0) {
      return widget.clearanceRecord!.estimatedDutyTotal;
    }
    return 0.0;
  }

  double get _varianceAmount => _estimatedTotal > 0
      ? _calculatedTotal - _estimatedTotal
      : 0.0;

  double get _variancePercentage => _estimatedTotal > 0
      ? (_varianceAmount / _estimatedTotal) * 100
      : 0.0;

  @override
  void initState() {
    super.initState();
    final rec = widget.clearanceRecord;

    _claimNumberController = TextEditingController(
      text: rec?.nafezaClaimNumber ?? '',
    );
    _cifBaseController = TextEditingController(
      text: (rec != null && rec.cifBaseAmount > 0)
          ? rec.cifBaseAmount.toStringAsFixed(2)
          : '',
    );
    _exchangeRateController = TextEditingController(
      text: (rec != null && rec.customsExchangeRate > 0)
          ? rec.customsExchangeRate.toStringAsFixed(2)
          : '48.50',
    );
    _importDutyController = TextEditingController(
      text: (rec != null && rec.importDutyAmount > 0)
          ? rec.importDutyAmount.toStringAsFixed(2)
          : '',
    );
    _vatController = TextEditingController(
      text: (rec != null && rec.vatAmount > 0)
          ? rec.vatAmount.toStringAsFixed(2)
          : '',
    );
    _scheduleTaxController = TextEditingController(
      text: (rec != null && rec.scheduleTaxAmount > 0)
          ? rec.scheduleTaxAmount.toStringAsFixed(2)
          : '0.00',
    );
    _devFeeController = TextEditingController(
      text: (rec != null && rec.developmentFeeAmount > 0)
          ? rec.developmentFeeAmount.toStringAsFixed(2)
          : '0.00',
    );
    _serviceFeesController = TextEditingController(
      text: (rec != null && rec.customsServiceFees > 0)
          ? rec.customsServiceFees.toStringAsFixed(2)
          : '0.00',
    );
    _whtController = TextEditingController(
      text: (rec != null && rec.whtAmount > 0)
          ? rec.whtAmount.toStringAsFixed(2)
          : '0.00',
    );
    _labFeesController = TextEditingController(
      text: (rec != null && rec.labServiceFees > 0)
          ? rec.labServiceFees.toStringAsFixed(2)
          : '0.00',
    );
    _varianceReasonController = TextEditingController(
      text: rec?.dutyVarianceReason ?? '',
    );
    _assessmentNotesController = TextEditingController(
      text: rec?.notes ?? '',
    );

    if (rec?.nafezaClaimDate != null) {
      final parsed = DateTime.tryParse(rec!.nafezaClaimDate!);
      if (parsed != null) _claimDate = parsed;
    }
  }

  @override
  void dispose() {
    _claimNumberController.dispose();
    _cifBaseController.dispose();
    _exchangeRateController.dispose();
    _importDutyController.dispose();
    _vatController.dispose();
    _scheduleTaxController.dispose();
    _devFeeController.dispose();
    _serviceFeesController.dispose();
    _whtController.dispose();
    _labFeesController.dispose();
    _varianceReasonController.dispose();
    _assessmentNotesController.dispose();
    super.dispose();
  }

  Future<void> _submitAssessment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'import_file_id': widget.file.importFileId,
        'nafeza_claim_number': _claimNumberController.text.trim(),
        'nafeza_claim_date': _claimDate.toIso8601String(),
        'cif_base_amount': _cifBase,
        'customs_exchange_rate':
            double.tryParse(_exchangeRateController.text.trim()) ?? 1.0,
        'import_duty_amount': _importDuty,
        'vat_amount': _vat,
        'schedule_tax_amount': _scheduleTax,
        'development_fee_amount': _devFee,
        'customs_service_fees': _serviceFees,
        'wht_amount': _wht,
        'lab_service_fees': _labFees,
        'actual_duty_total': _calculatedTotal,
        'duty_variance_reason': _varianceReasonController.text.trim().isNotEmpty
            ? _varianceReasonController.text.trim()
            : null,
        'assessment_notes': _assessmentNotesController.text.trim().isNotEmpty
            ? _assessmentNotesController.text.trim()
            : null,
      };

      await ref
          .read(customsClearanceProvider.notifier)
          .assessFinalDuties(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم احتساب واعتماد الرسوم الجمركية بمطالبة #${_claimNumberController.text.trim()} بإجمالي (${_calculatedTotal.toStringAsFixed(2)} ج.م). تم الانتقال للمرحلة التالية: سداد الرسوم بسداد (CL-03).',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء اعتماد الرسوم الجمركية: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width > 920
            ? 900
            : MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        child: Column(
          children: [
            // 1. Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadiusDirectional.only(
                  topStart: Radius.circular(16),
                  topEnd: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calculate_rounded,
                      color: AppTheme.cobalt,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'احتساب الرسوم والضرائب الجمركية النهائية (CL-02)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Final Customs Duty & Tax Assessment — مطابقة المطالبة الجمركية بنظام نافذة MTS',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ملف #${file.importFileCode}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. Dialog Body
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Nafeza Claim Info
                      _buildSectionCard(
                        title: 'بيانات المطالبة الجمركية بنظام نافذة MTS',
                        icon: Icons.receipt_long_rounded,
                        color: AppTheme.cobalt,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _claimNumberController,
                                    decoration: const InputDecoration(
                                      labelText: 'رقم المطالبة الجمركية بنظام نافذة *',
                                      hintText: 'مثال: CLM-MTS-2026-998822',
                                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'يرجى إدخال رقم المطالبة الجمركية';
                                      }
                                      if (val.trim().length < 3) {
                                        return 'رقم المطالبة يجب ألا يقل عن 3 أحرف';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _claimDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) {
                                        setState(() => _claimDate = picked);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'تاريخ المطالبة الجمركية *',
                                        prefixIcon: Icon(Icons.calendar_today_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        '${_claimDate.year}-${_claimDate.month.toString().padLeft(2, '0')}-${_claimDate.day.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cifBaseController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'القيمة المقبولة جمركياً (CIF Base بالجنيه) *',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                                      suffixText: 'ج.م',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'القيمة الجمركية CIF مطلوبة';
                                      }
                                      final parsed = double.tryParse(val.trim());
                                      if (parsed == null || parsed <= 0) {
                                        return 'يرجى إدخال قيمة صحيحة أكبر من 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _exchangeRateController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'سعر الصرف الجمركي الرسمي *',
                                      hintText: '48.50',
                                      prefixIcon: Icon(Icons.currency_exchange_rounded),
                                      suffixText: 'EGP/USD',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'سعر الصرف مطلوب';
                                      }
                                      final parsed = double.tryParse(val.trim());
                                      if (parsed == null || parsed <= 0) {
                                        return 'سعر الصرف يجب أن يكون أكبر من 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 2: Customs Duty & Tax Breakdown
                      _buildSectionCard(
                        title: 'تفصيل بنود الرسوم والضرائب الجمركية (HS Code Duty Breakdown)',
                        icon: Icons.pie_chart_outline_rounded,
                        color: AppTheme.flatCobalt,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _importDutyController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'ضريبة الوارد الجمركية (Import Duty) *',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.payments_outlined),
                                      suffixText: 'ج.م',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'ضريبة الوارد مطلوبة';
                                      }
                                      final parsed = double.tryParse(val.trim());
                                      if (parsed == null || parsed < 0) {
                                        return 'قيمة غير صالحة';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _vatController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'ضريبة القيمة المضافة (VAT) *',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.price_change_outlined),
                                      suffixText: 'ج.م',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'ضريبة القيمة المضافة مطلوبة';
                                      }
                                      final parsed = double.tryParse(val.trim());
                                      if (parsed == null || parsed < 0) {
                                        return 'قيمة غير صالحة';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _scheduleTaxController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'ضريبة الجدول (Schedule Tax)',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.table_chart_outlined),
                                      suffixText: 'ج.م',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _devFeeController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'رسم التنمية (Development Fee)',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.trending_up_rounded),
                                      suffixText: 'ج.م',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _serviceFeesController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'رسوم الخدمات الجمركية وأ.ت.ص',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.miscellaneous_services_outlined),
                                      suffixText: 'ج.م',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _whtController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'أرباح تجارية وصناعية (WHT)',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.corporate_fare_outlined),
                                      suffixText: 'ج.م',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _labFeesController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'رسوم التحاليل والمعامل',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.biotech_outlined),
                                      suffixText: 'ج.م',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Variance & Comparison Summary Card
                      _buildVarianceComparisonCard(),
                      const SizedBox(height: 20),

                      // Section 4: Notes
                      _buildSectionCard(
                        title: 'ملاحظات وتوجيهات التثمين والاحتساب النهائي',
                        icon: Icons.note_alt_outlined,
                        color: AppTheme.charcoal,
                        child: TextFormField(
                          controller: _assessmentNotesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'ملاحظات وتوجيهات مأمور التعريفة أو أي بنود استثنائية...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Dialog Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
                borderRadius: const BorderRadiusDirectional.only(
                  bottomStart: Radius.circular(16),
                  bottomEnd: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'الإجمالي المستحق بالسداد: ${_calculatedTotal.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitAssessment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      _isSubmitting
                          ? 'جاري الاعتماد...'
                          : 'اعتماد واحتساب الرسوم (CL-02)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildVarianceComparisonCard() {
    final est = _estimatedTotal;
    final act = _calculatedTotal;
    final diff = _varianceAmount;
    final pct = _variancePercentage;

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (est == 0) {
      badgeColor = AppTheme.cobalt;
      badgeText = 'تثمين أولي (بدون تقدير سابق)';
      badgeIcon = Icons.info_outline;
    } else if (diff <= 0) {
      badgeColor = AppTheme.emerald;
      badgeText = 'وفر بالرسوم (-${(-pct).toStringAsFixed(1)}%)';
      badgeIcon = Icons.arrow_downward_rounded;
    } else if (pct <= 10) {
      badgeColor = AppTheme.orange;
      badgeText = 'انحراف طفيف (+${pct.toStringAsFixed(1)}%)';
      badgeIcon = Icons.arrow_upward_rounded;
    } else {
      badgeColor = AppTheme.crimson;
      badgeText = 'انحراف ملحوظ (+${pct.toStringAsFixed(1)}%)';
      badgeIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(badgeIcon, color: badgeColor, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'مطابقة الرسوم الفعلية مع التقديرية (Variance Analysis)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'الرسوم التقديرية المبدئية',
                  est > 0 ? '${est.toStringAsFixed(2)} ج.م' : 'غير محددة',
                  Icons.receipt_outlined,
                  Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  'إجمالي المطالبة الفعلية',
                  '${act.toStringAsFixed(2)} ج.م',
                  Icons.account_balance_outlined,
                  AppTheme.cobalt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  'قيمة الانحراف الجمركي',
                  est > 0
                      ? '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)} ج.م'
                      : '---',
                  Icons.compare_arrows_rounded,
                  badgeColor,
                ),
              ),
            ],
          ),
          if (est > 0 && pct.abs() > 5) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _varianceReasonController,
              decoration: const InputDecoration(
                labelText: 'سبب انحراف الرسوم الفعلية عن التقديرية',
                hintText: 'مثال: تعديل مأمور التعريفة لبند HS Code أو زيادة تقييم CIF',
                prefixIcon: Icon(Icons.help_outline_rounded),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
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
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
