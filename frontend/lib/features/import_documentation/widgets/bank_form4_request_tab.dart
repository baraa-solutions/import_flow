import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import 'formal_letter_generator_dialog.dart';
import 'idoc_ui_b.dart';
import 'pull_tax_coding_sheet_dialog.dart';
import 'upload_tax_coding_dialog.dart';
import 'update_coding_progress_dialog.dart';
import 'nafeza_bank_link_dialog.dart';

/// Tab 0: Form 4 Request & Checklist.
/// Encapsulates all request form controllers with strict disposal lifecycle
/// to prevent memory leaks when navigating between tabs or screens.
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
        showErrorDetailsDialog(context, title: context.l10n.form4SaveError, error: e);
      }
    } finally {
      if (mounted) setState(() => _isSavingForm4 = false);
    }
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
                        Flexible(
                          child: Text(
                            'مسار جاهزية ما قبل طلب نموذج 4 (Pre-Form 4 Readiness)',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
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
                      'التحقق المسبق من تكويد الأصناف وفحص جهات العرض ومطابقة سويفت البنك قبل الاعتماد',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildReadinessOverallBadge(doc, isDark),
            ],
          ),
          const SizedBox(height: 16),
          if (doc != null) ...[
            if (isMobile) ...[
              _buildStage1TaxCodingCard(doc, isDark),
              const SizedBox(height: 12),
              _buildStage2ItemVerificationCard(doc, isDark),
              const SizedBox(height: 12),
              _buildStage3BankLinkageCard(doc, isDark),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildStage1TaxCodingCard(doc, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStage2ItemVerificationCard(doc, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStage3BankLinkageCard(doc, isDark)),
                ],
              ),
            ],
            if (hasBlockers) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.dangerBackground : AppTheme.dangerBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'المتطلبات المعلقة للتقديم للبنك:',
                          style: TextStyle(
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

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isPulled ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isPulled ? Icons.check : Icons.circle_outlined, size: 14, color: isPulled ? AppTheme.wcagEmerald : AppTheme.textMuted),
                        const SizedBox(width: 4),
                        const Flexible(
                          child: Text(
                            'أ) سحب الشيت (مستخلص)',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isPulled)
                      Text(doc.taxCodingPulledDate ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.wcagEmerald)),
                  ],
                ),
                if (!isPulled) ...[
                  const SizedBox(height: 6),
                  IdocBUi.fit(AppButton(
                    label: 'تسجيل سحب الشيت',
                    icon: Icons.file_download_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => PullTaxCodingSheetDialog.show(
                      context,
                      doc: doc,
                      onSubmitted: widget.onRefresh,
                    ),
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isUploaded ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isUploaded ? Icons.check : Icons.circle_outlined, size: 14, color: isUploaded ? AppTheme.wcagEmerald : AppTheme.textMuted),
                        const SizedBox(width: 4),
                        const Flexible(
                          child: Text(
                            'ب) رفع وتكويد (محاسب)',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isUploaded)
                      Text(doc.taxCodingUploadedDate ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.wcagEmerald)),
                  ],
                ),
                if (!isUploaded) ...[
                  const SizedBox(height: 6),
                  IdocBUi.fit(AppButton(
                    label: 'تأكيد رفع وتكويد المحاسب',
                    icon: Icons.upload_file_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: isPulled ? () => UploadTaxCodingDialog.show(
                      context,
                      doc: doc,
                      onSubmitted: widget.onRefresh,
                    ) : null,
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage2ItemVerificationCard(BankingDocumentModel doc, bool isDark) {
    final isDone = doc.itemsPulledVerified;

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
                isDone ? Icons.check_circle : Icons.checklist_outlined,
                color: isDone ? AppTheme.wcagEmerald : AppTheme.wcagCobalt,
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
            'تأكيد سحب الأصناف 100% وجهات العرض',
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDone ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'نسبة التكويد: ${doc.itemsCountCoded} / ${doc.itemsCountTotal > 0 ? doc.itemsCountTotal : "-"}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    if (isDone)
                      const Icon(Icons.check, size: 16, color: AppTheme.wcagEmerald),
                  ],
                ),
                if (doc.regulatoryBodiesDetected.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: doc.regulatoryBodiesDetected.map((b) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
                      ),
                      child: Text(b, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                IdocBUi.fit(AppButton(
                  label: isDone ? 'تحديث فحص الأصناف' : 'تأكيد سحب وفحص الأصناف',
                  icon: Icons.fact_check_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => UpdateCodingProgressDialog.show(
                    context,
                    doc: doc,
                    onSubmitted: widget.onRefresh,
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage3BankLinkageCard(BankingDocumentModel doc, bool isDark) {
    final isDone = doc.nafezaLinkedBankId != null;

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
                isDone ? Icons.check_circle : Icons.link,
                color: isDone ? AppTheme.wcagEmerald : AppTheme.wcagCobalt,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '3. ربط البنك على نافذة',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'مطابقة بنك السويفت مع إقرار نافذة',
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDone ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (doc.swiftExecutingBankName != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 14, color: AppTheme.wcagCobalt),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'سويفت: ${doc.swiftExecutingBankName}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.wcagCobalt),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isDone ? 'مربوط: ${doc.nafezaLinkedBankName ?? "تم الربط"}' : 'لم يتم ربط البنك بعد',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDone ? AppTheme.wcagEmerald : AppTheme.crimson,
                        ),
                      ),
                    ),
                    if (isDone)
                      const Icon(Icons.check, size: 16, color: AppTheme.wcagEmerald),
                  ],
                ),
                const SizedBox(height: 8),
                IdocBUi.fit(AppButton(
                  label: isDone ? 'تعديل الربط البنكي' : 'تسجيل الربط بالبنك',
                  icon: Icons.link,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => NafezaBankLinkDialog.show(
                    context,
                    doc: doc,
                    onSubmitted: widget.onRefresh,
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

        return SelectionArea(
          child: Form(
            key: _bankFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    IdocBUi.fit(AppButton(
                      key: const Key('subtab0SearchAndCloneBtn'),
                      label: context.l10n.searchAndCloneBankForm4Btn,
                      onPressed: widget.onOpenSearchAndClone,
                      variant: AppButtonVariant.secondary,
                      icon: Icons.copy_all,
                    )),
                  ],
                ),
                const SizedBox(height: 14),

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
                                child: IdocBUi.fit(AppButton(
                                  key: const Key('cancelForm4EditModeBtn'),
                                  label: context.l10n.cancelEditNewForm4,
                                  onPressed: _resetForm,
                                  variant: AppButtonVariant.secondary,
                                  icon: Icons.cancel,
                                )),
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
                              IdocBUi.fit(AppButton(
                                key: const Key('cancelForm4EditModeBtn'),
                                label: context.l10n.cancelEditNewForm4,
                                onPressed: _resetForm,
                                variant: AppButtonVariant.secondary,
                                icon: Icons.cancel,
                              )),
                            ],
                          ),
                  ),

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
                          _loadDoc(existingDoc);
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

                _buildPreForm4ReadinessPipeline(context, activeDoc, isDark, isMobile),
                const SizedBox(height: 20),

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

                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          IdocBUi.fit(AppButton(
                            key: const Key('saveForm4SubmitBtn'),
                            label: _isSavingForm4
                                ? context.l10n.loading
                                : _editingBankDocId != null
                                    ? context.l10n.updateForm4Button
                                    : context.l10n.saveForm4Button,
                            onPressed: _isSavingForm4 ? null : _saveBankingDoc,
                            icon: Icons.save,
                            isLoading: _isSavingForm4,
                          )),
                          IdocBUi.fit(AppButton(
                            label: context.l10n.goToBankRegistryButton,
                            onPressed: widget.onSwitchToRegistry,
                            variant: AppButtonVariant.secondary,
                            icon: Icons.history_edu,
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
