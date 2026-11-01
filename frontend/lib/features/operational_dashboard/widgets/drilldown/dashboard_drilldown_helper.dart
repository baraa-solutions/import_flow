import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../smart_tasks/models/smart_task_model.dart';
import 'drilldown_models.dart';

class DashboardDrillDownHelper {
  static List<DrillDownItem> getRecords({
    required DashboardCardType type,
    required List<ImportFileModel> shipments,
    required List<SmartTaskModel> tasks,
    required bool isArabic,
    required AppLocalizations l,
    void Function(String shipmentCode)? onFocusShipment,
    void Function(int taskId)? onCompleteTask,
    void Function(ImportFileModel shipment)? onDailyUpdate,
  }) {
    switch (type) {
      case DashboardCardType.todaysTasks:
        final todayStr = DateTime.now().toIso8601String().split('T').first;
        final filtered = tasks.where((t) {
          final d = t.dueDate;
          final isToday = d != null && (d == todayStr || d.startsWith(todayStr));
          return isToday && t.status != 'Completed' && t.status != 'Cancelled';
        }).toList();

        return filtered.map((t) {
          final shipmentName = t.importFileCode != null
              ? DisplayNameResolver.resolveShipmentNameByCode(
                  t.importFileCode,
                  shipments: shipments,
                  isArabic: isArabic,
                )
              : null;
          return DrillDownItem(
            id: t.taskId.toString(),
            title: t.displayTitle(l),
            subtitle: DisplayNameResolver.resolveTaskType(t.taskType, isArabic: isArabic),
            shipmentCode: t.importFileCode,
            shipmentTitle: shipmentName,
            who: t.assignedUser.isNotEmpty ? t.assignedUser : (isArabic ? 'كمال' : 'Kamal'),
            byWhen: t.dueDate ?? (isArabic ? 'اليوم' : 'Today'),
            status: DisplayNameResolver.resolveTaskStatus(t.status, isArabic: isArabic),
            statusColorType: 'info',
            nextAction: t.displayDescription(l, shipments: shipments, orNotes: true),
            dataGaps: [l.drillDownTimeDataGap],
            actionLabel: onCompleteTask != null ? l.drillDownActionCompleteTask : null,
            onAction: onCompleteTask != null ? () => onCompleteTask(t.taskId) : null,
            secondaryActionLabel: (onFocusShipment != null && t.importFileCode != null)
                ? l.drillDownActionFocusShipment
                : null,
            onSecondaryAction: (onFocusShipment != null && t.importFileCode != null)
                ? () => onFocusShipment(t.importFileCode!)
                : null,
          );
        }).toList();

      case DashboardCardType.pendingTasks:
        final filtered = tasks.where((t) => t.status == 'Pending' || t.status == 'In Progress').toList();

        return filtered.map((t) {
          final shipmentName = t.importFileCode != null
              ? DisplayNameResolver.resolveShipmentNameByCode(
                  t.importFileCode,
                  shipments: shipments,
                  isArabic: isArabic,
                )
              : null;
          return DrillDownItem(
            id: t.taskId.toString(),
            title: t.displayTitle(l),
            subtitle: DisplayNameResolver.resolveTaskType(t.taskType, isArabic: isArabic),
            shipmentCode: t.importFileCode,
            shipmentTitle: shipmentName,
            who: t.assignedUser.isNotEmpty ? t.assignedUser : (isArabic ? 'كمال' : 'Kamal'),
            byWhen: t.dueDate != null && t.dueDate!.isNotEmpty
                ? t.dueDate!
                : (isArabic ? 'غير محدد' : 'Unspecified'),
            status: DisplayNameResolver.resolveTaskStatus(t.status, isArabic: isArabic),
            statusColorType: 'warning',
            nextAction: t.displayDescription(l, shipments: shipments, orNotes: true),
            dataGaps: [l.drillDownPendingReasonDataGap],
            actionLabel: onCompleteTask != null ? l.drillDownActionCompleteTask : null,
            onAction: onCompleteTask != null ? () => onCompleteTask(t.taskId) : null,
            secondaryActionLabel: (onFocusShipment != null && t.importFileCode != null)
                ? l.drillDownActionFocusShipment
                : null,
            onSecondaryAction: (onFocusShipment != null && t.importFileCode != null)
                ? () => onFocusShipment(t.importFileCode!)
                : null,
          );
        }).toList();

      case DashboardCardType.upcomingShipments:
        final filtered = shipments.where((s) => s.status != 'Closed').toList();

        return filtered.map((s) {
          final title = DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic);
          final companyPart = s.companyName.isNotEmpty ? s.companyName : '';
          final supplierPart = s.supplierName.isNotEmpty ? s.supplierName : '';
          final subtitle = [companyPart, supplierPart].where((x) => x.isNotEmpty).join(' • ');

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: title,
            subtitle: subtitle.isNotEmpty ? subtitle : null,
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'المسؤول' : 'Owner'}: ${s.owner.isNotEmpty ? s.owner : 'Kamal'} • ${isArabic ? 'المخلص' : 'Broker'}: ${s.brokerName != null && s.brokerName!.isNotEmpty ? s.brokerName! : (isArabic ? 'غير محدد' : 'Unassigned')}',
            byWhen: s.requiredEta != null && s.requiredEta!.isNotEmpty
                ? '${isArabic ? "وصول متوقع" : "ETA"}: ${s.requiredEta}'
                : (isArabic ? 'موعد الوصول قيد التنسيق' : 'ETA pending scheduling'),
            status: (s.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(s.currentModule, isArabic: isArabic)),
            statusColorType: 'info',
            nextAction: s.displayNextAction(l),
            dataGaps: const [],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.arrivingThisWeek:
        final filtered = shipments.where((s) {
          return s.status != 'Closed' &&
              (s.requiredEta != null ||
                  s.currentModule.toString().contains('Phase 5') ||
                  s.currentModule.toString().contains('Phase 4'));
        }).toList();

        return filtered.map((s) {
          final vessel = s.selectedScenario != null && s.selectedScenario!.isNotEmpty
              ? s.selectedScenario!
              : (isArabic ? 'قيد التحديد' : 'TBD');
          final port = s.portOfDischarge != null && s.portOfDischarge!.isNotEmpty
              ? s.portOfDischarge!
              : (isArabic ? 'غير محدد' : 'Unspecified');

          String clearanceStatus;
          if (s.isCustomsReleased) {
            clearanceStatus = isArabic ? 'مفرج جمركياً' : 'Customs Released';
          } else if (s.form46No != null && s.form46No!.isNotEmpty) {
            clearanceStatus = isArabic ? 'إقرار 46 مسجل' : 'Form 46 Registered';
          } else {
            clearanceStatus = isArabic ? 'قيد الوصول والتخليص' : 'Pending Arrival/Clearance';
          }

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '${isArabic ? 'الناقل/الباخرة' : 'Vessel/Carrier'}: $vessel • ${isArabic ? 'ميناء التفريغ' : 'Port'}: $port',
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'المسؤول' : 'Owner'}: ${s.owner} • ${isArabic ? 'المخلص' : 'Broker'}: ${s.brokerName ?? (isArabic ? 'غير محدد' : 'Unassigned')}',
            byWhen: s.requiredEta != null && s.requiredEta!.isNotEmpty
                ? s.requiredEta!
                : (isArabic ? 'خلال هذا الأسبوع' : 'This week'),
            status: clearanceStatus,
            statusColorType: s.isCustomsReleased ? 'success' : 'info',
            nextAction: s.displayNextAction(l),
            dataGaps: [l.drillDownTimeDataGap],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.etaChanges:
        final filtered = shipments.where((s) => s.status != 'Closed' && s.requiredEta != null).toList();

        return filtered.map((s) {
          final carrier = s.selectedScenario != null && s.selectedScenario!.isNotEmpty
              ? s.selectedScenario!
              : (isArabic ? 'غير محدد' : 'Unassigned');

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '${isArabic ? 'الخط الملاحي' : 'Carrier'}: $carrier • ${s.portOfDischarge ?? ''}',
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'مسؤول الملف' : 'Owner'}: ${s.owner}',
            byWhen: '${isArabic ? 'تاريخ الوصول الفعلي' : 'Recorded ETA'}: ${s.requiredEta}',
            status: isArabic ? 'تاريخ ETA معتمد' : 'Confirmed ETA',
            statusColorType: 'info',
            nextAction: s.displayNextAction(l),
            dataGaps: [l.drillDownEtaChangeDataGap],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.waitingForPayment:
        final filtered = shipments.where((s) {
          return s.status != 'Closed' &&
              (s.currentModule.toString().contains('Phase 2') ||
                  (s.estimatedCost > 0 && (s.form4No == null || s.form4No!.trim().isEmpty)));
        }).toList();

        return filtered.map((s) {
          final amountFormatted = '${s.estimatedCost.toStringAsFixed(2)} ${s.estimatedCostCurrency}';
          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '${isArabic ? 'المبلغ المطلوب' : 'Amount'}: $amountFormatted • ${isArabic ? 'المورد' : 'Supplier'}: ${s.supplierName}',
            amount: amountFormatted,
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'المسؤول المالي' : 'Finance Officer'}: ${s.owner.isNotEmpty ? s.owner : 'Kamal'}',
            byWhen: s.cargoReadyDate != null && s.cargoReadyDate!.isNotEmpty
                ? '${isArabic ? "جاهزية البضاعة" : "Cargo Ready"}: ${s.cargoReadyDate}'
                : (isArabic ? 'بانتظار الموافقة وصرف الدفعة' : 'Awaiting Payment Approval'),
            status: isArabic ? 'بانتظار الاعتماد المالي وصرف الدفعة' : 'Awaiting Budget Approval',
            statusColorType: 'warning',
            nextAction: s.displayNextAction(l),
            dataGaps: [l.drillDownPaymentDeadlineDataGap],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.waitingForForm4:
        final filtered = shipments.where((s) => s.status != 'Closed' && (s.form4No == null || s.form4No!.trim().isEmpty)).toList();

        return filtered.map((s) {
          final swift = s.swiftNo != null && s.swiftNo!.isNotEmpty
              ? 'SWIFT: ${s.swiftNo}'
              : (isArabic ? 'قيد التقديم بالبنك' : 'Pending Bank Issuance');

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '${isArabic ? 'البنك' : 'Bank'}: $swift • ${isArabic ? 'الشركة المستوردة' : 'Company'}: ${s.companyName}',
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'مسؤول الاعتماد البنكي' : 'Banking Specialist'}: ${s.owner}',
            byWhen: s.form4RequestDate != null && s.form4RequestDate!.isNotEmpty
                ? '${isArabic ? "تاريخ الطلب" : "Request Date"}: ${s.form4RequestDate}'
                : (isArabic ? 'لم يتم تقديم الطلب بعد' : 'Not yet submitted'),
            status: isArabic ? 'نموذج 4 معلق' : 'Form 4 Pending',
            statusColorType: 'warning',
            nextAction: s.displayNextAction(l),
            dataGaps: const [],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.pendingRequirements:
        final filtered = shipments.where((s) {
          return s.status != 'Closed' &&
              (s.acidNumber == null || s.acidNumber!.trim().isEmpty || s.form46No == null || s.form46No!.trim().isEmpty);
        }).toList();

        return filtered.map((s) {
          final List<String> missing = [];
          if (s.acidNumber == null || s.acidNumber!.trim().isEmpty) {
            missing.add(isArabic ? 'رقم ACID نافذة (19 رقم)' : 'Nafeza ACID Number');
          }
          if (s.form46No == null || s.form46No!.trim().isEmpty) {
            missing.add(isArabic ? 'إقرار 46 ك.م جمركي' : 'Form 46 KM Declaration');
          }
          final missingDesc = missing.join(' • ');

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '${isArabic ? 'المتطلب الناقص' : 'Missing'}: $missingDesc',
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'المخلص/منسق نافذة' : 'Broker/Nafeza'}: ${s.brokerName ?? (isArabic ? 'غير محدد' : 'Unassigned')} • ${s.owner}',
            byWhen: '${isArabic ? 'معلق منذ' : 'Pending since'}: ${s.createdAt.contains('T') ? s.createdAt.split('T').first : s.createdAt}',
            status: isArabic ? 'متطلبات إجرائية غير مكتملة' : 'Incomplete Requirements',
            statusColorType: 'danger',
            nextAction: s.displayNextAction(l),
            dataGaps: const [],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.highPriorityAlerts:
        final filtered = shipments.where((s) => s.status != 'Closed' && (s.priority == 'High' || s.priority == 'Critical')).toList();

        return filtered.map((s) {
          final isCrit = s.priority == 'Critical';
          final prioText = isCrit
              ? (isArabic ? 'أولوية حرجة للغاية' : 'Critical Priority')
              : (isArabic ? 'أولوية عالية' : 'High Priority');

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '$prioText • ${(s.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(s.currentModule, isArabic: isArabic))}',
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'المسؤول' : 'Owner'}: ${s.owner}',
            byWhen: s.requiredEta != null && s.requiredEta!.isNotEmpty
                ? '${isArabic ? "وصول" : "ETA"}: ${s.requiredEta}'
                : (isArabic ? 'إجراء عاجل وفوري' : 'Immediate Action Required'),
            status: s.priority,
            statusColorType: isCrit ? 'danger' : 'warning',
            nextAction: s.displayNextAction(l),
            dataGaps: const [],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();
    }
  }
}
