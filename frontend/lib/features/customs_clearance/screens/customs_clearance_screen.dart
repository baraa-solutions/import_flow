import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import '../widgets/clearance_details_dialog.dart';
import '../widgets/clearance_expenses_dialog.dart';
import '../widgets/clearance_followup_dialog.dart';
import '../widgets/clearance_screen_dialogs.dart';
import '../widgets/customs_broker_authorization_dialog.dart';
import '../widgets/customs_declaration_46_dialog.dart';
import '../widgets/customs_duty_payment_dialog.dart';
import '../widgets/customs_final_release_dialog.dart';
import '../widgets/customs_inspection_sampling_dialog.dart';
import '../widgets/customs_ui.dart';
import '../widgets/delivery_order_payment_dialog.dart';
import '../widgets/discrepancy_and_damage_tab.dart';
import '../widgets/drawing_samples_and_shortage_tab.dart';
import '../widgets/final_duty_assessment_dialog.dart';
import '../widgets/final_duty_payment_tab.dart';
import '../widgets/import_file_picker_dialog.dart';
import '../widgets/search_and_clone_customs_clearance_dialog.dart';
import '../widgets/under_bond_release_dialog.dart';
import '../widgets/reexport_protocol_dialog.dart';
import '../widgets/inspection_appeals_dialog.dart';
import '../widgets/broker_custody_settlement_dialog.dart';
import '../widgets/clearance_followup_tab.dart';

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
  int _selectedTab = 0;

  // Local state for discrepancy protocols (Clean Production - 0 records)
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
    if (fileId == null) {
      if (mounted) setState(() => _clearanceGuideMatchResult = null);
      return;
    }
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file == null) {
      if (mounted) setState(() => _clearanceGuideMatchResult = null);
      return;
    }

    try {
      final res = await ref.read(experienceGuideProvider.notifier).matchImportFile(file);
      if (mounted) {
        setState(() => _clearanceGuideMatchResult = res);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, ApiErrorText.of(context.l10n, e), severity: AppSeverity.danger),
        );
      }
    }
  }

  void _showAddEditDialog([CustomsClearanceModel? recordToEdit, bool isCloneDraft = false]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClearanceFormDialog(
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
            entityType: l.ccCloneEntityType,
            sourceCode: rec.clearanceCode,
            suggestedNewCode: newDraftCode,
            sourceTitle: rec.declaration46No != null && rec.declaration46No!.isNotEmpty
                ? '${l.customsClearanceDeclaration46Label}: ${rec.declaration46No}'
                : rec.customsOfficeName,
            copiedFieldsSummary: {
              l.ccCloneFieldOffice: rec.customsOfficeName,
              l.ccCloneFieldChannel: rec.channelType,
              l.ccCloneFieldImportDuty: '${CcFormat.money(rec.importDutyAmount)} ${l.egpCurrency}',
              l.ccCloneFieldVat: '${CcFormat.money(rec.vatAmount)} ${l.egpCurrency}',
              l.ccCloneFieldScheduleTax: '${CcFormat.money(rec.scheduleTaxAmount)} ${l.egpCurrency}',
              l.ccCloneFieldWht: '${CcFormat.money(rec.whtAmount)} ${l.egpCurrency}',
              l.ccCloneFieldLabFees: '${CcFormat.money(rec.labServiceFees)} ${l.egpCurrency}',
              l.ccCloneFieldTotalDuty: '${CcFormat.money(rec.totalDutyPayable)} ${l.egpCurrency}',
              l.ccCloneFieldFreeDays: l.ccCloneDaysValue(rec.freeDaysAllowed),
            },
            mandatorilyResetFields: [
              l.ccCloneReset1,
              l.ccCloneReset2,
              l.ccCloneReset3,
              l.ccCloneReset4,
              l.ccCloneReset5,
              l.ccCloneReset6,
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
        builder: (context) => ClearanceDutyPaymentFallbackDialog(record: record),
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
        builder: (context) => ClearanceFinalReleaseFallbackDialog(record: record),
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

  void _showFollowupDialog(CustomsClearanceModel record) {
    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final matchingFile = allFiles.where((f) => f.importFileId == record.importFileId).firstOrNull;
    ClearanceFollowupDialog.show(
      context,
      clearanceRecord: record,
      importFile: matchingFile,
    );
  }

  /// Resolves the shipment a header stage button works on, or tells the user
  /// that no shipment file is registered.
  Future<void> _openStage(void Function(ImportFileModel file) open) async {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.ccNoImportFiles, severity: AppSeverity.warning),
      );
      return;
    }
    ImportFileModel? targetFile;
    if (widget.initialImportFileId != null) {
      targetFile = files.where((f) => f.importFileId == widget.initialImportFileId).firstOrNull;
    }
    if (targetFile == null) {
      targetFile = await showImportFilePickerDialog(
        context,
        ref,
        title: context.l10n.importFilePickerTitle,
      );
      if (targetFile == null) return;
    }
    if (!mounted) return;
    open(targetFile);
  }

  void _openRecordStage(CustomsClearanceModel record, void Function(ImportFileModel file) open) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == record.importFileId).firstOrNull;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.ccRecordFileNotFound,
          severity: AppSeverity.warning,
        ),
      );
      return;
    }
    open(file);
  }

  Widget _stageButton({
    required String keyName,
    required IconData icon,
    required String label,
    required void Function(ImportFileModel file) open,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: AppButton(
        key: Key(keyName),
        label: label,
        icon: icon,
        size: AppButtonSize.small,
        onPressed: () => _openStage(open),
      ),
    );
  }

  List<Widget> _headerActions(AppLocalizations l) {
    return [
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: AppButton(
          label: l.customsClearanceAiBrokerExtractorBtn,
          icon: Icons.auto_awesome_rounded,
          variant: AppButtonVariant.success,
          size: AppButtonSize.small,
          onPressed: () => UniversalEntityExtractorDialog.showCustomsBrokerExtractor(
            context,
            onSaved: () => ref.read(partnersProvider.notifier).fetchPartners(),
          ),
        ),
      ),
      _stageButton(
        keyName: 'authorizeCustomsBrokerHeaderBtn',
        icon: Icons.assignment_ind_rounded,
        label: l.ccStageBrokerAuth,
        open: (f) => CustomsBrokerAuthorizationDialog.show(context, f),
      ),
      _stageButton(
        keyName: 'deliveryOrderPaymentScreenBtn',
        icon: Icons.directions_boat_filled_rounded,
        label: l.ccStageDeliveryOrder,
        open: (f) => DeliveryOrderPaymentDialog.show(context, f),
      ),
      _stageButton(
        keyName: 'customsDeclaration46ScreenBtn',
        icon: Icons.description_rounded,
        label: l.ccStageDeclaration46,
        open: (f) => CustomsDeclaration46Dialog.show(context, f),
      ),
      _stageButton(
        keyName: 'customsInspectionSamplingScreenBtn',
        icon: Icons.biotech_rounded,
        label: l.ccStageInspection,
        open: (f) {
          final records = ref.read(customsClearanceProvider).valueOrNull ?? [];
          final record = records.where((r) => r.importFileId == f.importFileId).firstOrNull;
          CustomsInspectionSamplingDialog.show(context, f, clearanceRecord: record);
        },
      ),
      _stageButton(
        keyName: 'finalDutyAssessmentScreenBtn',
        icon: Icons.calculate_rounded,
        label: l.ccStageAssessment,
        open: (f) => FinalDutyAssessmentDialog.show(context, f),
      ),
      _stageButton(
        keyName: 'customsDutyPaymentScreenBtn',
        icon: Icons.receipt_long_rounded,
        label: l.ccStageDutyPayment,
        open: (f) => CustomsDutyPaymentDialog.show(context, f),
      ),
      _stageButton(
        keyName: 'customsFinalReleaseScreenBtn',
        icon: Icons.verified_outlined,
        label: l.ccStageRelease,
        open: (f) => CustomsFinalReleaseDialog.show(context, f),
      ),
      _stageButton(
        keyName: 'customsBrokerCustodyBtn',
        icon: Icons.account_balance_wallet_outlined,
        label: l.isArabic ? 'عهد ومصروفات المخلص' : 'Broker Custody',
        open: (f) => BrokerCustodySettlementDialog.show(context, initialImportFileId: f.importFileId),
      ),
      _stageButton(
        keyName: 'customsClearanceInvoicesScreenBtn',
        icon: Icons.receipt_long_rounded,
        label: l.ccStageInvoices,
        open: (f) => ClearanceExpensesDialog.show(context, f),
      ),
      _stageButton(
        keyName: 'customsFollowupsScreenBtn',
        icon: Icons.checklist_rtl_rounded,
        label: l.isArabic ? 'المتابعة الميدانية' : 'Field Follow-ups',
        open: (f) {
          final records = ref.read(customsClearanceProvider).valueOrNull ?? [];
          final record = records.where((r) => r.importFileId == f.importFileId).firstOrNull;
          if (record == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(
                context,
                l.isArabic ? 'يجب تسجيل قيد تخليص جمركي للشحنة أولاً' : 'Clearance record required first',
                severity: AppSeverity.warning,
              ),
            );
            return;
          }
          ClearanceFollowupDialog.show(context, clearanceRecord: record, importFile: f);
        },
      ),
      _stageButton(
        keyName: 'customsInspectionAppealsBtn',
        icon: Icons.biotech_rounded,
        label: l.isArabic ? 'تظلمات الفحص المعملي' : 'Lab Appeals',
        open: (f) {
          InspectionAppealsDialog.show(context, initialImportFileId: f.importFileId);
        },
      ),
      _stageButton(
        keyName: 'customsReexportProtocolBtn',
        icon: Icons.outbox_rounded,
        label: l.isArabic ? 'إعادة التصدير والرفض' : 'Re-Export Protocol',
        open: (f) {
          ReexportProtocolDialog.show(context, initialImportFileId: f.importFileId);
        },
      ),
      IconButton(
        icon: Icon(Icons.refresh, color: AppTheme.cloudWhite.withValues(alpha: 0.85), size: 20),
        tooltip: l.refresh,
        onPressed: _refreshData,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.watch(displayDensityProvider);
    final clearanceAsync = ref.watch(customsClearanceProvider);

    return VerticalStageScaffold(
      stageCode: 'PHASE-5',
      titleAr: 'الميناء والتخليص الجمركي والمعاينة والمطابقة',
      titleEn: 'Port Operations & Customs Clearance Hub',
      headerIcon: Icons.gavel_rounded,
      headerColor: AppTheme.cobalt,
      headerActions: _headerActions(l),
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
          loading: () => const AppLoadingState(),
          error: (err, stack) => AppErrorState(
            error: err,
            message: l.customsClearanceErrorFetch(ApiErrorText.of(l, err)),
            onRetry: _refreshData,
          ),
          data: (records) {
            switch (_selectedTab) {
              case 1:
                return _buildDrawingSamplesAndShortageView(records, l);
              case 2:
                return _buildDiscrepancyAndDamageView(records, l);
              case 3:
                return _buildFinalDutyPaymentView(records, l);
              case 0:
              default:
                return ClearanceFollowupTab(
                  records: records,
                  onRefresh: _refreshData,
                  onAddNew: () => _showAddEditDialog(),
                  onCloneFromList: _openSearchAndCloneClearanceDialog,
                  onViewDetails: _showClearanceDetails,
                  onBrokerAuth: (r) => _openRecordStage(r, (f) => CustomsBrokerAuthorizationDialog.show(context, f)),
                  onDeliveryOrder: (r) => _openRecordStage(r, (f) => DeliveryOrderPaymentDialog.show(context, f)),
                  onDeclaration46: (r) => _openRecordStage(r, (f) => CustomsDeclaration46Dialog.show(context, f)),
                  onInspection: (r) => _openRecordStage(r, (f) => CustomsInspectionSamplingDialog.show(context, f, clearanceRecord: r)),
                  onAssessDuties: (r) => _openRecordStage(r, (f) => FinalDutyAssessmentDialog.show(context, f)),
                  onEdit: (r) => _showAddEditDialog(r),
                  onCloneRecord: _onCloneClearance,
                  onUnderBond: (r) => showUnderBondReleaseDialog(
                    context,
                    ref,
                    clearanceId: r.customsClearanceId,
                    declarationNo: r.declaration46No ?? r.clearanceCode,
                    isAlreadyUnderBond: r.isUnderBondRelease,
                    onDone: _refreshData,
                  ),
                  onPayDuty: _showDutyPaymentDialog,
                  onRelease: _showFinalReleaseDialog,
                  onExpenses: _showClearanceExpensesDialog,
                  onFollowups: _showFollowupDialog,
                );
            }
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // SUB-VIEW 1: DRAWING SAMPLES & SHORTAGE TRACKING
  // ===========================================================================
  Widget _buildDrawingSamplesAndShortageView(List<CustomsClearanceModel> records, AppLocalizations l) {
    return DrawingSamplesAndShortageTab(
      records: records,
      onRefresh: _refreshData,
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

  void _showClearanceDetails(CustomsClearanceModel record) {
    ClearanceDetailsDialog.show(context, record: record);
  }

  // ===========================================================================
  // SUB-VIEW 3: FINAL CUSTOMS PAYMENT & RELEASE
  // ===========================================================================
  Widget _buildFinalDutyPaymentView(List<CustomsClearanceModel> records, AppLocalizations l) {
    return FinalDutyPaymentTab(
      records: records,
      onRefresh: _refreshData,
      onView: _showClearanceDetails,
      onPay: _showDutyPaymentDialog,
      onRelease: _showFinalReleaseDialog,
    );
  }
}
