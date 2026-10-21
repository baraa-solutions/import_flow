import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/formal_letters_provider.dart';

class FormalLettersScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const FormalLettersScreen({super.key, this.initialImportFileId});

  @override
  ConsumerState<FormalLettersScreen> createState() => _FormalLettersScreenState();
}

class _FormalLettersScreenState extends ConsumerState<FormalLettersScreen> {
  int? _selectedFileId;
  String? _selectedTemplateType;

  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _brokerNameController = TextEditingController();
  final TextEditingController _brokerLicenseController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankBranchController = TextEditingController();
  final TextEditingController _daysController = TextEditingController(text: '21');
  final TextEditingController _notesController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedFileId = widget.initialImportFileId;
    Future.microtask(() {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(formalLettersProvider.notifier).fetchTemplates();
      if (_selectedFileId != null) {
        ref.read(formalLettersProvider.notifier).fetchHistory(_selectedFileId!);
      }
    });
  }

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

  void _onFileSelected(int? fileId) {
    setState(() => _selectedFileId = fileId);
    if (fileId != null) {
      ref.read(formalLettersProvider.notifier).fetchHistory(fileId);
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
    final currentTemplate = _selectedTemplateType != null
        ? templates.where((t) => t.templateType == _selectedTemplateType).firstOrNull
        : null;

    return Scaffold(
      appBar: PageHeader(
        title: isArabic ? 'محرر ومولد الخطابات الرسمية المعتمدة' : 'AI Formal Letter Drafting Hub',
        subtitle: isArabic
            ? 'توليد خطابات التوكيلات الملاحية، تفويضات البنوك، ونماذج التخليص الجمركي ببيانات الشحنة الآلية'
            : 'Automated official letters drafting for shipping lines, banks, and customs clearance',
        icon: Icons.mark_email_read_rounded,
        actions: const [
          BackToDashboardButton(),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Configuration & Form (Width: 460)
              SizedBox(
                width: 460,
                child: Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                  ),
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
                              value: _selectedFileId,
                              hintText: isArabic ? 'اختر ملف الشحنة...' : 'Select import file...',
                              onChanged: _onFileSelected,
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
                            DropdownButtonFormField<String>(
                              initialValue: _selectedTemplateType,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              hint: Text(
                                isArabic ? 'اختر نموذج الخطاب...' : 'Select letter template...',
                                style: const TextStyle(fontSize: 12),
                              ),
                              items: templates
                                  .map((t) => DropdownMenuItem(
                                        value: t.templateType,
                                        child: Text(
                                          isArabic ? t.titleAr : t.titleEn,
                                          style: const TextStyle(fontSize: 12.5),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedTemplateType = v;
                                });
                              },
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

                            if (_selectedTemplateType == 'customs_broker_mandate' ||
                                _selectedTemplateType == 'bank_delegation') ...[
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

                            if (_selectedTemplateType == 'bank_delegation' ||
                                _selectedTemplateType == 'bank_form4') ...[
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

                            if (_selectedTemplateType == 'demurrage_extension') ...[
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
                                onPressed: state.isLoading
                                    ? null
                                    : () async {
                                        if (!_formKey.currentState!.validate()) return;
                                        final payload = {
                                          'import_file_id': _selectedFileId,
                                          'template_type': _selectedTemplateType,
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
                                        final res = await ref
                                            .read(formalLettersProvider.notifier)
                                            .generateLetter(payload);
                                        if (context.mounted && res != null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isArabic
                                                    ? 'تم توليد الخطاب بنجاح برقم: ${res.letterCode ?? ""}'
                                                    : 'Letter generated successfully: ${res.letterCode ?? ""}',
                                              ),
                                              backgroundColor: AppTheme.emerald,
                                            ),
                                          );
                                        }
                                      },
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
              ),
              const SizedBox(width: 16),

              // Right Column: Official Document Preview & History (Expanded)
              Expanded(
                child: Column(
                  children: [
                    // Preview Card
                    Expanded(
                      flex: 6,
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: state.lastGenerated == null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.description_outlined,
                                        size: 54,
                                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        isArabic
                                            ? 'اختر ملف الشحنة ونموذج الخطاب واضغط على "توليد وميكنة الخطاب الرسمي"'
                                            : 'Select an import file & template, then click "Generate Formal Letter"',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Header & Actions Row
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobalt.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            state.lastGenerated!.letterCode ?? 'FORMAL-LETTER',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppTheme.cobalt,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            state.lastGenerated!.letterTitleAr,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 18),
                                          tooltip: isArabic ? 'نسخ نص الخطاب نظيفاً' : 'Copy clean text',
                                          color: AppTheme.cobalt,
                                          onPressed: () =>
                                              CopyHelper.copy(context, state.lastGenerated!.letterBody),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),

                                    // Formal Document Paper Body
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1A222D) : const Color(0xFFFAFAFA),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: SingleChildScrollView(
                                          child: SelectableText(
                                            state.lastGenerated!.letterBody,
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.8,
                                              color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E293B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Previous History Table
                    Expanded(
                      flex: 4,
                      child: Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history_rounded, size: 18, color: AppTheme.charcoal),
                                  const SizedBox(width: 6),
                                  Text(
                                    isArabic ? 'سجل الخطابات الصادرة للشحنة' : 'Shipment Letters History',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const Spacer(),
                                  if (_selectedFileId != null)
                                    IconButton(
                                      icon: const Icon(Icons.refresh, size: 16),
                                      onPressed: () => ref
                                          .read(formalLettersProvider.notifier)
                                          .fetchHistory(_selectedFileId!),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: state.history.isEmpty
                                    ? Center(
                                        child: Text(
                                          isArabic
                                              ? 'لا توجد خطابات رسمية سابقة مسجلة لهذه الشحنة'
                                              : 'No previous letters recorded for this shipment',
                                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: state.history.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                                        itemBuilder: (context, index) {
                                          final rec = state.history[index];
                                          return ListTile(
                                            dense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                            title: Text(
                                              rec.letterTitleAr,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            subtitle: Text(
                                              '${rec.letterCode} — ${isArabic ? "بواسطة:" : "By:"} ${rec.createdBy}',
                                              style: const TextStyle(fontSize: 10.5),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.copy_rounded, size: 16),
                                              color: AppTheme.cobalt,
                                              onPressed: () => CopyHelper.copy(context, rec.letterBody),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
