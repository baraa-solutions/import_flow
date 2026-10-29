import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';

/// Standalone Card displaying the intelligent next operational action for a shipment.
class OperationalNextStepCard extends StatelessWidget {
  final ImportFileModel shipment;
  final bool isArabic;
  final ValueChanged<int>? onNavigate;

  const OperationalNextStepCard({
    super.key,
    required this.shipment,
    this.isArabic = true,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    if (shipment.status == 'Closed') return const SizedBox.shrink();

    final l = context.l10n;
    String nextStepTitle = l.nextStepDefaultTitle;
    String nextStepDesc = l.nextStepDefaultDesc;
    String responsible = l.responsibleImportTeam;
    int targetNavIndex = 1;
    IconData actionIcon = Icons.arrow_forward;

    final mod = '${shipment.currentStepCode ?? ''} ${shipment.currentModule}';
    final stg = shipment.currentStage.toString();
    if (mod.contains('STEP_07') || mod.contains('تخصيص') || mod.contains('Container Allocation')) {
      nextStepTitle = isArabic ? 'تدقيق أوزان VGM واعتماد مسودات مستندات الشحن' : 'VGM Verification & Shipping Draft Approval';
      nextStepDesc = isArabic
          ? 'استكمال أوزان الحاويات VGM ومراجعة بوالص الشحن وفواتير المورد للتجهيز لمنظومة CargoX'
          : 'Complete VGM container weights and review B/L drafts for CargoX processing';
      responsible = isArabic ? 'مسؤول الشحن والتوثيق الملاحي' : 'Shipping & Documentation Specialist';
      targetNavIndex = 25;
      actionIcon = Icons.rule_folder_outlined;
    } else if (mod.contains('STEP_02') || mod.contains('الدراسات والاستشارات الجمركية') || mod.contains('Customs Studies') || mod.contains('BP-002')) {
      nextStepTitle = l.nextStepImportReqsTitle;
      nextStepDesc = l.nextStepImportReqsDesc;
      responsible = l.responsibleImportSpecialist;
      targetNavIndex = 23;
      actionIcon = Icons.fact_check_outlined;
    } else if (mod.contains('STEP_01') || mod.contains('دراسات ومفاضلة نولون') || mod.contains('Freight Studies')) {
      nextStepTitle = l.nextStepCustomsConsultTitle;
      nextStepDesc = l.nextStepCustomsConsultDesc;
      responsible = l.responsibleCustomsBroker;
      targetNavIndex = 23;
      actionIcon = Icons.calculate_outlined;
    } else if (mod.contains('Phase 1') || stg.contains('Phase 1') || mod.contains('BP-001') || mod.contains('BP-007')) {
      nextStepTitle = l.nextStepFinanceApprovalTitle;
      nextStepDesc = l.nextStepFinanceApprovalDesc;
      responsible = l.responsibleFinanceDept;
      targetNavIndex = 8;
      actionIcon = Icons.monetization_on_outlined;
    } else if (mod.contains('Phase 2') || stg.contains('Phase 2') || mod.contains('BP-012')) {
      if (shipment.acidNumber != null && shipment.acidNumber!.trim().isNotEmpty) {
        if (shipment.selectedScenario != null && shipment.selectedScenario!.trim().isNotEmpty) {
          nextStepTitle = isArabic ? 'تدقيق أوزان VGM واعتماد مسودات مستندات الشحن' : 'VGM Verification & Shipping Draft Approval';
          nextStepDesc = isArabic
              ? 'استكمال أوزان الحاويات VGM ومراجعة بوالص الشحن وفواتير المورد للتجهيز لمنظومة CargoX'
              : 'Complete VGM container weights and review B/L drafts for CargoX processing';
          responsible = isArabic ? 'مسؤول الشحن والتوثيق الملاحي' : 'Shipping & Documentation Specialist';
          targetNavIndex = 25;
          actionIcon = Icons.rule_folder_outlined;
        } else {
          nextStepTitle = isArabic ? 'مفاضلة عروض أسعار الشحن واعتماد الخط الملاحي' : 'Freight Quote Comparison & Booking';
          nextStepDesc = isArabic
              ? 'مقارنة عروض النولون الملاحي وتأكيد حجز الحاويات وفترة السماح المعتمدة'
              : 'Compare freight quotes and finalize shipping line booking with free time';
          responsible = isArabic ? 'مسؤول التعاقدات واللوجستيات' : 'Logistics Procurement Specialist';
          targetNavIndex = 25;
          actionIcon = Icons.directions_boat_outlined;
        }
      } else {
        nextStepTitle = l.nextStepNafezaAcidTitle;
        nextStepDesc = l.nextStepNafezaAcidDesc;
        responsible = l.responsibleNafezaSpecialist;
        targetNavIndex = 11;
        actionIcon = Icons.description_outlined;
      }
    } else if (mod.contains('STEP_08_PO')) {
      nextStepTitle = isArabic ? 'مطابقة الفاتورة والباكينج مع أمر الشراء' : 'PO & Packing Reconciliation';
      nextStepDesc = isArabic ? 'مراجعة وتدقيق بنود الفاتورة والباكينج واستخراج الفروق' : 'Audit commercial invoice and packing list vs PO';
      responsible = isArabic ? 'مسؤول التدقيق المستندي' : 'Documentation Auditor';
      targetNavIndex = 21;
      actionIcon = Icons.fact_check_outlined;
    } else if (mod.contains('STEP_08_BL')) {
      nextStepTitle = isArabic ? 'مراجعة واعتماد مسودة بوليصة الشحن (B/L)' : 'Draft B/L Review & Approval';
      nextStepDesc = isArabic ? 'تدقيق مسودة البوليصة مع الخط الملاحي واعتمادها' : 'Review draft B/L with shipping line and approve';
      responsible = isArabic ? 'مسؤول الشحن والتوثيق' : 'Shipping Specialist';
      targetNavIndex = 18;
      actionIcon = Icons.assignment_turned_in_outlined;
    } else if (mod.contains('STEP_08_MATCH')) {
      nextStepTitle = isArabic ? 'المطابقة الذكية بين الفاتورة والبوليصة' : 'Smart Invoice vs B/L Match';
      nextStepDesc = isArabic ? 'مطابقة حقول الفاتورة النهائية مع بوليصة الشحن' : 'Match commercial invoice fields with draft B/L';
      responsible = isArabic ? 'مسؤول التوثيق' : 'Documentation Specialist';
      targetNavIndex = 22;
      actionIcon = Icons.auto_awesome;
    } else if (mod.contains('STEP_08_COO')) {
      nextStepTitle = isArabic ? 'مراجعة مسودة شهادة المنشأ و EUR.1' : 'Draft COO & EUR.1 Review';
      nextStepDesc = isArabic ? 'تدقيق قواعد المنشأ والاتفاقيات التفضيلية' : 'Audit rules of origin and preferential trade agreements';
      responsible = isArabic ? 'أخصائي الجمارك' : 'Customs Specialist';
      targetNavIndex = 19;
      actionIcon = Icons.flag_circle_outlined;
    } else if (mod.contains('STEP_08_COC')) {
      nextStepTitle = isArabic ? 'شهادات الفحص والتفتيش والمطابقة (COC)' : 'Inspection Review & COC';
      nextStepDesc = isArabic ? 'تدقيق شهادات المطابقة الدولية ومعايير GOEIC' : 'Audit pre-shipment inspection certificates';
      responsible = isArabic ? 'مسؤول المطابقة والجودة' : 'Conformity Specialist';
      targetNavIndex = 53;
      actionIcon = Icons.security_outlined;
    } else if (mod.contains('STEP_09') || mod.contains('BP-009')) {
      nextStepTitle = isArabic ? 'مركز اعتماد المستندات وتعديلات المورد' : 'Docs Customs Approval Hub';
      nextStepDesc = isArabic ? 'الحصول على الاعتماد الجمركي المبدئي وإصدار خطابات التعديل' : 'Obtain customs approval and issue supplier rectification notes';
      responsible = isArabic ? 'المستخلص الجمركي' : 'Customs Broker';
      targetNavIndex = 20;
      actionIcon = Icons.verified_user_outlined;
    } else if (mod.contains('Phase 3') || stg.contains('Phase 3') || mod.contains('BP-015') || mod.contains('BP-019')) {
      if (shipment.selectedScenario != null && shipment.selectedScenario!.trim().isNotEmpty) {
        nextStepTitle = isArabic ? 'تدقيق أوزان VGM واعتماد مسودات مستندات الشحن' : 'VGM Verification & Shipping Draft Approval';
        nextStepDesc = isArabic
            ? 'استكمال أوزان الحاويات VGM ومراجعة بوالص الشحن وفواتير المورد للتجهيز لمنظومة CargoX'
            : 'Complete VGM container weights and review B/L drafts for CargoX processing';
        responsible = isArabic ? 'مسؤول الشحن والتوثيق الملاحي' : 'Shipping & Documentation Specialist';
        targetNavIndex = 26;
        actionIcon = Icons.rule_folder_outlined;
      } else {
        nextStepTitle = l.nextStepFreightBookingTitle;
        nextStepDesc = l.nextStepFreightBookingDesc;
        responsible = l.responsibleFreightForwarder;
        targetNavIndex = 25;
        actionIcon = Icons.directions_boat_outlined;
      }
    } else if (mod.contains('Phase 4') || stg.contains('Phase 4')) {
      nextStepTitle = l.nextStepTransitTrackingTitle;
      nextStepDesc = l.nextStepTransitTrackingDesc;
      responsible = l.responsibleShippingCarrier;
      targetNavIndex = 26;
      actionIcon = Icons.sailing_outlined;
    } else if (mod.contains('Phase 5')) {
      nextStepTitle = l.nextStepArrivalNoticeTitle;
      nextStepDesc = l.nextStepArrivalNoticeDesc;
      responsible = l.responsibleCustomsBroker;
      targetNavIndex = 23;
      actionIcon = Icons.receipt_long_outlined;
    } else if (mod.contains('Phase 6')) {
      nextStepTitle = l.nextStepDutyPaymentTitle;
      nextStepDesc = l.nextStepDutyPaymentDesc;
      responsible = l.responsibleCustomsBroker;
      targetNavIndex = 27;
      actionIcon = Icons.verified_user_outlined;
    } else if (mod.contains('Phase 7')) {
      nextStepTitle = l.nextStepInlandTransportTitle;
      nextStepDesc = l.nextStepInlandTransportDesc;
      responsible = l.responsibleWarehouseCustodian;
      targetNavIndex = 28;
      actionIcon = Icons.warehouse_outlined;
    } else if (mod.contains('Phase 8')) {
      nextStepTitle = l.nextStepLandedCostTitle;
      nextStepDesc = l.nextStepLandedCostDesc;
      responsible = l.responsibleFinanceAuditing;
      targetNavIndex = 29;
      actionIcon = Icons.calculate_outlined;
    } else if (mod.contains('Phase 9')) {
      nextStepTitle = l.nextStepClosureTitle;
      nextStepDesc = l.nextStepClosureDesc;
      responsible = l.responsibleImportManager;
      targetNavIndex = 30;
      actionIcon = Icons.archive_outlined;
    }

    final isDark = AppTheme.isDark(context);
    final actionBgColor = isDark ? AppTheme.wcagCobalt : AppTheme.cobalt;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;

        final button = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: actionBgColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => onNavigate?.call(targetNavIndex),
          icon: const Icon(Icons.bolt, size: 14, color: Colors.white),
          label: Text(l.executeStepNow, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        );

        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.15) : AppTheme.cobalt.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.4) : AppTheme.cobalt.withValues(alpha: 0.25)),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: actionBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(actionIcon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(l.nextStepAction, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.lightBlueAccent : AppTheme.wcagCobalt)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.amber.shade900.withValues(alpha: 0.35) : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CopyableText(
                                  '${l.responsiblePerson}: $responsible',
                                  style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: isDark ? Colors.amber.shade200 : Colors.brown.shade800),
                                  showIcon: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CopyableText(nextStepTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    CopyableText(nextStepDesc, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: button),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: actionBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(actionIcon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(l.nextStepAction, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.lightBlueAccent : AppTheme.wcagCobalt)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.amber.shade900.withValues(alpha: 0.35) : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CopyableText(
                                  '${l.responsiblePerson}: $responsible',
                                  style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: isDark ? Colors.amber.shade200 : Colors.brown.shade800),
                                  showIcon: false,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          CopyableText(nextStepTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                          CopyableText(nextStepDesc, style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    button,
                  ],
                ),
        );
      },
    );
  }
}
