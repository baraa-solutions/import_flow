import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/concurrency_conflict_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/docs_customs_approval_model.dart';
import '../providers/docs_customs_approval_provider.dart';
import '../screens/central_docs_archive_screen.dart';
import 'search_and_clone_customs_approval_dialog.dart';
import '../../../core/localization/stored_text.dart';

class CustomsDocumentApprovalTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const CustomsDocumentApprovalTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<CustomsDocumentApprovalTab> createState() => CustomsDocumentApprovalTabState();
}

class CustomsDocumentApprovalTabState extends ConsumerState<CustomsDocumentApprovalTab> {
  int? _selectedImportFileId;
  CrossDocumentMatrixResultModel? _matrixResult;
  bool _isRunningMatrixCheck = false;
  String _selectedStatusFilter = 'All';
  int _activeViewIndex = 0; // 0: Dual-Tier Sign-off & Audit, 1: Central Archive & Rectifications Hub

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() {
      _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant CustomsDocumentApprovalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId &&
        widget.initialImportFileId != null) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
        _matrixResult = null;
      });
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (!ref.read(importFilesProvider).isLoading) {
      await ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    if (_selectedImportFileId == null && files.isNotEmpty && mounted) {
      setState(() {
        _selectedImportFileId = files.first.importFileId;
      });
    }
    if (!ref.read(docsCustomsApprovalProvider).isLoading) {
      ref.read(docsCustomsApprovalProvider.notifier).fetchApprovals(
            importFileId: _selectedImportFileId,
            overallStatus: _selectedStatusFilter == 'All' ? null : _selectedStatusFilter,
          );
    }
    if (!ref.read(discrepancyTicketsProvider).isLoading) {
      ref.read(discrepancyTicketsProvider.notifier).fetchTickets(
            importFileId: _selectedImportFileId,
          );
    }
  }

  Future<void> _handleRunMatrixCheck() async {
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.customsApprovalSelectFileForMatrixWarning)),
      );
      return;
    }

    setState(() => _isRunningMatrixCheck = true);
    try {
      final res = await ref.read(docsCustomsApprovalProvider.notifier).runMatrixCheck(_selectedImportFileId!);
      if (!mounted) return;
      setState(() => _matrixResult = res);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.customsApprovalMatrixCheckCompleted(
            _getLocalizedCompliance(res.overallCompliance, context.l10n),
          )),
          backgroundColor: res.overallCompliance == 'Fully Compliant' ? AppTheme.emerald : AppTheme.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.customsApprovalMatrixCheckFailed(e.toString())), backgroundColor: AppTheme.crimson),
      );
    } finally {
      if (mounted) {
        setState(() => _isRunningMatrixCheck = false);
      }
    }
  }

  Future<void> _handleAutoGenerate() async {
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.customsApprovalSelectFileWarning)),
      );
      return;
    }

    try {
      await ref.read(docsCustomsApprovalProvider.notifier).autoGenerateChecklist(_selectedImportFileId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.customsApprovalStandardListGeneratedSuccess), backgroundColor: AppTheme.emerald),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.customsApprovalGenerateFailed(e.toString())), backgroundColor: AppTheme.crimson),
      );
    }
  }

  void _showCommercialReviewDialog(CustomsDocumentApprovalModel item) {
    showDialog(
      context: context,
      builder: (c) => _CommercialReviewDialog(item: item, importFileId: _selectedImportFileId),
    );
  }

  void _showCustomsBrokerReviewDialog(CustomsDocumentApprovalModel item) {
    showDialog(
      context: context,
      builder: (c) => _CustomsBrokerReviewDialog(item: item, importFileId: _selectedImportFileId),
    );
  }

  void openSearchAndCloneDialog([List<CustomsDocumentApprovalModel>? items]) {
    _openSearchAndCloneDialog(items);
  }

  Future<void> _openSearchAndCloneDialog([List<CustomsDocumentApprovalModel>? items]) async {
    final available = items ?? (ref.read(docsCustomsApprovalProvider).valueOrNull ?? []);
    showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneCustomsApprovalDialog(
        items: available,
        onSelectItem: (item) {
          _cloneApprovalItem(item);
        },
      ),
    );
  }

  void _cloneApprovalItem(CustomsDocumentApprovalModel sourceItem) {
    final l = context.l10n;
    final suggestedCode = 'DOCAPPR-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final docType = _getLocalizedDocType(sourceItem.documentType, l);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
      context: context,
      builder: (dialogCtx) => CloneEntityReviewDialog(
        entityType: l.searchAndCloneCustomsApprovalDialogTitle,
        sourceCode: sourceItem.approvalCode,
        sourceTitle: '$docType - ${sourceItem.documentReferenceNo ?? "REF"}',
        suggestedNewCode: suggestedCode,
        copiedFieldsSummary: isAr
            ? {
                'نوع المستند': docType,
                'الرقم المرجعي': sourceItem.documentReferenceNo != null ? '${sourceItem.documentReferenceNo}-COPY' : '—',
                'ملف الشحنة': sourceItem.importFileCode ?? '—',
              }
            : {
                'Document Type': docType,
                'Reference No': sourceItem.documentReferenceNo != null ? '${sourceItem.documentReferenceNo}-COPY' : '—',
                'Import File': sourceItem.importFileCode ?? '—',
              },
        mandatorilyResetFields: isAr
            ? [
                l.customsApprovalClonedResetNotice,
                'حالة الاعتماد التجاري: إعادة تعيين إلى قيد الانتظار (Pending)',
                'حالة اعتماد المخلص الجمركي: إعادة تعيين إلى قيد الانتظار (Pending)',
                'الحالة العامة: إعادة تعيين إلى مسودة قيد التدقيق (Draft)',
                'تفريغ توقيعات وملاحظات المراجعين بالكامل لبدء اعتماد مستقل',
              ]
            : [
                l.customsApprovalClonedResetNotice,
                'Commercial Approval Status: Reset to Pending',
                'Customs Broker Approval Status: Reset to Pending',
                'Overall Status: Reset to Draft',
                'Reviewer signatures and notes fully cleared for independent review',
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.cloneCustomsApprovalSuccess),
                backgroundColor: AppTheme.emerald,
              ),
            );
          }
        },
      ),
    );
  }

  void _cloneTicket(DiscrepancyRectificationTicketModel sourceTicket) {
    _showRaiseTicketDialog(null, sourceTicket);
  }

  void _showRaiseTicketDialog([CustomsDocumentApprovalModel? item, DiscrepancyRectificationTicketModel? initialTicket]) {
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.customsApprovalSelectFileForTicketWarning)),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (c) => _RaiseTicketDialog(
        importFileId: _selectedImportFileId!,
        approvalItem: item,
        initialTicket: initialTicket,
      ),
    );
  }

  void _showResolveTicketDialog(DiscrepancyRectificationTicketModel ticket) {
    showDialog(
      context: context,
      builder: (c) => _ResolveTicketDialog(ticket: ticket, importFileId: _selectedImportFileId),
    );
  }

  void _copyApprovalsAsTsv(List<CustomsDocumentApprovalModel> approvals) {
    final isAr = context.l10n.isArabic;
    final headers = [
      isAr ? 'كود الاعتماد' : 'Approval Code',
      isAr ? 'نوع المستند' : 'Document Type',
      isAr ? 'الرقم المرجعي' : 'Ref Number',
      isAr ? 'الاعتماد التجاري' : 'Commercial Status',
      isAr ? 'المراجع التجاري' : 'Commercial Reviewer',
      isAr ? 'اعتماد المخلص' : 'Broker Status',
      isAr ? 'المخلص الجمركي' : 'Broker Reviewer',
      isAr ? 'الحالة العامة' : 'Overall Status',
    ];
    final rows = approvals.map((a) {
      return [
        a.approvalCode,
        _getLocalizedDocType(a.documentType, context.l10n),
        a.documentReferenceNo ?? '-',
        _getLocalizedCommercialStatus(a.commercialStatus, context.l10n),
        a.commercialReviewedBy ?? '-',
        _getLocalizedBrokerStatus(a.customsStatus, context.l10n),
        a.customsReviewedBy ?? a.customsBrokerName ?? '-',
        _getLocalizedOverallStatus(a.overallStatus, context.l10n),
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportApprovalsToExcel(List<CustomsDocumentApprovalModel> approvals) async {
    final isAr = context.l10n.isArabic;
    final headers = [
      isAr ? 'كود الاعتماد' : 'Approval Code',
      isAr ? 'نوع المستند' : 'Document Type',
      isAr ? 'الرقم المرجعي' : 'Ref Number',
      isAr ? 'الاعتماد التجاري' : 'Commercial Status',
      isAr ? 'المراجع التجاري' : 'Commercial Reviewer',
      isAr ? 'اعتماد المخلص' : 'Broker Status',
      isAr ? 'المخلص الجمركي' : 'Broker Reviewer',
      isAr ? 'الحالة العامة' : 'Overall Status',
    ];
    final rows = approvals.map((a) {
      return [
        a.approvalCode,
        _getLocalizedDocType(a.documentType, context.l10n),
        a.documentReferenceNo ?? '-',
        _getLocalizedCommercialStatus(a.commercialStatus, context.l10n),
        a.commercialReviewedBy ?? '-',
        _getLocalizedBrokerStatus(a.customsStatus, context.l10n),
        a.customsReviewedBy ?? a.customsBrokerName ?? '-',
        _getLocalizedOverallStatus(a.overallStatus, context.l10n),
      ];
    }).toList();
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isAr ? 'مصفوفة اعتماد المستندات' : 'Customs Document Approvals',
      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : 'Customs_Approvals',
    );
  }

  Future<void> _exportApprovalsToPdf(List<CustomsDocumentApprovalModel> approvals) async {
    final isAr = context.l10n.isArabic;
    final headers = [
      isAr ? 'الكود' : 'Code',
      isAr ? 'المستند' : 'Doc',
      isAr ? 'المرجع' : 'Ref',
      isAr ? 'التجاري' : 'Commercial',
      isAr ? 'المخلص' : 'Broker',
      isAr ? 'الحالة' : 'Status',
    ];
    final rows = approvals.map((a) {
      return [
        a.approvalCode,
        _getLocalizedDocType(a.documentType, context.l10n),
        a.documentReferenceNo ?? '-',
        _getLocalizedCommercialStatus(a.commercialStatus, context.l10n),
        _getLocalizedBrokerStatus(a.customsStatus, context.l10n),
        _getLocalizedOverallStatus(a.overallStatus, context.l10n),
      ];
    }).toList();
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isAr ? 'مصفوفة اعتماد المستندات' : 'Customs Document Approvals',
      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : 'Customs_Approvals',
      headerContext: TableExportHeaderContext(
        title: isAr ? 'تقرير ومصفوفة اعتماد المستندات الجمركية' : 'Customs Document Approvals Report',
        subtitle: 'Sorour Logistics ERP — Import Documentation',
        metadata: {
          isAr ? 'ملف الشحنة' : 'File': _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : '-',
          isAr ? 'إجمالي المستندات' : 'Total Docs': '${approvals.length}',
          isAr ? 'التاريخ' : 'Date': DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }

  void _copyTicketsAsTsv(List<DiscrepancyRectificationTicketModel> tickets) {
    final isAr = context.l10n.isArabic;
    final headers = [
      isAr ? 'كود التذكرة' : 'Ticket Code',
      isAr ? 'تصنيف المشكلة' : 'Issue Category',
      isAr ? 'درجة الخطورة' : 'Severity',
      isAr ? 'الحالة' : 'Status',
      isAr ? 'الوصف' : 'Description',
      isAr ? 'القيمة المتوقعة' : 'Expected',
      isAr ? 'القيمة الفعلية' : 'Found',
    ];
    final rows = tickets.map((t) {
      return [
        t.ticketCode,
        t.issueCategory,
        _getLocalizedSeverity(t.severity, context.l10n),
        _getLocalizedTicketStatus(t.status, context.l10n),
        t.description,
        t.expectedValue ?? '-',
        t.foundValue ?? '-',
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportTicketsToExcel(List<DiscrepancyRectificationTicketModel> tickets) async {
    final isAr = context.l10n.isArabic;
    final headers = [
      isAr ? 'كود التذكرة' : 'Ticket Code',
      isAr ? 'تصنيف المشكلة' : 'Issue Category',
      isAr ? 'درجة الخطورة' : 'Severity',
      isAr ? 'الحالة' : 'Status',
      isAr ? 'الوصف' : 'Description',
      isAr ? 'القيمة المتوقعة' : 'Expected',
      isAr ? 'القيمة الفعلية' : 'Found',
    ];
    final rows = tickets.map((t) {
      return [
        t.ticketCode,
        t.issueCategory,
        _getLocalizedSeverity(t.severity, context.l10n),
        _getLocalizedTicketStatus(t.status, context.l10n),
        t.description,
        t.expectedValue ?? '-',
        t.foundValue ?? '-',
      ];
    }).toList();
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isAr ? 'سجل تذاكر الاستدراك' : 'Rectification Tickets',
      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : 'Tickets',
    );
  }

  Future<void> _exportTicketsToPdf(List<DiscrepancyRectificationTicketModel> tickets) async {
    final isAr = context.l10n.isArabic;
    final headers = [
      isAr ? 'الكود' : 'Code',
      isAr ? 'الخطورة' : 'Severity',
      isAr ? 'الحالة' : 'Status',
      isAr ? 'الوصف' : 'Description',
      isAr ? 'المتوقع' : 'Expected',
      isAr ? 'الفعلي' : 'Found',
    ];
    final rows = tickets.map((t) {
      return [
        t.ticketCode,
        _getLocalizedSeverity(t.severity, context.l10n),
        _getLocalizedTicketStatus(t.status, context.l10n),
        t.description,
        t.expectedValue ?? '-',
        t.foundValue ?? '-',
      ];
    }).toList();
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isAr ? 'سجل تذاكر الاستدراك' : 'Rectification Tickets',
      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : 'Tickets',
      headerContext: TableExportHeaderContext(
        title: isAr ? 'سجل تذاكر واستفسارات استدراك المستندات' : 'Rectification Tickets Report',
        subtitle: 'Sorour Logistics ERP — Discrepancies Hub',
        metadata: {
          isAr ? 'ملف الشحنة' : 'File': _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : '-',
          isAr ? 'إجمالي التذاكر' : 'Total Tickets': '${tickets.length}',
          isAr ? 'التاريخ' : 'Date': DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }

  static String _getLocalizedDocType(String docType, AppLocalizations l) {
    switch (docType) {
      case 'Commercial Invoice':
        return l.customsApprovalDocCommercialInvoice;
      case 'Packing List':
        return l.customsApprovalDocPackingList;
      case 'Bill of Lading':
        return l.customsApprovalDocBillOfLading;
      case 'Certificate of Origin':
        return l.customsApprovalDocCertificateOfOrigin;
      case 'EUR.1':
        return l.customsApprovalDocEur1;
      case 'Inspection Certificate':
        return l.customsApprovalDocInspectionCertificate;
      case 'Fumigation Certificate':
        return l.isArabic ? 'شهادة التبخير والصحة النباتية' : 'Fumigation Certificate';
      case 'Bank Form 4':
        return l.customsApprovalDocBankForm4;
      case 'Proforma Invoice':
        return l.customsApprovalDocProformaInvoice;
      default:
        return docType;
    }
  }

  static String _getLocalizedOverallStatus(String status, AppLocalizations l) {
    switch (status) {
      case 'Approved for Clearance':
        return l.customsApprovalStatusApprovedForClearance;
      case 'Rectification Required':
        return l.customsApprovalStatusRectificationRequired;
      case 'Conditionally Approved':
        return l.customsApprovalStatusConditionallyApproved;
      case 'Under Review':
        return l.customsApprovalStatusUnderReview;
      case 'Pending Review':
        return l.customsApprovalStatusPendingReview;
      case 'Draft':
        return l.customsApprovalStatusDraft;
      case 'Rejected':
        return l.customsApprovalStatusRejected;
      case 'Approved':
        return l.customsApprovalStatusApproved;
      case 'Pending':
        return l.customsApprovalStatusPending;
      default:
        return status;
    }
  }

  static String _getLocalizedCommercialStatus(String status, AppLocalizations l) {
    switch (status) {
      case 'Approved':
        return l.customsApprovalStatusApproved;
      case 'Under Review':
        return l.customsApprovalStatusUnderReview;
      case 'Rejected':
        return l.customsApprovalStatusRejected;
      case 'Pending':
        return l.customsApprovalStatusPending;
      default:
        return status;
    }
  }

  static String _getLocalizedBrokerStatus(String status, AppLocalizations l) {
    switch (status) {
      case 'Approved':
        return l.customsApprovalStatusApproved;
      case 'Conditionally Approved':
        return l.customsApprovalStatusConditionallyApproved;
      case 'Rejected':
        return l.customsApprovalStatusRejected;
      case 'Pending':
        return l.customsApprovalStatusPending;
      default:
        return status;
    }
  }

  static String _getLocalizedSeverity(String severity, AppLocalizations l) {
    switch (severity) {
      case 'Critical':
        return l.customsApprovalSevCriticalBadge;
      case 'Major':
        return l.customsApprovalSevMajorBadge;
      case 'Minor':
        return l.customsApprovalSevMinorBadge;
      default:
        return severity;
    }
  }

  static String _getLocalizedTicketStatus(String status, AppLocalizations l) {
    switch (status) {
      case 'Open':
        return l.customsApprovalTicketStatusOpen;
      case 'Resolved':
        return l.customsApprovalStatusResolved;
      case 'Waived':
        return l.customsApprovalStatusWaived;
      case 'Closed':
        return l.customsApprovalStatusClosed;
      default:
        return status;
    }
  }

  static String _getLocalizedCompliance(String compliance, AppLocalizations l) {
    switch (compliance) {
      case 'Fully Compliant':
        return l.customsApprovalComplianceFullyCompliant;
      case 'Non-Compliant':
        return l.customsApprovalComplianceNonCompliant;
      case 'Discrepancies Found':
        return l.customsApprovalComplianceDiscrepancies;
      case 'Critical Blocker':
        return l.customsApprovalComplianceCriticalBlocker;
      default:
        return compliance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final approvalsState = ref.watch(docsCustomsApprovalProvider);
    final ticketsState = ref.watch(discrepancyTicketsProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () => _openSearchAndCloneDialog(),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
        // --- Control Toolbar ---
        Card(
          elevation: 2,
          color: isDark ? AppTheme.darkCardBackground : null,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: SearchableDropdownField<int>(
                      value: _selectedImportFileId,
                      labelText: context.l10n.customsApprovalImportFileLabel,
                      searchHintText: context.l10n.customsApprovalSearchFileHint,
                      items: importFiles.map((f) {
                        return SearchableDropdownItem(
                          value: f.importFileId,
                          label: '${f.primaryNameWithCode} - ${f.companyName} (${f.supplierName})',
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedImportFileId = val;
                          _matrixResult = null;
                        });
                        _refresh();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: _isRunningMatrixCheck ? null : _handleRunMatrixCheck,
                    icon: _isRunningMatrixCheck
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(context.l10n.customsApprovalRunAiMatrixButton),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    onPressed: _handleAutoGenerate,
                    icon: const Icon(Icons.playlist_add_check),
                    label: Text(context.l10n.customsApprovalAutoGenerateStandardListButton),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    onPressed: () => _showRaiseTicketDialog(),
                    icon: const Icon(Icons.report_problem_outlined),
                    label: Text(context.l10n.customsApprovalRaiseTicketButton),
                  ),
                  const SizedBox(width: 16),
                  const VerticalDivider(width: 1, thickness: 1),
                  const SizedBox(width: 12),
                  // Status Filter Dropdown
                  DropdownButton<String>(
                    value: _selectedStatusFilter,
                    underline: const SizedBox.shrink(),
                    icon: Icon(Icons.filter_list, size: 18, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    borderRadius: BorderRadius.circular(8),
                    dropdownColor: isDark ? AppTheme.darkCardBackground : null,
                    items: [
                      DropdownMenuItem(value: 'All', child: Text(context.l10n.customsApprovalFilterAll, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null))),
                      DropdownMenuItem(value: 'Pending', child: Text(context.l10n.customsApprovalFilterPending, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null))),
                      DropdownMenuItem(value: 'Approved', child: Text(context.l10n.customsApprovalFilterApproved, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null))),
                      DropdownMenuItem(value: 'Rejected', child: Text(context.l10n.customsApprovalFilterRejected, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null))),
                      DropdownMenuItem(value: 'Discrepancy', child: Text(context.l10n.customsApprovalFilterDiscrepancy, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null))),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _selectedStatusFilter = val);
                      _refresh();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // --- Sub-View Switcher Bar ---
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  key: const Key('dualSignoffChoiceChip'),
                  avatar: Icon(Icons.verified_user, size: 16, color: _activeViewIndex == 0 ? Colors.white : AppTheme.cobalt),
                  label: Text(context.l10n.customsApprovalTabDualSignoff, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  selected: _activeViewIndex == 0,
                  selectedColor: AppTheme.cobalt,
                  labelStyle: TextStyle(color: _activeViewIndex == 0 ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                  onSelected: (selected) {
                    if (selected) setState(() => _activeViewIndex = 0);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('centralArchiveChoiceChip'),
                  avatar: Icon(Icons.inventory_2_outlined, size: 16, color: _activeViewIndex == 1 ? Colors.white : AppTheme.emerald),
                  label: Text(context.l10n.customsApprovalTabCentralArchive, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  selected: _activeViewIndex == 1,
                  selectedColor: AppTheme.emerald,
                  labelStyle: TextStyle(color: _activeViewIndex == 1 ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                  onSelected: (selected) {
                    if (selected) setState(() => _activeViewIndex = 1);
                  },
                ),
              ],
            ),
          ),
        ),

        // --- Live Matrix Banner (if available and in view 0) ---
        if (_activeViewIndex == 0 && _matrixResult != null)
          SelectionArea(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _matrixResult!.overallCompliance == 'Fully Compliant'
                    ? AppTheme.emerald.withOpacity(0.12)
                    : AppTheme.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _matrixResult!.overallCompliance == 'Fully Compliant'
                      ? AppTheme.emerald
                      : AppTheme.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _matrixResult!.overallCompliance == 'Fully Compliant'
                        ? Icons.verified
                        : Icons.warning_amber_rounded,
                    color: _matrixResult!.overallCompliance == 'Fully Compliant'
                        ? AppTheme.emerald
                        : AppTheme.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CopyableText(
                          context.l10n.customsApprovalMatrixComplianceResult(
                            _getLocalizedCompliance(_matrixResult!.overallCompliance, context.l10n),
                            _matrixResult!.passedChecks,
                            _matrixResult!.totalChecks,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _matrixResult!.overallCompliance == 'Fully Compliant'
                                ? AppTheme.emerald
                                : AppTheme.orange,
                          ),
                          isSelectable: false,
                        ),
                        if (_matrixResult!.completenessPercent > 0 || _matrixResult!.missingDocuments.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _matrixResult!.completenessPercent >= 100
                                        ? AppTheme.emerald.withOpacity(0.2)
                                        : AppTheme.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    context.l10n.isArabic
                                        ? 'استكمال المستندات (DC-04): ${_matrixResult!.completenessPercent.toStringAsFixed(1)}%'
                                        : 'Docs Completeness: ${_matrixResult!.completenessPercent.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _matrixResult!.completenessPercent >= 100 ? AppTheme.emerald : AppTheme.orange,
                                    ),
                                  ),
                                ),
                                if (_matrixResult!.missingDocuments.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.crimson.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      context.l10n.isArabic
                                          ? '⚠️ نواقص مستندية: ${_matrixResult!.missingDocuments.join("، ")}'
                                          : '⚠️ Missing: ${_matrixResult!.missingDocuments.join(", ")}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (_matrixResult!.recommendations.isNotEmpty)
                          CopyableText(
                            context.l10n.customsApprovalMatrixRecommendations(_matrixResult!.recommendations.join(' | ')),
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
                            isSelectable: false,
                          ),
                      ],
                    ),
                  ),
                  CopyableText(
                    context.l10n.customsApprovalMatrixOpenTicketsCount(_matrixResult!.openTicketsCount),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    isSelectable: false,
                  ),
                ],
              ),
            ),
          ),

        // --- Main Workspace: View 0 (Split Matrix) vs View 1 (Central Archive & Rectifications) ---
        if (_activeViewIndex == 1)
          Expanded(
            child: CentralDocsArchiveScreen(
              initialImportFileId: _selectedImportFileId,
              isEmbedded: true,
            ),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 950;
                  final leftCol = Card(
                    elevation: 2,
                    color: isDark ? AppTheme.darkCardBackground : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: SelectionArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_user, color: AppTheme.cobalt),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.l10n.customsApprovalDualTierHeader,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  key: const Key('copyApprovalsBtn'),
                                  icon: const Icon(Icons.copy_outlined, size: 18),
                                  onPressed: approvalsState.valueOrNull == null || approvalsState.valueOrNull!.isEmpty
                                      ? null
                                      : () => _copyApprovalsAsTsv(approvalsState.valueOrNull!),
                                  tooltip: context.l10n.isArabic ? 'نسخ الجدول كـ TSV' : 'Copy Table as TSV',
                                ),
                                IconButton(
                                  key: const Key('exportApprovalsExcelBtn'),
                                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                                  onPressed: approvalsState.valueOrNull == null || approvalsState.valueOrNull!.isEmpty
                                      ? null
                                      : () => _exportApprovalsToExcel(approvalsState.valueOrNull!),
                                  tooltip: context.l10n.isArabic ? 'تصدير إكسيل' : 'Export Excel',
                                ),
                                IconButton(
                                  key: const Key('exportApprovalsPdfBtn'),
                                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                  onPressed: approvalsState.valueOrNull == null || approvalsState.valueOrNull!.isEmpty
                                      ? null
                                      : () => _exportApprovalsToPdf(approvalsState.valueOrNull!),
                                  tooltip: context.l10n.isArabic ? 'تصدير PDF' : 'Export PDF',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed: _refresh,
                                  tooltip: context.l10n.refresh,
                                ),
                              ],
                            ),
                            const Divider(),
                            Expanded(
                              child: approvalsState.when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, _) => Center(child: Text(context.l10n.customsApprovalError(e.toString()), style: const TextStyle(color: Colors.red))),
                                data: (approvals) {
                                  if (approvals.isEmpty) {
                                    return Center(
                                      child: Text(
                                        context.l10n.customsApprovalNoDocuments,
                                        style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                      ),
                                    );
                                  }
                                  return ListView.separated(
                                    itemCount: approvals.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = approvals[index];
                                      return _buildApprovalRow(item);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  final rightCol = Card(
                    elevation: 2,
                    color: isDark ? AppTheme.darkCardBackground : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: SelectionArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.confirmation_number_outlined, color: AppTheme.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.l10n.customsApprovalTicketsHeader,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Flexible(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          key: const Key('copyTicketsBtn'),
                                          icon: const Icon(Icons.copy_outlined, size: 18),
                                          onPressed: ticketsState.valueOrNull == null || ticketsState.valueOrNull!.isEmpty
                                              ? null
                                              : () => _copyTicketsAsTsv(ticketsState.valueOrNull!),
                                          tooltip: context.l10n.isArabic ? 'نسخ التذاكر كـ TSV' : 'Copy Tickets as TSV',
                                        ),
                                        IconButton(
                                          key: const Key('exportTicketsExcelBtn'),
                                          icon: const Icon(Icons.table_chart_outlined, size: 18),
                                          onPressed: ticketsState.valueOrNull == null || ticketsState.valueOrNull!.isEmpty
                                              ? null
                                              : () => _exportTicketsToExcel(ticketsState.valueOrNull!),
                                          tooltip: context.l10n.isArabic ? 'تصدير إكسيل' : 'Export Excel',
                                        ),
                                        IconButton(
                                          key: const Key('exportTicketsPdfBtn'),
                                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                          onPressed: ticketsState.valueOrNull == null || ticketsState.valueOrNull!.isEmpty
                                              ? null
                                              : () => _exportTicketsToPdf(ticketsState.valueOrNull!),
                                          tooltip: context.l10n.isArabic ? 'تصدير PDF' : 'Export PDF',
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.add, size: 16),
                                          label: Text(context.l10n.customsApprovalNewTicketButton),
                                          onPressed: () => _showRaiseTicketDialog(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Expanded(
                              child: ticketsState.when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, _) => Center(child: Text(context.l10n.customsApprovalError(e.toString()), style: const TextStyle(color: Colors.red))),
                                data: (tickets) {
                                  if (tickets.isEmpty) {
                                    return Center(
                                      child: Text(
                                        context.l10n.customsApprovalNoTickets,
                                        style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                      ),
                                    );
                                  }
                                  return ListView.separated(
                                    itemCount: tickets.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final t = tickets[index];
                                      return _buildTicketCard(t);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  if (isNarrow) {
                    return ListView(
                      children: [
                        SizedBox(height: 400, child: leftCol),
                        const SizedBox(height: 12),
                        SizedBox(height: 400, child: rightCol),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: leftCol),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: rightCol),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    ),
  ),
);
  }

  Widget _buildApprovalRow(CustomsDocumentApprovalModel item) {
    final isDark = AppTheme.isDark(context);
    final l = context.l10n;
    Color overallColor = AppTheme.orange;
    if (item.overallStatus == 'Approved for Clearance') overallColor = AppTheme.emerald;
    if (item.overallStatus == 'Rectification Required' || item.overallStatus == 'Rejected') overallColor = AppTheme.crimson;

    final localizedDocType = _getLocalizedDocType(item.documentType, l);
    final localizedOverallStatus = _getLocalizedOverallStatus(item.overallStatus, l);
    final localizedCommercialStatus = _getLocalizedCommercialStatus(item.commercialStatus, l);
    final localizedBrokerStatus = _getLocalizedBrokerStatus(item.customsStatus, l);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CopyableText(
                  localizedDocType,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                  overflow: TextOverflow.ellipsis,
                  isSelectable: false,
                ),
              ),
              if (item.documentReferenceNo != null)
                CopyableText(
                  l.customsApprovalDocRef(item.documentReferenceNo!),
                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.black54),
                  overflow: TextOverflow.ellipsis,
                  isSelectable: false,
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: overallColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: overallColor.withOpacity(0.5)),
                    ),
                    child: CopyableText(
                      localizedOverallStatus,
                      style: TextStyle(color: overallColor, fontWeight: FontWeight.bold, fontSize: 11),
                      isSelectable: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: Key('cloneApprovalRowBtn_${item.approvalId}'),
                    icon: const Icon(Icons.copy_all, size: 16, color: AppTheme.wcagCobalt),
                    tooltip: l.cloneApprovalRecordTooltip,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _cloneApprovalItem(item),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Tier 1: Commercial Review
              InkWell(
                onTap: () => _showCommercialReviewDialog(item),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.commercialStatus == 'Approved'
                        ? AppTheme.emerald.withOpacity(0.08)
                        : (isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.commercialStatus == 'Approved'
                          ? AppTheme.emerald
                          : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                    ),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Icon(
                        item.commercialStatus == 'Approved' ? Icons.check_circle : Icons.person_outline,
                        size: 16,
                        color: item.commercialStatus == 'Approved' ? AppTheme.emerald : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
                      ),
                      Text(
                        l.customsApprovalCommercialReviewStatus(localizedCommercialStatus),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.commercialStatus == 'Approved'
                              ? AppTheme.emerald
                              : (isDark ? AppTheme.darkTextPrimary : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tier 2: Customs Broker Sign-off
              InkWell(
                onTap: () => _showCustomsBrokerReviewDialog(item),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.customsStatus == 'Approved'
                        ? AppTheme.emerald.withOpacity(0.08)
                        : (isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.customsStatus == 'Approved'
                          ? AppTheme.emerald
                          : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                    ),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Icon(
                        item.customsStatus == 'Approved' ? Icons.verified : Icons.gavel,
                        size: 16,
                        color: item.customsStatus == 'Approved' ? AppTheme.emerald : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
                      ),
                      Text(
                        l.customsApprovalBrokerReviewStatus(localizedBrokerStatus),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.customsStatus == 'Approved'
                              ? AppTheme.emerald
                              : (isDark ? AppTheme.darkTextPrimary : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(DiscrepancyRectificationTicketModel ticket) {
    final isDark = AppTheme.isDark(context);
    final l = context.l10n;
    final isResolved = ticket.status == 'Resolved';
    final localizedSeverity = _getLocalizedSeverity(ticket.severity, l);
    final localizedTicketStatus = _getLocalizedTicketStatus(ticket.status, l);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isResolved
              ? AppTheme.emerald.withOpacity(0.06)
              : (isDark ? AppTheme.darkElevatedSurface : AppTheme.orange.withOpacity(0.06)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isResolved
                ? AppTheme.emerald.withOpacity(0.4)
                : (isDark ? AppTheme.darkBorder : AppTheme.orange.withOpacity(0.4)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                CopyableText(
                  ticket.ticketCode,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  isSelectable: false,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: ticket.severity == 'Critical' ? AppTheme.crimson : AppTheme.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: CopyableText(
                    localizedSeverity,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    isSelectable: false,
                  ),
                ),
                CopyableText(
                  localizedTicketStatus,
                  style: TextStyle(
                    color: isResolved ? AppTheme.emerald : AppTheme.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  isSelectable: false,
                ),
                IconButton(
                  key: Key('cloneTicketRowBtn_${ticket.ticketId}'),
                  icon: const Icon(Icons.copy_all, size: 16, color: AppTheme.wcagCobalt),
                  tooltip: l.cloneTicketRecordTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _cloneTicket(ticket),
                ),
              ],
            ),
            const SizedBox(height: 4),
            CopyableText(
              ticket.description,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
              isSelectable: false,
            ),
            if (ticket.expectedValue != null || ticket.foundValue != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: CopyableText(
                  l.customsApprovalTicketExpectedVsFound(ticket.expectedValue ?? "-", ticket.foundValue ?? "-"),
                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.blueGrey),
                  isSelectable: false,
                ),
              ),
            if (!isResolved)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: Text(l.customsApprovalResolveTicketButton, style: const TextStyle(fontSize: 11)),
                  onPressed: () => _showResolveTicketDialog(ticket),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Commercial Review Dialog ---
class _CommercialReviewDialog extends StatefulWidget {
  final CustomsDocumentApprovalModel item;
  final int? importFileId;

  const _CommercialReviewDialog({required this.item, this.importFileId});

  @override
  State<_CommercialReviewDialog> createState() => _CommercialReviewDialogState();
}

class _CommercialReviewDialogState extends State<_CommercialReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedStatus = 'Approved';
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _nameCtrl.text = storedText.customsApprovalDefaultCommercialReviewer;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer(builder: (context, ref, _) {
      return AlertDialog(
        backgroundColor: isDark ? AppTheme.darkElevatedSurface : null,
        title: Text(context.l10n.customsApprovalCommercialDialogTitle(
          CustomsDocumentApprovalTabState._getLocalizedDocType(widget.item.documentType, context.l10n),
        )),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: context.l10n.customsApprovalCommercialReviewerLabel, border: const OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? context.l10n.customsApprovalRequiredField : null,
                ),
                const SizedBox(height: 12),
                SearchableDropdownField<String>(
                  value: _selectedStatus,
                  labelText: context.l10n.customsApprovalCommercialDecisionLabel,
                  searchHintText: context.l10n.customsApprovalSelectDecisionHint,
                  items: [
                    SearchableDropdownItem(value: 'Approved', label: context.l10n.customsApprovalDecisionCommercialApproved),
                    SearchableDropdownItem(value: 'Under Review', label: context.l10n.customsApprovalDecisionCommercialUnderReview),
                    SearchableDropdownItem(value: 'Rejected', label: context.l10n.customsApprovalDecisionCommercialRejected),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: context.l10n.customsApprovalCommercialNotesLabel, border: const OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _isSubmitting = true);
                    try {
                      await ref.read(docsCustomsApprovalProvider.notifier).submitCommercialReview(
                            approvalId: widget.item.approvalId,
                            reviewerName: _nameCtrl.text.trim(),
                            status: _selectedStatus,
                            notes: _notesCtrl.text.trim(),
                            importFileId: widget.importFileId,
                            version: widget.item.version,
                          );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (e is DioException && e.response?.statusCode == 409) {
                        final data = e.response?.data;
                        final conflict = (data is Map<String, dynamic> && data['detail'] is Map)
                            ? Map<String, dynamic>.from(data['detail'] as Map)
                            : (data is Map<String, dynamic> ? data : <String, dynamic>{});
                        if (context.mounted) {
                          final resolution = await ConcurrencyConflictDialog.show(
                            context,
                            entityName: conflict['entity'] as String? ?? 'CustomsDocumentApproval',
                            recordId: conflict['record_id'] ?? widget.item.approvalId,
                            currentVersion: (conflict['current_version'] as num?)?.toInt() ?? (widget.item.version + 1),
                            submittedVersion: (conflict['submitted_version'] as num?)?.toInt() ?? widget.item.version,
                            updatedAt: conflict['updated_at'] as String?,
                            updatedBy: conflict['updated_by'] as String?,
                            serverMessage: conflict['message'] as String?,
                            currentDraftData: {
                              'reviewer_name': _nameCtrl.text.trim(),
                              'status': _selectedStatus,
                              'notes': _notesCtrl.text.trim(),
                            },
                          );
                          if (context.mounted && resolution == ConcurrencyResolution.discardAndReload) {
                            Navigator.pop(context);
                            if (widget.importFileId != null) {
                              await ref.read(docsCustomsApprovalProvider.notifier).fetchApprovals(importFileId: widget.importFileId);
                            }
                          }
                        }
                        return;
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.customsApprovalError(e.toString())), backgroundColor: AppTheme.crimson),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isSubmitting = false);
                      }
                    }
                  },
            child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(context.l10n.customsApprovalSaveApprovalButton),
          ),
        ],
      );
    });
  }
}

// --- Customs Broker Review Dialog ---
class _CustomsBrokerReviewDialog extends StatefulWidget {
  final CustomsDocumentApprovalModel item;
  final int? importFileId;

  const _CustomsBrokerReviewDialog({required this.item, this.importFileId});

  @override
  State<_CustomsBrokerReviewDialog> createState() => _CustomsBrokerReviewDialogState();
}

class _CustomsBrokerReviewDialogState extends State<_CustomsBrokerReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _brokerCtrl = TextEditingController();
  final _reviewerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedStatus = 'Approved';
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _brokerCtrl.text = storedText.customsApprovalDefaultBrokerOffice;
      _reviewerCtrl.text = storedText.customsApprovalDefaultLegalOfficer;
    }
  }

  @override
  void dispose() {
    _brokerCtrl.dispose();
    _reviewerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer(builder: (context, ref, _) {
      return AlertDialog(
        backgroundColor: isDark ? AppTheme.darkElevatedSurface : null,
        title: Text(context.l10n.customsApprovalBrokerDialogTitle(
          CustomsDocumentApprovalTabState._getLocalizedDocType(widget.item.documentType, context.l10n),
        )),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _brokerCtrl,
                  decoration: InputDecoration(labelText: context.l10n.customsApprovalBrokerOfficeLabel, border: const OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? context.l10n.customsApprovalRequiredField : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reviewerCtrl,
                  decoration: InputDecoration(labelText: context.l10n.customsApprovalBrokerReviewerNameLabel, border: const OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? context.l10n.customsApprovalRequiredField : null,
                ),
                const SizedBox(height: 12),
                SearchableDropdownField<String>(
                  value: _selectedStatus,
                  labelText: context.l10n.customsApprovalBrokerDecisionLabel,
                  searchHintText: context.l10n.customsApprovalSelectDecisionHint,
                  items: [
                    SearchableDropdownItem(value: 'Approved', label: context.l10n.customsApprovalDecisionBrokerApproved),
                    SearchableDropdownItem(value: 'Conditionally Approved', label: context.l10n.customsApprovalDecisionBrokerConditionallyApproved),
                    SearchableDropdownItem(value: 'Rejected', label: context.l10n.customsApprovalDecisionBrokerRejected),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: context.l10n.customsApprovalBrokerNotesLabel, border: const OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _isSubmitting = true);
                    try {
                      await ref.read(docsCustomsApprovalProvider.notifier).submitCustomsBrokerReview(
                            approvalId: widget.item.approvalId,
                            brokerName: _brokerCtrl.text.trim(),
                            reviewerName: _reviewerCtrl.text.trim(),
                            status: _selectedStatus,
                            notes: _notesCtrl.text.trim(),
                            importFileId: widget.importFileId,
                            version: widget.item.version,
                          );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (e is DioException && e.response?.statusCode == 409) {
                        final data = e.response?.data;
                        final conflict = (data is Map<String, dynamic> && data['detail'] is Map)
                            ? Map<String, dynamic>.from(data['detail'] as Map)
                            : (data is Map<String, dynamic> ? data : <String, dynamic>{});
                        if (context.mounted) {
                          final resolution = await ConcurrencyConflictDialog.show(
                            context,
                            entityName: conflict['entity'] as String? ?? 'CustomsDocumentApproval',
                            recordId: conflict['record_id'] ?? widget.item.approvalId,
                            currentVersion: (conflict['current_version'] as num?)?.toInt() ?? (widget.item.version + 1),
                            submittedVersion: (conflict['submitted_version'] as num?)?.toInt() ?? widget.item.version,
                            updatedAt: conflict['updated_at'] as String?,
                            updatedBy: conflict['updated_by'] as String?,
                            serverMessage: conflict['message'] as String?,
                            currentDraftData: {
                              'broker_name': _brokerCtrl.text.trim(),
                              'reviewer_name': _reviewerCtrl.text.trim(),
                              'status': _selectedStatus,
                              'notes': _notesCtrl.text.trim(),
                            },
                          );
                          if (context.mounted && resolution == ConcurrencyResolution.discardAndReload) {
                            Navigator.pop(context);
                            if (widget.importFileId != null) {
                              await ref.read(docsCustomsApprovalProvider.notifier).fetchApprovals(importFileId: widget.importFileId);
                            }
                          }
                        }
                        return;
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.customsApprovalError(e.toString())), backgroundColor: AppTheme.crimson),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isSubmitting = false);
                      }
                    }
                  },
            child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(context.l10n.customsApprovalBrokerSaveStampButton),
          ),
        ],
      );
    });
  }
}

// --- Raise Ticket Dialog ---
class _RaiseTicketDialog extends StatefulWidget {
  final int importFileId;
  final CustomsDocumentApprovalModel? approvalItem;
  final DiscrepancyRectificationTicketModel? initialTicket;

  const _RaiseTicketDialog({required this.importFileId, this.approvalItem, this.initialTicket});

  @override
  State<_RaiseTicketDialog> createState() => _RaiseTicketDialogState();
}

class _RaiseTicketDialogState extends State<_RaiseTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  String _issueCategory = 'HS Code Mismatch';
  String _severity = 'Major';
  final _descCtrl = TextEditingController();
  final _expectedCtrl = TextEditingController();
  final _foundCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTicket != null) {
      _issueCategory = widget.initialTicket!.issueCategory;
      _severity = widget.initialTicket!.severity;
      _descCtrl.text = widget.initialTicket!.description;
      _expectedCtrl.text = widget.initialTicket!.expectedValue ?? '';
      _foundCtrl.text = widget.initialTicket!.foundValue ?? '';
      _actionCtrl.text = widget.initialTicket!.supplierActionRequired ?? '';
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _expectedCtrl.dispose();
    _foundCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer(builder: (context, ref, _) {
      return AlertDialog(
        backgroundColor: isDark ? AppTheme.darkElevatedSurface : null,
        title: Text(context.l10n.customsApprovalRaiseTicketDialogTitle),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdownField<String>(
                    value: _issueCategory,
                    labelText: context.l10n.customsApprovalIssueCategoryLabel,
                    searchHintText: context.l10n.customsApprovalSelectCategoryHint,
                    items: [
                      SearchableDropdownItem(value: 'HS Code Mismatch', label: context.l10n.customsApprovalCatHsMismatch),
                      SearchableDropdownItem(value: 'Weight Discrepancy', label: context.l10n.customsApprovalCatWeightDiscrepancy),
                      SearchableDropdownItem(value: 'CBM Discrepancy', label: context.l10n.customsApprovalCatCbmDiscrepancy),
                      SearchableDropdownItem(value: 'Value Mismatch', label: context.l10n.customsApprovalCatValueMismatch),
                      SearchableDropdownItem(value: 'Missing ACID', label: context.l10n.customsApprovalCatMissingAcid),
                      SearchableDropdownItem(value: 'Incoterm Conflict', label: context.l10n.customsApprovalCatIncotermConflict),
                      SearchableDropdownItem(value: 'Other', label: context.l10n.customsApprovalCatOther),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _issueCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SearchableDropdownField<String>(
                    value: _severity,
                    labelText: context.l10n.customsApprovalSeverityLabel,
                    searchHintText: context.l10n.customsApprovalSelectSeverityHint,
                    items: [
                      SearchableDropdownItem(value: 'Critical', label: context.l10n.customsApprovalSevCritical),
                      SearchableDropdownItem(value: 'Major', label: context.l10n.customsApprovalSevMajor),
                      SearchableDropdownItem(value: 'Minor', label: context.l10n.customsApprovalSevMinor),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _severity = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: context.l10n.customsApprovalIssueDescLabel, border: const OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().length < 5 ? context.l10n.customsApprovalIssueDescMinLength : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expectedCtrl,
                          decoration: InputDecoration(labelText: context.l10n.customsApprovalExpectedValueLabel, border: const OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _foundCtrl,
                          decoration: InputDecoration(labelText: context.l10n.customsApprovalFoundValueLabel, border: const OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _actionCtrl,
                    decoration: InputDecoration(labelText: context.l10n.customsApprovalSupplierActionLabel, border: const OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange, foregroundColor: Colors.white),
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _isSubmitting = true);
                    try {
                      await ref.read(discrepancyTicketsProvider.notifier).createTicket({
                        'import_file_id': widget.importFileId,
                        'approval_id': widget.approvalItem?.approvalId,
                        'issue_category': _issueCategory,
                        'severity': _severity,
                        'description': _descCtrl.text.trim(),
                        'expected_value': _expectedCtrl.text.trim(),
                        'found_value': _foundCtrl.text.trim(),
                        'supplier_action_required': _actionCtrl.text.trim(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.customsApprovalError(e.toString())), backgroundColor: AppTheme.crimson),
                        );
                      }
                    } finally {
                      setState(() => _isSubmitting = false);
                    }
                  },
            child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(context.l10n.customsApprovalCreateTicketSubmitButton),
          ),
        ],
      );
    });
  }
}

// --- Resolve Ticket Dialog ---
class _ResolveTicketDialog extends StatefulWidget {
  final DiscrepancyRectificationTicketModel ticket;
  final int? importFileId;

  const _ResolveTicketDialog({required this.ticket, this.importFileId});

  @override
  State<_ResolveTicketDialog> createState() => _ResolveTicketDialogState();
}

class _ResolveTicketDialogState extends State<_ResolveTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _responseCtrl = TextEditingController();
  final _resolverCtrl = TextEditingController();
  String _newStatus = 'Resolved';
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _resolverCtrl.text = storedText.customsApprovalDefaultComplianceOfficer;
    }
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    _resolverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer(builder: (context, ref, _) {
      return AlertDialog(
        backgroundColor: isDark ? AppTheme.darkElevatedSurface : null,
        title: Text(context.l10n.customsApprovalResolveTicketDialogTitle(widget.ticket.ticketCode)),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _responseCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: context.l10n.customsApprovalSupplierResponseLabel, border: const OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? context.l10n.customsApprovalRequiredField : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _resolverCtrl,
                  decoration: InputDecoration(labelText: context.l10n.customsApprovalResolverNameLabel, border: const OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? context.l10n.customsApprovalRequiredField : null,
                ),
                const SizedBox(height: 12),
                SearchableDropdownField<String>(
                  value: _newStatus,
                  labelText: context.l10n.customsApprovalFinalStatusLabel,
                  searchHintText: context.l10n.customsApprovalSelectStatusHint,
                  items: [
                    SearchableDropdownItem(value: 'Resolved', label: context.l10n.customsApprovalStatusResolved),
                    SearchableDropdownItem(value: 'Waived', label: context.l10n.customsApprovalStatusWaived),
                    SearchableDropdownItem(value: 'Closed', label: context.l10n.customsApprovalStatusClosed),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _newStatus = val);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _isSubmitting = true);
                    try {
                      await ref.read(discrepancyTicketsProvider.notifier).resolveTicket(
                            widget.ticket.ticketId,
                            {
                              'supplier_response': _responseCtrl.text.trim(),
                              'resolved_by': _resolverCtrl.text.trim(),
                              'new_status': _newStatus,
                            },
                            importFileId: widget.importFileId,
                          );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.customsApprovalError(e.toString())), backgroundColor: AppTheme.crimson),
                        );
                      }
                    } finally {
                      setState(() => _isSubmitting = false);
                    }
                  },
            child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(context.l10n.customsApprovalConfirmResolveTicketButton),
          ),
        ],
      );
    });
  }
}
