import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/customs_declaration_assessment.dart';
import '../providers/import_documentation_provider.dart';
import '../services/customs_declaration46_calculator.dart';
import '../widgets/customs_declaration46_form_tab.dart';
import '../widgets/customs_declaration46_registry_tab.dart';
import '../widgets/search_and_clone_customs_declaration46_dialog.dart';

export '../models/customs_declaration_assessment.dart';

class CustomsDeclaration46Screen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;

  const CustomsDeclaration46Screen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
  });

  @override
  ConsumerState<CustomsDeclaration46Screen> createState() => _CustomsDeclaration46ScreenState();
}

class _CustomsDeclaration46ScreenState extends ConsumerState<CustomsDeclaration46Screen> {
  // Active Vertical Sub-Tab:
  // 0: Initial Declaration 46 Registration
  // 1: Declaration 46 Registry & Tracking
  int _selectedSubTab = 0;
  int? _selectedImportFileId;
  CustomsDeclarationAssessment? _clonedAssessment;

  bool _isFormDirty = false;

  String get _miss => context.l10n.idocBMissing;

  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() {
      _refreshData();
    });
  }

  @override
  void didUpdateWidget(CustomsDeclaration46Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(() => _selectedSubTab = widget.initialSubTab);
    }
    if (oldWidget.initialImportFileId != widget.initialImportFileId) {
      setState(() => _selectedImportFileId = widget.initialImportFileId);
    }
  }

  void _refreshData() {
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(customsClearanceProvider).isLoading) {
      ref.read(customsClearanceProvider.notifier).fetchRecords();
    }
    if (!ref.read(acidSessionsProvider).isLoading) {
      ref.read(acidSessionsProvider.notifier).fetchAcidSessions();
    }
    if (!ref.read(bankingDocumentsProvider).isLoading) {
      ref.read(bankingDocumentsProvider.notifier).fetchBankingDocuments();
    }
    if (!ref.read(customsTariffProvider).isLoading) {
      ref.read(customsTariffProvider.notifier).fetchTariffs();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
    if (!ref.read(draftBLReviewsProvider).isLoading) {
      ref.read(draftBLReviewsProvider.notifier).fetchReviews();
    }
    if (!ref.read(freightBookingProvider).isLoading) {
      ref.read(freightBookingProvider.notifier).fetchBookings();
    }
  }

  Future<void> _openSearchAndCloneDialog() async {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final acids = ref.read(acidSessionsProvider).valueOrNull ?? [];
    final bankDocs = ref.read(bankingDocumentsProvider).valueOrNull ?? [];
    final reviews = ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    final bookings = ref.read(freightBookingProvider).valueOrNull ?? [];
    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final pos = ref.read(purchaseOrdersProvider).purchaseOrders;
    final clearanceRecords = ref.read(customsClearanceProvider).valueOrNull ?? [];
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];

    final assessments = files.map((f) {
      final clearance = clearanceRecords.where((c) => c.importFileId == f.importFileId).firstOrNull;
      return CustomsDeclarationAssessmentHelper.calculateAssessment(
        f,
        context.l10n,
        declarationNo: clearance?.declaration46No ?? f.form46No ?? '',
        registrationDate: clearance?.declaration46Date ?? f.form46Date ?? '',
        status: clearance?.status ?? '',
        cachedAcids: acids,
        cachedBankDocs: bankDocs,
        cachedReviews: reviews,
        cachedBookings: bookings,
        cachedTariffs: tariffs,
        cachedPos: pos,
        cachedCurrencies: currencies,
      );
    }).toList();

    CustomsDeclarationAssessment? selected;
    await showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneCustomsDeclaration46Dialog(
        assessments: assessments,
        onSelectDeclaration: (decl) {
          selected = decl;
        },
      ),
    );

    if (selected != null && mounted) {
      _onCloneDeclarationSelected(selected!);
    }
  }

  void _onCloneDeclarationSelected(CustomsDeclarationAssessment a) {
    final isAr = context.l10n.isArabic;
    final l = context.l10n;

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: CloneEntityReviewDialog(
            entityType: l.idocBCloneDecl46Entity,
            sourceCode: a.declarationNo,
            sourceTitle: '${a.primaryNameWithCode} — ${a.supplierName}',
            suggestedNewCode: '46-DRAFT-${a.importFileCode}',
            copiedFieldsSummary: {
              l.idocBCloneFieldImportFile: a.primaryNameWithCode,
              l.idocBCloneFieldSupplier: a.supplierName,
              l.idocBCloneFieldCompany: a.companyName,
              l.idocBCloneFieldHsCode: '${a.hsCode} (${a.hsDescription})',
              l.idocBCloneFieldCif: a.cifEgp.egpOrMissing(_miss),
              l.idocBCloneFieldTotalDuties: a.totalDutiesEgp.egpOrMissing(_miss),
              l.idocBCloneFieldExemption: a.exemptionTitle,
            },
            mandatorilyResetFields: [
              l.idocBCloneReset1,
              l.idocBCloneReset2,
              l.idocBCloneReset3,
              l.idocBCloneReset4,
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
              setState(() {
                _clonedAssessment = a;
                _selectedSubTab = 0;
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  AppTheme.snackBar(context, context.l10n.cloneCustomsDeclSuccess),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.assignment_outlined,
        titleEn: 'Initial Declaration 46 Form',
        titleAr: 'قيد الإقرار الجمركي المبدئي',
      ),
      const VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'Declaration 46 Registry',
        titleAr: 'سجل شهادات 46 ومتابعتها',
      ),
    ];

    return SelectionArea(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): _openSearchAndCloneDialog,
        },
        child: Focus(
          autofocus: true,
          child: VerticalStageScaffold(
            isDirty: _selectedSubTab == 0 && _isFormDirty,
            onDiscard: () => setState(() => _isFormDirty = false),
            stageCode: 'PHASE-5: STEP_13',
            titleEn: 'Customs Declaration 46 Registration',
            titleAr: 'الإقرار الجمركي المبدئي وشهادة 46 ك.م',
            headerIcon: Icons.description_outlined,
            headerColor: AppTheme.cobalt,
            tabs: tabs,
            selectedIndex: _selectedSubTab,
            onTabSelected: (index) => setState(() => _selectedSubTab = index),
            selectedImportFileId: _selectedImportFileId,
            onShipmentStatusChanged: _refreshData,
            headerActions: [
              IconButton(
                key: const Key('searchAndCloneDeclHeaderBtn'),
                icon: Icon(Icons.copy_all, color: AppTheme.cloudWhite, size: density.buttonIconSize),
                tooltip: l.searchAndCloneCustomsDeclBtn,
                onPressed: _openSearchAndCloneDialog,
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: AppTheme.cloudWhite, size: density.buttonIconSize),
                tooltip: l.customsDeclRefreshTooltip,
                onPressed: _refreshData,
              ),
            ],
            body: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 92),
              child: _selectedSubTab == 0
                  ? CustomsDeclaration46FormTab(
                      initialImportFileId: _selectedImportFileId,
                      clonedAssessment: _clonedAssessment,
                      onDirtyChanged: (dirty) {
                        if (_isFormDirty != dirty && mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_isFormDirty != dirty && mounted) {
                              setState(() => _isFormDirty = dirty);
                            }
                          });
                        }
                      },
                      onSaved: () {
                        setState(() => _isFormDirty = false);
                        ref.invalidate(importFilesProvider);
                        setState(() {
                          _clonedAssessment = null;
                          _selectedSubTab = 1;
                        });
                        _refreshData();
                      },
                      onSwitchToRegistry: () => setState(() => _selectedSubTab = 1),
                      onOpenSearchAndClone: _openSearchAndCloneDialog,
                      onRefresh: _refreshData,
                    )
                  : CustomsDeclaration46RegistryTab(
                      onRegisterNew: () => setState(() {
                        _clonedAssessment = null;
                        _selectedSubTab = 0;
                      }),
                      onCloneDeclaration: _onCloneDeclarationSelected,
                      onOpenSearchAndClone: _openSearchAndCloneDialog,
                      onRefresh: _refreshData,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
