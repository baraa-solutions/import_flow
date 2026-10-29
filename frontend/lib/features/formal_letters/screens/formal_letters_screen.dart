import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/formal_letters_provider.dart';
import '../widgets/formal_letter_editor_card.dart';
import '../widgets/formal_letters_registry_table.dart';

class FormalLettersScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const FormalLettersScreen({super.key, this.initialImportFileId});

  @override
  ConsumerState<FormalLettersScreen> createState() => _FormalLettersScreenState();
}

class _FormalLettersScreenState extends ConsumerState<FormalLettersScreen> {
  int? _selectedFileId;
  String? _selectedTemplateType;

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

  void _onFileSelected(int? fileId) {
    setState(() => _selectedFileId = fileId);
    if (fileId != null) {
      ref.read(formalLettersProvider.notifier).fetchHistory(fileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(formalLettersProvider);
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

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
              // Left Column: Configuration & Form via FormalLetterEditorCard (Width: 460)
              SizedBox(
                width: 460,
                child: FormalLetterEditorCard(
                  selectedFileId: _selectedFileId,
                  onFileSelected: _onFileSelected,
                  selectedTemplateType: _selectedTemplateType,
                  onTemplateChanged: (v) => setState(() => _selectedTemplateType = v),
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

                    // Previous History Table via FormalLettersRegistryTable
                    Expanded(
                      flex: 4,
                      child: FormalLettersRegistryTable(
                        history: state.history,
                        selectedFileId: _selectedFileId,
                        onRefresh: _selectedFileId != null
                            ? () => ref
                                .read(formalLettersProvider.notifier)
                                .fetchHistory(_selectedFileId!)
                            : null,
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
