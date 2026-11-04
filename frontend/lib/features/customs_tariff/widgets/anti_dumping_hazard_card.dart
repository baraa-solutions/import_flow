import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/customs_tariff_model.dart';

class AntiDumpingHazardCard extends StatelessWidget {
  final CustomsTariffModel tariff;

  const AntiDumpingHazardCard({
    super.key,
    required this.tariff,
  });

  @override
  Widget build(BuildContext context) {
    if (!tariff.hasAntiDumpingRisk && (tariff.antiDumpingNotes == null || tariff.antiDumpingNotes!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final isDark = AppTheme.isDark(context);
    const crimson = AppTheme.flatCrimson;

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: crimson.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: crimson.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: crimson,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'إنذار جمركي حرج — خاضع لرسوم الإغراق والتدابير الوقائية'
                        : 'Critical Customs Hazard — Anti-Dumping & Safeguards',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: crimson,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: crimson,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isArabic ? 'حرج للغاية' : 'CRITICAL',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isArabic
                  ? 'هذا البند الجمركي يخضع لقرارات وزارية وإجراءات وقائية مشددة لمكافحة الإغراق. عدم التحضير المسبق في أوراق الشحنة قبل إصدار الرقم التعريفي يمثل خطورة قصوى قد تؤدي إلى مضاعفة التكاليف أو احتجاز البضاعة.'
                  : 'This tariff item is subject to anti-dumping and safeguard measures. Failure to prepare pre-shipment documentation prior to ACID issuance carries extreme financial and clearance risks.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: crimson.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic
                        ? 'الاشتراطات والتوجيهات الإلزامية قبل الشحن:'
                        : 'Mandatory Pre-Shipment Instructions:',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: crimson,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildInstructionItem(
                    isArabic
                        ? 'إيداع حصيلة رسم الإغراق بحساب وزارة الاستثمار والتجارة الخارجية بالبنك المركزي (بند نافذة غ6555).'
                        : 'Anti-dumping proceeds must be deposited into the Ministry of Investment & Foreign Trade account (Nafeza rule G6555).',
                    isDark,
                  ),
                  _buildInstructionItem(
                    isArabic
                        ? 'إلزام المورد بإرفاق شهادة منشأ أصلية مصدقة وفاتورة تفصيلية معتمدة من المصنع المنتج لتحديد فئة الإغراق الخاصة بالمصنع.'
                        : 'Supplier must provide certified original Certificate of Origin and detailed factory invoice to verify factory-specific margin.',
                    isDark,
                  ),
                  _buildInstructionItem(
                    isArabic
                        ? 'استيفاء شرط الشحن المباشر من بلد المنشأ أو المراكز الرئيسية للمصنع دون تفريغ وسيط لتفادي رفض المنشأ (ق4122).'
                        : 'Comply with direct shipment rule from country of origin or manufacturer hubs without transshipment (Rule Q4122).',
                    isDark,
                  ),
                  _buildInstructionItem(
                    isArabic
                        ? 'احتساب ضريبة القيمة المضافة على الوعاء الإجمالي متضمناً رسم الإغراق وضريبة الوارد، وتجهيز السيولة الإضافية.'
                        : 'VAT is assessed on total base including anti-dumping duty and import duty; prepare adequate liquid funds.',
                    isDark,
                  ),
                ],
              ),
            ),
            if (tariff.antiDumpingNotes != null && tariff.antiDumpingNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tariff.antiDumpingNotes!.trim(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    color: crimson,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: isDark ? AppTheme.darkTextSecondary : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
