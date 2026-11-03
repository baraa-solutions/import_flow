import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/project_model.dart';

/// Pure localization and formatting helpers for Projects & Cost Centers.
class ProjectsHelpers {
  ProjectsHelpers._();

  /// Returns pure localized label for project status.
  static String getStatusLabel(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'All':
        return l10n.statusAll;
      case 'Open':
        return l10n.statusOpen;
      case 'Closed':
        return l10n.statusClosed;
      case 'On Hold':
        return l10n.statusOnHold;
      default:
        return status;
    }
  }

  /// Returns pure localized label for project import type.
  static String getImportTypeLabel(BuildContext context, String importType) {
    final l10n = context.l10n;
    if (importType.contains('Direct Commercial') || importType == 'Direct Commercial') {
      return l10n.importTypeDirectCommercial;
    }
    if (importType.contains('Free Zone') || importType == 'Free Zone') {
      return l10n.importTypeFreeZone;
    }
    if (importType.contains('Temporary Release') || importType.contains('السماح المؤقت')) {
      return l10n.importTypeTemporaryRelease;
    }
    if (importType.contains('Drawback') || importType == 'Drawback') {
      return l10n.importTypeDrawback;
    }
    if (importType.contains('Project Equipment') || importType.contains('معدات مشروعات')) {
      return l10n.importTypeProjectEquipment;
    }
    return importType;
  }

  /// Returns pure localized label for shipment category.
  static String getCategoryLabel(BuildContext context, String category) {
    final l10n = context.l10n;
    switch (category.trim()) {
      case 'FCL Container':
        return l10n.categoryFclContainer;
      case 'LCL Breakbulk':
        return l10n.categoryLclBreakbulk;
      case 'Air Freight':
        return l10n.categoryAirFreight;
      case 'Bulk Cargo':
        return l10n.categoryBulkCargo;
      case 'Multimodal':
        return l10n.categoryMultimodal;
      case 'Courier':
        return l10n.categoryCourier;
      default:
        return category;
    }
  }

  /// Formats project budget with currency.
  static String formatBudget(BuildContext context, ProjectModel p) {
    if (p.totalBudgetUsd == null) return context.l10n.projectBudgetNotSet;
    return '${p.budgetCurrency} ${p.totalBudgetUsd!.toStringAsFixed(2)}';
  }

  /// Returns pure localized label for project priority.
  static String getPriorityLabel(BuildContext context, String priority) {
    final l10n = context.l10n;
    switch (priority) {
      case 'Low':
        return l10n.priorityLow;
      case 'Medium':
        return l10n.priorityMedium;
      case 'High':
        return l10n.priorityHigh;
      case 'Urgent':
      case 'Urgent / حرج':
        return l10n.priorityUrgent;
      default:
        return priority;
    }
  }

  /// Builds a human-readable multi-line summary of a project.
  static String buildProjectSummary(BuildContext context, ProjectModel p) {
    final l10n = context.l10n;
    final categoriesText = p.shipmentCategory
        .split(',')
        .map((c) => getCategoryLabel(context, c))
        .join(', ');
    final incotermText = p.incotermCode ?? l10n.projectIncotermFallback;
    final budgetText = formatBudget(context, p);
    final targetDateText = p.targetEndDate ?? '-';
    final activeText = p.isActive ? l10n.projectActiveYes : l10n.projectActiveNo;
    final multiShipmentText =
        p.allowMultiShipment ? l10n.projectMultiShipmentYes : l10n.projectMultiShipmentNo;
    final multiCompanyText =
        p.allowMultiCompany ? l10n.projectMultiCompanyYes : l10n.projectMultiCompanyNo;
    final notesText = (p.notes != null && p.notes!.trim().isNotEmpty)
        ? p.notes!.trim()
        : l10n.projectNotesFallback;

    return '''
[${p.projectCode}] ${p.projectName}
- ${l10n.projectOwnerLabelField.replaceAll('*', '').trim()}: ${p.projectOwner}
- ${l10n.importingCompaniesFieldLabel.replaceAll('*', '').trim()}: ${p.companyName ?? l10n.projectCompanyFallback(p.companyId)}
- ${l10n.primarySupplierLabel.replaceAll('*', '').trim()}: ${p.supplierName ?? '#${p.supplierId}'}
- ${l10n.importTypeLabel.replaceAll('*', '').trim()}: ${getImportTypeLabel(context, p.importType)}
- ${l10n.projectColShipmentCategories}: $categoriesText
- ${l10n.defaultIncotermLabel.replaceAll('*', '').trim()}: $incotermText
- ${l10n.budgetUsdCol}: $budgetText
- ${l10n.targetEndDateLabel}: $targetDateText
- ${l10n.capMultiShipment}: $multiShipmentText
- ${l10n.capMultiCompany}: $multiCompanyText
- ${l10n.statusCol}: ${getStatusLabel(context, p.status)}
- ${l10n.projectColActive}: $activeText
- ${l10n.projectNotesLabel}: $notesText
'''.trim();
  }

  /// Builds tab-separated summary string of a project row for clipboard copy.
  static String buildProjectRowSummary(BuildContext context, ProjectModel p) {
    final l10n = context.l10n;
    final categoriesText = p.shipmentCategory
        .split(',')
        .map((c) => getCategoryLabel(context, c))
        .join(', ');
    final incotermText = p.incotermCode ?? l10n.projectIncotermFallback;
    final budgetText = formatBudget(context, p);
    final targetDateText = p.targetEndDate ?? '';
    final activeText = p.isActive ? l10n.projectActiveYes : l10n.projectActiveNo;
    final multiShipmentText =
        p.allowMultiShipment ? l10n.projectMultiShipmentYes : l10n.projectMultiShipmentNo;
    final multiCompanyText =
        p.allowMultiCompany ? l10n.projectMultiCompanyYes : l10n.projectMultiCompanyNo;

    return [
      p.projectCode,
      p.projectName,
      p.projectOwner,
      p.companyName ?? l10n.projectCompanyFallback(p.companyId),
      p.supplierName ?? '#${p.supplierId}',
      getImportTypeLabel(context, p.importType),
      categoriesText,
      incotermText,
      budgetText,
      targetDateText,
      multiShipmentText,
      multiCompanyText,
      getStatusLabel(context, p.status),
      activeText,
    ].join('\t');
  }

  /// Copies all projects as TSV (Tab-Separated Values) to clipboard.
  static void copyProjectsTsv(BuildContext context, List<ProjectModel> projects) {
    final l10n = context.l10n;
    final headers = [
      l10n.projectCodeCol,
      l10n.projectNameAndOwnerCol,
      l10n.projectOwnerLabelField.replaceAll('*', '').trim(),
      l10n.companyAndSupplierCol,
      l10n.primarySupplierLabel.replaceAll('*', '').trim(),
      l10n.importTypeLabel.replaceAll('*', '').trim(),
      l10n.projectColShipmentCategories,
      l10n.defaultIncotermLabel.replaceAll('*', '').trim(),
      l10n.budgetUsdCol,
      l10n.targetEndDateCol,
      l10n.capMultiShipment,
      l10n.capMultiCompany,
      l10n.statusCol,
      l10n.projectColActive,
      l10n.projectNotesLabel,
    ];

    final rows = projects.map((p) {
      final categoriesText = p.shipmentCategory
          .split(',')
          .map((c) => getCategoryLabel(context, c))
          .join(', ');
      final incotermText = p.incotermCode ?? l10n.projectIncotermFallback;
      final budgetText = formatBudget(context, p);
      final targetDateText = p.targetEndDate ?? '';
      final activeText = p.isActive ? l10n.projectActiveYes : l10n.projectActiveNo;
      final multiShipmentText =
          p.allowMultiShipment ? l10n.projectMultiShipmentYes : l10n.projectMultiShipmentNo;
      final multiCompanyText =
          p.allowMultiCompany ? l10n.projectMultiCompanyYes : l10n.projectMultiCompanyNo;
      final notesText = (p.notes != null && p.notes!.trim().isNotEmpty)
          ? p.notes!.trim()
          : l10n.projectNotesFallback;

      return [
        p.projectCode,
        p.projectName,
        p.projectOwner,
        p.companyName ?? l10n.projectCompanyFallback(p.companyId),
        p.supplierName ?? '#${p.supplierId}',
        getImportTypeLabel(context, p.importType),
        categoriesText,
        incotermText,
        budgetText,
        targetDateText,
        multiShipmentText,
        multiCompanyText,
        getStatusLabel(context, p.status),
        activeText,
        notesText,
      ].join('\t');
    }).join('\n');

    final tsv = '${headers.join('\t')}\n$rows';
    CopyHelper.copy(context, tsv, customMessage: l10n.projectsExportTsvSuccess);
  }
}
