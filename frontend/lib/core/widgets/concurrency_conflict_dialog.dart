import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'copyable_data_helper.dart';

enum ConcurrencyResolution {
  discardAndReload,
  keepAndReview,
}

class ConcurrencyConflictDialog extends StatelessWidget {
  final String entityName;
  final dynamic recordId;
  final int currentVersion;
  final int submittedVersion;
  final String? updatedAt;
  final String? updatedBy;
  final String? serverMessage;
  final Map<String, dynamic>? currentDraftData;

  const ConcurrencyConflictDialog({
    super.key,
    required this.entityName,
    required this.recordId,
    required this.currentVersion,
    required this.submittedVersion,
    this.updatedAt,
    this.updatedBy,
    this.serverMessage,
    this.currentDraftData,
  });

  static Future<ConcurrencyResolution?> show(
    BuildContext context, {
    required String entityName,
    required dynamic recordId,
    required int currentVersion,
    required int submittedVersion,
    String? updatedAt,
    String? updatedBy,
    String? serverMessage,
    Map<String, dynamic>? currentDraftData,
  }) async {
    return showDialog<ConcurrencyResolution>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => ConcurrencyConflictDialog(
        entityName: entityName,
        recordId: recordId,
        currentVersion: currentVersion,
        submittedVersion: submittedVersion,
        updatedAt: updatedAt,
        updatedBy: updatedBy,
        serverMessage: serverMessage,
        currentDraftData: currentDraftData,
      ),
    );
  }

  String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return 'غير محدد';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  void _copyDraftToClipboard(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (currentDraftData == null || currentDraftData!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'لا توجد بيانات مسودة لنسخها.' : 'No draft data to copy.'),
          backgroundColor: AppTheme.orange,
        ),
      );
      return;
    }

    const encoder = JsonEncoder.withIndent('  ');
    final formatted = encoder.convert(currentDraftData);
    CopyHelper.copy(
      context,
      formatted,
      customMessage: isArabic
          ? 'تم نسخ بيانات مسودتك إلى الحافظة بنجاح!'
          : 'Draft data copied to clipboard successfully!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final modifier = (updatedBy != null && updatedBy!.isNotEmpty) ? updatedBy : (isArabic ? 'مستخدم آخر' : 'Another user');
    final formattedTime = _formatTimestamp(updatedAt);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SelectionArea(
        child: Container(
          width: 580,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.crimson.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.7 : 0.3),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(22, 18, 22, 16),
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.crimson.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.crimson.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.crimson,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'تنبيه تعارض في التعديل المتزامن' : 'Concurrent Modification Conflict',
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.crimson,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabic
                                ? 'تم منع الكتابة الفوقية التلقائية لحماية سلامة البيانات المالية واللوجستية.'
                                : 'Automatic overwrite prevented to safeguard financial and logistics data integrity.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFFCBD5E1) : AppTheme.charcoal.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Explanation Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 18, color: AppTheme.cobalt),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : AppTheme.charcoal,
                                      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                                    ),
                                    children: [
                                      TextSpan(text: isArabic ? 'تم تعديل وحفظ هذا السجل بواسطة: ' : 'Record modified and saved by: '),
                                      TextSpan(
                                        text: modifier,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 18, color: AppTheme.orange),
                              const SizedBox(width: 8),
                              Text(
                                isArabic ? 'تاريخ ووقت آخر حفظ: $formattedTime' : 'Last saved: $formattedTime',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.tag, size: 18, color: AppTheme.emerald),
                              const SizedBox(width: 8),
                              Text(
                                isArabic
                                    ? 'النسخة المخزنة الحالية: v$currentVersion | نسختك التي بدأت عليها: v$submittedVersion'
                                    : 'Current saved version: v$currentVersion | Your base version: v$submittedVersion',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      isArabic
                          ? 'لحماية عمل الزميل الآخر وعدم مسح بياناته، تم إلغاء عملية الحفظ. يمكنك الاختيار:'
                          : 'To protect your colleague\'s work and prevent data loss, the save operation was cancelled. You can choose:',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFE2E8F0) : AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bullet Points
                    _buildBullet(
                      icon: Icons.refresh_rounded,
                      color: AppTheme.cobalt,
                      title: isArabic ? 'تفريغ وإعادة تحميل أحدث نسخة' : 'Discard and reload latest version',
                      desc: isArabic
                          ? 'جلب أحدث التعديلات المحفوظة في قاعدة البيانات والبدء في التعديل عليها.'
                          : 'Fetch latest changes saved in the database and begin editing on them.',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildBullet(
                      icon: Icons.copy_rounded,
                      color: AppTheme.emerald,
                      title: isArabic ? 'نسخ تعديلاتي الحالية' : 'Copy my current changes',
                      desc: isArabic
                          ? 'حفظ كافة الملاحظات والبيانات التي أدخلتها بالحافظة حتى لا تفقد مجهودك.'
                          : 'Save all entered notes and data to clipboard to avoid losing work.',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              // Action Buttons Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Copy Button
                    OutlinedButton.icon(
                      onPressed: () => _copyDraftToClipboard(context),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(isArabic ? 'نسخ تعديلاتي الحالية' : 'Copy My Changes'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.emerald,
                        side: const BorderSide(color: AppTheme.emerald),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const Spacer(),
                    // Keep and Review
                    TextButton(
                      onPressed: () => Navigator.pop(context, ConcurrencyResolution.keepAndReview),
                      child: Text(
                        isArabic ? 'مراجعة النموذج' : 'Review Form',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Discard and Reload
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, ConcurrencyResolution.discardAndReload),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(isArabic ? 'إلغاء وإعادة تحميل أحدث نسخة' : 'Discard & Reload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBullet({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.charcoal,
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
