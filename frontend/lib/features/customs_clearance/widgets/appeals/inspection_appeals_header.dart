import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

class InspectionAppealsHeader extends StatelessWidget {
  final VoidCallback onNewAppeal;
  final VoidCallback onClose;

  const InspectionAppealsHeader({
    super.key,
    required this.onNewAppeal,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.biotech_rounded, color: AppTheme.cobalt, size: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تظلمات الفحص المعملي والتحكيم الثلاثي',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'إدارة دورة التظلم المعملي، لجان الخبراء، وتحكيم العينات الثلاثية لدى الهيئات الرقابية',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          AppButton(
            label: 'تقديم تظلم معملي',
            icon: Icons.add_circle_outline,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: onNewAppeal,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
