import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

class RegimeSelectionStepper extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onAddNew;

  const RegimeSelectionStepper({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onAddNew,
  });

  static const List<Map<String, dynamic>> _regimes = [
    {
      'type': 'TEMPORARY_ADMISSION',
      'title': 'السماح المؤقت',
      'icon': Icons.factory_outlined,
      'desc': 'إعفاء مستلزمات الإنتاج مع الالتزام بإعادة التصدير خلال سنة',
    },
    {
      'type': 'DRAWBACK',
      'title': 'الدروباك',
      'icon': Icons.assignment_return_outlined,
      'desc': 'سداد الرسوم مؤقتاً واستردادها بالكامل بعد تصدير المنتجات',
    },
    {
      'type': 'FREE_ZONE',
      'title': 'المناطق الحرة',
      'icon': Icons.domain_outlined,
      'desc': 'إدخال البضائع إلى مشروعات المناطق الحرة المعفاة من الضرائب',
    },
    {
      'type': 'CUSTOMS_WAREHOUSE',
      'title': 'المستودعات الجمركية',
      'icon': Icons.warehouse_outlined,
      'desc': 'تخزين البضائع في مستودع عام أو خاص مع تعليق سداد الرسوم',
    },
    {
      'type': 'TRANSIT',
      'title': 'الترانزيت المباشر',
      'icon': Icons.alt_route_outlined,
      'desc': 'عبور البضائع الأجنبية عبر الأراضي المصرية تحت الحراسة الجمركية',
    },
  ];

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
                const Icon(Icons.account_balance_outlined, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'اختيار وتصنيف النظام الجمركي المعلق للرسوم',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                ),
                const Spacer(),
                AppButton(
                  label: 'تسجيل نظام جديد',
                  icon: Icons.add,
                  variant: AppButtonVariant.primary,
                  onPressed: onAddNew,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _regimes.map((regime) {
                final isSelected = regime['type'] == selectedType;
                return InkWell(
                  onTap: () => onTypeChanged(regime['type'] as String),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.cobalt.withValues(alpha: 0.08) : Colors.white,
                      border: Border.all(
                        color: isSelected ? AppTheme.cobalt : AppTheme.border,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              regime['icon'] as IconData,
                              size: 20,
                              color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                regime['title'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, size: 16, color: AppTheme.cobalt),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          regime['desc'] as String,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
