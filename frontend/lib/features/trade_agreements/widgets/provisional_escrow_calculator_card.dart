import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../trade_agreements_provider.dart';

class ProvisionalEscrowCalculatorCard extends StatelessWidget {
  final TradeAgreementItem item;
  final VoidCallback onRecordRefund;

  const ProvisionalEscrowCalculatorCard({
    super.key,
    required this.item,
    required this.onRecordRefund,
  });

  @override
  Widget build(BuildContext context) {
    if (!item.provisionalEscrowRequired) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.border),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
              SizedBox(width: 8),
              Text(
                'لم يتم فرض أمانة جمركية مؤقتة على هذه الشهادة (أصل مستوفٍ فورياً)',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    Color bannerColor;
    String bannerTitle;
    final days = item.daysUntilEscrowDeadline;

    if (item.provisionalEscrowRefunded) {
      bannerColor = AppTheme.emerald;
      bannerTitle = 'تم استرداد مبلغ الأمانة المؤقتة بالكامل بعد تقديم الأصل';
    } else if (days == null) {
      bannerColor = AppTheme.orange;
      bannerTitle = 'أمانة جمركية مؤقتة مسددة وبانتظار تقديم الأصل للاسترداد';
    } else if (days < 0) {
      bannerColor = AppTheme.crimson;
      bannerTitle = 'انقضت المهلة القانونية لاسترداد الأمانة (خطر السقوط والتحويل النهائي)';
    } else if (days <= 15) {
      bannerColor = AppTheme.orange;
      bannerTitle = 'تنبيه عاجل: اقتراب انقضاء مهلة استرداد الأمانة الجمركية (متبقي $days يوم)';
    } else {
      bannerColor = AppTheme.cobalt;
      bannerTitle = 'مهلة تقديم الأصل واسترداد الأمانة سارية (متبقي $days يوم)';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: bannerColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.provisionalEscrowRefunded ? Icons.check_circle_outline : Icons.monetization_on_outlined,
                  color: bannerColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bannerTitle,
                    style: TextStyle(
                      color: bannerColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (!item.provisionalEscrowRefunded && item.hasOriginalReceived)
                  AppButton(
                    label: 'إثبات استرداد الأمانة',
                    icon: Icons.payments_outlined,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    onPressed: onRecordRefund,
                  ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTile(
                    'مبلغ الأمانة الجمركية المؤقتة',
                    '${item.provisionalEscrowAmount.toStringAsFixed(2)} جنيه',
                  ),
                ),
                Expanded(
                  child: _buildTile(
                    'رقم قسيمة سداد الأمانة',
                    item.provisionalEscrowReceipt ?? 'غير مسجل',
                  ),
                ),
                Expanded(
                  child: _buildTile(
                    'المهلة القانونية لتقديم الأصل',
                    item.provisionalEscrowDeadline != null
                        ? item.provisionalEscrowDeadline!.toIso8601String().substring(0, 10)
                        : 'غير مسجل',
                  ),
                ),
                Expanded(
                  child: _buildTile(
                    'حالة الاسترداد النقدي',
                    item.provisionalEscrowRefunded
                        ? 'مسترد في ${item.refundDate?.toIso8601String().substring(0, 10) ?? ""}'
                        : 'معلق بالخزينة',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
      ],
    );
  }
}
