import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class EmailSettingsHeader extends StatelessWidget {
  final VoidCallback onClose;

  const EmailSettingsHeader({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal;
    final secTextColor =
        isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.settings_suggest_rounded,
              color: AppTheme.cobalt, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إعدادات ربط البريد الإلكتروني (IMAP / SMTP)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'تكوين خادم الاستقبال لمتابعة إشعارات الوصول وخادم الإرسال لتنبيهات الشحن',
                style: TextStyle(fontSize: 12, color: secTextColor),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: secTextColor),
          onPressed: onClose,
        ),
      ],
    );
  }
}
