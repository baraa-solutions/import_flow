import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/smart_document_upload_model.dart';

/// Sessions archive and status tracking list for AI document extractions.
class DocumentOcrStatusList extends StatelessWidget {
  final List<UploadSessionModel> sessions;
  final bool isLoading;
  final List<String> supportedModules;
  final String? selectedModuleFilter;
  final ValueChanged<String?> onModuleFilterChanged;
  final VoidCallback onRefresh;
  final void Function(UploadSessionModel session)? onViewDetails;
  final void Function(UploadSessionModel session)? onDelete;

  const DocumentOcrStatusList({
    super.key,
    required this.sessions,
    required this.isLoading,
    required this.supportedModules,
    required this.selectedModuleFilter,
    required this.onModuleFilterChanged,
    required this.onRefresh,
    this.onViewDetails,
    this.onDelete,
  });

  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return AppTheme.emerald;
      case 'PARTIAL':
        return Colors.orange;
      case 'FAILED':
        return AppTheme.crimson;
      default:
        return Colors.grey;
    }
  }

  static Future<void> showSessionDetails(BuildContext context, UploadSessionModel session) async {
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.document_scanner_rounded, color: AppTheme.cobalt, size: 22),
            const SizedBox(width: 8),
            Text(
              '${isArabic ? 'تفاصيل جلسة الاستخراج:' : 'Extraction Details:'} ${session.sessionRef}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SelectionArea(
          child: SizedBox(
            width: 580,
            height: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          session.moduleName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.cobalt),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isArabic ? 'نسبة الدقة:' : 'Confidence:'} ${(session.confidenceScore * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        session.filename,
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Missing Fields
                  if (session.missingFields.isNotEmpty) ...[
                    Text(
                      isArabic ? 'الحقول الناقصة / غير المكتشفة:' : 'Missing / Undetected Fields:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: session.missingFields
                          .map((f) => Chip(
                                label: Text(f, style: const TextStyle(fontSize: 10.5, color: Colors.orange)),
                                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Extracted Fields Table
                  Text(
                    isArabic ? 'الحقول المستخرجة بنجاح:' : 'Extracted Fields:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: session.extractedFields.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                isArabic ? 'لم يتم استخراج حقول' : 'No fields extracted',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: session.extractedFields.entries.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = session.extractedFields.entries.elementAt(index);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.value?.toString() ?? '',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Filter Toolbar
          Row(
            children: [
              Container(
                width: 240,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: selectedModuleFilter,
                    isDense: true,
                    isExpanded: true,
                    hint: Text(isArabic ? 'كل الموديولات' : 'All Modules', style: const TextStyle(fontSize: 12)),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(isArabic ? 'كل الموديولات' : 'All Modules', style: const TextStyle(fontSize: 12)),
                      ),
                      ...supportedModules.map((m) => DropdownMenuItem<String?>(
                            value: m,
                            child: Text(m, style: const TextStyle(fontSize: 12)),
                          )),
                    ],
                    onChanged: onModuleFilterChanged,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: isArabic ? 'تحديث' : 'Refresh',
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sessions List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : sessions.isEmpty
                    ? Center(
                        child: Text(
                          isArabic ? 'لا توجد جلسات استخراج مسجلة' : 'No upload sessions found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return Card(
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: statusColor(session.extractionStatus).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.document_scanner_rounded,
                                      color: statusColor(session.extractionStatus),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              session.sessionRef,
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppTheme.cobalt,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              session.filename,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: statusColor(session.extractionStatus).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                session.extractionStatus,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: statusColor(session.extractionStatus),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 12,
                                          children: [
                                            Text(
                                              '${isArabic ? "الموديول:" : "Module:"} ${session.moduleName}',
                                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                            ),
                                            Text(
                                              '${isArabic ? "الدقة:" : "Confidence:"} ${(session.confidenceScore * 100).toStringAsFixed(1)}%',
                                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                            ),
                                            Text(
                                              '${isArabic ? "الحقول:" : "Fields:"} ${session.extractedFields.length}',
                                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                            ),
                                            if (session.createdAt != null)
                                              Text(
                                                session.createdAt!.toLocal().toString().substring(0, 16),
                                                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, size: 20),
                                    color: AppTheme.cobalt,
                                    tooltip: isArabic ? 'عرض تفاصيل الحقول' : 'View extracted details',
                                    onPressed: onViewDetails != null ? () => onViewDetails!(session) : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    color: AppTheme.crimson,
                                    tooltip: isArabic ? 'حذف الجلسة' : 'Delete session',
                                    onPressed: onDelete != null ? () => onDelete!(session) : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
