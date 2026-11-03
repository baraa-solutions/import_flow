import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/email_settings_model.dart';
import '../email_sync_review_dialog.dart';

class EmailSyncStatusSection extends StatelessWidget {
  final bool autoFetchEnabled;
  final int fetchIntervalMinutes;
  final ValueChanged<bool> onToggleAutoFetch;
  final ValueChanged<int?> onChangeFetchInterval;
  final EmailConnectionTestResultModel? testResult;
  final EmailSettingsModel? settings;
  final InboxFetchResultModel? fetchResult;
  final String Function(String?) formatDateTime;

  const EmailSyncStatusSection({
    super.key,
    required this.autoFetchEnabled,
    required this.fetchIntervalMinutes,
    required this.onToggleAutoFetch,
    required this.onChangeFetchInterval,
    required this.testResult,
    required this.settings,
    required this.fetchResult,
    required this.formatDateTime,
  });

  Widget _buildTestResultCard(
      EmailConnectionTestResultModel res, bool isDark) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: res.overallSuccess
              ? AppTheme.emerald.withValues(alpha: isDark ? 0.2 : 0.1)
              : AppTheme.crimson.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: res.overallSuccess ? AppTheme.emerald : AppTheme.crimson,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  res.overallSuccess
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  color:
                      res.overallSuccess ? AppTheme.emerald : AppTheme.crimson,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  res.overallSuccess
                      ? 'نجح اختبار الاتصال بالمخدمين بالكامل'
                      : 'فشل أحد اختبارات الاتصال',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: res.overallSuccess
                        ? AppTheme.emerald
                        : AppTheme.crimson,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• خادم الاستقبال (IMAP): ${res.imapMessage}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : Colors.grey.shade800,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '• خادم الإرسال (SMTP): ${res.smtpMessage}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : Colors.grey.shade800,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal;
    final secTextColor =
        isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Auto Fetch Polling Options
        Row(
          children: [
            Switch(
              value: autoFetchEnabled,
              onChanged: onToggleAutoFetch,
              activeThumbColor: AppTheme.cobalt,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تفعيل الفحص الدوري التلقائي لصندوق الوارد',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('كل: ',
                style: TextStyle(fontSize: 12, color: secTextColor)),
            DropdownButton<int>(
              value: fetchIntervalMinutes,
              dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 دقائق')),
                DropdownMenuItem(value: 15, child: Text('15 دقيقة')),
                DropdownMenuItem(value: 30, child: Text('30 دقيقة')),
                DropdownMenuItem(value: 60, child: Text('ساعة واحدة')),
              ],
              onChanged: autoFetchEnabled ? onChangeFetchInterval : null,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Test Results Card
        if (testResult != null) _buildTestResultCard(testResult!, isDark),

        // Last Sync Info
        if (settings?.lastSyncAt != null)
          Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkInputBackground
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 16, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Text(
                    'آخر فحص: ${formatDateTime(settings?.lastSyncAt)}',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (settings?.lastSyncStatus == 'SUCCESS'
                              ? AppTheme.emerald
                              : AppTheme.orange)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      settings?.lastSyncStatus == 'SUCCESS'
                          ? 'ناجح'
                          : (settings?.lastSyncStatus ?? '-'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: settings?.lastSyncStatus == 'SUCCESS'
                            ? AppTheme.emerald
                            : AppTheme.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      settings?.lastSyncMessage ?? '',
                      style: TextStyle(fontSize: 11, color: secTextColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (fetchResult != null &&
                      fetchResult!.matchedFilesCount > 0) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => EmailSyncReviewDialog.show(context,
                          result: fetchResult!),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  AppTheme.cobalt.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rule_folder_rounded,
                                size: 13, color: AppTheme.cobalt),
                            SizedBox(width: 4),
                            Text(
                              'مراجعة وتوجيه المهام 📋',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.cobalt),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
