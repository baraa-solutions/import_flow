import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import 'idoc_ui.dart';

class FormalLetterGeneratorDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const FormalLetterGeneratorDialog({
    super.key,
    this.initialImportFileId,
  });

  static Future<void> show(BuildContext context, {int? importFileId}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FormalLetterGeneratorDialog(initialImportFileId: importFileId),
    );
  }

  @override
  ConsumerState<FormalLetterGeneratorDialog> createState() => _FormalLetterGeneratorDialogState();
}

class _FormalLetterGeneratorDialogState extends ConsumerState<FormalLetterGeneratorDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedFileId;
  String _selectedTemplate = 'demurrage_extension';

  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankBranchController = TextEditingController();
  final TextEditingController _brokerNameController = TextEditingController();
  final TextEditingController _brokerLicenseController = TextEditingController();
  final TextEditingController _extensionDaysController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isGenerating = false;
  String? _errorMessage;
  Map<String, dynamic>? _generatedLetter;

  // History Tab
  bool _isLoadingHistory = false;
  List<dynamic> _letterHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedFileId = widget.initialImportFileId;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recipientController.dispose();
    _bankNameController.dispose();
    _bankBranchController.dispose();
    _brokerNameController.dispose();
    _brokerLicenseController.dispose();
    _extensionDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _generateLetter() async {
    if (_selectedFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.formalLetterSelectShipmentPrompt, severity: AppSeverity.danger),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/formal-letters/generate',
        data: {
          'import_file_id': _selectedFileId,
          'template_type': _selectedTemplate,
          'recipient_name': _recipientController.text.trim().isNotEmpty ? _recipientController.text.trim() : null,
          'bank_name': _bankNameController.text.trim().isNotEmpty ? _bankNameController.text.trim() : null,
          'bank_branch': _bankBranchController.text.trim().isNotEmpty ? _bankBranchController.text.trim() : null,
          'broker_name': _brokerNameController.text.trim().isNotEmpty ? _brokerNameController.text.trim() : null,
          'broker_license': _brokerLicenseController.text.trim().isNotEmpty ? _brokerLicenseController.text.trim() : null,
          'extension_days': int.tryParse(_extensionDaysController.text.trim()) ?? 21,
          'custom_notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        },
      );

      if (mounted) {
        setState(() {
          _generatedLetter = response.data is Map<String, dynamic> ? response.data : null;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiErrorText.of(context.l10n, e);
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _fetchHistory() async {
    if (_selectedFileId == null) return;
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/formal-letters/history/$_selectedFileId');
      if (mounted) {
        setState(() {
          _letterHistory = response.data is List ? response.data : [];
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  void _copyLetterBody() {
    if (_generatedLetter == null) return;
    final body = _generatedLetter!['letter_body']?.toString() ?? '';
    CopyHelper.copy(
      context,
      body,
      customMessage: context.l10n.formalLetterCopyBtn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filesState = ref.read(importFilesProvider);
    final files = filesState.valueOrNull ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
        width: 960,
        height: 720,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_outlined, color: AppTheme.cobalt, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.formalLetterDialogTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.formalLetterLetterheadHint,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.cobalt,
              unselectedLabelColor: AppTheme.textMutedOf(context),
              indicatorColor: AppTheme.cobalt,
              onTap: (index) {
                if (index == 1) _fetchHistory();
              },
              tabs: [
                Tab(
                  icon: const Icon(Icons.edit_document, size: 18),
                  text: l.formalLetterGenerateBtn,
                ),
                Tab(
                  icon: const Icon(Icons.history, size: 18),
                  text: l.smartEmailListenerLogsTabTitle,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Draft Builder & Live Preview
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Controls Panel (Left)
                      SizedBox(
                        width: 380,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Shipment File Selector
                              Text(
                                l.formalLetterSelectShipmentPrompt,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              SearchableDropdownField<int>(
                                value: _selectedFileId,
                                labelText: l.formalLetterSelectShipmentPrompt,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.folder, size: 18),
                                ),
                                items: files.map((f) {
                                  return SearchableDropdownItem<int>(
                                    value: f.importFileId,
                                    label: '${f.importFileCode} — ${f.supplierName}',
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedFileId = val;
                                    _generatedLetter = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),

                              // Template Selector
                              Text(
                                l.formalLetterTemplateLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              SearchableDropdownField<String>(
                                value: _selectedTemplate,
                                labelText: l.formalLetterTemplateLabel,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.article_outlined, size: 18),
                                ),
                                items: [
                                  SearchableDropdownItem(value: 'demurrage_extension', label: l.idocATemplateDemurrageExtension),
                                  SearchableDropdownItem(value: 'bank_delegation', label: l.idocATemplateBankDelegation),
                                  SearchableDropdownItem(value: 'bank_form4', label: l.idocATemplateBankForm4),
                                  SearchableDropdownItem(value: 'customs_broker_mandate', label: l.idocATemplateBrokerMandate),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedTemplate = val;
                                      _generatedLetter = null;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 12),

                              // Contextual Fields
                              if (_selectedTemplate == 'demurrage_extension') ...[
                                TextField(
                                  controller: _recipientController,
                                  decoration: InputDecoration(
                                    labelText: l.formalLetterRecipientLabel,
                                    hintText: context.l10n.idocAMaerskMSCAgency,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _extensionDaysController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: l.formalLetterExtensionDaysLabel,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ] else if (_selectedTemplate == 'bank_delegation' || _selectedTemplate == 'bank_form4') ...[
                                TextField(
                                  controller: _bankNameController,
                                  decoration: InputDecoration(
                                    labelText: l.formalLetterBankNameLabel,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _bankBranchController,
                                  decoration: InputDecoration(
                                    labelText: l.formalLetterBankBranchLabel,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                if (_selectedTemplate == 'bank_delegation') ...[
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _brokerNameController,
                                    decoration: InputDecoration(
                                      labelText: l.formalLetterBrokerNameLabel,
                                      hintText: context.l10n.idocANameOfTheAuthorizedReceiver,
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _brokerLicenseController,
                                    decoration: InputDecoration(
                                      labelText: l.formalLetterBrokerLicenseLabel,
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ] else if (_selectedTemplate == 'customs_broker_mandate') ...[
                                TextField(
                                  controller: _brokerNameController,
                                  decoration: InputDecoration(
                                    labelText: l.formalLetterBrokerNameLabel,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _brokerLicenseController,
                                  decoration: InputDecoration(
                                    labelText: l.formalLetterBrokerLicenseLabel,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 10),
                              TextField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: l.formalLetterCustomNotesLabel,
                                  alignLabelWithHint: true,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Generate Button
                              SizedBox(
                                width: double.infinity,
                                child: IdocUi.fit(AppButton(
                                  label: l.formalLetterGenerateBtn,
                                  icon: Icons.auto_fix_high,
                                  variant: AppButtonVariant.primary,
                                  isLoading: _isGenerating,
                                  onPressed: _isGenerating ? null : _generateLetter,
                                )),
                              ),

                              if (_errorMessage != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Live Letter Preview Pane (Right)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceOf(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderOf(context)),
                          ),
                          child: _generatedLetter == null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.mark_as_unread, size: 48, color: AppTheme.textMutedOf(context)),
                                      const SizedBox(height: 12),
                                      Text(
                                        l.formalLetterLetterheadHint,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Action Toolbar
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _generatedLetter!['letter_title_ar']?.toString() ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IdocUi.fit(AppButton(
                                          label: l.formalLetterCopyBtn,
                                          icon: Icons.copy,
                                          variant: AppButtonVariant.success,
                                          size: AppButtonSize.small,
                                          onPressed: _copyLetterBody,
                                        )),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Expanded(
                                      child: SelectionArea(
                                        child: SingleChildScrollView(
                                          child: SelectableText(
                                            _generatedLetter!['letter_body']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.6,
                                              color: AppTheme.charcoal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),

                  // Tab 2: Letter History
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l.smartEmailListenerLogsTabTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: l.smartEmailListenerLogsTabTitle,
                            onPressed: _fetchHistory,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _isLoadingHistory
                            ? const Center(child: CircularProgressIndicator())
                            : _letterHistory.isEmpty
                                ? Center(
                                    child: Text(
                                      l.smartTasksEmptyMessage,
                                      style: const TextStyle(color: AppTheme.textMuted),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _letterHistory.length,
                                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                                    itemBuilder: (ctx, i) {
                                      final item = _letterHistory[i] as Map<String, dynamic>;
                                      final code = item['letter_code'] ?? '-';
                                      final title = item['letter_title_ar'] ?? '-';
                                      final dateStr = item['created_at']?.toString().split('T').first ?? '-';
                                      final body = item['letter_body']?.toString() ?? '';

                                      return ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: AppTheme.charcoal,
                                          foregroundColor: AppTheme.white,
                                          radius: 16,
                                          child: Icon(Icons.assignment, size: 16),
                                        ),
                                        title: Text(
                                          '$code — $title',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        subtitle: Text(
                                          context.l10n.idocAIssueDate(dateStr),
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                                        ),
                                        trailing: IdocUi.fit(AppButton(
                                          label: l.formalLetterCopyBtn,
                                          icon: Icons.copy,
                                          variant: AppButtonVariant.success,
                                          size: AppButtonSize.small,
                                          onPressed: () => CopyHelper.copy(context, body, customMessage: title),
                                        )),
                                      );
                                    },
                                  ),
                      ),
                    ],
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
