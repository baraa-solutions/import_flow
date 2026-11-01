// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../models/import_file_model.dart';
import '../../../comprehensive_report/models/comprehensive_dossier_model.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../../../experience_guide/models/guide_entry_model.dart';
import '../../../experience_guide/widgets/similar_shipments_card.dart';
import '../../../experience_guide/widgets/detected_patterns_card.dart';
import '../../../experience_guide/widgets/smart_shipment_reference_card.dart';
import '../../../experience_guide/widgets/add_guide_entry_dialog.dart';
import '../../../comprehensive_report/widgets/shipment_audit_timeline_dialog.dart';
import '../../../smart_checklists/widgets/smart_checklist_dialog.dart';
import 'file_details_action_handler.dart';

/// ⏳ Stages & Timeline tab for Import File Details
/// Displays the 10-phase operational lifecycle timeline, institutional knowledge
/// reference cards, systemic patterns, audit steps, and phase action triggers.
class FileDetailsStagesTimelineTab extends ConsumerWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final GuideMatchResultModel? guideMatchResult;
  final List<PurchaseOrderModel> linkedPOs;
  final VoidCallback? onGuideReload;

  const FileDetailsStagesTimelineTab({
    super.key,
    required this.file,
    this.dossier,
    this.guideMatchResult,
    required this.linkedPOs,
    this.onGuideReload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final shipmentHsCodes = <String>{};
    final shipmentCategories = <String>{};
    for (final po in linkedPOs) {
      for (final pli in po.packingListItems) {
        if (pli.hsCode.trim().isNotEmpty) shipmentHsCodes.add(pli.hsCode.trim());
        if (pli.description != null && pli.description!.trim().isNotEmpty) {
          shipmentCategories.add(pli.description!.trim());
        }
      }
      for (final it in po.items) {
        if (it.hsCode != null && it.hsCode!.trim().isNotEmpty) {
          shipmentHsCodes.add(it.hsCode!.trim());
        }
        if (it.mainDescription != null && it.mainDescription!.trim().isNotEmpty) {
          shipmentCategories.add(it.mainDescription!.trim());
        }
      }
    }
    if (file.hsCode != null && file.hsCode!.trim().isNotEmpty) {
      shipmentHsCodes.add(file.hsCode!.trim());
    }
    if (file.productCategory != null && file.productCategory!.trim().isNotEmpty) {
      shipmentCategories.add(file.productCategory!.trim());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Operational Audit & Quick Tools Bar ──────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElevatedSurface : AppTheme.cloudWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.history_toggle_off_rounded, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'محطات التتبع الزمني والتدقيق التشغيلي' : 'Operational Lifecycle & Audit Stations',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      Text(
                        isAr
                            ? 'المرحلة الحالية: ${file.currentStage} | حالة الملف: ${file.status}'
                            : 'Current Stage: ${file.currentStage} | Status: ${file.status}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    AppButton(
                      label: isAr ? 'رادار المحطات' : 'Stations Radar',
                      icon: Icons.radar_rounded,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => showShipmentAuditTimelineDialog(context, importFileId: file.importFileId),
                    ),
                    AppButton(
                      label: isAr ? 'قائمة التحقق الذكية' : 'Smart Checklist',
                      icon: Icons.checklist_rtl_rounded,
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.primary,
                      onPressed: () => SmartChecklistDialog.show(context, file),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 10-Phase Lifecycle Interactive Cards ─────────────────────────
          Text(
            isAr ? '📋 مراحل الدورة التشغيلية للشحنة:' : '📋 Shipment Operational Lifecycle Stages:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          _buildLifecycleStagesList(context, ref, isDark: isDark, isAr: isAr),
          const SizedBox(height: 16),

          // ── Institutional Memory & Smart Guide ───────────────────────────
          SmartShipmentReferenceCard(
            importFileId: file.importFileId,
            dossier: dossier,
            initialHsCode: shipmentHsCodes.isNotEmpty ? shipmentHsCodes.first : file.hsCode,
            initialCategory: shipmentCategories.isNotEmpty ? shipmentCategories.first : file.productCategory,
            initialPod: file.portOfDischarge,
            initialSupplier: file.supplierName,
            initialCarrier: file.selectedScenario,
            linkedPOs: linkedPOs,
            file: file,
            onGuidelineAdded: () {
              showDialog(
                context: context,
                builder: (_) => AddGuideEntryDialog(
                  initialHsCode: shipmentHsCodes.isNotEmpty ? shipmentHsCodes.first : file.hsCode,
                  initialCategory: shipmentCategories.isNotEmpty ? shipmentCategories.first : file.productCategory,
                  initialDestinationPort: file.portOfDischarge,
                  initialSupplier: file.supplierName,
                  initialShippingLine: file.selectedScenario,
                  onSuccess: () => onGuideReload?.call(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // ── Historical Similar Shipments ──────────────────────────────────
          SimilarShipmentsCard(importFileId: file.importFileId),
          const SizedBox(height: 12),

          // ── Systemic Detected Patterns ────────────────────────────────────
          const DetectedPatternsCard(),
        ],
      ),
    );
  }

  Widget _buildLifecycleStagesList(
    BuildContext context,
    WidgetRef ref, {
    required bool isDark,
    required bool isAr,
  }) {
    final stages = [
      (
        step: 1,
        titleAr: 'أوامر الشراء والاعتماد',
        titleEn: 'Purchase Orders & Approval',
        actionKey: 'fn01_advance',
        actionLabelAr: 'طلب دفعة المورد',
        actionLabelEn: 'Supplier Advance',
        icon: Icons.assignment_turned_in_outlined,
        isDone: linkedPOs.isNotEmpty,
      ),
      (
        step: 2,
        titleAr: 'قيد نافذة والرقم الجمركي المبدئي',
        titleEn: 'Nafeza & ACID Issuance',
        actionKey: 'dc01_acid',
        actionLabelAr: 'إدارة الرقم الجمركي',
        actionLabelEn: 'Manage ACID',
        icon: Icons.verified_outlined,
        isDone: file.acidNumber != null && file.acidNumber!.isNotEmpty && file.acidNumber != 'PENDING',
      ),
      (
        step: 3,
        titleAr: 'النموذج البنكي والتحويلات',
        titleEn: 'Bank Form 4 & SWIFT',
        actionKey: 'dc03_bank',
        actionLabelAr: 'متابعة نموذج 4',
        actionLabelEn: 'Bank Form 4',
        icon: Icons.account_balance_outlined,
        isDone: file.form4No != null && file.form4No!.isNotEmpty && file.form4No != 'PENDING',
      ),
      (
        step: 4,
        titleAr: 'حجز الشحن الملاحي',
        titleEn: 'Freight Booking & Allocation',
        actionKey: 'bk01_booking',
        actionLabelAr: 'إدارة الحجز',
        actionLabelEn: 'Manage Booking',
        icon: Icons.directions_boat_outlined,
        isDone: file.requiredEta != null && file.requiredEta!.isNotEmpty,
      ),
      (
        step: 5,
        titleAr: 'تأكيد الإبحار والـ ETA',
        titleEn: 'Sailing & ETA Confirmation',
        actionKey: 'sh01_sailing',
        actionLabelAr: 'تأكيد الإبحار',
        actionLabelEn: 'Departure Confirm',
        icon: Icons.sailing_rounded,
        isDone: file.bookingNo != null && file.bookingNo!.isNotEmpty,
      ),
      (
        step: 6,
        titleAr: 'منصة البلوكشين وأصول المستندات',
        titleEn: 'CargoX Hub & Original Docs',
        actionKey: 'sh03_cargox',
        actionLabelAr: 'منصة CargoX',
        actionLabelEn: 'CargoX Hub',
        icon: Icons.cloud_upload_outlined,
        isDone: file.cargoxEnvelopeStatus == 'TRANSFERRED' || (file.cargoxTransferredAt != null && file.cargoxTransferredAt!.isNotEmpty),
      ),
      (
        step: 7,
        titleAr: 'قيد إقرار 46 جمرك وتفويض المخلص',
        titleEn: 'Customs Declaration 46 & Broker',
        actionKey: 'cs03_declaration_46',
        actionLabelAr: 'إقرار 46',
        actionLabelEn: 'Declaration 46',
        icon: Icons.description_outlined,
        isDone: file.form46No != null && file.form46No!.isNotEmpty,
      ),
      (
        step: 8,
        titleAr: 'الكشف والمعاينة وسداد الرسوم',
        titleEn: 'Inspection & Duty Settlement',
        actionKey: 'cl03_duty_payment',
        actionLabelAr: 'سداد الرسوم',
        actionLabelEn: 'Pay Duties',
        icon: Icons.receipt_long_outlined,
        isDone: file.customsDutyPaymentStatus == 'PAID' || file.customsDutyPaidAmount > 0,
      ),
      (
        step: 9,
        titleAr: 'الإفراج الجمركي والنقل الداخلي',
        titleEn: 'Customs Release & Trucking',
        actionKey: 'tr01_inland_transport',
        actionLabelAr: 'أوامر النقل',
        actionLabelEn: 'Trucking Order',
        icon: Icons.local_shipping_outlined,
        isDone: file.isCustomsReleased,
      ),
      (
        step: 10,
        titleAr: 'الاستلام المخزني والإغلاق الرسمي',
        titleEn: 'Warehouse GRN & File Closure',
        actionKey: 'clo04_official_closure',
        actionLabelAr: 'إغلاق الملف',
        actionLabelEn: 'Close File',
        icon: Icons.warehouse_outlined,
        isDone: file.status == 'Closed',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stages.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
        itemBuilder: (ctx, idx) {
          final s = stages[idx];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: s.isDone
                  ? (isDark ? AppTheme.emerald.withValues(alpha: 0.3) : AppTheme.emerald.withValues(alpha: 0.15))
                  : (isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100),
              child: Icon(
                s.isDone ? Icons.check_circle_rounded : s.icon,
                size: 16,
                color: s.isDone ? AppTheme.emerald : (isDark ? AppTheme.darkTextMuted : Colors.grey),
              ),
            ),
            title: Text(
              '${s.step}. ${isAr ? s.titleAr : s.titleEn}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppStatusBadge(
                  label: s.isDone ? (isAr ? 'مكتمل' : 'Completed') : (isAr ? 'قيد المتابعة' : 'Pending'),
                  severity: s.isDone ? AppSeverity.success : AppSeverity.warning,
                  size: AppStatusBadgeSize.small,
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: isAr ? s.actionLabelAr : s.actionLabelEn,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => FileDetailsActionHandler.handleDocumentAction(
                    context,
                    ref,
                    file,
                    s.actionKey,
                    onGuideReload: onGuideReload,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
