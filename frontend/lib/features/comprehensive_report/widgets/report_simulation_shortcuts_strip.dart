import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';

/// Shortcuts strip for stage navigation and simulation from the Comprehensive Report.
class ReportSimulationShortcutsStrip extends StatelessWidget {
  final ImportFileModel file;
  final ValueChanged<int>? onNavigate;
  final VoidCallback? onAddKbNote;

  const ReportSimulationShortcutsStrip({
    super.key,
    required this.file,
    this.onNavigate,
    this.onAddKbNote,
  });

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      {
        'label': 'محاكاة الجمارك',
        'icon': Icons.calculate_outlined,
        'color': const Color(0xFF2563EB),
        'navIndex': 6,
        'action': () => onNavigate?.call(6),
        'tooltip': 'الانتقال إلى دراسات الجمارك وبنود التعريفة وحساب الرسوم',
      },
      {
        'label': 'محاكاة تكلفة الوصول',
        'icon': Icons.pie_chart_outline,
        'color': const Color(0xFF0D9488),
        'navIndex': 4,
        'action': () => onNavigate?.call(4),
        'tooltip': 'محاكاة سيناريوهات الشحن والـ Landed Cost التقديري',
      },
      {
        'label': 'منظومة نافذة ACID',
        'icon': Icons.verified_outlined,
        'color': const Color(0xFF4F46E5),
        'navIndex': 11,
        'action': () => onNavigate?.call(11),
        'tooltip': 'تتبع رقم القيد الجمركي المبدئي والتحقق من صلاحية ACID',
      },
      {
        'label': 'نموذج 4 البنكي',
        'icon': Icons.account_balance_outlined,
        'color': const Color(0xFF0284C7),
        'navIndex': 16,
        'action': () => onNavigate?.call(16),
        'tooltip': 'متابعة النموذج البنكي وتدبير العملة والمصادقات',
      },
      {
        'label': 'كارغو إكس (CargoX)',
        'icon': Icons.cloud_upload_outlined,
        'color': const Color(0xFF7C3AED),
        'navIndex': 54,
        'action': () => onNavigate?.call(54),
        'tooltip': 'مستندات الشحن الأصلية وتحويلات البلوكشين عبر CargoX',
      },
      {
        'label': 'حجز الشحن الملاحي',
        'icon': Icons.directions_boat_outlined,
        'color': const Color(0xFF059669),
        'navIndex': 25,
        'action': () => onNavigate?.call(25),
        'tooltip': 'إدارة الحجوزات البحرية والخطوط الملاحية والحاويات',
      },
      {
        'label': 'مقدم المورد (دفعة)',
        'icon': Icons.payments_outlined,
        'color': const Color(0xFFD97706),
        'navIndex': 8,
        'action': () => onNavigate?.call(8),
        'tooltip': 'الموافقات المالية على التحويلات ودفعات الموردين',
      },
      {
        'label': 'إضافة ملاحظة خبرة +',
        'icon': Icons.add_comment_outlined,
        'color': const Color(0xFF475569),
        'action': () => onAddKbNote?.call(),
        'tooltip': 'تسجيل ملاحظة تشغيلية في قاعدة المعرفة للشحنات المستقبلية',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Icon(Icons.bolt, color: AppTheme.cobalt, size: 16),
              const SizedBox(width: 6),
              const Text(
                'اختصارات المحاكاة ومحطات الشحنة المباشرة:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
              const Spacer(),
              Text(
                'انتقال مباشر للشاشات التخصصية المرتبطة بهذه الشحنة',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: shortcuts.map((item) {
                final color = item['color'] as Color;
                final icon = item['icon'] as IconData;
                final label = item['label'] as String;
                final tooltip = item['tooltip'] as String;
                final action = item['action'] as VoidCallback;

                return Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Tooltip(
                    message: tooltip,
                    child: InkWell(
                      onTap: action,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: color),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
