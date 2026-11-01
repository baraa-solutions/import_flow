import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../services/customs_pdf_service.dart';
import 'duty_calculator_state.dart';

/// Primary action bar for calculating duties and error message handling.
class DutyCalcPrimaryActionBar extends StatelessWidget {
  final DutyCalculatorState state;
  final bool isArabic;
  final WidgetRef ref;

  const DutyCalcPrimaryActionBar({
    super.key,
    required this.state,
    required this.isArabic,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: isArabic
                ? 'حساب إجمالي الجمارك والإقرار الرسمي'
                : 'Calculate Nafeza Duties & Official Statement',
            icon: Icons.bolt,
            variant: AppButtonVariant.success,
            size: AppButtonSize.large,
            isLoading: state.isMultiCalculating,
            onPressed: state.isMultiCalculating
                ? null
                : () => state.calculateDuties(ref, isArabic: isArabic),
          ),
        ),
        if (state.multiError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.crimsonLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.crimsonBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.crimson, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.multiError!,
                      style: const TextStyle(
                        color: AppTheme.crimson,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Export and sharing actions (Print Statement, Download PDF, Copy TSV for Excel).
class DutyCalcExportActionBar extends StatelessWidget {
  final DutyCalculatorState state;
  final bool isArabic;

  const DutyCalcExportActionBar({
    super.key,
    required this.state,
    required this.isArabic,
  });

  double _getCalculatedRate() {
    return double.tryParse(state.exchangeRateCtrl.text.trim()) ??
        numToDouble(state.multiResult?['exchange_rate'], 1.0);
  }

  double _getInsEgp() {
    return (state.insuranceType == 'deemed')
        ? (double.tryParse(state.deemedInsuranceCtrl.text.trim()) ?? 0)
        : (double.tryParse(state.insuranceCtrl.text.trim()) ?? 0);
  }

  double _getFrtEgp() {
    return (state.freightType == 'deemed')
        ? (double.tryParse(state.deemedFreightCtrl.text.trim()) ?? 0)
        : (double.tryParse(state.multiFreightCtrl.text.trim()) ?? 0);
  }

  double _getAddEgp() {
    return double.tryParse(state.additionalFeesCtrl.text.trim()) ?? 0;
  }

  double _getCifEgp(double fobEgp, double insEgp, double frtEgp) {
    return double.tryParse(state.declaredCifCtrl.text.trim()) ??
        (fobEgp + insEgp + frtEgp);
  }

  @override
  Widget build(BuildContext context) {
    if (state.multiResult == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: isArabic ? 'طباعة التقرير 🖨️' : 'Print Statement 🖨️',
            icon: Icons.print,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
            onPressed: () async {
              final rate = _getCalculatedRate();
              final totalFc = state.computeTotalInvoiceFc();
              final fobEgp = totalFc * rate;
              final insEgp = _getInsEgp();
              final frtEgp = _getFrtEgp();
              final addEgp = _getAddEgp();
              final cifEgp = _getCifEgp(fobEgp, insEgp, frtEgp);

              await CustomsPdfService.printStatement(
                currency: state.selectedCurrency,
                exchangeRate: rate,
                totalFobFc: totalFc,
                totalFobEgp: fobEgp,
                insuranceEgp: insEgp,
                freightEgp: frtEgp,
                additionalFeesEgp: addEgp,
                totalCifEgp: cifEgp,
                insuranceMode: state.insuranceType == 'deemed'
                    ? (isArabic ? 'حكمي 2.5%' : 'Deemed 2.5%')
                    : (isArabic ? 'فعلي' : 'Actual'),
                freightMode: state.freightType == 'deemed'
                    ? (isArabic ? 'حكمي 2.0%' : 'Deemed 2.0%')
                    : (isArabic ? 'فعلي' : 'Actual'),
                result: state.multiResult!,
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppButton(
            label: isArabic ? 'تنزيل PDF 📄' : 'Download PDF 📄',
            icon: Icons.picture_as_pdf,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.medium,
            onPressed: () async {
              final rate = _getCalculatedRate();
              final totalFc = state.computeTotalInvoiceFc();
              final fobEgp = totalFc * rate;
              final insEgp = _getInsEgp();
              final frtEgp = _getFrtEgp();
              final addEgp = _getAddEgp();
              final cifEgp = _getCifEgp(fobEgp, insEgp, frtEgp);

              final savedPath = await CustomsPdfService.downloadPdf(
                currency: state.selectedCurrency,
                exchangeRate: rate,
                totalFobFc: totalFc,
                totalFobEgp: fobEgp,
                insuranceEgp: insEgp,
                freightEgp: frtEgp,
                additionalFeesEgp: addEgp,
                totalCifEgp: cifEgp,
                insuranceMode: state.insuranceType == 'deemed'
                    ? (isArabic ? 'حكمي 2.5%' : 'Deemed 2.5%')
                    : (isArabic ? 'فعلي' : 'Actual'),
                freightMode: state.freightType == 'deemed'
                    ? (isArabic ? 'حكمي 2.0%' : 'Deemed 2.0%')
                    : (isArabic ? 'فعلي' : 'Actual'),
                result: state.multiResult!,
              );

              if (savedPath != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  AppTheme.snackBar(
                    context,
                    isArabic
                        ? 'تم حفظ البيان بصيغة PDF بنجاح:\n$savedPath'
                        : 'Statement saved as PDF successfully:\n$savedPath',
                    severity: AppSeverity.success,
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppButton(
            label: isArabic
                ? 'نسخ البيان (Excel)'
                : 'Copy Statement (Excel)',
            icon: Icons.copy_rounded,
            variant: AppButtonVariant.success,
            size: AppButtonSize.medium,
            onPressed: () {
              final rate = _getCalculatedRate();
              final totalFc = state.computeTotalInvoiceFc();
              final fobEgp = totalFc * rate;
              final insEgp = _getInsEgp();
              final frtEgp = _getFrtEgp();
              final addEgp = _getAddEgp();
              final cifEgp = _getCifEgp(fobEgp, insEgp, frtEgp);

              copyDutyCalculatorStatement(
                context,
                multiLines: state.multiLines,
                result: state.multiResult!,
                currency: state.selectedCurrency,
                exchangeRate: rate,
                fobEgp: fobEgp,
                insEgp: insEgp,
                frtEgp: frtEgp,
                additionalFeesEgp: addEgp,
                cifEgp: cifEgp,
                isArabic: isArabic,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Formats and copies the complete customs declaration to clipboard in Excel-compatible TSV.
void copyDutyCalculatorStatement(
  BuildContext context, {
  required List<Map<String, dynamic>> multiLines,
  required Map<String, dynamic> result,
  required String currency,
  required double exchangeRate,
  required double fobEgp,
  required double insEgp,
  required double frtEgp,
  required double additionalFeesEgp,
  required double cifEgp,
  required bool isArabic,
}) {
  final buffer = StringBuffer();
  if (isArabic) {
    buffer.writeln('بيان احتساب الرسوم والضرائب الجمركية — منصة نافذة');
    buffer.writeln('العملة:\t$currency\tسعر الصرف:\t$exchangeRate');
    buffer.writeln('إجمالي فوب (ج.م):\t${fobEgp.toStringAsFixed(2)}');
    buffer.writeln('التأمين (ج.م):\t${insEgp.toStringAsFixed(2)}');
    buffer.writeln('النولون (ج.م):\t${frtEgp.toStringAsFixed(2)}');
    if (additionalFeesEgp > 0) {
      buffer.writeln('رسوم إضافية (ج.م):\t${additionalFeesEgp.toStringAsFixed(2)}');
    }
    buffer.writeln('القيمة الجمركية سيف (ج.م):\t${cifEgp.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('السطر\tبند التعريفة\tالقيمة سيف (ج.م)\tضريبة الوارد (ج.م)\tضريبة القيمة المضافة (ج.م)\tإجمالي البند (ج.م)');
  } else {
    buffer.writeln('Egyptian Customs Duty & Tax Statement — Nafeza Platform');
    buffer.writeln('Currency:\t$currency\tExchange Rate:\t$exchangeRate');
    buffer.writeln('Total FOB (EGP):\t${fobEgp.toStringAsFixed(2)}');
    buffer.writeln('Insurance (EGP):\t${insEgp.toStringAsFixed(2)}');
    buffer.writeln('Freight (EGP):\t${frtEgp.toStringAsFixed(2)}');
    if (additionalFeesEgp > 0) {
      buffer.writeln('Additional Fees (EGP):\t${additionalFeesEgp.toStringAsFixed(2)}');
    }
    buffer.writeln('Customs Value CIF (EGP):\t${cifEgp.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('Line\tHS Code\tCIF Value (EGP)\tImport Duty (EGP)\tVAT (EGP)\tLine Total (EGP)');
  }

  final items = (result['lines'] as List<dynamic>?) ??
      (result['items'] as List<dynamic>?) ??
      [];
  for (int i = 0; i < items.length; i++) {
    final item = items[i] as Map<String, dynamic>;
    final lineNum = item['line_no'] ?? (i + 1);
    final hs = item['hs_code'] ?? '';
    final itemCif = numToDouble(item['cif_value_egp'] ?? item['cif_egp'])
        .toStringAsFixed(2);
    final duty = numToDouble(item['duty_egp'] ?? item['customs_duty_egp'])
        .toStringAsFixed(2);
    final vat = numToDouble(item['vat_egp']).toStringAsFixed(2);
    final total = numToDouble(item['total_line_duties_egp'] ??
            item['total_item_taxes_egp'] ??
            item['total_duties_and_taxes_egp'])
        .toStringAsFixed(2);
    buffer.writeln('$lineNum\t$hs\t$itemCif\t$duty\t$vat\t$total');
  }

  final feeBreakdown = result['fee_codes_breakdown'] as Map<String, dynamic>?;
  if (feeBreakdown != null) {
    buffer.writeln('');
    buffer.writeln(isArabic ? 'تفاصيل بنود التحصيل:' : 'Fee Codes Breakdown:');
    final fees = feeBreakdown['fees'] as List<dynamic>?;
    if (fees != null) {
      for (final f in fees) {
        final fee = f as Map<String, dynamic>;
        final code = fee['code'] ?? '';
        final name = fee['name'] ?? '';
        final amt = numToDouble(fee['amount_egp']).toStringAsFixed(2);
        buffer.writeln('$code\t$name\t$amt');
      }
    }
    final grandTotal =
        numToDouble(feeBreakdown['grand_total']).toStringAsFixed(2);
    buffer.writeln('${isArabic ? "الإجمالي الكلي" : "Grand Total"}\t\t$grandTotal');
  } else if (result['total_duties_and_taxes_egp'] != null) {
    buffer.writeln('');
    final grandTotal =
        numToDouble(result['total_duties_and_taxes_egp']).toStringAsFixed(2);
    buffer.writeln(
        '${isArabic ? "الإجمالي الكلي للرسوم والضرائب (ج.م)" : "Grand Total Duties & Taxes (EGP)"}\t\t$grandTotal');
  }

  CopyHelper.copy(
    context,
    buffer.toString(),
    customMessage: isArabic
        ? 'تم نسخ بيان الرسوم الجمركية بنجاح بصيغة جدول Excel'
        : 'Customs duty statement copied successfully as Excel TSV',
  );
}
