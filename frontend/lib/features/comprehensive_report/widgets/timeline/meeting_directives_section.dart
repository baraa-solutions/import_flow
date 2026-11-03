import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Bottom section for editing and saving meeting action directives.
class MeetingDirectivesSection extends StatelessWidget {
  final TextEditingController controller;
  final bool isSaving;
  final bool isDark;
  final VoidCallback onSave;

  const MeetingDirectivesSection({
    super.key,
    required this.controller,
    required this.isSaving,
    required this.isDark,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.rate_review, color: AppTheme.cobalt, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'محضر مناقشة وتوجيهات الشحنة التشغيلية (Meeting Action Directives)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: controller,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11.5),
                  decoration: InputDecoration(
                    hintText:
                        'اكتب هنا القرارات التشغيلية ومحضر اجتماع الشحنة ليتم حفظها وتضمينها في ملفات التصدير...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            icon: isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save, size: 16),
            label: const Text('حفظ التوجيهات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            onPressed: isSaving ? null : onSave,
          ),
        ],
      ),
    );
  }
}
