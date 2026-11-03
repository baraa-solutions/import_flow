import 'package:flutter/material.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../models/docs_customs_approval_model.dart';

class DocApprovalHelpers {
  const DocApprovalHelpers._();

  static String getLocalizedDocType(String docType, AppLocalizations l) {
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
        return l.idocAFumigationCertificate;
      case 'Bank Form 4':
        return l.customsApprovalDocBankForm4;
      case 'Proforma Invoice':
        return l.customsApprovalDocProformaInvoice;
      default:
        return docType;
    }
  }

  static String getLocalizedOverallStatus(String status, AppLocalizations l) {
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

  static String getLocalizedCommercialStatus(String status, AppLocalizations l) {
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

  static String getLocalizedBrokerStatus(String status, AppLocalizations l) {
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

  static String getLocalizedSeverity(String severity, AppLocalizations l) {
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

  static String getLocalizedTicketStatus(String status, AppLocalizations l) {
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

  static String getLocalizedCompliance(String compliance, AppLocalizations l) {
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

  static void copyApprovalsAsTsv(BuildContext context, List<CustomsDocumentApprovalModel> approvals) {
    final l = context.l10n;
    final headers = [
      l.idocAApprovalCode,
      l.idocADocumentType,
      l.idocARefNumber,
      l.idocACommercialStatus,
      l.idocACommercialReviewer,
      l.idocABrokerStatus,
      l.idocABrokerReviewer,
      l.idocAOverallStatus,
    ];
    final rows = approvals.map((a) {
      return [
        a.approvalCode,
        getLocalizedDocType(a.documentType, l),
        a.documentReferenceNo ?? '-',
        getLocalizedCommercialStatus(a.commercialStatus, l),
        a.commercialReviewedBy ?? '-',
        getLocalizedBrokerStatus(a.customsStatus, l),
        a.customsReviewedBy ?? a.customsBrokerName ?? '-',
        getLocalizedOverallStatus(a.overallStatus, l),
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  static Future<void> exportApprovalsToExcel({
    required BuildContext context,
    required List<CustomsDocumentApprovalModel> approvals,
    required int? importFileId,
  }) async {
    final l = context.l10n;
    final headers = [
      l.idocAApprovalCode,
      l.idocADocumentType,
      l.idocARefNumber,
      l.idocACommercialStatus,
      l.idocACommercialReviewer,
      l.idocABrokerStatus,
      l.idocABrokerReviewer,
      l.idocAOverallStatus,
    ];
    final rows = approvals.map((a) {
      return [
        a.approvalCode,
        getLocalizedDocType(a.documentType, l),
        a.documentReferenceNo ?? '-',
        getLocalizedCommercialStatus(a.commercialStatus, l),
        a.commercialReviewedBy ?? '-',
        getLocalizedBrokerStatus(a.customsStatus, l),
        a.customsReviewedBy ?? a.customsBrokerName ?? '-',
        getLocalizedOverallStatus(a.overallStatus, l),
      ];
    }).toList();
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.idocAApprovalsMatrixTitle,
      importFileNameOrCode: importFileId != null ? 'IMP-$importFileId' : 'Customs_Approvals',
    );
  }

  static Future<void> exportApprovalsToPdf({
    required BuildContext context,
    required List<CustomsDocumentApprovalModel> approvals,
    required int? importFileId,
  }) async {
    final l = context.l10n;
    final headers = [
      l.idocACode,
      l.idocADoc,
      l.idocARef,
      l.idocACommercial,
      l.idocABroker,
      l.status,
    ];
    final rows = approvals.map((a) {
      return [
        a.approvalCode,
        getLocalizedDocType(a.documentType, l),
        a.documentReferenceNo ?? '-',
        getLocalizedCommercialStatus(a.commercialStatus, l),
        getLocalizedBrokerStatus(a.customsStatus, l),
        getLocalizedOverallStatus(a.overallStatus, l),
      ];
    }).toList();
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.idocAApprovalsMatrixTitle,
      importFileNameOrCode: importFileId != null ? 'IMP-$importFileId' : 'Customs_Approvals',
      headerContext: TableExportHeaderContext(
        title: l.idocACustomsDocumentApprovalsReport,
        subtitle: l.idocAFooterDocsBrand,
        metadata: {
          l.idocAFile: importFileId != null ? 'IMP-$importFileId' : '-',
          l.idocATotalDocs: '${approvals.length}',
          l.date: DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }

  static void copyTicketsAsTsv(BuildContext context, List<DiscrepancyRectificationTicketModel> tickets) {
    final l = context.l10n;
    final headers = [
      l.idocATicketCode,
      l.idocAIssueCategory,
      l.idocASeverity,
      l.status,
      l.idocADescription,
      l.idocAExpected,
      l.idocAFound,
    ];
    final rows = tickets.map((t) {
      return [
        t.ticketCode,
        t.issueCategory,
        getLocalizedSeverity(t.severity, l),
        getLocalizedTicketStatus(t.status, l),
        t.description,
        t.expectedValue ?? '-',
        t.foundValue ?? '-',
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  static Future<void> exportTicketsToExcel({
    required BuildContext context,
    required List<DiscrepancyRectificationTicketModel> tickets,
    required int? importFileId,
  }) async {
    final l = context.l10n;
    final headers = [
      l.idocATicketCode,
      l.idocAIssueCategory,
      l.idocASeverity,
      l.status,
      l.idocADescription,
      l.idocAExpected,
      l.idocAFound,
    ];
    final rows = tickets.map((t) {
      return [
        t.ticketCode,
        t.issueCategory,
        getLocalizedSeverity(t.severity, l),
        getLocalizedTicketStatus(t.status, l),
        t.description,
        t.expectedValue ?? '-',
        t.foundValue ?? '-',
      ];
    }).toList();
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.idocARectificationTickets,
      importFileNameOrCode: importFileId != null ? 'IMP-$importFileId' : 'Tickets',
    );
  }

  static Future<void> exportTicketsToPdf({
    required BuildContext context,
    required List<DiscrepancyRectificationTicketModel> tickets,
    required int? importFileId,
  }) async {
    final l = context.l10n;
    final headers = [
      l.idocACode,
      l.idocASeverityAlt,
      l.status,
      l.idocADescription,
      l.idocAExpectedAlt,
      l.idocAFoundAlt,
    ];
    final rows = tickets.map((t) {
      return [
        t.ticketCode,
        getLocalizedSeverity(t.severity, l),
        getLocalizedTicketStatus(t.status, l),
        t.description,
        t.expectedValue ?? '-',
        t.foundValue ?? '-',
      ];
    }).toList();
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.idocARectificationTickets,
      importFileNameOrCode: importFileId != null ? 'IMP-$importFileId' : 'Tickets',
      headerContext: TableExportHeaderContext(
        title: l.idocARectificationTicketsReport,
        subtitle: l.idocAFooterDiscrepancyBrand,
        metadata: {
          l.idocAFile: importFileId != null ? 'IMP-$importFileId' : '-',
          l.idocATotalTickets: '${tickets.length}',
          l.date: DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }
}
