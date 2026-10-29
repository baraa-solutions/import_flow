import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class StreamlitWorkflowPipelineCard extends StatelessWidget {
  const StreamlitWorkflowPipelineCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 6-Phase Lifecycle Architecture Overview
        const Text(
          'هيكل المستويات الـ 6 الكبرى المدمجة في لوحة Streamlit:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
        ),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPhaseColumnCard(
              titleEn: '1. Pre-Planning',
              titleAr: 'التخطيط والدراسات',
              color: Colors.amber.shade800,
              steps: [
                'Freight Studies (دراسات النولون)',
                'Customs Studies (الدراسات الجمركية)',
                'Regulatory Reqs (اشتراطات الاستيراد)',
              ],
            ),
            const SizedBox(width: 10),
            _buildPhaseColumnCard(
              titleEn: '2. Initiation',
              titleAr: 'بداية الشحنة',
              color: AppTheme.cobalt,
              steps: [
                'Finance Approvals (اعتماد الميزانية)',
                'ACID Operations (إصدار ACID)',
              ],
            ),
            const SizedBox(width: 10),
            _buildPhaseColumnCard(
              titleEn: '3. Booking & Docs',
              titleAr: 'حجز وتدقيق الشحن',
              color: const Color(0xFF16A085),
              steps: [
                'Freight Booking (تأكيد الحجز)',
                'Freight Allocations (تخصيص الحاويات)',
                'Draft Docs Review (مراجعة المسودات)',
                'Customs Approval (الاعتماد النهائي)',
              ],
            ),
            const SizedBox(width: 10),
            _buildPhaseColumnCard(
              titleEn: '4. Digital & Bank',
              titleAr: 'التوثيق والبنك',
              color: AppTheme.crimson,
              steps: [
                'CargoX Upload (رفع المستندات)',
                'Originals Collection (أصول المستندات)',
                'Bank Form 4 (نموذج 4 البنكي)',
              ],
            ),
            const SizedBox(width: 10),
            _buildPhaseColumnCard(
              titleEn: '5. Port & Clearance',
              titleAr: 'الميناء والتخليص',
              color: const Color(0xFF8E44AD),
              steps: [
                'Declaration 46 (إقرار 46 ك.م)',
                'Clearance Follow-up (الكشف والتثمين)',
                'Drawing Samples (سحب العينات)',
                'Discrepancy / Damage (محضر المعاينة)',
                'Final Calculation (سداد الرسوم)',
                'Demurrage & Detention (الأرضيات)',
              ],
            ),
            const SizedBox(width: 10),
            _buildPhaseColumnCard(
              titleEn: '6. Inbound & Closure',
              titleAr: 'الاستلام والإغلاق',
              color: AppTheme.emerald,
              steps: [
                'Warehouse GRN (إذن الإضافة)',
                'Landed Cost (تسوية التكلفة)',
                'Final Closure (إغلاق الملف)',
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Features and Rules Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'مميزات وقواعد العمل المطبقة في لوحة Streamlit:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildFeatureBullet('مزامنة حية ومباشرة مع قاعدة بيانات SQLite (sorour_logistics.db).'),
                _buildFeatureBullet('إمكانية تواجد نفس ملف الشحنة في أكثر من مرحلة بالتوازي (Multi-Stage Concurrent Tracking).'),
                _buildFeatureBullet('تحديث العدادات الرقمية لحظياً بمجرد حفظ أو نقل الشحنة من خطوة إلى أخرى.'),
                _buildFeatureBullet('واجهة تفاعلية كاملة لتنفيذ مهام كل خطوة (مفاضلة النولون، سداد الرسوم، الـ ACID، إقرار 46، ونموذج 4).'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseColumnCard({
    required String titleEn,
    required String titleAr,
    required Color color,
    required List<String> steps,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(7),
                  topEnd: Radius.circular(7),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    titleEn,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    titleAr,
                    style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.map((step) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline, size: 12, color: color),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, color: AppTheme.cobalt, size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
