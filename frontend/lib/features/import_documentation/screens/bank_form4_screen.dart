import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/table_row_clone_helper.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import '../widgets/bank_form4_registry_tab.dart';
import '../widgets/bank_form4_request_tab.dart';
import '../widgets/search_and_clone_bank_form4_dialog.dart';

class BankForm4Screen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;

  const BankForm4Screen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
  });

  @override
  ConsumerState<BankForm4Screen> createState() => _BankForm4ScreenState();
}

class _BankForm4ScreenState extends ConsumerState<BankForm4Screen> {
  // Active Vertical Sub-Tab:
  // 0: 📝 طلب وتوثيق نموذج 4 (Form 4 Request & Checklist)
  // 1: 📋 سجل النماذج البنكية والتوثيق (Bank Form 4 Registry)
  int _selectedSubTab = 0;
  int? _form4ImportFileId;
  BankingDocumentModel? _editingDoc;

  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
    _form4ImportFileId = widget.initialImportFileId;
    Future.microtask(() {
      _refreshData();
    });
  }

  @override
  void didUpdateWidget(BankForm4Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(() => _selectedSubTab = widget.initialSubTab);
    }
    if (oldWidget.initialImportFileId != widget.initialImportFileId) {
      setState(() => _form4ImportFileId = widget.initialImportFileId);
    }
  }

  void _refreshData() {
    if (!ref.read(partnersProvider).isLoading) {
      ref.read(partnersProvider.notifier).fetchPartners();
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(bankingDocumentsProvider).isLoading) {
      ref.read(bankingDocumentsProvider.notifier).fetchBankingDocuments();
    }
    if (!ref.read(currenciesProvider).isLoading) {
      ref.read(currenciesProvider.notifier).fetchCurrencies();
    }
  }

  void _openSearchAndCloneBankForm4Dialog() {
    final bankingDocs = ref.read(bankingDocumentsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneBankForm4Dialog(
        bankingDocs: bankingDocs,
        onSelectDoc: _onCloneBankDocSelected,
      ),
    );
  }

  void _onCloneBankDocSelected(BankingDocumentModel doc) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: CloneEntityReviewDialog(
            entityType: context.l10n.idocBBankCloneEntity,
            sourceCode: doc.bankDocCode,
            sourceTitle: doc.bankName,
            suggestedNewCode: 'FORM4-2026-DRAFT',
            copiedFieldsSummary: {
              context.l10n.idocBBankCloneFieldBank: doc.bankName,
              context.l10n.idocBBankCloneFieldAmount: '${doc.amount.toStringAsFixed(2)} ${doc.currencyCode}',
              context.l10n.idocBCloneFieldImportFile: doc.importFileCode ?? (doc.importFileId != null ? 'IMP-${doc.importFileId}' : '-'),
              context.l10n.idocBBankCloneFieldNotes: doc.notes ?? '-',
            },
            mandatorilyResetFields: [
              context.l10n.idocBBankCloneReset1,
              context.l10n.idocBBankCloneReset2,
              context.l10n.idocBBankCloneReset3,
              context.l10n.idocBBankCloneReset4,
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
                _editingDoc = BankingDocumentModel(
                  bankDocId: 0,
                  bankDocCode: 'FORM4-2026-DRAFT',
                  docType: doc.docType,
                  importFileId: doc.importFileId,
                  poId: doc.poId,
                  bankId: doc.bankId,
                  bankName: doc.bankName,
                  docReferenceNumber: 'PENDING',
                  amount: doc.amount,
                  currencyCode: doc.currencyCode,
                  requestDate: DateTime.now().toIso8601String().substring(0, 10),
                  issueDate: DateTime.now().toIso8601String().substring(0, 10),
                  status: 'Draft',
                  notes: (doc.notes != null && doc.notes!.isNotEmpty)
                      ? '${doc.notes}${TableRowCloneHelper.copySuffix}'
                      : '(Cloned from previous doc)',
                  isActive: true,
                  createdAt: DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                );
                _form4ImportFileId = doc.importFileId;
                _selectedSubTab = 0;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  AppTheme.snackBar(context, context.l10n.cloneBankForm4Success),
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
    final density = ref.watch(displayDensityProvider);
    final bankingDocs = ref.watch(bankingDocumentsProvider).valueOrNull ?? [];

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.note_add_outlined,
        titleEn: 'Form 4 Request & Checklist',
        titleAr: 'طلب وتوثيق نموذج 4',
      ),
      VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'Bank Form 4 Registry',
        titleAr: 'سجل النماذج البنكية',
        badge: bankingDocs.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.wcagCobalt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${bankingDocs.length}',
                  style: TextStyle(
                    color: AppTheme.wcagCobalt,
                    fontSize: DisplayDensityMode.clampFontSize(11.0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    ];

    return SelectionArea(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): _openSearchAndCloneBankForm4Dialog,
        },
        child: Focus(
          autofocus: true,
          child: VerticalStageScaffold(
            stageCode: 'PHASE-4: STEP_12',
            titleEn: 'Bank Form 4 & Financial Endorsement',
            titleAr: 'المستندات والتوثيق البنكي ونموذج 4',
            headerIcon: Icons.account_balance_outlined,
            headerColor: AppTheme.wcagCobalt,
            tabs: tabs,
            selectedIndex: _selectedSubTab,
            onTabSelected: (index) {
              setState(() => _selectedSubTab = index);
              if (index == 1) {
                ref.read(bankingDocumentsProvider.notifier).fetchBankingDocuments();
              }
            },
            selectedImportFileId: _form4ImportFileId,
            onShipmentStatusChanged: _refreshData,
            headerActions: [
              IconButton(
                key: const Key('searchAndCloneBankForm4Btn'),
                icon: Icon(Icons.copy_all, color: AppTheme.cloudWhite, size: density.buttonIconSize),
                tooltip: context.l10n.searchAndCloneBankForm4Btn,
                onPressed: _openSearchAndCloneBankForm4Dialog,
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: AppTheme.cloudWhite, size: density.buttonIconSize),
                tooltip: context.l10n.refresh,
                onPressed: _refreshData,
              ),
            ],
            body: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 92),
              child: _selectedSubTab == 0
                  ? BankForm4RequestTab(
                      initialImportFileId: _form4ImportFileId,
                      editingDoc: _editingDoc,
                      onCancelEdit: () => setState(() => _editingDoc = null),
                      onSwitchToRegistry: () => setState(() {
                        _editingDoc = null;
                        _selectedSubTab = 1;
                      }),
                      onOpenSearchAndClone: _openSearchAndCloneBankForm4Dialog,
                      onRefresh: _refreshData,
                    )
                  : BankForm4RegistryTab(
                      onNewDoc: () => setState(() {
                        _editingDoc = null;
                        _selectedSubTab = 0;
                      }),
                      onOpenSearchAndClone: _openSearchAndCloneBankForm4Dialog,
                      onEditDoc: (doc) => setState(() {
                        _editingDoc = doc;
                        _selectedSubTab = 0;
                      }),
                      onCloneDoc: (doc) => _onCloneBankDocSelected(doc),
                      onRefresh: _refreshData,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
