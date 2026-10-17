import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/original_documents_collection_model.dart';
import '../providers/original_documents_collection_provider.dart';
import '../services/original_docs_export_service.dart';
import 'idoc_feedback.dart';
import '../../../core/localization/stored_text.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/metric_card.dart';
import 'idoc_ui.dart';

String _formatDateTime(DateTime dt) {
  final str = dt.toIso8601String();
  if (str.length >= 16) {
    return str.substring(0, 16).replaceAll('T', ' ');
  }
  return str;
}

class OriginalDocumentsCollectionTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const OriginalDocumentsCollectionTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<OriginalDocumentsCollectionTab> createState() =>
      _OriginalDocumentsCollectionTabState();
}

class _OriginalDocumentsCollectionTabState
    extends ConsumerState<OriginalDocumentsCollectionTab> {
  final _formKey = GlobalKey<FormState>();

  ImportFileModel? _selectedImportFile;
  OriginalDocumentsCollectionSessionModel? _existingSession;

  List<CourierEntryModel> _couriers = [];
  List<OriginalDocumentItemModel> _documents = [];

  bool _isLoading = false;
  bool _isSaving = false;

  String _sessionStatus = 'DRAFT';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _overrideReasonController = TextEditingController();
  final TextEditingController _registrySearchController = TextEditingController();
  String _registryStatusFilter = 'All';

  int _registryTabMode = 0; // 0 = Sessions, 1 = Courier Tracking
  final TextEditingController _courierSearchController = TextEditingController();
  String _courierStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(originalDocumentsSessionsProvider).isLoading) {
        ref.read(originalDocumentsSessionsProvider.notifier).fetchSessions();
      }
      ref.invalidate(courierAlertsProvider);
      ref.invalidate(allCouriersProvider);
      if (widget.initialImportFileId != null) {
        _loadInitialFile(widget.initialImportFileId!);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _overrideReasonController.dispose();
    _registrySearchController.dispose();
    _courierSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialFile(int fileId) async {
    final filesAsync = ref.read(importFilesProvider);
    filesAsync.whenData((files) {
      final match = files.where((f) => f.importFileId == fileId).firstOrNull;
      if (match != null) {
        _onSelectImportFile(match);
      }
    });
  }

  Future<void> _onSelectImportFile(ImportFileModel file) async {
    final l = context.l10n;
    setState(() {
      _selectedImportFile = file;
      _existingSession = null;
      _couriers = [];
      _documents = [];
      _notesController.clear();
      _overrideReasonController.clear();
      _isLoading = true;
    });

    try {
      final notifier = ref.read(originalDocumentsSessionsProvider.notifier);
      final autoData = await notifier.fetchAutoPopulate(file.importFileId);

      if (!mounted) return;
      setState(() {
        if (autoData.existingSession != null) {
          _existingSession = autoData.existingSession;
          _couriers = List.from(autoData.existingSession!.couriersList);
          _documents = List.from(autoData.existingSession!.documentsList);
          _sessionStatus = autoData.existingSession!.status;
          _notesController.text = autoData.existingSession!.notes ?? '';
          _overrideReasonController.text =
              autoData.existingSession!.discrepancyOverrideReason ?? '';
        } else {
          _couriers = List.from(autoData.defaultCouriers);
          _documents = List.from(autoData.requiredDocuments);
          _sessionStatus = 'DRAFT';
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.errorFetchingArchiveData(ApiErrorText.of(l, e))), backgroundColor: AppTheme.crimson),
      );
    }
  }

  void _addCourier() {
    setState(() {
      _couriers.add(
        CourierEntryModel(
          courierNo: '',
          courierCompany: '',
          dispatchDate: DateTime.now().toIso8601String().substring(0, 10),
          isReceived: false,
        ),
      );
    });
  }

  void _removeCourier(int index) {
    setState(() {
      _couriers.removeAt(index);
    });
  }

  void _addCustomDocument() {
    setState(() {
      _documents.add(
        OriginalDocumentItemModel(
          category: 'Commercial',
          documentName: storedText.defaultNewCustomDocName,
          isRequired: 'Yes',
          responsibleParty: 'Supplier',
          status: 'Pending',
        ),
      );
    });
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  Future<void> _handleSaveSession({bool isConfirmComplete = false}) async {
    final l = context.l10n;
    if (_selectedImportFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.selectImportFileFirstWarning), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    if (isConfirmComplete) {
      final unverified = _documents.where((d) => !d.isVerified && d.isRequired == 'Yes').toList();
      if (unverified.isNotEmpty && _overrideReasonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.unverifiedMandatoryDocsWarning),
            backgroundColor: AppTheme.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(originalDocumentsSessionsProvider.notifier);
      final payload = {
        'import_file_id': _selectedImportFile!.importFileId,
        'import_file_code': _selectedImportFile!.importFileCode,
        'acid_number': _selectedImportFile!.acidNumber,
        'importer_name': _selectedImportFile!.companyName,
        'supplier_name': _selectedImportFile!.supplierName,
        'status': isConfirmComplete ? 'FULLY_VERIFIED' : _sessionStatus,
        'couriers_list': _couriers.map((c) => c.toJson()).toList(),
        'documents_list': _documents.map((d) => d.toJson()).toList(),
        'discrepancy_override_reason': _overrideReasonController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      final saved = await notifier.saveOrUpsertSession(payload);
      if (!mounted) return;
      setState(() {
        _existingSession = saved;
        _sessionStatus = saved.status;
        _isSaving = false;
      });

      ref.invalidate(courierAlertsProvider);
      ref.invalidate(allCouriersProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.sessionSavedSuccess(saved.collectionCode)),
          backgroundColor: AppTheme.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.sessionSaveError(ApiErrorText.of(l, e))), backgroundColor: AppTheme.crimson),
      );
    }
  }

  String _getDocCategoryLabel(String category, AppLocalizations l) {
    switch (category) {
      case 'Commercial':
        return l.docCatCommercial;
      case 'Certificate':
        return l.docCatCertificate;
      case 'Shipping':
        return l.docCatShipping;
      case 'Egypt Import':
        return l.docCatEgyptImport;
      case 'Banking':
        return l.docCatBanking;
      case 'Regulatory':
        return l.docCatRegulatory;
      case 'Other':
        return l.docCatOther;
      default:
        return category;
    }
  }

  String _getCourierCompanyLabel(String company, AppLocalizations l) {
    switch (company) {
      case 'DHL':
        return l.courierCompanyDhl;
      case 'FedEx':
        return l.courierCompanyFedex;
      case 'Aramex':
        return l.courierCompanyAramex;
      case 'UPS':
        return l.courierCompanyUps;
      case 'Naqel':
        return l.courierCompanyNaqel;
      case 'SMSA':
        return l.courierCompanySmsa;
      case 'Hand Delivery':
        return l.courierCompanyHandDelivery;
      case 'Other':
        return l.courierCompanyOther;
      default:
        return company;
    }
  }

  String _getResponsiblePartyLabel(String party, AppLocalizations l) {
    switch (party) {
      case 'Supplier':
        return l.partySupplier;
      case 'Freight Forwarder':
        return l.partyFreightForwarder;
      case 'Customs Broker':
        return l.partyCustomsBroker;
      case 'Bank':
        return l.partyBank;
      case 'Importer':
        return l.partyImporter;
      case 'Carrier':
      case 'Shipping Line':
        return l.partyCarrier;
      default:
        return party;
    }
  }

  String _getStatusLabel(String status, AppLocalizations l) {
    switch (status) {
      case 'Verified':
        return l.statusBadgeVerified;
      case 'Received':
        return l.statusBadgeReceived;
      case 'In Transit':
        return l.statusBadgeInTransit;
      case 'Discrepant':
        return l.statusBadgeDiscrepant;
      case 'DRAFT':
        return l.filterStatusDraft;
      case 'PARTIALLY_RECEIVED':
        return l.filterStatusPartiallyReceived;
      case 'FULLY_RECEIVED':
        return l.filterStatusFullyReceived;
      case 'FULLY_VERIFIED':
        return l.filterStatusFullyVerified;
      case 'Pending':
      default:
        return l.statusBadgePending;
    }
  }

  String _getRegistryStatusFilterLabel(String filter, AppLocalizations l) {
    switch (filter) {
      case 'All':
        return l.filterStatusAll;
      case 'DRAFT':
        return l.filterStatusDraft;
      case 'PARTIALLY_RECEIVED':
        return l.filterStatusPartiallyReceived;
      case 'FULLY_RECEIVED':
        return l.filterStatusFullyReceived;
      case 'FULLY_VERIFIED':
        return l.filterStatusFullyVerified;
      default:
        return filter;
    }
  }

  String _getRequirementLabel(String req, AppLocalizations l) {
    switch (req) {
      case 'Yes':
        return l.reqBadgeYes;
      case 'Conditional':
        return l.reqBadgeConditional;
      case 'No':
      default:
        return l.reqBadgeNo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filesAsync = ref.watch(importFilesProvider);
    final sessionsAsync = ref.watch(originalDocumentsSessionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.cloudWhite,
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(l),
                if (_isLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                _buildFileSelector(l, filesAsync),
                if (_selectedImportFile != null) ...[
                  const SizedBox(height: 16),
                  _buildStatisticsCards(l),
                  const SizedBox(height: 16),
                  _buildCouriersManagementCard(l),
                  const SizedBox(height: 16),
                  _buildDocumentsCollectionGrid(l),
                  const SizedBox(height: 16),
                  _buildSessionNotesCard(l),
                  const SizedBox(height: 16),
                  _buildActionToolbar(l),
                ],
                const SizedBox(height: 24),
                _buildCourierAlertsBanner(l),
                const SizedBox(height: 16),
                _buildRegistrySection(l, sessionsAsync),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: AppTheme.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.markunread_mailbox_outlined, color: AppTheme.cobalt, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.originalDocsHubTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                ),
                const SizedBox(height: 4),
                Text(
                  l.originalDocsHubSubtitle,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ),
          if (_existingSession != null)
            InkWell(
              onTap: () => CopyHelper.copy(
                context,
                _existingSession!.collectionCode,
                customMessage: l.originalDocsCopyRowSuccess,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.emerald),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l.savedSessionBadge(_existingSession!.collectionCode),
                      style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy, size: 14, color: AppTheme.emerald),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileSelector(AppLocalizations l, AsyncValue<List<ImportFileModel>> filesAsync) {
    final acidLabel = context.l10n.idocAACID;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: AppTheme.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: filesAsync.when(
        data: (files) {
          return Row(
            children: [
              Expanded(
                child: SearchableDropdownField<int>(
                  labelText: l.selectImportFileLabel,
                  hintText: l.selectImportFileHint,
                  value: _selectedImportFile?.importFileId,
                  items: files
                      .map((f) => SearchableDropdownItem<int>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} — ${f.supplierName} (${f.companyName}) [$acidLabel: ${f.acidNumber ?? "—"}]',
                            searchValue: '${f.primaryNameWithCode} ${f.supplierName} ${f.companyName} ${f.acidNumber ?? ""}',
                          ))
                      .toList(),
                  onChanged: (fileId) {
                    if (fileId != null) {
                      final match = files.where((f) => f.importFileId == fileId).firstOrNull;
                      if (match != null) _onSelectImportFile(match);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              IdocUi.fit(AppButton(
                label: l.refreshDataTooltip,
                icon: Icons.refresh,
                variant: AppButtonVariant.primary,
                onPressed: () => ref.read(importFilesProvider.notifier).fetchImportFiles(),
              )),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(l.errorFetchingImportFiles(e), style: const TextStyle(color: AppTheme.crimson)),
      ),
    );
  }

  Widget _buildStatisticsCards(AppLocalizations l) {
    final totalDocs = _documents.length;
    final receivedDocs = _documents.where((d) => d.isReceived).length;
    final verifiedDocs = _documents.where((d) => d.isVerified).length;
    final pendingDocs = totalDocs - receivedDocs;
    final completionPct = totalDocs > 0 ? (verifiedDocs / totalDocs * 100).toStringAsFixed(1) : '0.0';

    MetricCardData metric(String label, String value, IconData icon, Color color) => MetricCardData(
          title: label,
          shortTitle: label,
          value: value,
          icon: icon,
          color: color,
        );

    return IdocUi.metrics([
      metric(l.statTotalRequiredDocs, '$totalDocs', Icons.description_outlined, AppTheme.charcoal),
      metric(l.statReceivedOriginals, '$receivedDocs', Icons.inbox_outlined, AppTheme.cobalt),
      metric(l.statVerifiedDocs, '$verifiedDocs', Icons.verified_outlined, AppTheme.emerald),
      metric(l.statPendingDocs, '$pendingDocs', Icons.hourglass_empty_outlined, AppTheme.orange),
      metric(l.statReadinessRate, '$completionPct%', Icons.pie_chart_outline, AppTheme.wcagCobalt),
    ]);
  }

  Widget _buildCouriersManagementCard(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: AppTheme.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: AppTheme.cobalt, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l.courierDispatchPackagesHeader,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
                  ),
                ],
              ),
              IdocUi.fit(AppButton(
                label: l.addCourierAwbBtn,
                icon: Icons.add,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: _addCourier,
              )),
            ],
          ),
          const SizedBox(height: 12),
          if (_couriers.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(l.noCouriersRegisteredMsg,
                  style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _couriers.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, idx) {
                final c = _couriers[idx];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.cobalt.withValues(alpha: 0.15),
                      child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: c.courierNo,
                        decoration: InputDecoration(
                          labelText: l.courierTrackingNoField,
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                            tooltip: l.originalDocsCopyRowSuccess,
                            onPressed: c.courierNo.isNotEmpty
                                ? () => CopyHelper.copy(context, c.courierNo, customMessage: l.originalDocsCopyRowSuccess)
                                : null,
                          ),
                        ),
                        onChanged: (val) => c.courierNo = val.trim(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        value: ['DHL', 'FedEx', 'Aramex', 'UPS', 'Naqel', 'SMSA', 'Hand Delivery', 'Other'].contains(c.courierCompany)
                            ? c.courierCompany
                            : null,
                        labelText: l.courierCompanyField,
                        decoration: InputDecoration(
                          labelText: l.courierCompanyField,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        items: ['DHL', 'FedEx', 'Aramex', 'UPS', 'Naqel', 'SMSA', 'Hand Delivery', 'Other']
                            .map((company) => SearchableDropdownItem<String>(
                                  value: company,
                                  label: _getCourierCompanyLabel(company, l),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => c.courierCompany = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: c.dispatchDate,
                        decoration: InputDecoration(
                          labelText: l.dispatchDateField,
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                            tooltip: l.originalDocsCopyRowSuccess,
                            onPressed: (c.dispatchDate != null && c.dispatchDate!.isNotEmpty)
                                ? () => CopyHelper.copy(context, c.dispatchDate!, customMessage: l.originalDocsCopyRowSuccess)
                                : null,
                          ),
                        ),
                        onChanged: (val) => c.dispatchDate = val.trim(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: c.isReceived,
                          activeColor: AppTheme.emerald,
                          onChanged: (val) {
                            setState(() {
                              c.isReceived = val ?? false;
                              if (c.isReceived && (c.receivedDate == null || c.receivedDate!.isEmpty)) {
                                c.receivedDate = DateTime.now().toIso8601String().substring(0, 10);
                              }
                            });
                          },
                        ),
                        Text(l.isReceivedCheckbox, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: c.receivedBy,
                        decoration: InputDecoration(
                          labelText: l.receivedByNameField,
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                            tooltip: l.originalDocsCopyRowSuccess,
                            onPressed: (c.receivedBy != null && c.receivedBy!.isNotEmpty)
                                ? () => CopyHelper.copy(context, c.receivedBy!, customMessage: l.originalDocsCopyRowSuccess)
                                : null,
                          ),
                        ),
                        onChanged: (val) => c.receivedBy = val.trim(),
                      ),
                    ),
                    if (c.courierNo.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18, color: AppTheme.cobalt),
                        tooltip: context.l10n.idocATrackTheCourierDirectlyOnThe,
                        onPressed: () => OriginalDocsExportService.launchCarrierTracking(c.courierCompany, c.courierNo),
                      ),
                      IconButton(
                        icon: Icon(
                          c.isReceived ? Icons.verified : Icons.verified_outlined,
                          size: 18,
                          color: AppTheme.emerald,
                        ),
                        tooltip: l.confirmCourierDeliveryBtn,
                        onPressed: () => _showCourierDeliveryProofDialog(
                          importFileId: _selectedImportFile!.importFileId,
                          courierNo: c.courierNo,
                          courierCompany: c.courierCompany,
                          trackingNo: c.courierNo,
                          importFileCode: _selectedImportFile!.importFileCode,
                        ),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                      tooltip: l.deleteCourierTooltip,
                      onPressed: () => _removeCourier(idx),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCollectionGrid(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: AppTheme.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_view_outlined, color: AppTheme.emerald, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l.physicalDocsVerificationMatrixHeader,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
                  ),
                ],
              ),
              IdocUi.fit(AppButton(
                label: l.addCustomDocBtn,
                icon: Icons.add,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: _addCustomDocument,
              )),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
              headingTextStyle: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columns: [
                DataColumn(label: Text(l.colAction)),
                DataColumn(label: Text(l.colCourierNo)),
                DataColumn(label: Text(l.colDocCategory)),
                DataColumn(label: Text(l.colDocName)),
                DataColumn(label: Text(l.colRequirement)),
                DataColumn(label: Text(l.colResponsibleParty)),
                DataColumn(label: Text(l.colPhysicalReceived)),
                DataColumn(label: Text(l.colReceivedDate)),
                DataColumn(label: Text(l.colVerified)),
                DataColumn(label: Text(l.colAuditor)),
                DataColumn(label: Text(l.colDocStatus)),
                DataColumn(label: Text(l.colRemarks)),
              ],
              rows: List.generate(_documents.length, (index) {
                final doc = _documents[index];
                final rowSummary = '${doc.documentName} | ${_getDocCategoryLabel(doc.category, l)} | '
                    '${_getRequirementLabel(doc.isRequired, l)} | ${_getResponsiblePartyLabel(doc.responsibleParty, l)} | '
                    '${doc.courierNo ?? "—"} | ${_getStatusLabel(doc.status, l)} | '
                    '${l.colPhysicalReceived}: ${doc.isReceived ? "Yes" : "No"} (${doc.receivedDate ?? "—"}) | '
                    '${l.colVerified}: ${doc.isVerified ? "Yes" : "No"} (${doc.verificationDate ?? "—"} - ${doc.verifiedBy ?? "—"})';

                return DataRow(
                  cells: [
                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18, color: AppTheme.cobalt),
                            tooltip: l.originalDocsCopyRowSuccess,
                            onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.originalDocsCopyRowSuccess),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                            tooltip: l.colAction,
                            onPressed: () => _removeDocument(index),
                          ),
                        ],
                      ),
                    ),
                    // Courier No
                    DataCell(
                      CopyableTableCell(
                        value: doc.courierNo ?? '',
                        rowSummary: rowSummary,
                        child: SizedBox(
                          width: 140,
                          child: SearchableDropdownField<String>(
                            value: _couriers.any((c) => c.courierNo == doc.courierNo && c.courierNo.isNotEmpty)
                                ? doc.courierNo
                                : null,
                            labelText: l.selectCourierPlaceholder,
                            hintText: l.selectCourierPlaceholder,
                            decoration: const InputDecoration(border: InputBorder.none),
                            items: _couriers
                                .where((c) => c.courierNo.isNotEmpty)
                                .map((c) => SearchableDropdownItem<String>(value: c.courierNo, label: c.courierNo))
                                .toList(),
                            onChanged: (val) {
                              setState(() => doc.courierNo = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    // Category
                    DataCell(
                      CopyableTableCell(
                        value: _getDocCategoryLabel(doc.category, l),
                        rowSummary: rowSummary,
                        child: SizedBox(
                          width: 110,
                          child: SearchableDropdownField<String>(
                            value: doc.category,
                            labelText: l.colCategory,
                            decoration: const InputDecoration(border: InputBorder.none),
                            items: ['Commercial', 'Certificate', 'Shipping', 'Egypt Import', 'Banking', 'Regulatory', 'Other']
                                .map((cat) => SearchableDropdownItem<String>(
                                      value: cat,
                                      label: _getDocCategoryLabel(cat, l),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => doc.category = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    // Document Name
                    DataCell(
                      CopyableTableCell(
                        value: doc.documentName,
                        rowSummary: rowSummary,
                        child: SizedBox(
                          width: 170,
                          child: TextFormField(
                            initialValue: doc.documentName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                                tooltip: l.originalDocsCopyRowSuccess,
                                onPressed: doc.documentName.isNotEmpty
                                    ? () => CopyHelper.copy(context, doc.documentName, customMessage: l.originalDocsCopyRowSuccess)
                                    : null,
                              ),
                            ),
                            onChanged: (val) => doc.documentName = val.trim(),
                          ),
                        ),
                      ),
                    ),
                    // Required
                    DataCell(
                      CopyableTableCell(
                        value: _getRequirementLabel(doc.isRequired, l),
                        rowSummary: rowSummary,
                        child: _buildRequiredBadge(doc.isRequired, l),
                      ),
                    ),
                    // Responsible Party
                    DataCell(
                      CopyableTableCell(
                        value: _getResponsiblePartyLabel(doc.responsibleParty, l),
                        rowSummary: rowSummary,
                        child: Text(_getResponsiblePartyLabel(doc.responsibleParty, l), style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    // Received Checkbox
                    DataCell(
                      CopyableTableCell(
                        value: doc.isReceived ? 'Yes' : 'No',
                        rowSummary: rowSummary,
                        child: Checkbox(
                          value: doc.isReceived,
                          activeColor: AppTheme.cobalt,
                          onChanged: (val) {
                            setState(() {
                              doc.isReceived = val ?? false;
                              if (doc.isReceived && (doc.receivedDate == null || doc.receivedDate!.isEmpty)) {
                                doc.receivedDate = DateTime.now().toIso8601String().substring(0, 10);
                              }
                              if (doc.isReceived && doc.status == 'Pending') {
                                doc.status = 'Received';
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    // Received Date
                    DataCell(
                      CopyableTableCell(
                        value: doc.receivedDate ?? '',
                        rowSummary: rowSummary,
                        child: SizedBox(
                          width: 100,
                          child: TextFormField(
                            initialValue: doc.receivedDate,
                            style: const TextStyle(fontSize: 11),
                            decoration: const InputDecoration(hintText: 'YYYY-MM-DD', border: InputBorder.none),
                            onChanged: (val) => doc.receivedDate = val.trim(),
                          ),
                        ),
                      ),
                    ),
                    // Verified Checkbox
                    DataCell(
                      CopyableTableCell(
                        value: doc.isVerified ? 'Yes' : 'No',
                        rowSummary: rowSummary,
                        child: Checkbox(
                          value: doc.isVerified,
                          activeColor: AppTheme.emerald,
                          onChanged: (val) {
                            setState(() {
                              doc.isVerified = val ?? false;
                              if (doc.isVerified) {
                                doc.isReceived = true;
                                doc.status = 'Verified';
                                if (doc.verificationDate == null || doc.verificationDate!.isEmpty) {
                                  doc.verificationDate = DateTime.now().toIso8601String().substring(0, 10);
                                }
                                if (doc.verifiedBy == null || doc.verifiedBy!.isEmpty) {
                                  doc.verifiedBy = idocCurrentUserName(ref);
                                }
                              } else {
                                doc.status = doc.isReceived ? 'Received' : 'Pending';
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    // Verified By
                    DataCell(
                      CopyableTableCell(
                        value: doc.verifiedBy ?? '',
                        rowSummary: rowSummary,
                        child: SizedBox(
                          width: 100,
                          child: TextFormField(
                            initialValue: doc.verifiedBy,
                            style: const TextStyle(fontSize: 11),
                            decoration: InputDecoration(hintText: l.hintAuditor, border: InputBorder.none),
                            onChanged: (val) => doc.verifiedBy = val.trim(),
                          ),
                        ),
                      ),
                    ),
                    // Status Badge
                    DataCell(
                      CopyableTableCell(
                        value: _getStatusLabel(doc.status, l),
                        rowSummary: rowSummary,
                        child: _buildStatusBadge(doc.status, l),
                      ),
                    ),
                    // Remarks
                    DataCell(
                      CopyableTableCell(
                        value: doc.remarks ?? '',
                        rowSummary: rowSummary,
                        child: SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue: doc.remarks,
                            style: const TextStyle(fontSize: 11),
                            decoration: InputDecoration(hintText: l.hintRemarks, border: InputBorder.none),
                            onChanged: (val) => doc.remarks = val.trim(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionNotesCard(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: AppTheme.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l.sessionNotesLabel,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy, size: 18, color: AppTheme.cobalt),
                tooltip: l.originalDocsCopyRowSuccess,
                onPressed: () {
                  if (_notesController.text.trim().isNotEmpty) {
                    CopyHelper.copy(context, _notesController.text.trim(), customMessage: l.originalDocsCopyRowSuccess);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _overrideReasonController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l.overrideReasonLabel,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy, size: 18, color: AppTheme.cobalt),
                tooltip: l.originalDocsCopyRowSuccess,
                onPressed: () {
                  if (_overrideReasonController.text.trim().isNotEmpty) {
                    CopyHelper.copy(context, _overrideReasonController.text.trim(), customMessage: l.originalDocsCopyRowSuccess);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequiredBadge(String req, AppLocalizations l) {
    Color bg = AppTheme.borderOf(context);
    Color fg = AppTheme.textPrimaryOf(context);
    String label = l.reqBadgeNo;
    if (req == 'Yes') {
      bg = AppTheme.severityBackgroundOf(context, AppSeverity.danger);
      fg = AppTheme.severityForegroundOf(context, AppSeverity.danger);
      label = l.reqBadgeYes;
    } else if (req == 'Conditional') {
      bg = AppTheme.severityBackgroundOf(context, AppSeverity.warning);
      fg = AppTheme.severityForegroundOf(context, AppSeverity.warning);
      label = l.reqBadgeConditional;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusBadge(String status, AppLocalizations l) {
    Color bg = AppTheme.surfaceAltOf(context);
    Color fg = AppTheme.textSecondaryOf(context);
    switch (status) {
      case 'Verified':
      case 'FULLY_VERIFIED':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.success);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.success);
        break;
      case 'Received':
      case 'FULLY_RECEIVED':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.info);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.info);
        break;
      case 'In Transit':
      case 'PARTIALLY_RECEIVED':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.warning);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.warning);
        break;
      case 'Discrepant':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.danger);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.danger);
        break;
      case 'DRAFT':
      case 'Pending':
      default:
        bg = AppTheme.surfaceAltOf(context);
        fg = AppTheme.textSecondaryOf(context);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(_getStatusLabel(status, l), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionToolbar(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: AppTheme.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IdocUi.fit(AppButton(
                  label: l.saveDraftSessionBtn,
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.primary,
                  onPressed: _isSaving ? null : () => _handleSaveSession(isConfirmComplete: false),
                )),
                const SizedBox(width: 12),
                IdocUi.fit(AppButton(
                  label: l.completeCollectionBtn,
                  icon: Icons.check_circle,
                  variant: AppButtonVariant.success,
                  onPressed: _isSaving ? null : () => _handleSaveSession(isConfirmComplete: true),
                )),
              ],
            ),
            const SizedBox(width: 24),
            Row(
              children: [
                IdocUi.fit(AppButton(
                  label: l.originalDocsExportTsvBtn,
                  icon: Icons.table_chart_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _selectedImportFile == null
                      ? null
                      : () => OriginalDocsExportService.exportDocumentsTsv(
                            context: context,
                            file: _selectedImportFile!,
                            documents: _documents,
                            couriers: _couriers,
                          ),
                )),
                const SizedBox(width: 8),
                IdocUi.fit(AppButton(
                  label: l.originalDocsExportExcelBtn,
                  icon: Icons.file_download_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _selectedImportFile == null
                      ? null
                      : () => OriginalDocsExportService.exportDocumentsExcel(
                            context: context,
                            file: _selectedImportFile!,
                            documents: _documents,
                            couriers: _couriers,
                          ),
                )),
                const SizedBox(width: 8),
                IdocUi.fit(AppButton(
                  label: l.originalDocsPrintPdfBtn,
                  icon: Icons.print_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _selectedImportFile == null
                      ? null
                      : () => OriginalDocsExportService.printDocumentsPdf(
                            context: context,
                            file: _selectedImportFile!,
                            documents: _documents,
                            couriers: _couriers,
                            session: _existingSession,
                            notes: _notesController.text,
                            overrideReason: _overrideReasonController.text,
                          ),
                )),
                const SizedBox(width: 8),
                IdocUi.fit(AppButton(
                  label: l.originalDocsCopyDossierBtn,
                  icon: Icons.copy_all_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _selectedImportFile == null
                      ? null
                      : () => OriginalDocsExportService.copyDocumentsDossier(
                            context: context,
                            file: _selectedImportFile!,
                            documents: _documents,
                            couriers: _couriers,
                            session: _existingSession,
                            notes: _notesController.text,
                            overrideReason: _overrideReasonController.text,
                          ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourierAlertsBanner(AppLocalizations l) {
    final alertsAsync = ref.watch(courierAlertsProvider);
    return alertsAsync.when(
      data: (alertsData) {
        if (alertsData.alerts.isEmpty) {
          return const SizedBox.shrink();
        }

        final hasCritical = alertsData.delayedCount > 0;
        final hasWarning = alertsData.alerts.any((a) => a.alertLevel == 'WARNING');
        final bannerColor = hasCritical
            ? AppTheme.crimson
            : (hasWarning ? AppTheme.orange : AppTheme.cobalt);

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bannerColor.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Icon(
                      hasCritical
                          ? Icons.error_outline
                          : (hasWarning ? Icons.warning_amber_rounded : Icons.local_shipping_outlined),
                      color: bannerColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.courierAlertsHeader,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: bannerColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (hasCritical)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.crimson,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l.courierAlertCriticalCount(alertsData.delayedCount),
                          style: const TextStyle(color: AppTheme.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (hasWarning) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l.courierAlertWarningCount(alertsData.alerts.where((a) => a.alertLevel == 'WARNING').length),
                          style: const TextStyle(color: AppTheme.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: alertsData.alerts.map((alert) {
                  final itemColor = alert.alertLevel == 'CRITICAL'
                      ? AppTheme.crimson
                      : (alert.alertLevel == 'WARNING' ? AppTheme.orange : AppTheme.cobalt);

                  final isAr = Localizations.localeOf(context).languageCode == 'ar';
                  final alertMsg = isAr ? alert.alertMessageAr : alert.alertMessageEn;

                  return Container(
                    width: 340,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: itemColor.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(color: AppTheme.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: itemColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  alert.alertLevel == 'CRITICAL'
                                      ? (context.l10n.idocACriticalDelay)
                                      : (alert.alertLevel == 'WARNING'
                                          ? (context.l10n.idocAWarning)
                                          : (context.l10n.idocAInTransit)),
                                  style: TextStyle(
                                    color: itemColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l.daysInTransitLabel(alert.daysInTransit),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: alert.daysInTransit >= 5 ? AppTheme.crimson : AppTheme.charcoal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${alert.importFileCode} — ${alert.courierCompany}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                        ),
                        if (alertMsg.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            alertMsg,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'AWB: ${alert.courierNo}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => OriginalDocsExportService.launchCarrierTracking(
                                alert.courierCompany,
                                alert.courierNo,
                              ),
                              child: const Icon(Icons.open_in_new, size: 13, color: AppTheme.cobalt),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: IdocUi.fit(AppButton(
                            label: l.confirmCourierDeliveryBtn,
                            icon: Icons.done_all,
                            variant: AppButtonVariant.success,
                            size: AppButtonSize.small,
                            onPressed: () => _showCourierDeliveryProofDialog(
                              importFileId: alert.importFileId,
                              courierNo: alert.courierNo,
                              courierCompany: alert.courierCompany,
                              trackingNo: alert.courierNo,
                              importFileCode: alert.importFileCode,
                            ),
                          )),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _showCourierDeliveryProofDialog({
    required int importFileId,
    required String courierNo,
    required String courierCompany,
    String? trackingNo,
    required String importFileCode,
  }) async {
    final l = context.l10n;
    DateTime selectedDate = DateTime.now();
    final now = DateTime.now();
    final timeCtrl = TextEditingController(
      text: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
    final receiverCtrl = TextEditingController();
    final podCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool markDocsReceived = true;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final dateStr =
              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

          return SelectionArea(
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_outlined, color: AppTheme.emerald, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.courierDeliveryProofDialogTitle,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$importFileCode | $courierCompany ${trackingNo != null ? "($trackingNo)" : ""}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 12),
                      // Receipt Date Picker
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 1)),
                                );
                                if (picked != null) {
                                  setModalState(() => selectedDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l.courierReceiptDateLabel,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                ),
                                child: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Receipt Time Field
                          Expanded(
                            child: TextField(
                              controller: timeCtrl,
                              decoration: InputDecoration(
                                labelText: l.courierReceiptTimeLabel,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.access_time, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Received By Field
                      TextField(
                        controller: receiverCtrl,
                        decoration: InputDecoration(
                          labelText: l.courierReceivedByLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_outline, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // POD Reference
                      TextField(
                        controller: podCtrl,
                        decoration: InputDecoration(
                          labelText: l.courierPodRefLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.receipt_long_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Notes
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: context.l10n.idocAReceiptAndVisualInspectionNotes,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Auto-mark documents received checkbox
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l.markAssociatedDocsReceivedLabel,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                          ),
                          value: markDocsReceived,
                          activeColor: AppTheme.emerald,
                          onChanged: (val) => setModalState(() => markDocsReceived = val ?? true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IdocUi.fit(AppButton(
                  label: l.cancel,
                  variant: AppButtonVariant.ghost,
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                )),
                IdocUi.fit(AppButton(
                  label: l.confirmCourierDeliveryBtn,
                  icon: Icons.verified,
                  variant: AppButtonVariant.success,
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);
                          try {
                            final req = CourierReceiptProofRequestModel(
                              importFileId: importFileId,
                              courierNo: courierNo,
                              receivedDate: dateStr,
                              receivedTime: timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : null,
                              receivedBy: receiverCtrl.text.trim().isNotEmpty
                                  ? receiverCtrl.text.trim()
                                  : 'مكتب الاستقبال والتخليص',
                              podReference: podCtrl.text.trim().isNotEmpty ? podCtrl.text.trim() : null,
                              notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                              markDocumentsReceived: markDocsReceived,
                            );

                            await ref.read(originalDocumentsSessionsProvider.notifier).confirmCourierReceipt(req);

                            ref.invalidate(courierAlertsProvider);
                            ref.invalidate(allCouriersProvider);

                            if (_selectedImportFile?.importFileId == importFileId) {
                              await _loadInitialFile(importFileId);
                            }

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.courierReceiptRecordedSuccess),
                                  backgroundColor: AppTheme.emerald,
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${l.errorPrefix}: ${ApiErrorText.of(l, e)}'), backgroundColor: AppTheme.crimson),
                              );
                            }
                          }
                        },
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRegistrySection(
      AppLocalizations l, AsyncValue<List<OriginalDocumentsCollectionSessionModel>> sessionsAsync) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: AppTheme.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tabs switch: Sessions Registry vs Courier Tracking Registry
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_edu_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(l.sessionsRegistryTab, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  selected: _registryTabMode == 0,
                  selectedColor: AppTheme.cobalt.withValues(alpha: 0.15),
                  onSelected: (val) {
                    if (val) setState(() => _registryTabMode = 0);
                  },
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(l.courierTrackingRegistryTab, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  selected: _registryTabMode == 1,
                  selectedColor: AppTheme.cobalt.withValues(alpha: 0.15),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _registryTabMode = 1);
                      ref.invalidate(allCouriersProvider);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_registryTabMode == 0)
            _buildSessionsRegistryTable(l, sessionsAsync)
          else
            _buildCourierTrackingRegistryTable(l),
        ],
      ),
    );
  }

  Widget _buildSessionsRegistryTable(
      AppLocalizations l, AsyncValue<List<OriginalDocumentsCollectionSessionModel>> sessionsAsync) {
    final sessions = sessionsAsync.asData?.value ?? [];
    final hasSessions = sessions.isNotEmpty;
    final allImportFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_edu_outlined, color: AppTheme.cobalt, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l.collectionRegistryHeader,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _registrySearchController,
                      decoration: InputDecoration(
                        hintText: l.searchRegistryHint,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _registrySearchController.text.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.copy, size: 15),
                                tooltip: l.copyTooltip,
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  _registrySearchController.text.trim(),
                                  customMessage: l.copiedToClipboard(_registrySearchController.text.trim()),
                                ),
                              )
                            : null,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        ref.read(originalDocumentsSessionsProvider.notifier).fetchSessions(
                              search: val,
                              status: _registryStatusFilter,
                            );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _registryStatusFilter,
                    items: ['All', 'DRAFT', 'PARTIALLY_RECEIVED', 'FULLY_RECEIVED', 'FULLY_VERIFIED']
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(_getRegistryStatusFilterLabel(s, l), style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _registryStatusFilter = val);
                        ref.read(originalDocumentsSessionsProvider.notifier).fetchSessions(
                              search: _registrySearchController.text,
                              status: val,
                            );
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  IdocUi.fit(AppButton(
                    label: l.originalDocsExportTsvBtn,
                    icon: Icons.table_view_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: !hasSessions
                        ? null
                        : () => OriginalDocsExportService.exportRegistryTsv(
                              context: context,
                              sessions: sessions,
                              shipments: allImportFiles,
                            ),
                  )),
                  const SizedBox(width: 8),
                  IdocUi.fit(AppButton(
                    label: l.originalDocsExportExcelBtn,
                    icon: Icons.file_download_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: !hasSessions
                        ? null
                        : () => OriginalDocsExportService.exportRegistryExcel(
                              context: context,
                              sessions: sessions,
                              shipments: allImportFiles,
                            ),
                  )),
                  const SizedBox(width: 8),
                  IdocUi.fit(AppButton(
                    label: l.originalDocsPrintPdfBtn,
                    icon: Icons.print_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: !hasSessions
                        ? null
                        : () => OriginalDocsExportService.printRegistryPdf(
                              context: context,
                              sessions: sessions,
                              shipments: allImportFiles,
                            ),
                  )),
                  const SizedBox(width: 8),
                  IdocUi.fit(AppButton(
                    label: l.originalDocsCopyDossierBtn,
                    icon: Icons.copy_all_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: !hasSessions
                        ? null
                        : () => OriginalDocsExportService.copyRegistryDossier(
                              context: context,
                              sessions: sessions,
                              shipments: allImportFiles,
                            ),
                  )),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        sessionsAsync.when(
          data: (sessionsList) {
            if (sessionsList.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Text(l.noRegisteredSessionsFound, style: TextStyle(color: AppTheme.textSecondaryOf(context))),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAlt),
                headingTextStyle: const TextStyle(color: AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 12),
                columns: [
                  DataColumn(label: Text(l.colAction)),
                  DataColumn(label: Text(l.colSessionCode)),
                  DataColumn(label: Text(l.colImportFile)),
                  DataColumn(label: Text(l.colAcidNumber)),
                  DataColumn(label: Text(l.colSupplierName)),
                  DataColumn(label: Text(l.colTotalDocs)),
                  DataColumn(label: Text(l.colReceivedDocs)),
                  DataColumn(label: Text(l.colVerifiedDocs)),
                  DataColumn(label: Text(l.colCompletionPercentage)),
                  DataColumn(label: Text(l.colDocStatus)),
                  DataColumn(label: Text(l.colUpdatedAt)),
                ],
                rows: sessionsList.map((s) {
                  final isAr = Localizations.localeOf(context).languageCode == 'ar';
                  final allFiles = allImportFiles;
                  final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
                    s.importFileCode,
                    shipments: allFiles,
                    isArabic: isAr,
                  );
                  final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
                    s.importFileCode,
                    shipments: allFiles,
                    isArabic: isAr,
                  );
                  final statusStr = _getRegistryStatusFilterLabel(s.status, l);
                  final updatedStr = _formatDateTime(s.updatedAt);
                  final sessionSummary =
                      '${s.collectionCode} | $shipmentTitle | ${s.acidNumber ?? "—"} | ${s.supplierName ?? "—"} | ${s.totalDocumentsCount} | ${s.receivedDocumentsCount} | ${s.verifiedDocumentsCount} | ${s.completionPercentage}% | $statusStr | $updatedStr';

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                              tooltip: l.copyRow,
                              onPressed: () => CopyHelper.copy(
                                context,
                                sessionSummary,
                                customMessage: l.originalDocsCopyRowSuccess,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.folder_open_outlined, size: 16, color: AppTheme.charcoal),
                              tooltip: l.originalDocsLoadSessionTooltip,
                              onPressed: () => _loadInitialFile(s.importFileId),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: s.collectionCode,
                          rowSummary: sessionSummary,
                          child: InkWell(
                            onTap: () => CopyHelper.copy(
                              context,
                              s.collectionCode,
                              customMessage: l.copiedToClipboard(s.collectionCode),
                            ),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    s.collectionCode,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy, size: 12, color: AppTheme.cobalt),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: shipmentName,
                          rowSummary: sessionSummary,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (shipmentName != s.importFileCode) ...[
                                Text(
                                  shipmentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
                                ),
                                const SizedBox(height: 2),
                              ],
                              InkWell(
                                onTap: () => CopyHelper.copy(
                                  context,
                                  s.importFileCode,
                                  customMessage: l.copiedToClipboard(s.importFileCode),
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        s.importFileCode,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy, size: 10, color: AppTheme.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: s.acidNumber ?? '—',
                          rowSummary: sessionSummary,
                          child: s.acidNumber != null && s.acidNumber!.isNotEmpty
                              ? InkWell(
                                  onTap: () => CopyHelper.copy(
                                    context,
                                    s.acidNumber!,
                                    customMessage: l.copiedToClipboard(s.acidNumber!),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          s.acidNumber!,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.orange,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.copy, size: 12, color: AppTheme.orange),
                                      ],
                                    ),
                                  ),
                                )
                              : const Text('—'),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: s.supplierName ?? '—',
                          rowSummary: sessionSummary,
                          child: Text(s.supplierName ?? '—'),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: '${s.totalDocumentsCount}',
                          rowSummary: sessionSummary,
                          child: Text('${s.totalDocumentsCount}'),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: '${s.receivedDocumentsCount}',
                          rowSummary: sessionSummary,
                          child: Text('${s.receivedDocumentsCount}'),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: '${s.verifiedDocumentsCount}',
                          rowSummary: sessionSummary,
                          child: Text('${s.verifiedDocumentsCount}'),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: '${s.completionPercentage}%',
                          rowSummary: sessionSummary,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: s.completionPercentage == 100 ? AppTheme.severityBackgroundOf(context, AppSeverity.success) : AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${s.completionPercentage}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: s.completionPercentage == 100 ? AppTheme.severityForegroundOf(context, AppSeverity.success) : AppTheme.severityForegroundOf(context, AppSeverity.warning),
                              ),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: statusStr,
                          rowSummary: sessionSummary,
                          child: _buildStatusBadge(s.status, l),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: updatedStr,
                          rowSummary: sessionSummary,
                          child: Text(updatedStr),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(l.errorFetchingRegistry(e), style: const TextStyle(color: AppTheme.crimson)),
        ),
      ],
    );
  }

  Widget _buildCourierTrackingRegistryTable(AppLocalizations l) {
    final allCouriersAsync = ref.watch(allCouriersProvider);
    final allImportFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _courierSearchController,
                  decoration: InputDecoration(
                    hintText: context.l10n.idocASearchByWaybillCourierOrShipment,
                    prefixIcon: Icon(Icons.search, size: 18),
                    suffixIcon: _courierSearchController.text.trim().isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 15),
                            onPressed: () {
                              setState(() => _courierSearchController.clear());
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: 10),
              DropdownButton<String>(
                value: _courierStatusFilter,
                items: [
                  DropdownMenuItem(value: 'All', child: Text(l.filterStatusAll, style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'IN_TRANSIT', child: Text(l.filterStatusInTransit, style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'DELIVERED', child: Text(l.filterStatusDelivered, style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _courierStatusFilter = val);
                },
              ),
              SizedBox(width: 16),
              IdocUi.fit(AppButton(
                label: l.refreshDataTooltip,
                icon: Icons.refresh,
                variant: AppButtonVariant.primary,
                onPressed: () => ref.invalidate(allCouriersProvider),
              )),
            ],
          ),
        ),
        SizedBox(height: 16),
        allCouriersAsync.when(
          data: (couriersList) {
            final query = _courierSearchController.text.trim().toLowerCase();
            final filtered = couriersList.where((c) {
              if (_courierStatusFilter == 'IN_TRANSIT' && c.isReceived) return false;
              if (_courierStatusFilter == 'DELIVERED' && !c.isReceived) return false;
              if (query.isNotEmpty) {
                final matchNo = c.courierNo.toLowerCase().contains(query);
                final matchCompany = c.courierCompany.toLowerCase().contains(query);
                final matchFile = c.importFileCode.toLowerCase().contains(query);
                final matchReceiver = (c.receivedBy ?? '').toLowerCase().contains(query);
                final matchPod = (c.podReference ?? '').toLowerCase().contains(query);
                if (!matchNo && !matchCompany && !matchFile && !matchReceiver && !matchPod) {
                  return false;
                }
              }
              return true;
            }).toList();

            if (filtered.isEmpty) {
              return Container(
                padding: EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Text(context.l10n.idocANoCourierPackagesMatchTheSearch, style: TextStyle(color: AppTheme.textMuted)),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAlt),
                headingTextStyle: TextStyle(color: AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 12),
                columns: [
                  DataColumn(label: Text(context.l10n.idocAOperations)),
                  DataColumn(label: Text(context.l10n.idocAShippingCompany)),
                  DataColumn(label: Text(context.l10n.idocAWaybillNumberAWB)),
                  DataColumn(label: Text(context.l10n.idocAImportFile)),
                  DataColumn(label: Text(context.l10n.idocALinkedDocuments)),
                  DataColumn(label: Text(context.l10n.idocADispatchDate)),
                  DataColumn(label: Text(context.l10n.idocATransitTime)),
                  DataColumn(label: Text(context.l10n.idocAReceiptStatus)),
                  DataColumn(label: Text(context.l10n.idocAReceiptDateAndTime)),
                  DataColumn(label: Text(context.l10n.idocAReceivedBy)),
                  DataColumn(label: Text(context.l10n.idocAPODNumber)),
                  DataColumn(label: Text(context.l10n.notes)),
                ],
                rows: filtered.map((c) {
                  final isAr = Localizations.localeOf(context).languageCode == 'ar';
                  final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
                    c.importFileCode,
                    shipments: allImportFiles,
                    isArabic: isAr,
                  );
                  final rowSummary =
                      '${c.courierCompany} | ${c.courierNo} | ${c.importFileCode} | ${c.isReceived ? "Delivered" : "In Transit"} | ${c.receivedDate ?? "-"}';

                  return DataRow(
                    cells: [
                      // Operations cell
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_new, size: 16, color: AppTheme.cobalt),
                              tooltip: context.l10n.idocATrackTheCourierDirectlyOnThe,
                              onPressed: () => OriginalDocsExportService.launchCarrierTracking(
                                c.courierCompany,
                                c.courierNo,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                c.isReceived ? Icons.verified : Icons.verified_outlined,
                                size: 16,
                                color: AppTheme.emerald,
                              ),
                              tooltip: l.confirmCourierDeliveryBtn,
                              onPressed: () => _showCourierDeliveryProofDialog(
                                importFileId: c.importFileId,
                                courierNo: c.courierNo,
                                courierCompany: c.courierCompany,
                                trackingNo: c.courierNo,
                                importFileCode: c.importFileCode,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 15, color: AppTheme.textSecondary),
                              tooltip: l.copyRow,
                              onPressed: () => CopyHelper.copy(
                                context,
                                rowSummary,
                                customMessage: l.originalDocsCopyRowSuccess,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.folder_open_outlined, size: 16, color: AppTheme.charcoal),
                              tooltip: l.originalDocsLoadSessionTooltip,
                              onPressed: () => _loadInitialFile(c.importFileId),
                            ),
                          ],
                        ),
                      ),
                      // Courier Company
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_shipping, size: 15, color: AppTheme.cobalt),
                            const SizedBox(width: 6),
                            Text(
                              _getCourierCompanyLabel(c.courierCompany, l),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // AWB No
                      DataCell(
                        CopyableTableCell(
                          value: c.courierNo,
                          rowSummary: rowSummary,
                          child: InkWell(
                            onTap: () => CopyHelper.copy(
                              context,
                              c.courierNo,
                              customMessage: l.copiedToClipboard(c.courierNo),
                            ),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    c.courierNo,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.charcoal,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy, size: 12, color: AppTheme.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Shipment Code & Name
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (shipmentName != c.importFileCode) ...[
                              Text(
                                shipmentName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                              ),
                              const SizedBox(height: 2),
                            ],
                            InkWell(
                              onTap: () => _loadInitialFile(c.importFileId),
                              child: Text(
                                c.importFileCode,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.cobalt),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Associated Docs Count
                      DataCell(
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              context.l10n.idocADocumentsCount(c.associatedDocsCount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.cobalt),
                            ),
                          ),
                        ),
                      ),
                      // Dispatch Date
                      DataCell(Text(c.dispatchDate ?? '—', style: const TextStyle(fontSize: 12))),
                      // Days in transit
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.daysInTransit >= 5
                                ? AppTheme.crimson.withValues(alpha: 0.12)
                                : (c.daysInTransit >= 3 ? AppTheme.orange.withValues(alpha: 0.12) : AppTheme.severityBackgroundOf(context, AppSeverity.info)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l.daysInTransitLabel(c.daysInTransit),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: c.daysInTransit >= 5
                                  ? AppTheme.crimson
                                  : (c.daysInTransit >= 3 ? AppTheme.orange : AppTheme.cobalt),
                            ),
                          ),
                        ),
                      ),
                      // Status
                      DataCell(
                        c.isReceived
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 12, color: AppTheme.emerald),
                                    SizedBox(width: 4),
                                    Text(
                                      context.l10n.idocAReceived,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_shipping, size: 12, color: AppTheme.orange),
                                    SizedBox(width: 4),
                                    Text(
                                      context.l10n.idocAInTransitAlt,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      // Received Date & Time
                      DataCell(
                        Text(
                          c.receivedDate != null
                              ? '${c.receivedDate} ${c.receivedTime ?? ""}'.trim()
                              : '—',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Received By
                      DataCell(Text(c.receivedBy ?? '—', style: const TextStyle(fontSize: 12))),
                      // POD Ref
                      DataCell(
                        Text(
                          c.podReference ?? '—',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Notes
                      DataCell(Text(c.notes ?? '—', style: const TextStyle(fontSize: 11))),
                    ],
                  );
                }).toList(),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('${l.errorPrefix}: ${ApiErrorText.of(l, e)}', style: const TextStyle(color: AppTheme.crimson)),
        ),
      ],
    );
  }
}
