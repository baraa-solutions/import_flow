import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/formal_letters_provider.dart';

/// Form editor card for drafting and automating formal official letters.
class FormalLetterEditorCard extends ConsumerStatefulWidget {
  final int? selectedFileId;
  final ValueChanged<int?> onFileSelected;
  final String? selectedTemplateType;
  final ValueChanged<String?> onTemplateChanged;

  const FormalLetterEditorCard({
    super.key,
    required this.selectedFileId,
    required this.onFileSelected,
    required this.selectedTemplateType,
    required this.onTemplateChanged,
  });

  @override
  ConsumerState<FormalLetterEditorCard> createState() => _FormalLetterEditorCardState();
}

class _FormalLetterEditorCardState extends ConsumerState<FormalLetterEditorCard> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _brokerNameController = TextEditingController();
  final TextEditingController _brokerLicenseController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankBranchController = TextEditingController();
  final TextEditingController _daysController = TextEditingController(text: '21');
  final TextEditingController _notesController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _recipientController.dispose();
    _brokerNameController.dispose();
    _brokerLicenseController.dispose();
    _bankNameController.dispose();
    _bankBranchController.dispose();
    _daysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    final isArabic = context.l10n.isArabic;
    if (!_formKey.currentState!.validate()) return;

    final payload = {
      'import_file_id': widget.selectedFileId,
      'template_type': widget.selectedTemplateType,
      'recipient_name': _recipientController.text.trim().isEmpty
          ? null
          : _recipientController.text.trim(),
      'broker_name': _brokerNameController.text.trim().isEmpty
          ? null
          : _brokerNameController.text.trim(),
      'broker_license': _brokerLicenseController.text.trim().isEmpty
          ? null
          : _brokerLicenseController.text.trim(),
      'bank_name': _bankNameController.text.trim().isEmpty
          ? null
          : _bankNameController.text.trim(),
      'bank_branch': _bankBranchController.text.trim().isEmpty
          ? null
          : _bankBranchController.text.trim(),
      'extension_days': int.tryParse(_daysController.text.trim()) ?? 21,
      'custom_notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    };

    final res = await ref.read(formalLettersProvider.notifier).generateLetter(payload);
    if (mounted && res != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, isArabic
                ? 'تم توليد الخطاب بنجاح برقم: ${res.letterCode ?? ""}'
                : 'Letter generated successfully: ${res.letterCode ?? ""}', severity: AppSeverity.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(formalLettersProvider);
    final filesState = ref.watch(importFilesProvider);
    final fileItems = filesState.value ?? [];
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    final templates = state.templates;
    final currentTemplate = widget.selectedTemplateType != null
        ? templates.where((t) => t.templateType == widget.selectedTemplateType).firstOrNull
        : null;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: SelectionArea(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppTheme.cobalt, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'إعدادات ومحتوى الخطاب' : 'Letter Setup',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Import File Picker
                Text(
                  isArabic ? 'ملف الشحنة / الاستيراد المرتبط *' : 'Associated Import File *',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                SearchableDropdownField<int>(
                  items: fileItems
                      .map((f) => SearchableDropdownItem(
                            value: f.importFileId,
                            label: '${f.importFileCode} — ${f.companyName} (${f.customFileNumber ?? f.poNumber ?? ''})',
                          ))
                      .toList(),
                  value: widget.selectedFileId,
                  hintText: isArabic ? 'اختر ملف الشحنة...' : 'Select import file...',
                  onChanged: widget.onFileSelected,
                  validator: (v) => v == null
                      ? (isArabic ? 'يرجى اختيار ملف الشحنة' : 'Please select an import file')
                      : null,
                ),
                const SizedBox(height: 12),

                // Template Type Picker
                Text(
                  isArabic ? 'نوع الخطاب الرسمي *' : 'Letter Template *',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                SearchableDropdownField<String>(
                  value: widget.selectedTemplateType,
                  labelText: isArabic ? 'نوع الخطاب الرسمي *' : 'Letter Template *',
                  hintText: isArabic ? 'اختر نموذج الخطاب...' : 'Select letter template...',
                  items: templates
                      .map((t) => SearchableDropdownItem<String>(
                            value: t.templateType,
                            label: isArabic ? t.titleAr : t.titleEn,
                          ))
                      .toList(),
                  onChanged: widget.onTemplateChanged,
                  validator: (v) => v == null
                      ? (isArabic ? 'يرجى اختيار نوع الخطاب' : 'Please select a template')
                      : null,
                ),
                if (currentTemplate != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      currentTemplate.descriptionAr,
                      style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Conditional Fields based on template
                Text(
                  isArabic ? 'اسم الجهة أو المستلم (إلى السادة /)' : 'Recipient Name / Attention',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    hintText: isArabic ? 'مثال: السادة / توكيل ميرسك مصر' : 'e.g. Maersk Egypt Shipping Agency',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                if (widget.selectedTemplateType == 'customs_broker_mandate' ||
                    widget.selectedTemplateType == 'bank_delegation') ...[
                  Text(
                    isArabic ? 'اسم المخلص الجمركي المفوض' : 'Customs Broker Name',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _brokerNameController,
                    decoration: InputDecoration(
                      hintText: isArabic ? 'اسم المخلص المفوض' : 'Broker Full Name',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isArabic ? 'رقم رخصة التخليص' : 'Broker License Number',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _brokerLicenseController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 12345/2024',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                if (widget.selectedTemplateType == 'bank_delegation' ||
                    widget.selectedTemplateType == 'bank_form4') ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'اسم البنك' : 'Bank Name',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _bankNameController,
                              decoration: InputDecoration(
                                hintText: isArabic ? 'البنك الأهلي المصري' : 'NBE',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'الفرع' : 'Branch',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _bankBranchController,
                              decoration: InputDecoration(
                                hintText: isArabic ? 'فرع مدينة نصر' : 'Branch',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                if (widget.selectedTemplateType == 'demurrage_extension') ...[
                  Text(
                    isArabic ? 'عدد أيام مهلة السماح المطلوبة' : 'Extension Days Requested',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '21',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                Text(
                  isArabic ? 'ملاحظات أو تعهدات إضافية' : 'Custom Notes / Additional Clauses',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: isArabic
                        ? 'أي فقرات أو توضيحات خاصة تضاف للخطاب...'
                        : 'Special clauses or instructions...',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Generate Button
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: state.isLoading ? null : _handleGenerate,
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      isArabic ? 'توليد وميكنة الخطاب الرسمي' : 'Generate Formal Letter',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
