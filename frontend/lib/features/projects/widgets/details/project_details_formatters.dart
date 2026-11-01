import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../models/project_model.dart';

class ProjectDetailsFormatters {
  static String getStatusLabel(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status) {
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

  static String getPriorityLabel(BuildContext context, String priority) {
    final l10n = context.l10n;
    switch (priority) {
      case 'High':
      case 'High / مرتفع':
        return l10n.priorityHigh;
      case 'Medium':
      case 'Medium / متوسط':
        return l10n.priorityMedium;
      case 'Low':
      case 'Low / منخفض':
        return l10n.priorityLow;
      case 'Urgent':
      case 'Urgent / حرج':
        return l10n.priorityUrgent;
      default:
        return priority;
    }
  }

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

  static String buildProjectSummary(BuildContext context, ProjectModel project) {
    final l10n = context.l10n;
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final b = StringBuffer();
    b.writeln('📋 [${project.projectCode}] ${project.projectName}');
    b.writeln('${l10n.projectOwnerLabelField.replaceAll('*', '').trim()}: ${project.projectOwner}');
    if (project.companyName != null && project.companyName!.isNotEmpty) {
      b.writeln('${l10n.importingCompaniesFieldLabel.replaceAll('*', '').trim()}: ${project.companyName}');
    }
    if (project.supplierName != null && project.supplierName!.isNotEmpty) {
      b.writeln('${l10n.primarySupplierLabel.replaceAll('*', '').trim()}: ${project.supplierName}');
    }
    if (project.incotermCode != null) {
      b.writeln('${l10n.defaultIncotermLabel.replaceAll('*', '').trim()}: ${project.incotermCode}');
    }
    b.writeln('${l10n.importTypeLabel.replaceAll('*', '').trim()}: ${getImportTypeLabel(context, project.importType)}');
    b.writeln('${l10n.priorityLabel}: ${getPriorityLabel(context, project.priority)}');
    if (project.totalBudgetUsd != null) {
      b.writeln('${l10n.budgetUsdCol}: ${project.budgetCurrency} ${project.totalBudgetUsd!.toStringAsFixed(2)}');
    }
    if (project.totalCommittedUsd != null) {
      b.writeln('${isArabic ? "الالتزامات والارتباطات" : "Committed Budget"}: ${project.budgetCurrency} ${project.totalCommittedUsd!.toStringAsFixed(2)}');
    }
    if (project.remainingBudgetUsd != null) {
      b.writeln('${isArabic ? "المتبقي من الموازنة" : "Remaining Budget"}: ${project.budgetCurrency} ${project.remainingBudgetUsd!.toStringAsFixed(2)}');
    }
    b.writeln('${l10n.statusCol}: ${getStatusLabel(context, project.status)} (${project.isActive ? l10n.statusActive : l10n.statusInactive})');
    if (project.targetEndDate != null && project.targetEndDate!.isNotEmpty) {
      b.writeln('${l10n.targetEndDateLabel}: ${project.targetEndDate}');
    }
    if (project.notes != null && project.notes!.isNotEmpty) {
      b.writeln('${l10n.projectNotesLabel}: ${project.notes}');
    }
    return b.toString().trim();
  }
}
