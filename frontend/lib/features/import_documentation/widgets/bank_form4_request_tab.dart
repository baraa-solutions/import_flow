import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import 'bank_form4/bank_form4_actions_bar.dart';
import 'bank_form4/bank_form4_details_card.dart';
import 'bank_form4/bank_form4_dialogs.dart';
import 'bank_form4/bank_form4_header.dart';
import 'bank_form4/bank_form4_history_table.dart';
import 'bank_form4/bank_form4_swift_card.dart';

/// Tab 0: Form 4 Request & Checklist coordinator widget (< 350 lines).
/// Encapsulates request form controllers, Swift pre-readiness workflow,
/// and document checklist with strict lifecycle disposal.
class BankForm4RequestTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final BankingDocumentModel? editingDoc;
  final VoidCallback onCancelEdit;
  final VoidCallback onSwitchToRegistry;
  final VoidCallback onOpenSearchAndClone;
  final VoidCallback onRefresh;

  const BankForm4RequestTab({
    super.key,
    required this.initialImportFileId,
    this.editingDoc,
    required this.onCancelEdit,
    required this.onSwitchToRegistry,
    required this.onOpenSearchAndClone,
    required this.onRefresh,
  });

  @override
  ConsumerState<BankForm4RequestTab> createState() => _BankForm4RequestTabState();
}

class _BankForm4RequestTabState extends ConsumerState<BankForm4RequestTab> {
  final _bankFormKey = GlobalKey<FormState>();
  int? _editingBankDocId;
  String? _editingBankDocCode;
  int? _form4ImportFileId;
  String _bankDocType = 'Form 4';
  String _form4Currency = 'USD';
  int? _selectedBankId;
  String _bankName = '';
  bool _isSavingForm4 = false;

  late final TextEditingController _bankAmountController;
  late final TextEditingController _form4RequestDateCtrl;
  late final TextEditingController _form4NotesCtrl;
  late final TextEditingController _docReferenceNumberCtrl;

  final Map<String, bool> _form4DocsChecklist = {
    'proforma_invoice': false,
    'packing_list': false,
    'certificate_of_origin': false,
    'bill_of_lading': false,
    'acid_notice': false,
    'marine_insurance': false,
    'bank_application': false,
    'admin_fee_receipt': false,
  };

  @override
  void initState() {
    super.initState();
    _bankAmountController = TextEditingController();
    _form4RequestDateCtrl = TextEditingController(
      text: DateTime.now().toString().substring(0, 10),
    );
    _form4NotesCtrl = TextEditingController();
    _docReferenceNumberCtrl = TextEditingController();

    _form4ImportFileId = widget.initialImportFileId;
    if (widget.editingDoc != null) {
      _loadDoc(widget.editingDoc!);
    }
  }

  @override
  void didUpdateWidget(BankForm4RequestTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingDoc != oldWidget.editingDoc && widget.editingDoc != null) {
      _loadDoc(widget.editingDoc!);
    }
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      setState(() => _form4ImportFileId = widget.initialImportFileId);
    }
  }

  void _loadDoc(BankingDocumentModel doc) {
    setState(() {
      _editingBankDocId = doc.bankDocId;
      _editingBankDocCode = doc.bankDocCode;
      _form4ImportFileId = doc.importFileId;
      _bankDocType = doc.docType;
      _docReferenceNumberCtrl.text = (doc.docReferenceNumber == 'PENDING') ? '' : doc.docReferenceNumber;
      _selectedBankId = doc.nafezaLinkedBankId ?? doc.swiftExecutingBankId ?? doc.bankId;
      _bankName = doc.bankName;
      _bankAmountController.text = doc.amount.toStringAsFixed(2);
      _form4Currency = doc.currencyCode.toUpperCase();
      _form4RequestDateCtrl.text = doc.requestDate ?? doc.issueDate;
      _form4NotesCtrl.text = doc.notes ?? '';
    });
  }

  void _resetForm() {
    setState(() {
      _editingBankDocId = null;
      _editingBankDocCode = null;
      _form4ImportFileId = null;
      _bankDocType = 'Form 4';
      _docReferenceNumberCtrl.clear();
      _selectedBankId = null;
      _bankName = 'National Bank of Egypt (NBE)';
      _bankAmountController.clear();
      _form4Currency = 'USD';
      _form4RequestDateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
      _form4NotesCtrl.clear();
    });
    widget.onCancelEdit();
  }

  @override
  void dispose() {
    _bankAmountController.dispose();
    _form4RequestDateCtrl.dispose();
    _form4NotesCtrl.dispose();
    _docReferenceNumberCtrl.dispose();
    super.dispose();
  }

  void _onSelectImportFile(
    int? val,
    List<ImportFileModel> importFiles,
    List<BankingDocumentModel> bankingDocs,
  ) {
    setState(() => _form4ImportFileId = val);
    if (val != null) {
      final existingDoc = bankingDocs.where((d) => d.importFileId == val).firstOrNull;
      if (existingDoc != null && _editingBankDocId == null) {
        _loadDoc(existingDoc);
      } else {
        final file = importFiles.where((f) => f.importFileId == val).firstOrNull;
        if (file != null && file.estimatedCost > 0) {
          _bankAmountController.text = file.estimatedCost.toStringAsFixed(2);
          _form4Currency = file.estimatedCostCurrency.isNotEmpty ? file.estimatedCostCurrency : 'USD';
        }
      }
    }
  }

  Future<void> _saveBankingDoc() async {
    if (!_bankFormKey.currentState!.validate()) return;
    if (_form4ImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.selectImportFileFirst, severity: AppSeverity.danger),
      );
      return;
    }

    setState(() => _isSavingForm4 = true);
    try {
      final payload = {
        'import_file_id': _form4ImportFileId,
        'doc_type': _bankDocType,
        'bank_id': _selectedBankId,
        'bank_name': _bankName,
        'amount': double.tryParse(_bankAmountController.text) ?? 0.0,
        'currency_code': _form4Currency,
        'request_date': _form4RequestDateCtrl.text.trim(),
        'doc_reference_number': _docReferenceNumberCtrl.text.trim().isNotEmpty
            ? _docReferenceNumberCtrl.text.trim()
            : 'PENDING',
        'notes': _form4NotesCtrl.text.trim(),
      };

      if (_editingBankDocId != null) {
        await ref.read(bankingDocumentsProvider.notifier).updateBankingDocument(_editingBankDocId!, payload);
      } else {
        await ref.read(bankingDocumentsProvider.notifier).createBankingDocument(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.form4SavedSuccess, severity: AppSeverity.success),
        );
        _resetForm();
        widget.onSwitchToRegistry();
      }
    } catch (e) {
      if (mounted) {
        BankForm4Dialogs.showError(context, title: context.l10n.form4SaveError, error: e);
      }
    } finally {
      if (mounted) setState(() => _isSavingForm4 = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnersState = ref.watch(partnersProvider);
    final banksList = (partnersState.valueOrNull ?? [])
        .where((p) => p.partnerType.contains('Bank') || p.partnerType.contains('بنك'))
        .toList();
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bankingDocs = ref.watch(bankingDocumentsProvider).valueOrNull ?? [];

    final activeDoc = (_editingBankDocId != null)
        ? bankingDocs.where((d) => d.bankDocId == _editingBankDocId).firstOrNull
        : (_form4ImportFileId != null
            ? bankingDocs.where((d) => d.importFileId == _form4ImportFileId).firstOrNull
            : null);

    final historyDocs = _form4ImportFileId != null
        ? bankingDocs.where((d) => d.importFileId == _form4ImportFileId).toList()
        : <BankingDocumentModel>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return SelectionArea(
          child: Form(
            key: _bankFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BankForm4Header(
                  isMobile: isMobile,
                  isDark: isDark,
                  editingBankDocId: _editingBankDocId,
                  editingBankDocCode: _editingBankDocCode,
                  selectedImportFileId: _form4ImportFileId,
                  importFiles: importFiles,
                  onOpenSearchAndClone: widget.onOpenSearchAndClone,
                  onCancelEdit: _resetForm,
                  onSelectImportFile: (val) => _onSelectImportFile(val, importFiles, bankingDocs),
                ),
                const SizedBox(height: 20),
                BankForm4SwiftCard(
                  importFileId: _form4ImportFileId,
                  activeDoc: activeDoc,
                  isDark: isDark,
                  isMobile: isMobile,
                  onRefresh: widget.onRefresh,
                  onOpenFormalLetter: () => BankForm4Dialogs.showFormalLetterGenerator(
                    context,
                    importFileId: _form4ImportFileId,
                  ),
                ),
                const SizedBox(height: 20),
                BankForm4DetailsCard(
                  isMobile: isMobile,
                  isDark: isDark,
                  bankDocType: _bankDocType,
                  onDocTypeChanged: (val) => setState(() => _bankDocType = val ?? 'Form 4'),
                  docReferenceNumberCtrl: _docReferenceNumberCtrl,
                  selectedBankId: _selectedBankId,
                  banksList: banksList,
                  onBankChanged: (bankId, bankName) {
                    setState(() {
                      _selectedBankId = bankId;
                      _bankName = bankName;
                    });
                  },
                  activeDoc: activeDoc,
                  bankAmountController: _bankAmountController,
                  form4Currency: _form4Currency,
                  onCurrencyChanged: (val) => setState(() => _form4Currency = val ?? 'USD'),
                  currencies: currencies,
                  form4RequestDateCtrl: _form4RequestDateCtrl,
                  form4NotesCtrl: _form4NotesCtrl,
                  checklist: _form4DocsChecklist,
                  onToggleChecklistItem: (key) {
                    setState(() {
                      _form4DocsChecklist[key] = !(_form4DocsChecklist[key] ?? false);
                    });
                  },
                ),
                const SizedBox(height: 24),
                BankForm4ActionsBar(
                  isSaving: _isSavingForm4,
                  isEditing: _editingBankDocId != null,
                  hasActiveDoc: activeDoc != null,
                  canSubmit: activeDoc?.canSubmitForm4 ?? false,
                  blockersCount: activeDoc?.blockers.length ?? 0,
                  onSave: _saveBankingDoc,
                  onSwitchToRegistry: widget.onSwitchToRegistry,
                ),
                BankForm4HistoryTable(
                  isDark: isDark,
                  isMobile: isMobile,
                  selectedImportFileId: _form4ImportFileId,
                  historyDocs: historyDocs,
                  onEditDoc: _loadDoc,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
