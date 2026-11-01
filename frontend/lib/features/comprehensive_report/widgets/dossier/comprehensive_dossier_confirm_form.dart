import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

/// Confirmation form and downstream dispatch button for ComprehensiveDossierExportDialog
class ComprehensiveDossierConfirmForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController exportedByController;
  final TextEditingController notesController;
  final String selectedFormat;
  final List<String> formatOptions;
  final bool isSubmitting;
  final ValueChanged<String?> onFormatChanged;
  final VoidCallback onConfirmExport;

  const ComprehensiveDossierConfirmForm({
    super.key,
    required this.formKey,
    required this.exportedByController,
    required this.notesController,
    required this.selectedFormat,
    required this.formatOptions,
    required this.isSubmitting,
    required this.onFormatChanged,
    required this.onConfirmExport,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.flatCobalt.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.flatCobalt.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اعتماد تصدير الملف الشامل والإرسال للأرشيف الرقمي (CLO-04):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.flatCobalt),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: const Key('dossierExportedByField'),
                    controller: exportedByController,
                    decoration: const InputDecoration(
                      labelText: 'المسؤول المالي المعتمد للتصدير *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.person, size: 18),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال اسم المسؤول المعتمد';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    key: const Key('dossierExportFormatDropdown'),
                    value: selectedFormat,
                    labelText: 'صيغة الحزمة المصدرة',
                    items: formatOptions
                        .map((f) => SearchableDropdownItem<String>(value: f, label: f))
                        .toList(),
                    onChanged: onFormatChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('dossierExportNotesField'),
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات الأرشفة والتدقيق الختامي (اختياري)',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.note, size: 18),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                key: const Key('confirmDossierExportBtn'),
                onPressed: isSubmitting ? null : onConfirmExport,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.done_all),
                label: Text(
                  isSubmitting
                      ? 'جاري الاعتماد والإرسال...'
                      : 'اعتماد التصدير وإطلاق مهمة الإغلاق (CLO-04)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatCobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
