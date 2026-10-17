import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../widgets/idoc_ui_b.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import '../widgets/search_and_clone_bank_form4_dialog.dart';
import '../widgets/formal_letter_generator_dialog.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/widgets/table_row_clone_helper.dart';

class BankForm4Screen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;

  const BankForm4Screen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
  });

  @override
  ConsumerState<BankForm4Screen> createState() => _BankForm4ScreenState();
}

class _BankForm4ScreenState extends ConsumerState<BankForm4Screen> {
  // Active Vertical Sub-Tab:
  // 0: 📝 طلب وتوثيق نموذج 4 (Form 4 Request & Checklist)
  // 1: 📋 سجل النماذج البنكية والتوثيق (Bank Form 4 Registry)
  int _selectedSubTab = 0;

  // Form 4 State (BP-015)
  final _bankFormKey = GlobalKey<FormState>();
  int? _editingBankDocId;
  String? _editingBankDocCode;
  int? _form4ImportFileId;
  final TextEditingController _bankAmountController = TextEditingController();
  String _bankDocType = 'Form 4';
  String _form4Currency = 'USD';
  int? _selectedBankId;
  String _bankName = '';
  final TextEditingController _form4RequestDateCtrl = TextEditingController(text: DateTime.now().toString().substring(0, 10));
  final TextEditingController _form4NotesCtrl = TextEditingController();
  final TextEditingController _docReferenceNumberCtrl = TextEditingController();

  String _form4SearchQuery = '';
  bool _isSavingForm4 = false;

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
    _selectedSubTab = widget.initialSubTab;
    _form4ImportFileId = widget.initialImportFileId;
    Future.microtask(() {
      _refreshData();
    });
  }

  @override
  void didUpdateWidget(BankForm4Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(() => _selectedSubTab = widget.initialSubTab);
    }
    if (oldWidget.initialImportFileId != widget.initialImportFileId) {
      setState(() => _form4ImportFileId = widget.initialImportFileId);
    }
  }

  void _refreshData() {
    if (!ref.read(partnersProvider).isLoading) {
      ref.read(partnersProvider.notifier).fetchPartners();
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(bankingDocumentsProvider).isLoading) {
      ref.read(bankingDocumentsProvider.notifier).fetchBankingDocuments();
    }
    if (!ref.read(currenciesProvider).isLoading) {
      ref.read(currenciesProvider.notifier).fetchCurrencies();
    }
  }

  @override
  void dispose() {
    _bankAmountController.dispose();
    _form4RequestDateCtrl.dispose();
    _form4NotesCtrl.dispose();
    _docReferenceNumberCtrl.dispose();
    super.dispose();
  }

  void _loadForm4ForEdit(BankingDocumentModel doc) {
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
      _selectedSubTab = 0; // Switch to Request Tab
    });
  }

  void _resetForm4Form() {
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
  }

  void _openSearchAndCloneBankForm4Dialog() {
    final bankingDocs = ref.read(bankingDocumentsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneBankForm4Dialog(
        bankingDocs: bankingDocs,
        onSelectDoc: _onCloneBankDocSelected,
      ),
    );
  }

  void _onCloneBankDocSelected(BankingDocumentModel doc) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: CloneEntityReviewDialog(
            entityType: context.l10n.idocBBankCloneEntity,
            sourceCode: doc.bankDocCode,
            sourceTitle: doc.bankName,
            suggestedNewCode: 'FORM4-2026-DRAFT',
            copiedFieldsSummary: {
              context.l10n.idocBBankCloneFieldBank: doc.bankName,
              context.l10n.idocBBankCloneFieldAmount: '${doc.amount.toStringAsFixed(2)} ${doc.currencyCode}',
              context.l10n.idocBCloneFieldImportFile: doc.importFileCode ?? (doc.importFileId != null ? 'IMP-${doc.importFileId}' : '-'),
              context.l10n.idocBBankCloneFieldNotes: doc.notes ?? '-',
            },
            mandatorilyResetFields: [
              context.l10n.idocBBankCloneReset1,
              context.l10n.idocBBankCloneReset2,
              context.l10n.idocBBankCloneReset3,
              context.l10n.idocBBankCloneReset4,
            ],
            allowCopyLineItems: false,
            allowCopyAttachments: false,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              setState(() {
                _editingBankDocId = null;
                _editingBankDocCode = null;
                _selectedSubTab = 0;
                _form4ImportFileId = doc.importFileId;
                _bankDocType = doc.docType;
                _docReferenceNumberCtrl.clear();
                _selectedBankId = doc.bankId;
                _bankName = doc.bankName;
                _bankAmountController.text = doc.amount.toStringAsFixed(2);
                _form4Currency = doc.currencyCode;
                _form4RequestDateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
                _form4NotesCtrl.text = (doc.notes != null && doc.notes!.isNotEmpty)
                    ? '${doc.notes}${TableRowCloneHelper.copySuffix}'
                    : '(Cloned from previous doc)';
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.cloneBankForm4Success),
                    backgroundColor: AppTheme.wcagEmerald,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _onCloneBankDocRow(BankingDocumentModel doc) {
    _onCloneBankDocSelected(doc);
  }

  void _openReceiveBankDocDialog(BankingDocumentModel doc) {
    final formKey = GlobalKey<FormState>();
    final numCtrl = TextEditingController(text: doc.docReferenceNumber != 'PENDING' ? doc.docReferenceNumber : '');
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final notesCtrl = TextEditingController(text: doc.notes ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.verified, color: AppTheme.wcagEmerald),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.idocBBankReceiptTitle(doc.docType),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.idocBBankReceiptIntro(doc.bankName),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: numCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.idocBBankReceiptNumLabel(doc.docType),
                        hintText: context.l10n.idocBBankReceiptNumHint,
                        prefixIcon: const Icon(Icons.confirmation_number_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? (context.l10n.idocBBankReceiptNumRequired)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: dateCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.idocBBankReceiptDateLabel,
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? (context.l10n.idocBBankReceiptDateRequired)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.l10n.idocBBankReceiptNotesLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IdocBUi.fit(AppButton(label: context.l10n.cancel, onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(), variant: AppButtonVariant.secondary)),
              IdocBUi.fit(AppButton(label: isSubmitting
                    ? (context.l10n.idocBBankEndorsing)
                    : (context.l10n.idocBBankEndorseAndLink), onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isSubmitting = true);
                        try {
                          await ref.read(bankingDocumentsProvider.notifier).receiveBankingDocument(
                            doc.bankDocId,
                            {
                              'form4_number': numCtrl.text.trim(),
                              'received_date': dateCtrl.text.trim(),
                              'notes': notesCtrl.text.trim(),
                            },
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.idocBBankEndorsedSuccess),
                                backgroundColor: AppTheme.wcagEmerald,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (mounted) {
                            showErrorDetailsDialog(
                              context,
                              title: context.l10n.idocBBankEndorseError,
                              error: e,
                            );
                          }
                        }
                      }, icon: Icons.check, isLoading: isSubmitting)),
            ],
          );
        },
      ),
    );
  }

  void _openPullTaxCodingSheetDialog(BankingDocumentModel doc) {
    final partners = ref.read(partnersProvider).valueOrNull ?? [];
    final brokers = partners.where((p) =>
      p.partnerType.contains('Customs') ||
      p.partnerType.contains('مستخلص') ||
      p.partnerType.contains('Broker')
    ).toList();

    int? selectedBrokerId = doc.taxCodingBrokerId ?? (brokers.isNotEmpty ? brokers.first.providerId : null);
    final dateCtrl = TextEditingController(text: doc.taxCodingPulledDate ?? DateTime.now().toIso8601String().substring(0, 10));
    final fileUrlCtrl = TextEditingController(text: doc.taxCodingSheetFileUrl ?? '');
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.file_download_outlined, color: AppTheme.wcagCobalt),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تسجيل سحب شيت التكويد الضريبي (المستخلص)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'يقوم المستخلص الجمركي بسحب شيت الأصناف الضريبي من منصة نافذة لتسليمه لمحاسب الشركة لتكويده.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SearchableDropdownField<int>(
                    labelText: 'المستخلص الجمركي المسئول',
                    hintText: 'اختر المستخلص الجمركي',
                    value: selectedBrokerId,
                    isRequired: true,
                    items: brokers.map((b) => SearchableDropdownItem<int>(
                      value: b.providerId ?? 0,
                      label: '${b.partnerName} (${b.partnerCode})',
                    )).toList(),
                    onChanged: (val) => setModalState(() => selectedBrokerId = val),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ سحب الشيت من نافذة',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: fileUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رابط / مسار ملف الشيت (اختياري)',
                      prefixIcon: Icon(Icons.attachment_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات المستخلص',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IdocBUi.fit(AppButton(
                label: context.l10n.cancel,
                variant: AppButtonVariant.secondary,
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              )),
              IdocBUi.fit(AppButton(
                label: 'تأكيد السحب',
                icon: Icons.check,
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setModalState(() => isSubmitting = true);
                        try {
                          await ref.read(bankingDocumentsProvider.notifier).pullTaxCodingSheet(
                            doc.bankDocId,
                            {
                              'broker_id': selectedBrokerId,
                              'pulled_date': dateCtrl.text.trim(),
                              'file_url': fileUrlCtrl.text.trim().isNotEmpty ? fileUrlCtrl.text.trim() : null,
                              'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                            },
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('تم تسجيل سحب شيت التكويد الضريبي بنجاح ومطالبة المحاسب بالرفع والتكويد'),
                              backgroundColor: AppTheme.wcagEmerald,
                            ),
                          );
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            showErrorDetailsDialog(ctx, title: 'خطأ في تسجيل سحب الشيت', error: e);
                          }
                        }
                      },
              )),
            ],
          );
        },
      ),
    );
  }

  void _openUploadTaxCodingSheetDialog(BankingDocumentModel doc) {
    final accountantCtrl = TextEditingController(text: doc.taxCodingAccountantName ?? 'محاسب الشركة المعتمد');
    final dateCtrl = TextEditingController(text: doc.taxCodingUploadedDate ?? DateTime.now().toIso8601String().substring(0, 10));
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.upload_file_outlined, color: AppTheme.wcagEmerald),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تأكيد رفع وتكويد الشيت على نافذة (المحاسب)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'يقوم محاسب الشركة برفع وتكويد الأصناف على منصة نافذة باستخدام التوكن الضريبي الخاص بالشركة (EGS/GS1).',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: accountantCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المحاسب المسئول عن التكويد',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ نجاح الرفع والتكويد',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات التكويد ورقم الإقرار الضريبي إن وجد',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IdocBUi.fit(AppButton(
                label: context.l10n.cancel,
                variant: AppButtonVariant.secondary,
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              )),
              IdocBUi.fit(AppButton(
                label: 'تأكيد التكويد والرفع',
                icon: Icons.check,
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setModalState(() => isSubmitting = true);
                        try {
                          await ref.read(bankingDocumentsProvider.notifier).uploadTaxCodingSheet(
                            doc.bankDocId,
                            {
                              'accountant_name': accountantCtrl.text.trim(),
                              'uploaded_date': dateCtrl.text.trim(),
                              'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                            },
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('تم تأكيد رفع وتكويد الأصناف ضريبياً على نافذة بنجاح'),
                              backgroundColor: AppTheme.wcagEmerald,
                            ),
                          );
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            showErrorDetailsDialog(ctx, title: 'خطأ في تأكيد التكويد', error: e);
                          }
                        }
                      },
              )),
            ],
          );
        },
      ),
    );
  }

  void _openVerifyItemsDialog(BankingDocumentModel doc) {
    final totalCtrl = TextEditingController(text: doc.itemsCountTotal > 0 ? '${doc.itemsCountTotal}' : '1');
    final codedCtrl = TextEditingController(text: doc.itemsCountCoded > 0 ? '${doc.itemsCountCoded}' : totalCtrl.text);
    final selectedBodies = Set<String>.from(doc.regulatoryBodiesDetected);
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.fact_check_outlined, color: AppTheme.wcagEmerald),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تأكيد سحب الأصناف والتحقق من التكويد 100% (المستخلص)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'يقوم المستخلص بسحب الأصناف على نافذة للتأكد من نجاح التكويد 100% واكتشاف أي جهات عرض رقابية.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: totalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'إجمالي عدد الأصناف',
                              prefixIcon: Icon(Icons.numbers),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: codedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'عدد الأصناف المكودة بنجاح',
                              prefixIcon: Icon(Icons.check_circle_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'جهات العرض الرقابية المكتشفة على نافذة:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('GOEIC (صادرات وواردات)', selectedBodies.contains('GOEIC'), () {
                          setModalState(() {
                            if (selectedBodies.contains('GOEIC')) {
                              selectedBodies.remove('GOEIC');
                            } else {
                              selectedBodies.add('GOEIC');
                            }
                          });
                        }),
                        _buildFilterChip('NFSA (سلامة الغذاء)', selectedBodies.contains('NFSA'), () {
                          setModalState(() {
                            if (selectedBodies.contains('NFSA')) {
                              selectedBodies.remove('NFSA');
                            } else {
                              selectedBodies.add('NFSA');
                            }
                          });
                        }),
                        _buildFilterChip('Radiation (هيئة الطاقة الذرية)', selectedBodies.contains('Radiation'), () {
                          setModalState(() {
                            if (selectedBodies.contains('Radiation')) {
                              selectedBodies.remove('Radiation');
                            } else {
                              selectedBodies.add('Radiation');
                            }
                          });
                        }),
                        _buildFilterChip('Phytosanitary (حجر زراعي/بيطري)', selectedBodies.contains('Phytosanitary'), () {
                          setModalState(() {
                            if (selectedBodies.contains('Phytosanitary')) {
                              selectedBodies.remove('Phytosanitary');
                            } else {
                              selectedBodies.add('Phytosanitary');
                            }
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات فحص الأصناف',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IdocBUi.fit(AppButton(
                label: context.l10n.cancel,
                variant: AppButtonVariant.secondary,
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              )),
              IdocBUi.fit(AppButton(
                label: 'تأكيد السحب والفحص',
                icon: Icons.check,
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final total = int.tryParse(totalCtrl.text) ?? 1;
                        final coded = int.tryParse(codedCtrl.text) ?? total;
                        setModalState(() => isSubmitting = true);
                        try {
                          await ref.read(bankingDocumentsProvider.notifier).verifyItems(
                            doc.bankDocId,
                            {
                              'items_pulled_verified': true,
                              'items_count_total': total,
                              'items_count_coded': coded,
                              'regulatory_bodies': selectedBodies.toList(),
                              'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                            },
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('تم تأكيد سحب وفحص الأصناف والتكويد 100% بنجاح'),
                              backgroundColor: AppTheme.wcagEmerald,
                            ),
                          );
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            showErrorDetailsDialog(ctx, title: 'خطأ في تأكيد فحص الأصناف', error: e);
                          }
                        }
                      },
              )),
            ],
          );
        },
      ),
    );
  }

  void _openLinkNafezaBankDialog(BankingDocumentModel doc) {
    final partners = ref.read(partnersProvider).valueOrNull ?? [];
    final banks = partners.where((p) => p.partnerType.contains('Bank') || p.partnerType.contains('بنك')).toList();
    int? selectedBankId = doc.nafezaLinkedBankId ?? doc.swiftExecutingBankId ?? (banks.isNotEmpty ? banks.first.providerId : null);
    final dateCtrl = TextEditingController(text: doc.nafezaBankLinkDate ?? DateTime.now().toIso8601String().substring(0, 10));
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isMatchingSwift = doc.swiftExecutingBankId != null && selectedBankId == doc.swiftExecutingBankId;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.link, color: AppTheme.wcagCobalt),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ربط الشهادة بالبنك على منصة نافذة (المستخلص)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'يقوم المستخلص بربط الإقرار الجمركي على نافذة بالبنك المنفذ لسويفت التحويل حصراً حتى يتمكن البنك من إقرار نموذج 4.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (doc.swiftExecutingBankName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.wcagCobalt.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.wcagCobalt.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz, size: 16, color: AppTheme.wcagCobalt),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'البنك المنفذ لسويفت التحويل: ${doc.swiftExecutingBankName}'
                              '${doc.swiftReferenceNo != null ? " (سويفت: ${doc.swiftReferenceNo})" : ""}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.wcagCobalt),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SearchableDropdownField<int>(
                    labelText: 'البنك المربوط عليه الشهادة على نافذة',
                    hintText: 'اختر البنك',
                    value: selectedBankId,
                    isRequired: true,
                    items: banks.map((b) => SearchableDropdownItem<int>(
                      value: b.providerId ?? 0,
                      label: '${b.partnerName} (${b.partnerCode})'
                          '${b.providerId == doc.swiftExecutingBankId ? " ⭐️ [بنك السويفت]" : ""}',
                    )).toList(),
                    onChanged: (val) => setModalState(() => selectedBankId = val),
                  ),
                  const SizedBox(height: 8),

                  if (!isMatchingSwift && doc.swiftExecutingBankId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.crimson.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, size: 16, color: AppTheme.crimson),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'تنبيه: البنك المختار لا يطابق بنك سويفت التحويل! يجب الربط بنفس بنك السويفت.',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.crimson, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  TextFormField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ إتمام الربط البنكي',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الربط البنكي ورقم التأكيد على نافذة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IdocBUi.fit(AppButton(
                label: context.l10n.cancel,
                variant: AppButtonVariant.secondary,
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              )),
              IdocBUi.fit(AppButton(
                label: 'تأكيد الربط البنكي',
                icon: Icons.link,
                isLoading: isSubmitting,
                onPressed: isSubmitting || selectedBankId == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setModalState(() => isSubmitting = true);
                        try {
                          await ref.read(bankingDocumentsProvider.notifier).linkNafezaBank(
                            doc.bankDocId,
                            {
                              'nafeza_linked_bank_id': selectedBankId,
                              'link_date': dateCtrl.text.trim(),
                              'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                            },
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('تم تسجيل الربط البنكي على نافذة بنجاح ومطابقة البنك'),
                              backgroundColor: AppTheme.wcagEmerald,
                            ),
                          );
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            showErrorDetailsDialog(ctx, title: 'خطأ في الربط البنكي', error: e);
                          }
                        }
                      },
              )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _initializeReadinessDraft() async {
    if (_form4ImportFileId == null) return;
    try {
      final created = await ref.read(bankingDocumentsProvider.notifier).createBankingDocument({
        'import_file_id': _form4ImportFileId,
        'doc_type': _bankDocType,
        'bank_id': _selectedBankId,
        'bank_name': _bankName.isNotEmpty ? _bankName : 'National Bank of Egypt (NBE)',
        'amount': double.tryParse(_bankAmountController.text) ?? 0.0,
        'currency_code': _form4Currency,
        'request_date': _form4RequestDateCtrl.text.trim(),
        'doc_reference_number': 'PENDING',
        'notes': 'مسودة أولية لتتبع جاهزية ما قبل نموذج 4',
      });
      if (created != null && mounted) {
        _loadForm4ForEdit(created);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم بدء مسار الجاهزية وحفظ مسودة الطلب بنجاح'),
            backgroundColor: AppTheme.wcagEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: 'خطأ في بدء مسار الجاهزية', error: e);
      }
    }
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.wcagCobalt.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.wcagCobalt : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: isSelected ? AppTheme.wcagCobalt : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.wcagCobalt : AppTheme.textStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreForm4ReadinessPipeline(BuildContext context, BankingDocumentModel? doc, bool isDark, bool isMobile) {
    if (_form4ImportFileId == null) {
      return const SizedBox.shrink();
    }

    final isDocReady = doc != null && doc.canSubmitForm4;
    final hasBlockers = doc != null && doc.blockers.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDocReady
              ? AppTheme.wcagEmerald
              : (hasBlockers ? AppTheme.orange : (isDark ? AppTheme.darkBorder : AppTheme.border)),
          width: isDocReady || hasBlockers ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Readiness Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDocReady ? AppTheme.wcagEmerald : AppTheme.wcagCobalt).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDocReady ? Icons.verified : Icons.account_balance,
                  color: isDocReady ? AppTheme.wcagEmerald : AppTheme.wcagCobalt,
                  size: 22,
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
                          'مسار جاهزية ما قبل طلب نموذج 4 (Pre-Form 4 Readiness)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.wcagCobalt.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'BP-015',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.wcagCobalt,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الخطوات الإلزامية قبل مخاطبة البنك: سحب شيت التكويد ← رفع وتكويد المحاسب ← سحب وفحص الأصناف ← الربط البنكي بنافذة',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Overall Status Badge
              _buildReadinessOverallBadge(doc, isDark),
            ],
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? AppTheme.darkBorder : AppTheme.border),
          const SizedBox(height: 16),

          if (doc == null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.08) : AppTheme.infoBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.wcagCobalt.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.wcagCobalt, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لم يتم إنشاء مسودة جلسة توثيق بنكي لهذه الشحنة بعد. اضغط على الزر لبدء مسار الجاهزية والربط البنكي.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IdocBUi.fit(AppButton(
                    label: 'بدء مسار الجاهزية',
                    icon: Icons.play_arrow,
                    onPressed: _initializeReadinessDraft,
                  )),
                ],
              ),
            ),
          ] else ...[
            // Stepper Cards (Stage 1, Stage 2, Stage 3)
            if (isMobile) ...[
              _buildStage1TaxCodingCard(doc, isDark),
              const SizedBox(height: 12),
              _buildStage2ItemsVerificationCard(doc, isDark),
              const SizedBox(height: 12),
              _buildStage3NafezaBankLinkCard(doc, isDark),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildStage1TaxCodingCard(doc, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStage2ItemsVerificationCard(doc, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStage3NafezaBankLinkCard(doc, isDark)),
                ],
              ),
            ],

            // Blockers Warning Banner
            if (hasBlockers) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.crimson.withValues(alpha: 0.15) : AppTheme.dangerBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'موانع تقديم نموذج 4 للبنك (${doc.blockers.length} متطلب غير مستوفى):',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.crimson,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...doc.blockers.map((blocker) => Padding(
                      padding: const EdgeInsetsDirectional.only(start: 26, bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              blocker,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.dangerForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],

            // Bottom Action Bar: Formal Cover Letter & Readiness Confirmation
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IdocBUi.fit(AppButton(
                      label: 'خطاب تغطية بنكي لنموذج 4',
                      icon: Icons.mark_email_read_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => FormalLetterGeneratorDialog.show(
                        context,
                        importFileId: _form4ImportFileId,
                      ),
                    )),
                    if (doc.swiftReferenceNo != null && doc.swiftReferenceNo!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.wcagCobalt.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.wcagCobalt.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_horiz, size: 16, color: AppTheme.wcagCobalt),
                            const SizedBox(width: 6),
                            Text(
                              'سويفت التحويل: ${doc.swiftReferenceNo}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.wcagCobalt),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (doc.canSubmitForm4)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.wcagEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AppTheme.wcagEmerald),
                        SizedBox(width: 6),
                        Text(
                          'مستوفي لشروط تقديم نموذج 4',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.wcagEmerald),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadinessOverallBadge(BankingDocumentModel? doc, bool isDark) {
    if (doc == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.textMuted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'لم تبدأ الجاهزية',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
        ),
      );
    }

    if (doc.canSubmitForm4) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.wcagEmerald.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.wcagEmerald),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 14, color: AppTheme.wcagEmerald),
            SizedBox(width: 4),
            Text(
              'جاهز للبنك (100%)',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.wcagEmerald),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.orange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pending_actions, size: 14, color: AppTheme.orange),
          const SizedBox(width: 4),
          Text(
            'معلق (${doc.blockers.length} متطلبات)',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildStage1TaxCodingCard(BankingDocumentModel doc, bool isDark) {
    final isPulled = doc.taxCodingPulledDate != null;
    final isUploaded = doc.taxCodingUploadedDate != null;
    final isDone = isPulled && isUploaded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDone ? AppTheme.wcagEmerald : (isDark ? AppTheme.darkBorder : AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.receipt_long_outlined,
                color: isDone ? AppTheme.wcagEmerald : AppTheme.wcagCobalt,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '1. شيت التكويد الضريبي',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'سحب مستخلص ← تكويد محاسب',
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
          ),
          const SizedBox(height: 10),

          // Sub-step A: Pulled
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isPulled ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'أ) سحب الشيت (مستخلص)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isPulled ? AppTheme.wcagEmerald : null),
                    ),
                    Icon(isPulled ? Icons.check : Icons.hourglass_top, size: 14, color: isPulled ? AppTheme.wcagEmerald : AppTheme.orange),
                  ],
                ),
                if (isPulled) ...[
                  const SizedBox(height: 2),
                  Text('التاريخ: ${doc.taxCodingPulledDate}', style: const TextStyle(fontSize: 10.5)),
                  if (doc.taxCodingBrokerName != null)
                    Text('المستخلص: ${doc.taxCodingBrokerName}', style: const TextStyle(fontSize: 10.5)),
                ] else ...[
                  const SizedBox(height: 6),
                  IdocBUi.fit(AppButton(
                    label: 'سحب الشيت',
                    icon: Icons.download,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _openPullTaxCodingSheetDialog(doc),
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Sub-step B: Uploaded
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isUploaded ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ب) رفع وتكويد نافذة (محاسب)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isUploaded ? AppTheme.wcagEmerald : null),
                    ),
                    Icon(isUploaded ? Icons.check : Icons.hourglass_top, size: 14, color: isUploaded ? AppTheme.wcagEmerald : AppTheme.orange),
                  ],
                ),
                if (isUploaded) ...[
                  const SizedBox(height: 2),
                  Text('التاريخ: ${doc.taxCodingUploadedDate}', style: const TextStyle(fontSize: 10.5)),
                  if (doc.taxCodingAccountantName != null)
                    Text('المحاسب: ${doc.taxCodingAccountantName}', style: const TextStyle(fontSize: 10.5)),
                ] else ...[
                  const SizedBox(height: 6),
                  IdocBUi.fit(AppButton(
                    label: 'رفع وتكويد الشيت',
                    icon: Icons.upload,
                    variant: AppButtonVariant.secondary,
                    onPressed: isPulled ? () => _openUploadTaxCodingSheetDialog(doc) : null,
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage2ItemsVerificationCard(BankingDocumentModel doc, bool isDark) {
    final isVerified = doc.itemsPulledVerified;
    final codedRatio = doc.itemsCountTotal > 0 ? (doc.itemsCountCoded / doc.itemsCountTotal).clamp(0.0, 1.0) : 0.0;
    final isFullyCoded = doc.itemsCountTotal > 0 && doc.itemsCountCoded == doc.itemsCountTotal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isVerified && isFullyCoded) ? AppTheme.wcagEmerald : (isDark ? AppTheme.darkBorder : AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                (isVerified && isFullyCoded) ? Icons.check_circle : Icons.fact_check_outlined,
                color: (isVerified && isFullyCoded) ? AppTheme.wcagEmerald : AppTheme.wcagCobalt,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '2. سحب وفحص الأصناف',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'تأكيد التكويد 100% وجهات العرض',
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
          ),
          const SizedBox(height: 10),

          // Verification Status & Counts
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isVerified ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'أصناف مكودة: ${doc.itemsCountCoded} / ${doc.itemsCountTotal}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(codedRatio * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isFullyCoded ? AppTheme.wcagEmerald : AppTheme.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: codedRatio,
                    minHeight: 5,
                    backgroundColor: isDark ? AppTheme.darkBorder : AppTheme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFullyCoded ? AppTheme.wcagEmerald : AppTheme.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (doc.regulatoryBodiesDetected.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: doc.regulatoryBodiesDetected.map((body) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        body,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.orange),
                      ),
                    )).toList(),
                  ),
                ] else ...[
                  Text(
                    'جهات العرض: لا توجد جهات فحص خاصة',
                    style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          IdocBUi.fit(AppButton(
            label: isVerified ? 'إعادة تأكيد فحص الأصناف' : 'تأكيد فحص الأصناف',
            icon: Icons.check_circle_outline,
            variant: AppButtonVariant.secondary,
            onPressed: () => _openVerifyItemsDialog(doc),
          )),
        ],
      ),
    );
  }

  Widget _buildStage3NafezaBankLinkCard(BankingDocumentModel doc, bool isDark) {
    final isLinked = doc.nafezaBankLinkStatus.toUpperCase() == 'LINKED';
    final isMatching = doc.isBankMatchingSwift;
    final isSuccess = isLinked && isMatching;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess ? AppTheme.wcagEmerald : (!isMatching ? AppTheme.crimson : (isDark ? AppTheme.darkBorder : AppTheme.border)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.link,
                color: isSuccess ? AppTheme.wcagEmerald : (!isMatching ? AppTheme.crimson : AppTheme.wcagCobalt),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '3. الربط البنكي على نافذة',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'الربط الحصري ببنك سويفت التحويل',
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
          ),
          const SizedBox(height: 10),

          // Bank Info Container
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isSuccess ? AppTheme.wcagEmerald : (!isMatching ? AppTheme.crimson : AppTheme.textMuted)).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('بنك السويفت المنفذ:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    Icon(
                      isMatching ? Icons.verified : Icons.warning_amber_rounded,
                      size: 14,
                      color: isMatching ? AppTheme.wcagEmerald : AppTheme.crimson,
                    ),
                  ],
                ),
                Text(
                  doc.swiftExecutingBankName ?? 'لم يتم رصد سويفت بعد',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('البنك المربوط بنافذة:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Text(
                  doc.nafezaLinkedBankName ?? 'لم يتم الربط على نافذة بعد',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isLinked ? (isMatching ? AppTheme.wcagEmerald : AppTheme.crimson) : AppTheme.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          IdocBUi.fit(AppButton(
            label: isLinked ? 'تعديل الربط البنكي' : 'ربط الشهادة بالبنك على نافذة',
            icon: Icons.link,
            variant: AppButtonVariant.secondary,
            onPressed: () => _openLinkNafezaBankDialog(doc),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final density = ref.watch(displayDensityProvider);
    final bankingDocs = ref.watch(bankingDocumentsProvider).valueOrNull ?? [];

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.note_add_outlined,
        titleEn: 'Form 4 Request & Checklist',
        titleAr: 'طلب وتوثيق نموذج 4',
      ),
      VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'Bank Form 4 Registry',
        titleAr: 'سجل النماذج البنكية',
        badge: bankingDocs.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.wcagCobalt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${bankingDocs.length}',
                  style: TextStyle(
                    color: AppTheme.wcagCobalt,
                    fontSize: DisplayDensityMode.clampFontSize(11.0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    ];

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _openSearchAndCloneBankForm4Dialog,
      },
      child: Focus(
        autofocus: true,
        child: VerticalStageScaffold(
          stageCode: 'PHASE-4: STEP_12',
          titleEn: 'Bank Form 4 & Financial Endorsement',
          titleAr: 'المستندات والتوثيق البنكي ونموذج 4',
          headerIcon: Icons.account_balance_outlined,
          headerColor: AppTheme.wcagCobalt,
          tabs: tabs,
          selectedIndex: _selectedSubTab,
          onTabSelected: (index) {
            setState(() => _selectedSubTab = index);
            if (index == 1) {
              ref.read(bankingDocumentsProvider.notifier).fetchBankingDocuments();
            }
          },
          selectedImportFileId: _form4ImportFileId,
          onShipmentStatusChanged: _refreshData,
          headerActions: [
            IconButton(
              key: const Key('searchAndCloneBankForm4Btn'),
              icon: Icon(Icons.copy_all, color: AppTheme.cloudWhite, size: density.buttonIconSize),
              tooltip: context.l10n.searchAndCloneBankForm4Btn,
              onPressed: _openSearchAndCloneBankForm4Dialog,
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: AppTheme.cloudWhite, size: density.buttonIconSize),
              tooltip: context.l10n.refresh,
              onPressed: _refreshData,
            ),
          ],
          body: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 92),
            child: _selectedSubTab == 0 ? _buildForm4RequestTab() : _buildForm4HistoryRegistryTab(),
          ),
        ),
      ),
    );
  }

  // --- SUB-VIEW 0: REQUEST TAB ---
  Widget _buildForm4RequestTab() {
    final partnersState = ref.watch(partnersProvider);
    final banksList = (partnersState.valueOrNull ?? []).where((p) => p.partnerType.contains('Bank') || p.partnerType.contains('بنك')).toList();
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bankingDocs = ref.watch(bankingDocumentsProvider).valueOrNull ?? [];

    final activeDoc = (_editingBankDocId != null)
        ? bankingDocs.where((d) => d.bankDocId == _editingBankDocId).firstOrNull
        : (_form4ImportFileId != null
            ? bankingDocs.where((d) => d.importFileId == _form4ImportFileId).firstOrNull
            : null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final docTypeField = SearchableDropdownField<String>(
          labelText: context.l10n.idocBBankDocTypeLabel,
          hintText: context.l10n.idocBBankDocTypeHint,
          value: _bankDocType,
          isRequired: true,
          items: [
            SearchableDropdownItem<String>(
              value: 'Form 4',
              label: context.l10n.idocBBankTypeForm4,
            ),
            SearchableDropdownItem<String>(
              value: 'Letter of Credit (L/C)',
              label: context.l10n.idocBBankTypeLc,
            ),
            SearchableDropdownItem<String>(
              value: 'Form 9',
              label: context.l10n.idocBBankTypeForm9,
            ),
          ],
          onChanged: (val) => setState(() => _bankDocType = val ?? 'Form 4'),
        );
        final refNoField = TextFormField(
          controller: _docReferenceNumberCtrl,
          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: context.l10n.idocBBankRefLabel,
            hintText: context.l10n.idocBBankRefHint,
            prefixIcon: const Icon(Icons.pin_outlined),
            border: const OutlineInputBorder(),
          ),
        );

        return Form(
          key: _bankFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action / Header Bar with Search & Clone
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.form4RequestTab,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                  ),
                  IdocBUi.fit(AppButton(key: const Key('subtab0SearchAndCloneBtn'), label: context.l10n.searchAndCloneBankForm4Btn, onPressed: _openSearchAndCloneBankForm4Dialog, variant: AppButtonVariant.secondary, icon: Icons.copy_all)),
                ],
              ),
              const SizedBox(height: 14),

              // Edit Banner
              if (_editingBankDocId != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.orangeLight : AppTheme.warningBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.orange),
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.edit_note, color: AppTheme.orange, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: CopyableText(
                                    context.l10n.bankForm4EditingBanner(_editingBankDocCode ?? ''),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.orange : AppTheme.warningForeground,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: IdocBUi.fit(AppButton(key: const Key('cancelForm4EditModeBtn'), label: context.l10n.cancelEditNewForm4, onPressed: _resetForm4Form, variant: AppButtonVariant.secondary, icon: Icons.cancel)),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(Icons.edit_note, color: AppTheme.orange, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CopyableText(
                                context.l10n.bankForm4EditingBanner(_editingBankDocCode ?? ''),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.orange : AppTheme.warningForeground,
                                ),
                              ),
                            ),
                            IdocBUi.fit(AppButton(key: const Key('cancelForm4EditModeBtn'), label: context.l10n.cancelEditNewForm4, onPressed: _resetForm4Form, variant: AppButtonVariant.secondary, icon: Icons.cancel)),
                          ],
                        ),
                ),

              // File Selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecorationOf(context),
                child: SearchableDropdownField<int>(
                  labelText: context.l10n.selectImportFileForm4Label,
                  hintText: context.l10n.searchFileOrSupplierHint,
                  value: _form4ImportFileId,
                  isRequired: true,
                  items: importFiles.map((f) => SearchableDropdownItem<int>(
                    value: f.importFileId,
                    label: '${f.primaryNameWithCode} — ${f.supplierName} (${f.companyName})',
                  )).toList(),
                  onChanged: (val) {
                    setState(() => _form4ImportFileId = val);
                    if (val != null) {
                      final existingDoc = bankingDocs.where((d) => d.importFileId == val).firstOrNull;
                      if (existingDoc != null && _editingBankDocId == null) {
                        _loadForm4ForEdit(existingDoc);
                      } else {
                        final file = importFiles.where((f) => f.importFileId == val).firstOrNull;
                        if (file != null && file.estimatedCost > 0) {
                          _bankAmountController.text = file.estimatedCost.toStringAsFixed(2);
                          _form4Currency = file.estimatedCostCurrency.isNotEmpty ? file.estimatedCostCurrency : 'USD';
                        }
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Pre-Form 4 Readiness Pipeline (BP-015)
              _buildPreForm4ReadinessPipeline(context, activeDoc, isDark, isMobile),
              const SizedBox(height: 20),

              // Main Form Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecorationOf(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.bankApplicationDetailsSection,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                    Divider(height: 24, color: isDark ? AppTheme.darkBorder : AppTheme.border),

                    // Inputs Row 0: Doc Type & Reference Number (DC-03)
                    if (isMobile) ...[
                      docTypeField,
                      const SizedBox(height: 14),
                      refNoField,
                      const SizedBox(height: 14),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(child: docTypeField),
                          const SizedBox(width: 14),
                          Expanded(child: refNoField),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Inputs Row 1: Bank, Amount, Currency
                    if (isMobile) ...[
                      SearchableDropdownField<int>(
                        labelText: context.l10n.issuingBankLabel,
                        hintText: context.l10n.selectBankHint,
                        value: _selectedBankId,
                        isRequired: true,
                        items: banksList.map((b) => SearchableDropdownItem<int>(
                          value: b.providerId ?? 0,
                          label: '${b.partnerName} (${b.partnerCode})',
                        )).toList(),
                        onChanged: (val) {
                          setState(() => _selectedBankId = val);
                          final b = banksList.where((p) => p.providerId == val).firstOrNull;
                          if (b != null) _bankName = b.partnerName;
                        },
                      ),
                      if (activeDoc != null && activeDoc.swiftExecutingBankId != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _selectedBankId == activeDoc.swiftExecutingBankId ? Icons.check_circle : Icons.warning_amber_rounded,
                              size: 14,
                              color: _selectedBankId == activeDoc.swiftExecutingBankId ? AppTheme.wcagEmerald : AppTheme.crimson,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _selectedBankId == activeDoc.swiftExecutingBankId
                                    ? 'مطابق للبنك المنفذ لسويفت التحويل (${activeDoc.swiftExecutingBankName})'
                                    : 'تحذير: لا يطابق البنك المنفذ لسويفت التحويل (${activeDoc.swiftExecutingBankName})!',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedBankId == activeDoc.swiftExecutingBankId ? AppTheme.wcagEmerald : AppTheme.crimson,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _bankAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: context.l10n.bankAmountLabel,
                          prefixIcon: const Icon(Icons.attach_money),
                          suffixText: _form4Currency,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? context.l10n.requiredField : null,
                      ),
                      const SizedBox(height: 14),
                      SearchableDropdownField<String>(
                        labelText: context.l10n.transferCurrencyLabel,
                        hintText: context.l10n.selectCurrencyHint,
                        value: _form4Currency,
                        isRequired: true,
                        items: (currencies.isNotEmpty ? currencies.map((c) => c.currencyCode).toSet() : ['USD', 'EUR', 'GBP', 'CNY', 'SAR', 'AED', 'EGP'])
                            .map((code) => SearchableDropdownItem<String>(
                                  value: code,
                                  label: code,
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _form4Currency = val ?? 'USD'),
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SearchableDropdownField<int>(
                                  labelText: context.l10n.issuingBankLabel,
                                  hintText: context.l10n.selectBankHint,
                                  value: _selectedBankId,
                                  isRequired: true,
                                  items: banksList.map((b) => SearchableDropdownItem<int>(
                                    value: b.providerId ?? 0,
                                    label: '${b.partnerName} (${b.partnerCode})',
                                  )).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedBankId = val);
                                    final b = banksList.where((p) => p.providerId == val).firstOrNull;
                                    if (b != null) _bankName = b.partnerName;
                                  },
                                ),
                                if (activeDoc != null && activeDoc.swiftExecutingBankId != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        _selectedBankId == activeDoc.swiftExecutingBankId ? Icons.check_circle : Icons.warning_amber_rounded,
                                        size: 14,
                                        color: _selectedBankId == activeDoc.swiftExecutingBankId ? AppTheme.wcagEmerald : AppTheme.crimson,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _selectedBankId == activeDoc.swiftExecutingBankId
                                              ? 'مطابق للبنك المنفذ لسويفت التحويل (${activeDoc.swiftExecutingBankName})'
                                              : 'تحذير: لا يطابق البنك المنفذ لسويفت التحويل (${activeDoc.swiftExecutingBankName})!',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _selectedBankId == activeDoc.swiftExecutingBankId ? AppTheme.wcagEmerald : AppTheme.crimson,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _bankAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                              decoration: InputDecoration(
                                labelText: context.l10n.bankAmountLabel,
                                prefixIcon: const Icon(Icons.attach_money),
                                suffixText: _form4Currency,
                                border: const OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? context.l10n.requiredField : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SearchableDropdownField<String>(
                              labelText: context.l10n.transferCurrencyLabel,
                              hintText: context.l10n.selectCurrencyHint,
                              value: _form4Currency,
                              isRequired: true,
                              items: (currencies.isNotEmpty ? currencies.map((c) => c.currencyCode).toSet() : ['USD', 'EUR', 'GBP', 'CNY', 'SAR', 'AED', 'EGP'])
                                  .map((code) => SearchableDropdownItem<String>(
                                        value: code,
                                        label: code,
                                      ))
                                  .toList(),
                              onChanged: (val) => setState(() => _form4Currency = val ?? 'USD'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Inputs Row 2: Date, Notes
                    if (isMobile) ...[
                      TextFormField(
                        controller: _form4RequestDateCtrl,
                        style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: context.l10n.bankRequestDateLabel,
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _form4NotesCtrl,
                        style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: context.l10n.bankNotesLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _form4RequestDateCtrl,
                              style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                              decoration: InputDecoration(
                                labelText: context.l10n.bankRequestDateLabel,
                                prefixIcon: const Icon(Icons.calendar_today),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _form4NotesCtrl,
                              style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                              decoration: InputDecoration(
                                labelText: context.l10n.bankNotesLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Documents Checklist
                    Text(
                      context.l10n.form4ChecklistSectionTitle,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.wcagCobalt),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _buildChecklistItem('proforma_invoice', context.l10n.form4ItemProformaInvoice, true, isDark),
                        _buildChecklistItem('packing_list', context.l10n.form4ItemPackingList, true, isDark),
                        _buildChecklistItem('certificate_of_origin', context.l10n.form4ItemCertificateOfOrigin, true, isDark),
                        _buildChecklistItem('bill_of_lading', context.l10n.form4ItemBillOfLading, true, isDark),
                        _buildChecklistItem('acid_notice', context.l10n.form4ItemAcidNotice, true, isDark),
                        _buildChecklistItem('marine_insurance', context.l10n.form4ItemMarineInsurance, false, isDark),
                        _buildChecklistItem('bank_application', context.l10n.form4ItemBankApplication, true, isDark),
                        _buildChecklistItem('admin_fee_receipt', context.l10n.form4ItemAdminFeeReceipt, false, isDark),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (activeDoc != null && !activeDoc.canSubmitForm4) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppTheme.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تنبيه: يمكنك حفظ وتحديث مسودة الطلب، ولكن يجب استيفاء مسار الجاهزية (${activeDoc.blockers.length} متطلبات) قبل التقديم الفعلي للبنك.',
                                style: const TextStyle(fontSize: 12, color: AppTheme.orange, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Submit Button
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        IdocBUi.fit(AppButton(key: const Key('saveForm4SubmitBtn'), label: _isSavingForm4
                                ? context.l10n.loading
                                : _editingBankDocId != null
                                    ? context.l10n.updateForm4Button
                                    : context.l10n.saveForm4Button, onPressed: _isSavingForm4 ? null : _saveBankingDoc, icon: Icons.save, isLoading: _isSavingForm4)),
                        IdocBUi.fit(AppButton(label: context.l10n.goToBankRegistryButton, onPressed: () => setState(() => _selectedSubTab = 1), variant: AppButtonVariant.secondary, icon: Icons.history_edu)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChecklistItem(String key, String title, bool isRequired, bool isDark) {
    final isChecked = _form4DocsChecklist[key] ?? false;
    return InkWell(
      onTap: () => setState(() => _form4DocsChecklist[key] = !isChecked),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isChecked
              ? (isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.2) : AppTheme.infoBackground)
              : (isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isChecked
                ? AppTheme.wcagCobalt
                : (isDark ? AppTheme.darkBorder : AppTheme.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isChecked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: isChecked
                  ? AppTheme.wcagCobalt
                  : (isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }

  // --- SUB-VIEW 1: REGISTRY TAB ---
  Widget _buildForm4HistoryRegistryTab() {
    final bankingDocs = ref.watch(bankingDocumentsProvider).valueOrNull ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final filtered = bankingDocs.where((d) {
      final matchesSearch = _form4SearchQuery.isEmpty ||
          d.bankDocCode.toLowerCase().contains(_form4SearchQuery.toLowerCase()) ||
          d.bankName.toLowerCase().contains(_form4SearchQuery.toLowerCase()) ||
          (d.importFileCode != null && d.importFileCode!.toLowerCase().contains(_form4SearchQuery.toLowerCase()));
      return matchesSearch;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Toolbar
            if (isMobile) ...[
              TextField(
                key: const Key('bankRegistrySearchInput'),
                decoration: InputDecoration(
                  hintText: context.l10n.searchBankRegistryHint,
                  hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                  prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                onChanged: (val) => setState(() => _form4SearchQuery = val),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  IdocBUi.fit(AppButton(key: const Key('subtab1NewForm4Btn'), label: context.l10n.newForm4RequestButton, onPressed: () {
                      _resetForm4Form();
                      setState(() => _selectedSubTab = 0);
                    }, icon: Icons.add)),
                  IdocBUi.fit(AppButton(key: const Key('subtab1SearchAndCloneBtn'), label: context.l10n.searchAndCloneBankForm4Btn, onPressed: _openSearchAndCloneBankForm4Dialog, variant: AppButtonVariant.secondary, icon: Icons.copy_all)),
                  IdocBUi.fit(AppButton(key: const Key('bankRegistryCopyBtn'), label: context.l10n.idocBCopyTable, onPressed: () => _copyBankForm4AsTsv(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.copy)),
                  IdocBUi.fit(AppButton(key: const Key('bankRegistryExcelBtn'), label: context.l10n.idocBExportExcel, onPressed: () => _exportBankForm4ToExcel(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.table_chart)),
                  IdocBUi.fit(AppButton(key: const Key('bankRegistryPdfBtn'), label: context.l10n.idocBExportPdf, onPressed: () => _exportBankForm4ToPdf(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.picture_as_pdf)),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('bankRegistrySearchInput'),
                      decoration: InputDecoration(
                        hintText: context.l10n.searchBankRegistryHint,
                        hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                        prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                        ),
                        filled: true,
                        fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                      onChanged: (val) => setState(() => _form4SearchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Buttons wrap onto a second line instead of overflowing the toolbar.
                  Flexible(
                    flex: 2,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 8,
                        children: [
                        IdocBUi.fit(AppButton(key: const Key('bankRegistryCopyBtn'), label: context.l10n.idocBCopyTable, onPressed: () => _copyBankForm4AsTsv(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.copy)),
                        const SizedBox(width: 8),
                        IdocBUi.fit(AppButton(key: const Key('bankRegistryExcelBtn'), label: context.l10n.idocBExportExcel, onPressed: () => _exportBankForm4ToExcel(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.table_chart)),
                        const SizedBox(width: 8),
                        IdocBUi.fit(AppButton(key: const Key('bankRegistryPdfBtn'), label: context.l10n.idocBExportPdf, onPressed: () => _exportBankForm4ToPdf(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.picture_as_pdf)),
                        const SizedBox(width: 8),
                        IdocBUi.fit(AppButton(key: const Key('subtab1SearchAndCloneBtn'), label: context.l10n.searchAndCloneBankForm4Btn, onPressed: _openSearchAndCloneBankForm4Dialog, variant: AppButtonVariant.secondary, icon: Icons.copy_all)),
                        const SizedBox(width: 10),
                        IdocBUi.fit(AppButton(key: const Key('subtab1NewForm4Btn'), label: context.l10n.newForm4RequestButton, onPressed: () {
                            _resetForm4Form();
                            setState(() => _selectedSubTab = 0);
                          }, icon: Icons.add)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Registry Table or Empty State
            Container(
              width: double.infinity,
              decoration: AppTheme.cardDecorationOf(context),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.borderStrong),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.noBankForm4Found,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SelectionArea(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 750),
                        child: DataTable(
                    headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt),
                    columns: [
                      DataColumn(label: Text(context.l10n.actionCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                      DataColumn(label: Text(context.l10n.documentCodeCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                      DataColumn(label: Text(context.l10n.idocBBankColDocType, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                      DataColumn(label: Text(context.l10n.idocBBankColReference, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                      DataColumn(label: Text(context.l10n.importFile, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                      DataColumn(label: Text(context.l10n.certifiedBankCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                      DataColumn(label: Text(context.l10n.amountAndCurrencyCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                      DataColumn(label: Text(context.l10n.requestDateCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                      DataColumn(label: Text(context.l10n.endorsementStatusCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                    ],
                    rows: filtered.map((d) {
                      final rawCode = d.importFileCode ?? (d.importFileId != null ? 'IMP-${d.importFileId}' : '');
                      final shipName = DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: importFiles, isArabic: isAr);
                      final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);
                      final statusLabel = d.status == 'Received' ? context.l10n.endorsedStatusBadge : context.l10n.bankProcessingStatusBadge;
                      final formattedDate = d.requestDate ?? d.issueDate.substring(0, min(10, d.issueDate.length));
                      final formattedAmount = '${d.amount.toStringAsFixed(2)} ${d.currencyCode}';
                      final rowSummary = '${d.bankDocCode}\t${d.docType}\t${d.docReferenceNumber}\t$shipTitle\t${d.bankName}\t$formattedAmount\t$formattedDate\t$statusLabel';

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: Key('receiveBankDocBtn_${d.bankDocId}'),
                                  icon: const Icon(Icons.verified, color: AppTheme.wcagEmerald, size: 18),
                                  tooltip: context.l10n.idocBBankEndorseTooltip,
                                  onPressed: () => _openReceiveBankDocDialog(d),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: AppTheme.wcagCobalt, size: 18),
                                  tooltip: context.l10n.edit,
                                  onPressed: () => _loadForm4ForEdit(d),
                                ),
                                IconButton(
                                  key: Key('cloneBankForm4RowBtn_${d.bankDocId}'),
                                  icon: const Icon(Icons.copy_all, color: AppTheme.wcagCobalt, size: 18),
                                  tooltip: context.l10n.cloneBankForm4RecordTooltip,
                                  onPressed: () => _onCloneBankDocRow(d),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: d.bankDocCode,
                              rowSummary: rowSummary,
                              child: Text(d.bankDocCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.wcagCobalt)),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: d.docType,
                              rowSummary: rowSummary,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.wcagCobalt.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(d.docType, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: d.docReferenceNumber,
                              rowSummary: rowSummary,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: d.docReferenceNumber != 'PENDING'
                                      ? AppTheme.wcagEmerald.withValues(alpha: 0.12)
                                      : AppTheme.textMuted.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  d.docReferenceNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: d.docReferenceNumber != 'PENDING'
                                        ? AppTheme.wcagEmerald
                                        : (isDark ? AppTheme.borderStrong : AppTheme.textStrong),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: shipTitle,
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    shipName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (rawCode.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        rawCode,
                                        style: TextStyle(
                                          fontSize: DisplayDensityMode.clampFontSize(11.0),
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: d.bankName,
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(d.bankName, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null)),
                                  if (d.nafezaBankLinkStatus.toUpperCase() == 'LINKED')
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          d.isBankMatchingSwift ? Icons.check_circle : Icons.warning,
                                          size: 11,
                                          color: d.isBankMatchingSwift ? AppTheme.wcagEmerald : AppTheme.crimson,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'مربوط بنافذة (${d.isBankMatchingSwift ? "مطابق للسويفت" : "غير مطابق!"})',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: d.isBankMatchingSwift ? AppTheme.wcagEmerald : AppTheme.crimson,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: formattedAmount,
                              rowSummary: rowSummary,
                              child: Text(formattedAmount, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null)),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: formattedDate,
                              rowSummary: rowSummary,
                              child: Text(formattedDate, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null)),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: statusLabel,
                              rowSummary: rowSummary,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: d.status == 'Received'
                                      ? (isDark ? AppTheme.emeraldLight : AppTheme.successBackground)
                                      : (isDark ? AppTheme.orangeLight : AppTheme.warningBackground),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: d.status == 'Received'
                                        ? (isDark ? AppTheme.emerald : AppTheme.emeraldBorder)
                                        : (AppTheme.orange),
                                  ),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: d.status == 'Received'
                                        ? (isDark ? AppTheme.emerald : AppTheme.successForeground)
                                        : (isDark ? AppTheme.orange : AppTheme.warningForeground),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          ],
        );
      },
    );
  }

  Future<void> _saveBankingDoc() async {
    if (!_bankFormKey.currentState!.validate()) return;
    if (_form4ImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.selectImportFileFirst), backgroundColor: AppTheme.crimson),
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
        'doc_reference_number': _docReferenceNumberCtrl.text.trim().isNotEmpty ? _docReferenceNumberCtrl.text.trim() : 'PENDING',
        'notes': _form4NotesCtrl.text.trim(),
      };

      if (_editingBankDocId != null) {
        await ref.read(bankingDocumentsProvider.notifier).updateBankingDocument(_editingBankDocId!, payload);
      } else {
        await ref.read(bankingDocumentsProvider.notifier).createBankingDocument(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.form4SavedSuccess), backgroundColor: AppTheme.emerald),
        );
        _resetForm4Form();
        setState(() => _selectedSubTab = 1);
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.form4SaveError, error: e);
      }
    } finally {
      if (mounted) setState(() => _isSavingForm4 = false);
    }
  }

  Future<void> _exportBankForm4ToExcel(List<dynamic> list, List<ImportFileModel> importFiles) async {
    final headers = [
      context.l10n.documentCodeCol,
      context.l10n.importFile,
      context.l10n.certifiedBankCol,
      context.l10n.amountAndCurrencyCol,
      context.l10n.requestDateCol,
      context.l10n.endorsementStatusCol,
    ];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final rows = list.map((d) {
      final rawCode = d.importFileCode ?? (d.importFileId != null ? 'IMP-${d.importFileId}' : '');
      final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);
      final statusLabel = d.status == 'Received' ? context.l10n.endorsedStatusBadge : context.l10n.bankProcessingStatusBadge;
      final formattedDate = d.requestDate ?? (d.issueDate.length >= 10 ? d.issueDate.substring(0, 10) : d.issueDate);
      final formattedAmount = '${d.amount.toStringAsFixed(2)} ${d.currencyCode}';

      return [
        d.bankDocCode,
        shipTitle,
        d.bankName,
        formattedAmount,
        formattedDate,
        statusLabel,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocBBankRegistryStage,
      importFileNameOrCode: 'Bank_Form4_Registry',
    );
  }

  Future<void> _exportBankForm4ToPdf(List<dynamic> list, List<ImportFileModel> importFiles) async {
    final headers = [
      context.l10n.documentCodeCol,
      context.l10n.importFile,
      context.l10n.certifiedBankCol,
      context.l10n.amountAndCurrencyCol,
      context.l10n.requestDateCol,
      context.l10n.endorsementStatusCol,
    ];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final rows = list.map((d) {
      final rawCode = d.importFileCode ?? (d.importFileId != null ? 'IMP-${d.importFileId}' : '');
      final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);
      final statusLabel = d.status == 'Received' ? context.l10n.endorsedStatusBadge : context.l10n.bankProcessingStatusBadge;
      final formattedDate = d.requestDate ?? (d.issueDate.length >= 10 ? d.issueDate.substring(0, 10) : d.issueDate);
      final formattedAmount = '${d.amount.toStringAsFixed(2)} ${d.currencyCode}';

      return [
        d.bankDocCode,
        shipTitle,
        d.bankName,
        formattedAmount,
        formattedDate,
        statusLabel,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocBBankRegistryStage,
      importFileNameOrCode: 'Bank_Form4_Registry',
    );
  }

  void _copyBankForm4AsTsv(List<dynamic> list, List<ImportFileModel> importFiles) {
    final headers = [
      context.l10n.documentCodeCol,
      context.l10n.importFile,
      context.l10n.certifiedBankCol,
      context.l10n.amountAndCurrencyCol,
      context.l10n.requestDateCol,
      context.l10n.endorsementStatusCol,
    ];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final rows = list.map((d) {
      final rawCode = d.importFileCode ?? (d.importFileId != null ? 'IMP-${d.importFileId}' : '');
      final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);
      final statusLabel = d.status == 'Received' ? context.l10n.endorsedStatusBadge : context.l10n.bankProcessingStatusBadge;
      final formattedDate = d.requestDate ?? (d.issueDate.length >= 10 ? d.issueDate.substring(0, 10) : d.issueDate);
      final formattedAmount = '${d.amount.toStringAsFixed(2)} ${d.currencyCode}';

      return [
        d.bankDocCode,
        shipTitle,
        d.bankName,
        formattedAmount,
        formattedDate,
        statusLabel,
      ];
    }).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }
}
