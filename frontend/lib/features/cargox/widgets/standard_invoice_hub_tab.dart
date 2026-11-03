import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_tab_scaffold.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/cargox_model.dart';
import '../providers/cargox_provider.dart';
import 'standard_invoice_hub/invoice_hub_actions_bar.dart';
import 'standard_invoice_hub/invoice_hub_customs_tracks_view.dart';
import 'standard_invoice_hub/invoice_hub_extraction_dialog.dart';
import 'standard_invoice_hub/invoice_hub_formatters.dart';
import 'standard_invoice_hub/invoice_hub_governance_tab.dart';
import 'standard_invoice_hub/invoice_hub_header_bar.dart';
import 'standard_invoice_hub/invoice_hub_items_table.dart';
import 'standard_invoice_hub/invoice_hub_reconciliation_section.dart';
import 'standard_invoice_hub/invoice_hub_registry_view.dart';

/// 🎯 StandardInvoiceHubTab Coordinator
/// Radical decomposition conforming to Enterprise Clean Architecture:
/// - Universal SelectionArea at root
/// - Zero parenthesized bilingual stacking (pure l10n separation)
/// - Sub-components decoupled into `standard_invoice_hub/`
/// - Strict adherence to canonical design system components (< 400 lines)
class StandardInvoiceHubTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const StandardInvoiceHubTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<StandardInvoiceHubTab> createState() => _StandardInvoiceHubTabState();
}

class _StandardInvoiceHubTabState extends ConsumerState<StandardInvoiceHubTab> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _subTabController;

  ImportFileModel? _selectedImportFile;
  StandardInvoiceSessionModel? _existingSession;
  StandardInvoicePayloadModel? _supplierData;
  StandardInvoiceComparisonResponseModel? _comparisonResult;
  List<CustomsInvoiceTrackModel> _customsTracks = [];

  bool _isLoading = false;
  final bool _isDownloading = false;
  bool _isParsing = false;
  bool _isSaving = false;

  String _selectedStatus = 'UNDER_REVIEW';
  final TextEditingController _overrideReasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 5, vsync: this);
    Future.microtask(() {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(standardInvoiceSessionsProvider.notifier).fetchSessions();
      if (widget.initialImportFileId != null) {
        _loadInitialFile(widget.initialImportFileId!);
      }
    });
  }

  @override
  void dispose() {
    _subTabController.dispose();
    _overrideReasonController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialFile(int fileId) async {
    final filesAsync = ref.read(importFilesProvider);
    filesAsync.whenData((files) {
      final match = files.where((f) => f.importFileId == fileId).firstOrNull;
      if (match != null) _onSelectImportFile(match);
    });
  }

  Future<void> _onSelectImportFile(ImportFileModel file) async {
    setState(() {
      _selectedImportFile = file;
      _existingSession = null;
      _supplierData = null;
      _comparisonResult = null;
      _customsTracks = [];
      _overrideReasonController.clear();
      _notesController.clear();
      _isLoading = true;
    });

    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final session = await notifier.fetchSessionByFile(file.importFileId);
      final tracks = await notifier.fetchCustomsTracks(file.importFileId);
      if (mounted) {
        setState(() {
          _existingSession = session;
          _customsTracks = tracks;
          if (session != null) {
            _selectedStatus = session.status;
            _overrideReasonController.text = session.discrepancyOverrideReason ?? '';
            _notesController.text = session.notes ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDownloadTemplate() async {
    if (_selectedImportFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.standardInvoiceSelectFileFirstError, severity: AppSeverity.danger),
      );
      return;
    }

    await InvoiceHubExtractionDialog.show(
      context: context,
      file: _selectedImportFile!,
      onCustomsTrackCreated: (track) async {
        final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
        final tracks = await notifier.fetchCustomsTracks(widget.initialImportFileId ?? _selectedImportFile!.importFileId);
        if (mounted) {
          setState(() => _customsTracks = tracks);
          _subTabController.animateTo(4);
        }
      },
    );
  }

  Future<void> _handlePickAndParseExcel() async {
    if (_selectedImportFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.standardInvoiceSelectFileFirstError, severity: AppSeverity.danger),
      );
      return;
    }

    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isParsing = true);
      try {
        final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
        final parsed = await notifier.parseExcelFile(file.bytes!, file.name);
        if (!mounted) return;
        setState(() {
          _supplierData = parsed;
          _isParsing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.standardInvoiceExtractedSuccess(parsed.invoiceNumber ?? parsed.invoiceType, parsed.items.length)),
            backgroundColor: AppTheme.emerald,
          ),
        );
        await _handleRunComparison();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isParsing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.errorPrefix}: $e'), backgroundColor: AppTheme.crimson),
        );
      }
    }
  }

  Future<void> _handleRunComparison() async {
    if (_selectedImportFile == null || _supplierData == null) return;

    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final comp = await notifier.compareInvoice(_selectedImportFile!.importFileId, _supplierData!);
      if (!mounted) return;
      setState(() => _comparisonResult = comp);
      _subTabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.errorPrefix}: $e'), backgroundColor: AppTheme.crimson),
      );
    }
  }

  Future<void> _handleSaveSession({bool isDraft = false}) async {
    if (_selectedImportFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.standardInvoiceSelectFileFirstError, severity: AppSeverity.danger),
      );
      return;
    }

    final saveStatus = isDraft ? 'DRAFT' : _selectedStatus;
    final hasIssues = (_comparisonResult?.hasDiscrepancies ?? false) || (_comparisonResult?.hasCriticalMismatch ?? false);
    if (!isDraft && saveStatus == 'APPROVED' && hasIssues && _overrideReasonController.text.trim().isEmpty) {
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.standardInvoiceMustProvideOverrideJustification),
          backgroundColor: AppTheme.crimson,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      final payload = buildStandardInvoiceSessionPayload(
        file: _selectedImportFile!,
        supplierData: _supplierData,
        comparisonResult: _comparisonResult,
        status: saveStatus,
        overrideReason: _overrideReasonController.text,
        notes: _notesController.text,
      );

      final saved = await notifier.saveOrUpsertSession(payload);
      if (!mounted) return;
      setState(() {
        _existingSession = saved;
        if (isDraft) _selectedStatus = 'DRAFT';
        _isSaving = false;
      });

      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final msg = isDraft
          ? (isAr ? 'تم حفظ مسودة جلسة مراجعة الفاتورة بنجاح (${saved.sessionCode})' : 'Invoice draft session saved successfully (${saved.sessionCode})')
          : context.l10n.standardInvoiceSessionSavedSuccess(saved.sessionCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: isDraft ? AppTheme.cobalt : AppTheme.emerald),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.errorPrefix}: ${extractInvoiceHubErrorMessage(e)}'), backgroundColor: AppTheme.crimson),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(importFilesProvider);
    final sessionsAsync = ref.watch(standardInvoiceSessionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InvoiceHubHeaderBar(
                  selectedImportFile: _selectedImportFile,
                  existingSession: _existingSession,
                  filesAsync: filesAsync,
                  onSelectImportFile: _onSelectImportFile,
                  onRefresh: () {
                    ref.invalidate(importFilesProvider);
                    ref.read(importFilesProvider.notifier).fetchImportFiles();
                    ref.read(standardInvoiceSessionsProvider.notifier).fetchSessions();
                  },
                  onViewExistingSession: () {
                    if (_existingSession != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.standardInvoiceSessionLoadedToast(_existingSession!.sessionCode))),
                      );
                    }
                  },
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 20),
                InvoiceHubActionsBar(
                  isDownloading: _isDownloading,
                  isParsing: _isParsing,
                  onDownloadTemplate: _handleDownloadTemplate,
                  onPickAndParseExcel: _handlePickAndParseExcel,
                ),
                const SizedBox(height: 20),
                AdaptiveTabScaffold(
                  controller: _subTabController,
                  accentColor: AppTheme.emerald,
                  tabs: _buildTabItems(sessionsAsync),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AdaptiveTabItem> _buildTabItems(AsyncValue<List<StandardInvoiceSessionModel>> sessionsAsync) {
    final l10n = context.l10n;

    return [
      AdaptiveTabItem(
        icon: Icons.visibility,
        label: l10n.standardInvoiceTabExtracted,
        content: InvoiceHubItemsTable(supplierData: _supplierData),
      ),
      AdaptiveTabItem(
        icon: Icons.compare_arrows,
        label: l10n.standardInvoiceTabComparison,
        content: InvoiceHubReconciliationSection(comparisonResult: _comparisonResult),
      ),
      AdaptiveTabItem(
        icon: Icons.gavel,
        label: l10n.standardInvoiceTabGovernance,
        content: InvoiceHubGovernanceTab(
          selectedStatus: _selectedStatus,
          onStatusChanged: (val) => setState(() => _selectedStatus = val),
          overrideReasonController: _overrideReasonController,
          notesController: _notesController,
          hasIssues: (_comparisonResult?.hasDiscrepancies ?? false) || (_comparisonResult?.hasCriticalMismatch ?? false),
          isSaving: _isSaving,
          onSaveSession: _handleSaveSession,
        ),
      ),
      AdaptiveTabItem(
        icon: Icons.history,
        label: l10n.standardInvoiceTabRegistry,
        content: InvoiceHubRegistryView(
          sessionsAsync: sessionsAsync,
          searchController: _searchController,
          filterStatus: _filterStatus,
          onFilterChanged: (v) {
            setState(() => _filterStatus = v);
            ref.read(standardInvoiceSessionsProvider.notifier).fetchSessions(search: _searchController.text, status: v);
          },
          onSearchChanged: (v) => ref.read(standardInvoiceSessionsProvider.notifier).fetchSessions(search: v, status: _filterStatus),
        ),
      ),
      AdaptiveTabItem(
        icon: Icons.account_balance,
        label: l10n.standardInvoiceTabCustomsTracks,
        badge: _customsTracks.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.emerald, borderRadius: BorderRadius.circular(10)),
                child: Text('${_customsTracks.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            : null,
        content: InvoiceHubCustomsTracksView(
          selectedImportFile: _selectedImportFile,
          customsTracks: _customsTracks,
          onOpenExtractionDialog: _handleDownloadTemplate,
          onTracksUpdated: (tracks) {
            if (mounted) setState(() => _customsTracks = tracks);
          },
        ),
      ),
    ];
  }
}
