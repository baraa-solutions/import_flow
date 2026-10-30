import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Interactive dropzone and live text input workbench for document parsing.
class DocumentUploadDropzone extends StatelessWidget {
  final String selectedModule;
  final ValueChanged<String> onModuleChanged;
  final TextEditingController textController;
  final bool isProcessing;
  final VoidCallback onProcess;
  final Map<String, dynamic>? result;

  const DocumentUploadDropzone({
    super.key,
    required this.selectedModule,
    required this.onModuleChanged,
    required this.textController,
    required this.isProcessing,
    required this.onProcess,
    required this.result,
  });

  static const List<String> availableModules = [
    'purchase-order',
    'cargo-shipping',
    'customs-clearance',
    'freight-quotation',
    'coo-certificate',
    'inspection-certificate',
    'warehouse-receiving',
    'company-entity',
    'supplier-entity',
  ];

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left input pane
          SizedBox(
            width: 480,
            child: Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_snippet_rounded, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isArabic ? 'مدخلات النص / الوثيقة المباشرة' : 'Direct Text / Document Input',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: selectedModule,
                      labelText: isArabic ? 'اختر الموديول المستهدف' : 'Target Module',
                      items: availableModules
                          .map((m) => SearchableDropdownItem<String>(value: m, label: m))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) onModuleChanged(v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArabic ? 'ألصق نص الفاتورة / المستند هنا' : 'Paste raw document text here',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: TextField(
                        controller: textController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: isArabic
                              ? 'ألصق نص الفاتورة التجارية، البوليصة، أو بيانات الموردين...'
                              : 'Paste text from Commercial Invoice, B/L, or contact card...',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: isProcessing ? null : onProcess,
                        icon: isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(
                          isArabic ? 'تشغيل الاستخراج الذكي الفوري' : 'Run Live AI Extraction',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Right results pane
          Expanded(
            child: Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: result == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.psychology_outlined, size: 54, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              isArabic
                                  ? 'ألصق النص واضغط "تشغيل الاستخراج الذكي" لرؤية الحقول المستخلصة ونسب الثقة'
                                  : 'Paste text & click "Run Live AI Extraction" to see extracted fields and confidence scores',
                              style: const TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isArabic ? 'نتائج الاستخراج المباشرة' : 'Live Extracted Results',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${isArabic ? "الدقة:" : "Confidence:"} ${((result!["confidence_score"] as num? ?? 0) * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.emerald,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (result!['extracted_fields'] is Map) ...[
                                    ...((result!['extracted_fields'] as Map).entries).map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 180,
                                              child: Text(
                                                e.key.toString(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'monospace',
                                                  fontSize: 12,
                                                  color: AppTheme.cobalt,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                e.value?.toString() ?? '',
                                                style: const TextStyle(fontSize: 12.5),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.copy_rounded, size: 14),
                                              color: AppTheme.cobalt,
                                              tooltip: isArabic ? 'نسخ القيمة' : 'Copy value',
                                              onPressed: () => CopyHelper.copy(context, e.value?.toString() ?? ''),
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
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
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
