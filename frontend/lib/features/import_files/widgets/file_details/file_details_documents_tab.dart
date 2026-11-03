// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/import_file_model.dart';
import '../../../comprehensive_report/models/comprehensive_dossier_model.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import 'file_details_action_handler.dart';

/// 📁 Documents Registry tab for Import File Details
/// Displays attached trade and logistics documents, bills of lading, commercial invoices,
/// packing lists, certificates, blockchain transfers, and customs declarations.
class FileDetailsDocumentsTab extends ConsumerWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final List<PurchaseOrderModel> linkedPOs;
  final Set<String> invoiceNumbers;

  const FileDetailsDocumentsTab({
    super.key,
    required this.file,
    this.dossier,
    required this.linkedPOs,
    required this.invoiceNumbers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final isCargoXDone = file.cargoxEnvelopeStatus == 'TRANSFERRED' ||
        (file.cargoxTransferredAt != null && file.cargoxTransferredAt!.isNotEmpty);
    final isOriginalDocsDone = file.originalDocumentsReceivedAt != null &&
        file.originalDocumentsReceivedAt!.isNotEmpty;
    final isEmptyReturned = file.emptyContainersReturnStatus == 'RETURNED' ||
        (file.emptyContainersReturnedAt != null && file.emptyContainersReturnedAt!.isNotEmpty);

    final documents = [
      (
        titleAr: 'أوامر التوريد والفواتير المبدئية',
        titleEn: 'Purchase Orders & Proforma',
        refNo: linkedPOs.isNotEmpty ? linkedPOs.map((p) => p.poNumber).join(', ') : (file.poNumber ?? '—'),
        status: linkedPOs.isNotEmpty ? 'CONFIRMED' : 'PENDING',
        statusAr: linkedPOs.isNotEmpty ? 'مؤكد' : 'معلق',
        statusEn: linkedPOs.isNotEmpty ? 'Confirmed' : 'Pending',
        actionKey: 'fn01_advance',
        actionLabelAr: 'عرض الاعتماد',
        actionLabelEn: 'View Approval',
        icon: Icons.receipt_long_rounded,
      ),
      (
        titleAr: 'الفواتير التجارية',
        titleEn: 'Commercial Invoices',
        refNo: invoiceNumbers.isNotEmpty ? invoiceNumbers.join(', ') : '—',
        status: invoiceNumbers.isNotEmpty ? 'ACTIVE' : 'PENDING',
        statusAr: invoiceNumbers.isNotEmpty ? 'مسجلة' : 'بانتظار التسجيل',
        statusEn: invoiceNumbers.isNotEmpty ? 'Registered' : 'Pending',
        actionKey: 'dc04_matrix',
        actionLabelAr: 'فحص الفواتير',
        actionLabelEn: 'Audit Invoices',
        icon: Icons.description_rounded,
      ),
      (
        titleAr: 'قوائم التعبئة وأوزان الشحنة',
        titleEn: 'Packing Lists & Weights',
        refNo: file.packingListsData.isNotEmpty
            ? '${file.packingListsData.length} ${isAr ? "قوائم تعبئة" : "Lists"}'
            : '—',
        status: file.packingListsData.isNotEmpty ? 'VALID' : 'PENDING',
        statusAr: file.packingListsData.isNotEmpty ? 'معتمدة' : 'معلقة',
        statusEn: file.packingListsData.isNotEmpty ? 'Valid' : 'Pending',
        actionKey: 'dc04_matrix',
        actionLabelAr: 'مراجعة الباكينج',
        actionLabelEn: 'Review PL',
        icon: Icons.inventory_rounded,
      ),
      (
        titleAr: 'نافذة والرقم الجمركي المبدئي',
        titleEn: 'Nafeza & ACID Number',
        refNo: file.acidNumber ?? '—',
        status: (file.acidNumber != null && file.acidNumber!.isNotEmpty && file.acidNumber != 'PENDING')
            ? 'APPROVED'
            : 'PENDING',
        statusAr: (file.acidNumber != null && file.acidNumber!.isNotEmpty && file.acidNumber != 'PENDING')
            ? 'صادر'
            : 'قيد الطلب',
        statusEn: (file.acidNumber != null && file.acidNumber!.isNotEmpty && file.acidNumber != 'PENDING')
            ? 'Approved'
            : 'Pending',
        actionKey: 'dc01_acid',
        actionLabelAr: 'إدارة نافذة',
        actionLabelEn: 'Manage ACID',
        icon: Icons.verified_outlined,
      ),
      (
        titleAr: 'النموذج البنكي رقم 4 والتحويلات',
        titleEn: 'Bank Form 4 & SWIFT',
        refNo: file.form4No ?? '—',
        status: (file.form4No != null && file.form4No!.isNotEmpty && file.form4No != 'PENDING')
            ? 'APPROVED'
            : 'PENDING',
        statusAr: (file.form4No != null && file.form4No!.isNotEmpty && file.form4No != 'PENDING')
            ? 'مستلم'
            : 'بانتظار الاعتماد',
        statusEn: (file.form4No != null && file.form4No!.isNotEmpty && file.form4No != 'PENDING')
            ? 'Received'
            : 'Pending',
        actionKey: 'dc03_bank',
        actionLabelAr: 'إدارة نموذج 4',
        actionLabelEn: 'Manage Form 4',
        icon: Icons.account_balance_outlined,
      ),
      (
        titleAr: 'مسودة بوليصة الشحن الملاحي',
        titleEn: 'Draft Bill of Lading (B/L)',
        refNo: file.blNumber ?? (file.customFileNumber ?? '—'),
        status: file.blNumber != null ? 'CONFIRMED' : 'DRAFT',
        statusAr: file.blNumber != null ? 'مؤكدة' : 'مسودة',
        statusEn: file.blNumber != null ? 'Confirmed' : 'Draft',
        actionKey: 'sh02_draft_bl',
        actionLabelAr: 'مطابقة البوليصة',
        actionLabelEn: 'Verify B/L',
        icon: Icons.fact_check_rounded,
      ),
      (
        titleAr: 'الرفع الرقمي عبر منصة البلوكشين',
        titleEn: 'CargoX Blockchain Hub',
        refNo: isCargoXDone
            ? (isAr ? 'تم الرفع والاعتماد' : 'Uploaded')
            : (isAr ? 'قيد المتابعة' : 'Pending'),
        status: isCargoXDone ? 'DONE' : 'WAITING',
        statusAr: isCargoXDone ? 'مكتمل' : 'بانتظار الرفع',
        statusEn: isCargoXDone ? 'Done' : 'Waiting',
        actionKey: 'sh03_cargox',
        actionLabelAr: 'منصة CargoX',
        actionLabelEn: 'CargoX Hub',
        icon: Icons.cloud_upload_outlined,
      ),
      (
        titleAr: 'أصول المستندات والبريد السريع',
        titleEn: 'Original Documents & Courier',
        refNo: file.originalDocumentsCourierNo ?? '—',
        status: isOriginalDocsDone ? 'RECEIVED' : 'IN_TRANSIT',
        statusAr: isOriginalDocsDone ? 'تم الاستلام' : 'قيد الشحن',
        statusEn: isOriginalDocsDone ? 'Received' : 'In Transit',
        actionKey: 'sh04_original_docs',
        actionLabelAr: 'تتبع البريد',
        actionLabelEn: 'Track Courier',
        icon: Icons.markunread_mailbox_outlined,
      ),
      (
        titleAr: 'تفويض المخلص الجمركي',
        titleEn: 'Customs Broker Authorization',
        refNo: file.brokerName ?? '—',
        status: file.brokerName != null ? 'ACTIVE' : 'DRAFT',
        statusAr: file.brokerName != null ? 'مفوض' : 'غير مسجل',
        statusEn: file.brokerName != null ? 'Active' : 'Unregistered',
        actionKey: 'cs01_broker_auth',
        actionLabelAr: 'خطاب التفويض',
        actionLabelEn: 'Authorization',
        icon: Icons.assignment_ind_outlined,
      ),
      (
        titleAr: 'قيد إقرار 46 جمرك',
        titleEn: 'Customs Declaration 46',
        refNo: file.form46No ?? '—',
        status: file.form46No != null ? 'REGISTERED' : 'PENDING',
        statusAr: file.form46No != null ? 'مقيد' : 'معلق',
        statusEn: file.form46No != null ? 'Registered' : 'Pending',
        actionKey: 'cs03_declaration_46',
        actionLabelAr: 'عرض الإقرار',
        actionLabelEn: 'Declaration',
        icon: Icons.description_outlined,
      ),
      (
        titleAr: 'إذن الإفراج الجمركي النهائي',
        titleEn: 'Customs Final Release',
        refNo: file.isCustomsReleased
            ? (isAr ? 'تم الإفراج النهائي' : 'Out of Charge')
            : (isAr ? 'تحت التخليص' : 'Under Clearance'),
        status: file.isCustomsReleased ? 'RELEASED' : 'PROCESSING',
        statusAr: file.isCustomsReleased ? 'مفرج عنه' : 'قيد الإجراء',
        statusEn: file.isCustomsReleased ? 'Released' : 'Processing',
        actionKey: 'cl04_final_release',
        actionLabelAr: 'إذن الإفراج',
        actionLabelEn: 'Final Release',
        icon: Icons.verified_user_outlined,
      ),
      (
        titleAr: 'إيصالات الساحات وإرجاع الحاويات',
        titleEn: 'Empty Container Return Slips',
        refNo: file.emptyContainersEirNumbers ?? '—',
        status: isEmptyReturned ? 'DONE' : 'PENDING',
        statusAr: isEmptyReturned ? 'تم الإرجاع' : 'معلق',
        statusEn: isEmptyReturned ? 'Returned' : 'Pending',
        actionKey: 'tr05_empty_return',
        actionLabelAr: 'إيصالات EIR',
        actionLabelEn: 'EIR Slips',
        icon: Icons.assignment_turned_in_outlined,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr ? '📑 سجل ومصفوفة مستندات الشحنة:' : '📑 Shipment Documents Registry & Matrix:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              AppButton(
                label: isAr ? 'الملف الشامل والأرشفة' : 'Export Full Dossier',
                icon: Icons.archive_outlined,
                size: AppButtonSize.small,
                variant: AppButtonVariant.primary,
                onPressed: () => FileDetailsActionHandler.handleDocumentAction(
                  context,
                  ref,
                  file,
                  'clo03_dossier',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: documents.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
              itemBuilder: (ctx, idx) {
                final doc = documents[idx];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100,
                    child: Icon(doc.icon, size: 16, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                  ),
                  title: Text(
                    isAr ? doc.titleAr : doc.titleEn,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  subtitle: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          doc.refNo,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (doc.refNo != '—') ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => CopyHelper.copy(context, doc.refNo),
                          borderRadius: BorderRadius.circular(4),
                          child: Icon(Icons.copy_rounded, size: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppStatusBadge.fromStatus(
                        status: doc.status,
                        label: isAr ? doc.statusAr : doc.statusEn,
                        size: AppStatusBadgeSize.small,
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        label: isAr ? doc.actionLabelAr : doc.actionLabelEn,
                        size: AppButtonSize.small,
                        variant: AppButtonVariant.ghost,
                        onPressed: () => FileDetailsActionHandler.handleDocumentAction(
                          context,
                          ref,
                          file,
                          doc.actionKey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
