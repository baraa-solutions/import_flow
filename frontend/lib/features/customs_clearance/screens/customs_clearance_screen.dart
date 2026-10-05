import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/smart_upload_button.dart';
import '../../../core/widgets/universal_entity_extractor_dialog.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import '../widgets/drawing_samples_and_shortage_tab.dart';
import '../widgets/discrepancy_and_damage_tab.dart';
import '../widgets/final_duty_payment_tab.dart';
import '../widgets/under_bond_release_dialog.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../widgets/search_and_clone_customs_clearance_dialog.dart';
import '../widgets/customs_broker_authorization_dialog.dart';
import '../widgets/delivery_order_payment_dialog.dart';
import '../widgets/customs_declaration_46_dialog.dart';
import '../widgets/customs_inspection_sampling_dialog.dart';
import '../widgets/final_duty_assessment_dialog.dart';
import '../widgets/customs_duty_payment_dialog.dart';
import '../widgets/customs_final_release_dialog.dart';
import '../widgets/clearance_expenses_dialog.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';
import '../../auth/providers/auth_provider.dart';


class CustomsClearanceScreen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;

  const CustomsClearanceScreen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
  });

  @override
  ConsumerState<CustomsClearanceScreen> createState() => _CustomsClearanceScreenState();
}

class _CustomsClearanceScreenState extends ConsumerState<CustomsClearanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';
  int _selectedTab = 0;

  // Local state for sample drawing items & discrepancy protocols (Clean Production - 0 records)
  final List<Map<String, dynamic>> _drawnSamples = [];
  final List<Map<String, dynamic>> _shortageProtocols = [];
  final List<Map<String, dynamic>> _discrepancyProtocols = [];
  GuideMatchResultModel? _clearanceGuideMatchResult;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialSubTab;
    Future.microtask(() {
      _refreshData();
    });
  }

  @override
  void didUpdateWidget(covariant CustomsClearanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubTab != oldWidget.initialSubTab) {
      setState(() => _selectedTab = widget.initialSubTab);
    }
    if (widget.initialImportFileId != oldWidget.initialImportFileId) {
      _loadClearanceGuide(widget.initialImportFileId);
    }
  }

  void _refreshData() {
    if (!ref.read(customsClearanceProvider).isLoading) {
      ref.read(customsClearanceProvider.notifier).fetchRecords();
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(partnersProvider).isLoading) {
      ref.read(partnersProvider.notifier).fetchPartners();
    }
    _loadClearanceGuide(widget.initialImportFileId);
  }

  Future<void> _loadClearanceGuide(int? fileId) async {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    dynamic file;
    if (fileId != null) {
      file = files.where((f) => f.importFileId == fileId).firstOrNull;
    } else if (files.isNotEmpty) {
      file = files.first;
    }
    if (file == null) {
      if (mounted) setState(() => _clearanceGuideMatchResult = null);
      return;
    }

    try {
      final res = await ref.read(experienceGuideProvider.notifier).matchShipment(
        supplier: file.supplierName,
        hsCode: file.hsCode,
        productCategory: file.productCategory,
        portOfLoading: file.portOfLoading,
        portOfDischarge: file.portOfDischarge,
        incoterm: file.incotermCode,
        importFileReference: file.importFileCode,
      );
      if (mounted) {
        setState(() => _clearanceGuideMatchResult = res);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }



  void _showAddEditDialog([CustomsClearanceModel? recordToEdit, bool isCloneDraft = false]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CustomsClearanceFormDialog(
        recordToEdit: recordToEdit,
        isCloneDraft: isCloneDraft,
      ),
    );
  }

  void _openSearchAndCloneClearanceDialog(List<CustomsClearanceModel> records) {
    showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneCustomsClearanceDialog(
        records: records,
        onSelectRecord: _onCloneClearance,
      ),
    );
  }

  void _onCloneClearance(CustomsClearanceModel rec) {
    final l = context.l10n;
    final isAr = l.isArabic;
    final newDraftCode = 'CLR-DRAFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: CloneEntityReviewDialog(
            entityType: isAr ? 'بيان تخليص ومعاينة جمركية' : 'Customs Clearance & Inspection Record',
            sourceCode: rec.clearanceCode,
            suggestedNewCode: newDraftCode,
            sourceTitle: rec.declaration46No != null && rec.declaration46No!.isNotEmpty
                ? '${l.customsClearanceDeclaration46Label}: ${rec.declaration46No}'
                : rec.customsOfficeName,
            copiedFieldsSummary: {
              isAr ? 'الجمرك / المركز' : 'Customs Office': rec.customsOfficeName,
              isAr ? 'المسار الجمركي' : 'Channel Type': rec.channelType,
              isAr ? 'ضريبة الوارد' : 'Import Duty': '${rec.importDutyAmount.toStringAsFixed(2)} EGP',
              isAr ? 'ضريبة القيمة المضافة' : 'VAT': '${rec.vatAmount.toStringAsFixed(2)} EGP',
              isAr ? 'ضريبة الجدول' : 'Schedule Tax': '${rec.scheduleTaxAmount.toStringAsFixed(2)} EGP',
              isAr ? 'أرباح تجارية (WHT)' : 'WHT': '${rec.whtAmount.toStringAsFixed(2)} EGP',
              isAr ? 'رسوم الفحص المعملي' : 'Lab Service Fees': '${rec.labServiceFees.toStringAsFixed(2)} EGP',
              isAr ? 'إجمالي الرسوم الجمركية' : 'Total Duty Payable': '${rec.totalDutyPayable.toStringAsFixed(2)} EGP',
              isAr ? 'فترة السماح بالميناء' : 'Free Days Allowed': '${rec.freeDaysAllowed} days',
            },
            mandatorilyResetFields: isAr
                ? const [
                    'معرف التخليص الجمركي: يتم تفريغه لتوليد سجل بيان جمركي جديد',
                    'كود المعاملة: يعاد تعيينه كمسودة (CLR-DRAFT)',
                    'رقم 46 ك.م وإذن التسليم: يتم تفريغهم لحين القيد والتسليم الفعلي للبيان الجديد',
                    'حالة السداد وإيصال البنك: يعاد ضبطها إلى "غير مسدد" ومسح الإيصالات السابقة',
                    'تصريح وتاريخ الإفراج الجمركي: يتم تفريغهما لحين إنهاء إجراءات الإفراج',
                    'حالة المعاملة: تعاد للبدء المبدئي (قيد المعاينة والفحص)',
                  ]
                : const [
                    'Clearance ID: Cleared for new record generation',
                    'Clearance Code: Re-assigned as new DRAFT',
                    'Decl. 46 & Delivery Order: Cleared until actual registration',
                    'Payment Status & Bank Receipt: Reset to Unpaid and receipts wiped',
                    'Release Permit & Dates: Cleared until final release procedures',
                    'Operational Status: Reset to Initial (Inspection In Progress)',
                  ],
            allowCopyLineItems: true,
            allowCopyAttachments: false,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final clonedDraft = CustomsClearanceModel(
                customsClearanceId: 0,
                clearanceCode: newCode,
                importFileId: rec.importFileId,
                declaration46No: null,
                customsOfficeName: rec.customsOfficeName,
                channelType: rec.channelType,
                inspectionDate: null,
                regulatoryBodies: List<String>.from(rec.regulatoryBodies),
                sampleTestStatus: 'Samples Under Testing',
                inspectionNotes: null,
                importDutyAmount: rec.importDutyAmount,
                vatAmount: rec.vatAmount,
                scheduleTaxAmount: rec.scheduleTaxAmount,
                whtAmount: rec.whtAmount,
                labServiceFees: rec.labServiceFees,
                totalDutyPayable: rec.totalDutyPayable,
                estimatedDutyTotal: rec.estimatedDutyTotal,
                actualDutyTotal: 0.0,
                dutyVarianceAmount: 0.0,
                dutyVariancePercentage: 0.0,
                dutyVarianceReason: null,
                nafezaAssessmentJson: null,
                portArrivalDate: null,
                deliveryOrderNumber: null,
                deliveryOrderExpiry: null,
                freeDaysAllowed: rec.freeDaysAllowed,
                portGateOutDate: null,
                paymentStatus: 'Unpaid',
                bankReceiptNo: null,
                payingBankName: null,
                paymentDate: null,
                paymentNotes: null,
                releasePermitNo: null,
                releaseDate: null,
                demurrageStorageFees: 0.0,
                dispatchAuthorized: false,
                dispatchDate: null,
                status: 'Inspection In Progress',
                owner: ref.read(authProvider).user?.fullName ?? '',
                notes: notes ?? 'Cloned from ${rec.clearanceCode}',
                isActive: true,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showAddEditDialog(clonedDraft, true);
                }
              });
            },
          ),
        ),
      ),
    );
  }

  void _copyClearanceRowTsv(CustomsClearanceModel record, AppLocalizations l) {
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final rawCode = 'IMP-${record.importFileId}';
    final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: allFiles, isArabic: isAr);
    final actual = (record.actualDutyTotal > 0 ? record.actualDutyTotal : record.totalDutyPayable).toStringAsFixed(2);
    final est = record.estimatedDutyTotal.toStringAsFixed(2);
    final variance = '${record.dutyVarianceAmount >= 0 ? "+" : ""}${record.dutyVarianceAmount.toStringAsFixed(2)}';

    final rowData = [
      record.clearanceCode,
      shipTitle,
      record.declaration46No ?? '-',
      record.customsOfficeName,
      record.channelType,
      record.deliveryOrderNumber ?? '-',
      actual,
      est,
      variance,
      record.paymentStatus,
      record.status,
    ];

    final headers = [
      l.customsClearanceColClearanceCode,
      l.importFile,
      l.customsClearanceColDecl46,
      l.customsClearanceOfficeLabel,
      l.customsClearanceChannelLabel,
      l.customsClearanceDeliveryOrderLabel,
      l.customsClearanceColActualDuty,
      l.customsClearanceColEstimatedDuty,
      l.customsClearanceColDutyVariance,
      l.customsClearanceColPaymentStatus,
      l.status,
    ];

    TableCopyHelper.copyRow(
      context,
      rowData,
      headers: headers,
      includeHeaders: true,
      customMessage: l.copyCustomsClearanceRowSuccess,
    );
  }

  void _copyClearanceTableTsv(List<CustomsClearanceModel> records, AppLocalizations l) {
    if (records.isEmpty) return;
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      l.customsClearanceColClearanceCode,
      l.importFile,
      l.customsClearanceColDecl46,
      l.customsClearanceOfficeLabel,
      l.customsClearanceChannelLabel,
      l.customsClearanceDeliveryOrderLabel,
      l.customsClearanceColActualDuty,
      l.customsClearanceColEstimatedDuty,
      l.customsClearanceColDutyVariance,
      l.customsClearanceColPaymentStatus,
      l.status,
    ];

    final rows = records.map((r) {
      final rawCode = 'IMP-${r.importFileId}';
      final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: allFiles, isArabic: isAr);
      final actual = (r.actualDutyTotal > 0 ? r.actualDutyTotal : r.totalDutyPayable).toStringAsFixed(2);
      final est = r.estimatedDutyTotal.toStringAsFixed(2);
      final variance = '${r.dutyVarianceAmount >= 0 ? "+" : ""}${r.dutyVarianceAmount.toStringAsFixed(2)}';
      return [
        r.clearanceCode,
        shipTitle,
        r.declaration46No ?? '-',
        r.customsOfficeName,
        r.channelType,
        r.deliveryOrderNumber ?? '-',
        actual,
        est,
        variance,
        r.paymentStatus,
        r.status,
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l.copyCustomsClearanceTableSuccess,
    );
  }

  Future<void> _exportClearanceExcel(List<CustomsClearanceModel> records, AppLocalizations l) async {
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      'كود التخليص',
      'ملف الشحنة',
      'رقم 46 ك.م',
      'الجمرك / المركز',
      'المسار',
      'إذن التسليم',
      'الرسوم الفعلية (ج.م)',
      'الرسوم التقديرية (ج.م)',
      'الفارق (ج.م)',
      'حالة السداد',
      'الحالة التشغيلية',
    ];

    final rows = records.map((r) {
      final rawCode = 'IMP-${r.importFileId}';
      final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: allFiles, isArabic: isAr);
      final actual = (r.actualDutyTotal > 0 ? r.actualDutyTotal : r.totalDutyPayable).toStringAsFixed(2);
      final est = r.estimatedDutyTotal.toStringAsFixed(2);
      final variance = '${r.dutyVarianceAmount >= 0 ? "+" : ""}${r.dutyVarianceAmount.toStringAsFixed(2)}';
      return [
        r.clearanceCode,
        shipTitle,
        r.declaration46No ?? '-',
        r.customsOfficeName,
        r.channelType,
        r.deliveryOrderNumber ?? '-',
        actual,
        est,
        variance,
        r.paymentStatus,
        r.status,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Customs Clearance',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
    );
  }

  Future<void> _exportClearancePdf(List<CustomsClearanceModel> records, AppLocalizations l) async {
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      'كود التخليص',
      'ملف الشحنة',
      '46 ك.م',
      'الجمرك',
      'المسار',
      'إذن التسليم',
      'الرسوم',
      'حالة السداد',
      'الحالة',
    ];

    final rows = records.map((r) {
      final rawCode = 'IMP-${r.importFileId}';
      final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: allFiles, isArabic: isAr);
      final actual = (r.actualDutyTotal > 0 ? r.actualDutyTotal : r.totalDutyPayable).toStringAsFixed(2);
      return [
        r.clearanceCode,
        shipTitle,
        r.declaration46No ?? '-',
        r.customsOfficeName,
        r.channelType,
        r.deliveryOrderNumber ?? '-',
        actual,
        r.paymentStatus,
        r.status,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Customs Clearance',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: 'Customs Clearance & Port Operations Registry',
        subtitle: 'Sorour Logistics ERP — سجل الميناء والتخليص الجمركي والمعاينة والمطابقة',
        metadata: {
          'Total Records': records.length.toString(),
          'Paid & Verified': records.where((r) => r.paymentStatus == 'Paid & Verified').length.toString(),
          'Final Release': records.where((r) => r.status == 'Final Release Granted').length.toString(),
        },
      ),
    );
  }

  void _showDutyPaymentDialog(CustomsClearanceModel record) {
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final matchingFile = allFiles.where((f) => f.importFileId == record.importFileId).firstOrNull;
    if (matchingFile != null) {
      CustomsDutyPaymentDialog.show(
        context,
        matchingFile,
        clearanceRecord: record,
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DutyPaymentDialog(record: record),
      );
    }
  }

  void _showFinalReleaseDialog(CustomsClearanceModel record) {
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final matchingFile = allFiles.where((f) => f.importFileId == record.importFileId).firstOrNull;
    if (matchingFile != null) {
      CustomsFinalReleaseDialog.show(
        context,
        matchingFile,
        clearanceRecord: record,
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _FinalReleaseDialog(record: record),
      );
    }
  }

  void _showClearanceExpensesDialog(CustomsClearanceModel record) {
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final matchingFile = allFiles.where((f) => f.importFileId == record.importFileId).firstOrNull;
    if (matchingFile != null) {
      ClearanceExpensesDialog.show(
        context,
        matchingFile,
        clearanceRecord: record,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final clearanceAsync = ref.watch(customsClearanceProvider);

    return VerticalStageScaffold(
      stageCode: 'PHASE-5',
      titleAr: 'الميناء والتخليص الجمركي والمعاينة والمطابقة',
      titleEn: 'Port Operations & Customs Clearance Hub',
      headerIcon: Icons.gavel_rounded,
      headerColor: AppTheme.cobalt,
      headerActions: [
        ElevatedButton.icon(
          icon: Icon(Icons.auto_awesome_rounded, size: density.buttonIconSize),
          label: Text(l.customsClearanceAiBrokerExtractorBtn),
          onPressed: () => UniversalEntityExtractorDialog.showCustomsBrokerExtractor(
            context,
            onSaved: () => ref.read(partnersProvider.notifier).fetchPartners(),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: density.isCompact ? 10 : 14,
              vertical: density.isCompact ? 6 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('authorizeCustomsBrokerHeaderBtn'),
          icon: Icon(Icons.assignment_ind_rounded, size: density.buttonIconSize),
          label: const Text('تفويض المخلص (CS-01)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            final files = ref.read(importFilesProvider).valueOrNull ?? [];
            if (files.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد ملفات شحنات مسجلة')),
              );
              return;
            }
            final targetFile = widget.initialImportFileId != null
                ? files.firstWhere(
                    (f) => f.importFileId == widget.initialImportFileId,
                    orElse: () => files.first,
                  )
                : files.first;
            CustomsBrokerAuthorizationDialog.show(context, targetFile);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: density.isCompact ? 10 : 14,
              vertical: density.isCompact ? 6 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('deliveryOrderPaymentScreenBtn'),
          icon: Icon(Icons.directions_boat_filled_rounded, size: density.buttonIconSize),
          label: const Text('سداد إذن التسليم (CS-02)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            final files = ref.read(importFilesProvider).valueOrNull ?? [];
            if (files.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد ملفات شحنات مسجلة')),
              );
              return;
            }
            final targetFile = widget.initialImportFileId != null
                ? files.firstWhere(
                    (f) => f.importFileId == widget.initialImportFileId,
                    orElse: () => files.first,
                  )
                : files.first;
            DeliveryOrderPaymentDialog.show(context, targetFile);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: density.isCompact ? 10 : 14,
              vertical: density.isCompact ? 6 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('customsDeclaration46ScreenBtn'),
          icon: Icon(Icons.description_rounded, size: density.buttonIconSize),
          label: const Text('قيد إقرار 46 (CS-03)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            final files = ref.read(importFilesProvider).valueOrNull ?? [];
            if (files.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد ملفات شحنات مسجلة')),
              );
              return;
            }
            final targetFile = widget.initialImportFileId != null
                ? files.firstWhere(
                    (f) => f.importFileId == widget.initialImportFileId,
                    orElse: () => files.first,
                  )
                : files.first;
            CustomsDeclaration46Dialog.show(context, targetFile);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: density.isCompact ? 10 : 14,
              vertical: density.isCompact ? 6 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('customsInspectionSamplingScreenBtn'),
          icon: Icon(Icons.biotech_rounded, size: density.buttonIconSize),
          label: const Text('الكشف والمعاينة (CL-01)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            final files = ref.read(importFilesProvider).valueOrNull ?? [];
            if (files.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد ملفات شحنات مسجلة')),
              );
              return;
            }
            final targetFile = widget.initialImportFileId != null
                ? files.firstWhere(
                    (f) => f.importFileId == widget.initialImportFileId,
                    orElse: () => files.first,
                  )
                : files.first;
            CustomsInspectionSamplingDialog.show(context, targetFile);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: density.isCompact ? 10 : 14,
              vertical: density.isCompact ? 6 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('finalDutyAssessmentScreenBtn'),
          icon: Icon(Icons.calculate_rounded, size: density.buttonIconSize),
          label: const Text('حساب الرسوم (CL-02)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            final files = ref.read(importFilesProvider).valueOrNull ?? [];
            if (files.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد ملفات شحنات مسجلة')),
              );
              return;
            }
            final targetFile = widget.initialImportFileId != null
                ? files.firstWhere(
                    (f) => f.importFileId == widget.initialImportFileId,
                    orElse: () => files.first,
                  )
                : files.first;
            FinalDutyAssessmentDialog.show(context, targetFile);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: density.isCompact ? 10 : 14,
              vertical: density.isCompact ? 6 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('customsDutyPaymentScreenBtn'),
          icon: Icon(Icons.receipt_long_rounded, size: density.buttonIconSize),
          label: const Text('سداد الرسوم (CL-03)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            final files = ref.read(importFilesProvider).valueOrNull ?? [];
            if (files.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد ملفات شحنات مسجلة')),
              );
              return;
            }
            final targetFile = widget.initialImportFileId != null
                ? files.firstWhere(
                    (f) => f.importFileId == widget.initialImportFileId,
                    orElse: () => files.first,
                  )
                : files.first;
            CustomsDutyPaymentDialog.show(context, targetFile);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: density.isCompact ? 10 : 14,
              vertical: density.isCompact ? 6 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('customsFinalReleaseScreenBtn'),
          icon: Icon(Icons.verified_outlined, size: density.buttonIconSize),
          label: const Text('إذن الإفراج (CL-04)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            final files = ref.read(importFilesProvider).valueOrNull ?? [];
            if (files.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد ملفات شحنات مسجلة')),
              );
              return;
            }
            final targetFile = widget.initialImportFileId != null
                ? files.firstWhere(
                    (f) => f.importFileId == widget.initialImportFileId,
                    orElse: () => files.first,
                  )
                : files.first;
            CustomsFinalReleaseDialog.show(context, targetFile);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: density.isCompact ? 10 : 14,
              vertical: density.isCompact ? 6 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('customsClearanceInvoicesScreenBtn'),
          icon: Icon(Icons.receipt_long_rounded, size: density.buttonIconSize),
          label: const Text('فواتير التخليص (CL-05)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            final files = ref.read(importFilesProvider).valueOrNull ?? [];
            if (files.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد ملفات شحنات مسجلة')),
              );
              return;
            }
            final targetFile = widget.initialImportFileId != null
                ? files.firstWhere(
                    (f) => f.importFileId == widget.initialImportFileId,
                    orElse: () => files.first,
                  )
                : files.first;
            ClearanceExpensesDialog.show(context, targetFile);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: density.isCompact ? 10 : 14,
              vertical: density.isCompact ? 6 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.white70, size: density.buttonIconSize),
          tooltip: l.refresh,
          onPressed: _refreshData,
        ),
      ],
      selectedIndex: _selectedTab,
      onTabSelected: (idx) => setState(() => _selectedTab = idx),
      selectedImportFileId: widget.initialImportFileId,
      onShipmentStatusChanged: _refreshData,
      topBanner: (_clearanceGuideMatchResult != null && _clearanceGuideMatchResult!.matchedEntries.isNotEmpty)
          ? Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
              child: ExperienceGuideAlertBanner(
                matchResult: _clearanceGuideMatchResult!,
              ),
            )
          : null,
      tabs: const [
        VerticalNavTabItem(
          icon: Icons.fact_check_outlined,
          titleAr: 'متابعة الكشف والتثمين والتفتيش الجمركي',
          titleEn: 'Customs Clearance Follow-up',
        ),
        VerticalNavTabItem(
          icon: Icons.science_outlined,
          titleAr: 'سحب العينات وتحديد عجز البضائع',
          titleEn: 'Drawing Samples & Shortage Tracking',
        ),
        VerticalNavTabItem(
          icon: Icons.report_problem_outlined,
          titleAr: 'إثبات الفاقد والتلف الجمركي ومحاضر النقص',
          titleEn: 'Discrepancy & Damage Registry',
        ),
        VerticalNavTabItem(
          icon: Icons.receipt_long_outlined,
          titleAr: 'سداد الرسوم والضرائب الجمركية النهائية',
          titleEn: 'Final Customs Duty Payment & Release',
        ),
      ],
      body: SelectionArea(
        child: clearanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Text(l.customsClearanceErrorFetch(err.toString()), style: const TextStyle(color: Colors.red)),
            ),
            data: (records) {
              switch (_selectedTab) {
                case 0:
                  return _buildClearanceFollowUpView(records, l);
                case 1:
                  return _buildDrawingSamplesAndShortageView(records, l);
                case 2:
                  return _buildDiscrepancyAndDamageView(records, l);
                case 3:
                  return _buildFinalDutyPaymentView(records, l);
                default:
                  return _buildClearanceFollowUpView(records, l);
              }
            },
          ),
      ),
    );
  }

  // ===========================================================================
  // SUB-VIEW 0: CUSTOMS CLEARANCE FOLLOW-UP
  // ===========================================================================
  Widget _buildClearanceFollowUpView(List<CustomsClearanceModel> records, AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = records.where((r) {
      if (_selectedStatusFilter != 'All' && r.status != _selectedStatusFilter) return false;
      if (_searchController.text.trim().isEmpty) return true;
      final q = _searchController.text.trim().toLowerCase();
      return r.clearanceCode.toLowerCase().contains(q) ||
          (r.declaration46No ?? '').toLowerCase().contains(q) ||
          (r.deliveryOrderNumber ?? '').toLowerCase().contains(q) ||
          r.customsOfficeName.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Responsive Filter & Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 750;
              final searchField = SizedBox(
                width: isSmall ? constraints.maxWidth : 260,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l.customsClearanceSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        return value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              );

              final statusDropdown = DropdownButton<String>(
                value: _selectedStatusFilter,
                underline: const SizedBox(),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: [
                  DropdownMenuItem(value: 'All', child: Text(l.customsClearanceFilterAll)),
                  DropdownMenuItem(value: 'Inspection In Progress', child: Text(l.customsClearanceFilterInspection)),
                  DropdownMenuItem(value: 'Duty Requested', child: Text(l.customsClearanceFilterDutyRequested)),
                  DropdownMenuItem(value: 'Duty Paid', child: Text(l.customsClearanceFilterDutyPaid)),
                  DropdownMenuItem(value: 'Final Release Granted', child: Text(l.customsClearanceFilterFinalRelease)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatusFilter = val);
                },
              );

              final actionButtons = [
                ElevatedButton.icon(
                  key: const Key('createClearanceBtn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l.customsClearanceNewRecordButton),
                  onPressed: () => _showAddEditDialog(),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  key: const Key('searchAndCloneClearanceBtn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt.withOpacity(0.85),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.difference_outlined, size: 16),
                  label: Text(l.searchAndCloneCustomsClearanceBtn),
                  onPressed: () => _openSearchAndCloneClearanceDialog(records),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('copyClearanceTableTsvBtn'),
                  icon: const Icon(Icons.copy_all_outlined, size: 20, color: AppTheme.cobalt),
                  tooltip: l.copyCustomsClearanceTableSuccess,
                  onPressed: () => _copyClearanceTableTsv(filtered, l),
                ),
                IconButton(
                  key: const Key('exportClearanceExcelBtn'),
                  icon: const Icon(Icons.table_view_outlined, size: 20, color: AppTheme.emerald),
                  tooltip: l.exportCustomsClearanceExcelTooltip,
                  onPressed: () => _exportClearanceExcel(filtered, l),
                ),
                IconButton(
                  key: const Key('exportClearancePdfBtn'),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppTheme.crimson),
                  tooltip: l.exportCustomsClearancePdfTooltip,
                  onPressed: () => _exportClearancePdf(filtered, l),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.cobalt, size: 20),
                  tooltip: l.customsDeclRefreshTooltip,
                  onPressed: _refreshData,
                ),
              ];

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        statusDropdown,
                        ...actionButtons,
                      ],
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      searchField,
                      const SizedBox(width: 12),
                      statusDropdown,
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actionButtons,
                  ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),

        // List of Cards
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(l.customsClearanceEmptyRecords))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final record = filtered[index];
                    return _buildClearanceCard(record, l);
                  },
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SUB-VIEW 1: DRAWING SAMPLES & SHORTAGE TRACKING
  // ===========================================================================
  Widget _buildDrawingSamplesAndShortageView(List<CustomsClearanceModel> records, AppLocalizations l) {
    return DrawingSamplesAndShortageTab(
      records: records,
      drawnSamples: _drawnSamples,
      shortageProtocols: _shortageProtocols,
      onRefresh: _refreshData,
      onAddSample: (sample) {
        setState(() => _drawnSamples.insert(0, sample));
      },
      onAddShortage: (shortage) {
        setState(() => _shortageProtocols.insert(0, shortage));
      },
    );
  }

  // ===========================================================================
  // SUB-VIEW 2: DISCREPANCY & DAMAGE REGISTRY
  // ===========================================================================
  Widget _buildDiscrepancyAndDamageView(List<CustomsClearanceModel> records, AppLocalizations l) {
    return DiscrepancyAndDamageTab(
      records: records,
      discrepancyProtocols: _discrepancyProtocols,
      onRefresh: _refreshData,
      onAddProtocol: (protocol) {
        setState(() => _discrepancyProtocols.insert(0, protocol));
      },
    );
  }

  // ===========================================================================
  // SUB-VIEW 3: FINAL CUSTOMS PAYMENT & RELEASE
  // ===========================================================================
  Widget _buildFinalDutyPaymentView(List<CustomsClearanceModel> records, AppLocalizations l) {
    return FinalDutyPaymentTab(
      records: records,
      onRefresh: _refreshData,
      onPay: _showDutyPaymentDialog,
      onRelease: _showFinalReleaseDialog,
    );
  }

  Widget _buildClearanceCard(CustomsClearanceModel record, AppLocalizations l) {
    final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawFileCode = 'IMP-${record.importFileId}';
    final shipName = DisplayNameResolver.resolveShipmentNameByCode(rawFileCode, shipments: allFiles, isArabic: isAr);

    Color statusColor = Colors.blueGrey;
    String statusLabel = record.status;
    if (record.status == 'Final Release Granted') {
      statusColor = AppTheme.emerald;
      statusLabel = l.customsClearanceFilterFinalRelease;
    } else if (record.status == 'Duty Paid') {
      statusColor = AppTheme.cobalt;
      statusLabel = l.customsClearanceFilterDutyPaid;
    } else if (record.status == 'Duty Requested') {
      statusColor = AppTheme.orange;
      statusLabel = l.customsClearanceFilterDutyRequested;
    } else if (record.status == 'Inspection In Progress') {
      statusLabel = l.customsClearanceFilterInspection;
    }

    final isGreenChannel = record.channelType.toLowerCase().contains('green');
    String channelLabel = record.channelType;
    if (record.channelType.toLowerCase().contains('red')) {
      channelLabel = l.customsClearanceChannelRed;
    } else if (record.channelType.toLowerCase().contains('green')) {
      channelLabel = l.customsClearanceChannelGreen;
    } else if (record.channelType.toLowerCase().contains('yellow')) {
      channelLabel = l.customsClearanceChannelYellow;
    }

    final primaryTextColor = isDark ? const Color(0xFFF1F5F9) : AppTheme.charcoal;
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : Colors.black87;
    final tertiaryTextColor = isDark ? const Color(0xFF64748B) : Colors.black54;

    final actionButtons = [
      IconButton(
        key: Key('editClearanceBtn_${record.clearanceCode}'),
        icon: const Icon(Icons.edit_outlined, color: AppTheme.cobalt, size: 20),
        tooltip: l.customsClearanceEditTooltip,
        onPressed: () => _showAddEditDialog(record),
      ),
      IconButton(
        key: Key('copyClearanceRowBtn_${record.clearanceCode}'),
        icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
        tooltip: l.copyCustomsClearanceRowSuccess,
        onPressed: () => _copyClearanceRowTsv(record, l),
      ),
      IconButton(
        key: Key('cloneClearanceBtn_${record.clearanceCode}'),
        icon: const Icon(Icons.difference_outlined, color: AppTheme.cobalt, size: 20),
        tooltip: l.cloneCustomsClearanceTooltip,
        onPressed: () => _onCloneClearance(record),
      ),
      IconButton(
        key: Key('underBondBtn_${record.clearanceCode}'),
        icon: const Icon(Icons.lock_clock_outlined, color: AppTheme.orange, size: 20),
        tooltip: l.customsClearanceUnderBondTooltip,
        onPressed: () => showUnderBondReleaseDialog(
          context,
          ref,
          clearanceId: record.customsClearanceId,
          declarationNo: record.declaration46No ?? record.clearanceCode,
          isAlreadyUnderBond: record.status.contains('Bond') || record.status.contains('Quarantine'),
          onDone: _refreshData,
        ),
      ),
      IconButton(
        key: Key('payDutyBtn_${record.clearanceCode}'),
        icon: const Icon(Icons.payments_outlined, color: AppTheme.emerald, size: 20),
        tooltip: l.customsClearancePayTooltip,
        onPressed: () => _showDutyPaymentDialog(record),
      ),
      IconButton(
        key: Key('finalReleaseBtn_${record.clearanceCode}'),
        icon: const Icon(Icons.assignment_turned_in_outlined, color: Colors.indigo, size: 20),
        tooltip: l.customsClearanceReleaseTooltip,
        onPressed: () => _showFinalReleaseDialog(record),
      ),
      IconButton(
        key: Key('clearanceExpensesBtn_${record.clearanceCode}'),
        icon: const Icon(Icons.receipt_long_outlined, color: Color(0xFF0284C7), size: 20),
        tooltip: 'فواتير ومصاريف التخليص (CL-05)',
        onPressed: () => _showClearanceExpensesDialog(record),
      ),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, cardConstraints) {
            final isNarrow = cardConstraints.maxWidth < 650;

            final statusBadge = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            );

            final channelBadge = Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isGreenChannel ? AppTheme.emerald : AppTheme.crimson).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isGreenChannel ? AppTheme.emerald : AppTheme.crimson, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGreenChannel ? Icons.check_circle_outline : Icons.flag_rounded,
                    size: 14,
                    color: isGreenChannel ? AppTheme.emerald : AppTheme.crimson,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      channelLabel,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isGreenChannel ? AppTheme.emerald : AppTheme.crimson),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );

            final headerWidget = isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : AppTheme.charcoal.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: CopyableText(
                                record.clearanceCode,
                                style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          statusBadge,
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          channelBadge,
                          if (record.declaration46No != null && record.declaration46No!.isNotEmpty)
                            CopyableText('${l.customsClearanceDeclaration46Label}: ${record.declaration46No}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt)),
                          if (record.deliveryOrderNumber != null && record.deliveryOrderNumber!.isNotEmpty)
                            CopyableText('${l.customsClearanceDeliveryOrderLabel}: ${record.deliveryOrderNumber}', style: TextStyle(fontSize: 11.5, color: tertiaryTextColor)),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : AppTheme.charcoal.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: CopyableText(
                                record.clearanceCode,
                                style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor, fontSize: 13),
                              ),
                            ),
                            channelBadge,
                            if (record.declaration46No != null && record.declaration46No!.isNotEmpty)
                              CopyableText('${l.customsClearanceDeclaration46Label}: ${record.declaration46No}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt)),
                            if (record.deliveryOrderNumber != null && record.deliveryOrderNumber!.isNotEmpty)
                              CopyableText('${l.customsClearanceDeliveryOrderLabel}: ${record.deliveryOrderNumber}', style: TextStyle(fontSize: 11.5, color: tertiaryTextColor)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      statusBadge,
                    ],
                  );

            final officeAndShipmentBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CopyableText('🏢 ${l.customsClearanceOfficeLabel}: ${record.customsOfficeName}', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    CopyableText(
                      '📦 ${l.customsClearanceFileRefLabel}: $shipName',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryTextColor),
                    ),
                    if (rawFileCode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: CopyableText(
                          rawFileCode,
                          style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(11.0), color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                if (record.freeDaysAllowed > 0) ...[
                  const SizedBox(height: 4),
                  Text('⏱️ ${l.customsClearanceFreeDaysLabel(record.freeDaysAllowed)}', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF818CF8) : Colors.indigo, fontWeight: FontWeight.bold)),
                ],
              ],
            );

            final dutiesAndPaymentBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CopyableText('💰 ${l.customsClearanceTotalDutiesCard}: ${(record.actualDutyTotal > 0 ? record.actualDutyTotal : record.totalDutyPayable).toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                const SizedBox(height: 4),
                if (record.estimatedDutyTotal > 0)
                  CopyableText(
                    '⚖️ ${l.customsClearanceEstimatedDutiesCard(record.estimatedDutyTotal.toStringAsFixed(2), "${record.dutyVarianceAmount >= 0 ? '+' : ''}${record.dutyVarianceAmount.toStringAsFixed(2)}", record.dutyVariancePercentage.toString())}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: record.dutyVarianceAmount.abs() > 500 ? AppTheme.orange : tertiaryTextColor),
                  ),
                const SizedBox(height: 4),
                Text('${l.customsClearancePaymentStatusLabel}: ${record.paymentStatus == "Paid & Verified" ? l.customsClearanceStatusPaid : l.customsClearanceStatusPendingPayment}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: record.paymentStatus == 'Paid & Verified' ? AppTheme.emerald : Colors.red)),
              ],
            );

            Widget detailsAndActions;
            if (isNarrow) {
              detailsAndActions = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  officeAndShipmentBlock,
                  const SizedBox(height: 10),
                  dutiesAndPaymentBlock,
                  const SizedBox(height: 8),
                  const Divider(height: 12),
                  Wrap(
                    spacing: 2,
                    runSpacing: 2,
                    children: actionButtons,
                  ),
                ],
              );
            } else {
              detailsAndActions = Row(
                children: [
                  Expanded(child: officeAndShipmentBlock),
                  Expanded(child: dutiesAndPaymentBlock),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actionButtons,
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerWidget,
                const Divider(height: 18),
                detailsAndActions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CustomsClearanceFormDialog extends ConsumerStatefulWidget {
  final CustomsClearanceModel? recordToEdit;
  final bool isCloneDraft;
  const _CustomsClearanceFormDialog({this.recordToEdit, this.isCloneDraft = false});

  @override
  ConsumerState<_CustomsClearanceFormDialog> createState() => _CustomsClearanceFormDialogState();
}

class _CustomsClearanceFormDialogState extends ConsumerState<_CustomsClearanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedImportFileId;
  final TextEditingController _decl46Ctrl = TextEditingController();
  final TextEditingController _officeCtrl = TextEditingController(text: 'Alexandria Port Customs');
  final TextEditingController _doNumberCtrl = TextEditingController();
  final TextEditingController _freeDaysCtrl = TextEditingController(text: '14');
  String _channelType = 'Red Channel';
  final TextEditingController _dutyCtrl = TextEditingController(text: '0');
  final TextEditingController _vatCtrl = TextEditingController(text: '0');
  final TextEditingController _scheduleTaxCtrl = TextEditingController(text: '0');
  final TextEditingController _whtCtrl = TextEditingController(text: '0');
  final TextEditingController _labFeesCtrl = TextEditingController(text: '0');
  final TextEditingController _estimatedDutyCtrl = TextEditingController(text: '0');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.recordToEdit != null) {
      final r = widget.recordToEdit!;
      _selectedImportFileId = r.importFileId;
      _decl46Ctrl.text = widget.isCloneDraft ? '' : (r.declaration46No ?? '');
      _officeCtrl.text = r.customsOfficeName;
      _doNumberCtrl.text = widget.isCloneDraft ? '' : (r.deliveryOrderNumber ?? '');
      _freeDaysCtrl.text = r.freeDaysAllowed.toString();
      _channelType = r.channelType;
      _dutyCtrl.text = r.importDutyAmount.toString();
      _vatCtrl.text = r.vatAmount.toString();
      _scheduleTaxCtrl.text = r.scheduleTaxAmount.toString();
      _whtCtrl.text = r.whtAmount.toString();
      _labFeesCtrl.text = r.labServiceFees.toString();
      _estimatedDutyCtrl.text = r.estimatedDutyTotal.toString();
    }
  }

  void _applyExtractedNafezaData(Map<String, dynamic> ext, AppLocalizations l) {
    setState(() {
      if (ext['declaration_no'] != null && ext['declaration_no'].toString().isNotEmpty) {
        _decl46Ctrl.text = ext['declaration_no'].toString();
      }
      if (ext['customs_office_name'] != null && ext['customs_office_name'].toString().isNotEmpty) {
        _officeCtrl.text = ext['customs_office_name'].toString();
      }
      if (ext['channel_type'] != null && ext['channel_type'].toString().isNotEmpty) {
        _channelType = ext['channel_type'].toString();
      }
      if (ext['import_duty'] != null) {
        _dutyCtrl.text = ext['import_duty'].toString();
      }
      if (ext['vat_amount'] != null) {
        _vatCtrl.text = ext['vat_amount'].toString();
      }
      if (ext['schedule_tax'] != null) {
        _scheduleTaxCtrl.text = ext['schedule_tax'].toString();
      }
      if (ext['wht_amount'] != null) {
        _whtCtrl.text = ext['wht_amount'].toString();
      }
      if (ext['lab_service_fees'] != null) {
        _labFeesCtrl.text = ext['lab_service_fees'].toString();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.customsClearanceExtractNafezaSuccess), backgroundColor: AppTheme.emerald),
    );
  }

  @override
  void dispose() {
    _decl46Ctrl.dispose();
    _officeCtrl.dispose();
    _doNumberCtrl.dispose();
    _freeDaysCtrl.dispose();
    _dutyCtrl.dispose();
    _vatCtrl.dispose();
    _scheduleTaxCtrl.dispose();
    _whtCtrl.dispose();
    _labFeesCtrl.dispose();
    _estimatedDutyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final titleText = widget.isCloneDraft
        ? l.cloneCustomsClearanceDialogTitle
        : (widget.recordToEdit == null
            ? l.customsClearanceNewDialogTitle
            : l.customsClearanceEditDialogTitle(widget.recordToEdit!.clearanceCode));

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titleText),
          SmartUploadButton(
            module: SmartUploadModule.customsClearance,
            compact: true,
            label: l.customsClearanceExtractNafezaBtn,
            onDataExtracted: (res) => _applyExtractedNafezaData(res.extractedFields, l),
          ),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 680.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdownField<int>(
                    value: _selectedImportFileId,
                    labelText: l.customsClearanceImportFileLabel,
                    searchHintText: l.customsClearanceImportFileSearchHint,
                    items: importFiles
                        .map((f) => SearchableDropdownItem<int>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode} - ${f.companyName}',
                              subtitle: 'PO: ${f.poNumber ?? "N/A"} | ACID: ${f.acidNumber ?? "N/A"}',
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedImportFileId = val),
                    validator: (val) => val == null ? l.customsClearanceSelectFileValidator : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _decl46Ctrl,
                          decoration: InputDecoration(
                            labelText: l.customsClearanceDecl46Label,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: l.customsClearanceCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(context, _decl46Ctrl.text),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _doNumberCtrl,
                          decoration: InputDecoration(
                            labelText: l.customsClearanceDoNumberLabel,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: l.customsClearanceCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(context, _doNumberCtrl.text),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _freeDaysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l.customsClearanceFreeDaysInputLabel, border: const OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _officeCtrl,
                        decoration: InputDecoration(labelText: l.customsClearanceOfficeInputLabel, border: const OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l.customsClearanceOfficeValidator : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _channelType,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l.customsClearanceChannelLabel, border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'Red Channel', child: Text('🔴 ${l.customsClearanceChannelRed}', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'Green Channel', child: Text('🟢 ${l.customsClearanceChannelGreen}', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'Yellow Channel', child: Text('🟡 ${l.customsClearanceChannelYellow}', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _channelType = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(l.customsClearanceDutyBreakdownHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dutyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l.customsClearanceImportDutyInput, border: const OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _vatCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l.customsClearanceVatInput, border: const OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _scheduleTaxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l.customsClearanceScheduleTaxInput, border: const OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _whtCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l.customsClearanceWhtInput, border: const OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _labFeesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l.customsClearanceLabFeesInput, border: const OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _estimatedDutyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l.customsClearanceEstimatedDutyInput, border: const OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
          onPressed: _isLoading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isLoading = true);

                  final duty = double.tryParse(_dutyCtrl.text) ?? 0.0;
                  final vat = double.tryParse(_vatCtrl.text) ?? 0.0;
                  final sched = double.tryParse(_scheduleTaxCtrl.text) ?? 0.0;
                  final wht = double.tryParse(_whtCtrl.text) ?? 0.0;
                  final lab = double.tryParse(_labFeesCtrl.text) ?? 0.0;
                  final total = duty + vat + sched + wht + lab;

                  final payload = {
                    'import_file_id': _selectedImportFileId,
                    'declaration_46_no': _decl46Ctrl.text.trim().isNotEmpty ? _decl46Ctrl.text.trim() : null,
                    'customs_office_name': _officeCtrl.text.trim(),
                    'channel_type': _channelType,
                    'delivery_order_number': _doNumberCtrl.text.trim().isNotEmpty ? _doNumberCtrl.text.trim() : null,
                    'free_days_allowed': int.tryParse(_freeDaysCtrl.text) ?? 14,
                    'import_duty_amount': duty,
                    'vat_amount': vat,
                    'schedule_tax_amount': sched,
                    'wht_amount': wht,
                    'lab_service_fees': lab,
                    'total_duty_payable': total,
                    'estimated_duty_total': double.tryParse(_estimatedDutyCtrl.text) ?? 0.0,
                  };

                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  try {
                    await ref.read(customsClearanceProvider.notifier).createRecord(payload);
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.customsClearanceSaveRecordSuccess), backgroundColor: AppTheme.emerald),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.customsClearanceSaveRecordError(e.toString())), backgroundColor: AppTheme.crimson),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(l.customsClearanceSaveRecordBtn, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _DutyPaymentDialog extends ConsumerStatefulWidget {
  final CustomsClearanceModel record;
  const _DutyPaymentDialog({required this.record});

  @override
  ConsumerState<_DutyPaymentDialog> createState() => _DutyPaymentDialogState();
}

class _DutyPaymentDialogState extends ConsumerState<_DutyPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _receiptCtrl = TextEditingController();
  final TextEditingController _actualPaidCtrl = TextEditingController();
  final TextEditingController _varianceReasonCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _actualPaidCtrl.text = (widget.record.actualDutyTotal > 0 ? widget.record.actualDutyTotal : widget.record.totalDutyPayable).toString();
    _receiptCtrl.text = widget.record.bankReceiptNo ?? '';
    _varianceReasonCtrl.text = widget.record.dutyVarianceReason ?? '';
  }

  @override
  void dispose() {
    _receiptCtrl.dispose();
    _actualPaidCtrl.dispose();
    _varianceReasonCtrl.dispose();
    super.dispose();
  }

  void _applyExtractedPayment(Map<String, dynamic> ext) {
    setState(() {
      if (ext['receipt_number'] != null) _receiptCtrl.text = ext['receipt_number'].toString();
      if (ext['actual_paid_amount'] != null) _actualPaidCtrl.text = ext['actual_paid_amount'].toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final est = widget.record.estimatedDutyTotal;
    final act = double.tryParse(_actualPaidCtrl.text) ?? widget.record.totalDutyPayable;
    final diff = act - est;
    final diffPercent = est > 0 ? ((diff / est) * 100).toStringAsFixed(1) : '0.0';

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l.customsClearanceDutyPaymentDialogTitle(widget.record.clearanceCode)),
          SmartUploadButton(
            module: SmartUploadModule.customsClearance,
            compact: true,
            label: l.customsClearanceExtractReceiptBtn,
            onDataExtracted: (res) => _applyExtractedPayment(res.extractedFields),
          ),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 560.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Variance Comparison Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (diff.abs() > 500 ? AppTheme.orange : AppTheme.emerald).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: diff.abs() > 500 ? AppTheme.orange : AppTheme.emerald),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l.customsClearanceEstimatorDutyBoxLabel(est.toStringAsFixed(2)), style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(l.customsClearanceNafezaDutyBoxLabel(act.toStringAsFixed(2)), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l.customsClearanceVarianceBoxLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(2)} EGP ($diffPercent%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: diff.abs() > 500 ? AppTheme.crimson : AppTheme.emerald,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _actualPaidCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.customsClearanceActualPaidInput, border: const OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? l.poRecRequired : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _receiptCtrl,
                  decoration: InputDecoration(
                    labelText: l.customsClearanceBankReceiptInput,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l.customsClearanceCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _receiptCtrl.text),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? l.poRecRequired : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _varianceReasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: l.customsClearanceVarianceReasonInput, border: const OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
          onPressed: _isLoading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isLoading = true);
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  try {
                    await ref.read(customsClearanceProvider.notifier).submitDutyPayment(
                          widget.record.customsClearanceId,
                          {
                            'bank_receipt_no': _receiptCtrl.text.trim(),
                            'actual_duty_total': double.tryParse(_actualPaidCtrl.text) ?? widget.record.totalDutyPayable,
                            'duty_variance_reason': _varianceReasonCtrl.text.trim().isNotEmpty ? _varianceReasonCtrl.text.trim() : null,
                          },
                        );
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.customsClearancePaymentSuccess), backgroundColor: AppTheme.emerald),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.customsClearancePaymentError(e.toString())), backgroundColor: AppTheme.crimson),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(l.customsClearanceConfirmPaymentBtn, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _FinalReleaseDialog extends ConsumerStatefulWidget {
  final CustomsClearanceModel record;
  const _FinalReleaseDialog({required this.record});

  @override
  ConsumerState<_FinalReleaseDialog> createState() => _FinalReleaseDialogState();
}

class _FinalReleaseDialogState extends ConsumerState<_FinalReleaseDialog> {
  final TextEditingController _releaseNoCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _releaseNoCtrl.text = widget.record.releasePermitNo ?? 'REL-${widget.record.clearanceCode}';
  }

  @override
  void dispose() {
    _releaseNoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.indigo),
          const SizedBox(width: 8),
          Text(l.customsClearanceFinalReleaseDialogTitle),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 480.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.customsClearanceFinalReleaseDialogDesc),
              const SizedBox(height: 14),
              TextFormField(
                controller: _releaseNoCtrl,
                decoration: InputDecoration(
                  labelText: l.customsClearanceReleasePermitInput,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l.customsClearanceCopyFieldTooltip,
                    onPressed: () => CopyHelper.copy(context, _releaseNoCtrl.text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  try {
                    await ref.read(customsClearanceProvider.notifier).completeRelease(
                          widget.record.customsClearanceId,
                          {
                            'release_permit_no': _releaseNoCtrl.text.trim(),
                          },
                        );
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.customsClearanceReleaseSuccess), backgroundColor: AppTheme.emerald),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.customsClearanceReleaseError(e.toString())), backgroundColor: AppTheme.crimson),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(l.customsClearanceConfirmReleaseBtn, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
