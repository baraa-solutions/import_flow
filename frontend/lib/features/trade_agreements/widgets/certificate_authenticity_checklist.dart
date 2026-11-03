import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../trade_agreements_provider.dart';

class CertificateAuthenticityChecklist extends StatelessWidget {
  final TradeAgreementItem item;
  final VoidCallback onVerifyOriginal;

  const CertificateAuthenticityChecklist({
    super.key,
    required this.item,
    required this.onVerifyOriginal,
  });

  String _formatAgreement(String name) {
    switch (name) {
      case 'EUR1':
        return 'اتفاقية الشراكة المصرية الأوروبية';
      case 'GAFTA':
        return 'منطقة التجارة الحرة العربية الكبرى';
      case 'AGADIR':
        return 'اتفاقية أغادير العربية المتوسطية';
      case 'COMESA':
        return 'السوق المشتركة لشرق وجنوب إفريقيا';
      case 'EFTA':
        return 'اتفاقية التجارة الحرة مع دول إفتا';
      case 'TURKEY':
        return 'اتفاقية التجارة الحرة المصرية التركية';
      case 'MERCOSUR':
        return 'اتفاقية التجارة الحرة مع الميركوسور';
      default:
        return 'اتفاقية تفضيلية أخرى';
    }
  }

  String _formatCriterion(String? criterion) {
    switch (criterion) {
      case 'WHOLLY_OBTAINED':
        return 'منتجات تم الحصول عليها بالكامل';
      case 'VALUE_ADDED':
        return 'نسبة قيمة مضافة محلية مطابقة';
      case 'SUFFICIENT_PROCESSING':
        return 'عمليات تصنيع وتشغيل كافية ومحددة';
      default:
        return 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'التحقق من صحة واشتراطات شهادة المنشأ: ${item.certificateNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
                  ),
                ),
                AppStatusBadge.fromStatus(
                  status: item.submissionStatus,
                  label: item.hasOriginalReceived ? 'أصل مستلم' : 'صورة معلقة',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatAgreement(item.agreementName),
              style: const TextStyle(fontSize: 13, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            _buildCheckItem(
              title: 'تقديم أصل الشهادة الجمركية',
              subtitle: item.hasOriginalReceived
                  ? 'تم استلام وفحص أصل الشهادة وتوثيقه'
                  : 'مقدم صورة ضوئية فقط لحين إحضار الأصل',
              isChecked: item.hasOriginalReceived,
              trailing: !item.hasOriginalReceived
                  ? AppButton(
                      label: 'إثبات استلام الأصل',
                      icon: Icons.check,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: onVerifyOriginal,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            _buildCheckItem(
              title: 'استيفاء شرط الشحن المباشر',
              subtitle: item.directTransportCompliant
                  ? 'تم الشحن مباشرة من بلد المنشأ دون عبور وسيط مخل'
                  : 'مخالف لشرط الشحن المباشر أو يستلزم إثبات عدم التلاعب',
              isChecked: item.directTransportCompliant,
            ),
            const SizedBox(height: 8),
            _buildCheckItem(
              title: 'معيار قواعد المنشأ التفضيلية',
              subtitle: _formatCriterion(item.rulesOfOriginCriterion),
              isChecked: item.rulesOfOriginCriterion != null,
            ),
            const SizedBox(height: 8),
            _buildCheckItem(
              title: 'سريان الصلاحية الزمنية للشهادة',
              subtitle: item.expiryDate != null
                  ? 'تاريخ الانتهاء المحدد: ${item.expiryDate!.toIso8601String().substring(0, 10)} (متبقي ${item.daysUntilExpiry ?? 0} يوم)'
                  : 'صلاحية الشهادة غير محددة',
              isChecked: !item.isCertExpired,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem({
    required String title,
    required String subtitle,
    required bool isChecked,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isChecked ? AppTheme.emerald.withValues(alpha: 0.05) : AppTheme.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChecked ? AppTheme.emerald.withValues(alpha: 0.3) : AppTheme.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_circle : Icons.warning_amber_rounded,
            color: isChecked ? AppTheme.emerald : AppTheme.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
