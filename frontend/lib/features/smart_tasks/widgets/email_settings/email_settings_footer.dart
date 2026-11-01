import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class EmailSettingsFooter extends StatelessWidget {
  final bool isTesting;
  final VoidCallback onTestConnection;
  final bool isFetching;
  final VoidCallback onFetchInbox;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onClose;

  const EmailSettingsFooter({
    super.key,
    required this.isTesting,
    required this.onTestConnection,
    required this.isFetching,
    required this.onFetchInbox,
    required this.isSaving,
    required this.onSave,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secTextColor =
        isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700;

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Test Connection Button
              OutlinedButton.icon(
                onPressed: isTesting ? null : onTestConnection,
                icon: isTesting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.network_check_rounded, size: 16),
                label: Text(
                  isTesting ? 'جارٍ الفحص...' : 'اختبار الاتصال',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.cobalt,
                  side: const BorderSide(color: AppTheme.cobalt),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),

              // Sync Now Button
              OutlinedButton.icon(
                onPressed: isFetching ? null : onFetchInbox,
                icon: isFetching
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  isFetching ? 'جارٍ المزامنة...' : 'فحص الصندوق الآن',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.emerald,
                  side: const BorderSide(color: AppTheme.emerald),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close Button
              TextButton(
                onPressed: onClose,
                child: Text('إغلاق',
                    style: TextStyle(color: secTextColor, fontSize: 12)),
              ),
              const SizedBox(width: 8),

              // Save Button
              ElevatedButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(
                  isSaving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
