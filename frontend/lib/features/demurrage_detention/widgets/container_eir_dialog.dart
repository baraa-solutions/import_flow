import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../l10n/container_eir_l10n.dart';
import '../models/container_eir_model.dart';
import '../providers/demurrage_provider.dart';
import '../services/container_eir_service.dart';
import 'eir/container_eir_form_tab.dart';
import 'eir/container_eir_header.dart';
import 'eir/container_eir_ledger_tab.dart';

/// EPIC-CONT-EIR: الحوار الموحد لتتبع الحاويات، وخروج البوابة، وتوثيق إيصال إرجاع الفارغ EIR ووقف الغرامة
class ContainerEirDialog extends ConsumerStatefulWidget {
  final int? importFileId;
  final int? initialContainerId;
  final String? initialContainerNumber;

  const ContainerEirDialog({
    super.key,
    this.importFileId,
    this.initialContainerId,
    this.initialContainerNumber,
  });

  static Future<bool?> show(
    BuildContext context, {
    int? importFileId,
    int? initialContainerId,
    String? initialContainerNumber,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ContainerEirDialog(
        importFileId: importFileId,
        initialContainerId: initialContainerId,
        initialContainerNumber: initialContainerNumber,
      ),
    );
  }

  @override
  ConsumerState<ContainerEirDialog> createState() => _ContainerEirDialogState();
}

class _ContainerEirDialogState extends ConsumerState<ContainerEirDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  int? _selectedContainerId;
  String? _selectedContainerNumber;

  late final TextEditingController _eirNumberCtrl;
  late final TextEditingController _depotNameCtrl;
  final _truckPlateCtrl = TextEditingController();
  final _customsSealCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _emptyReturnDate = DateTime.now();
  String _conditionStatus = 'Sound and Clean';
  bool _isSubmitting = false;
  bool _isLoadingLedger = true;
  ContainerLedgerResponseModel? _ledgerData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedContainerId = widget.initialContainerId;
    _selectedContainerNumber = widget.initialContainerNumber;

    final randomId = 1000 + Random().nextInt(9000);
    _eirNumberCtrl = TextEditingController(text: 'EIR-${DateTime.now().year}-$randomId');
    _depotNameCtrl = TextEditingController(text: 'Alexandria Depot');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLedger();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eirNumberCtrl.dispose();
    _depotNameCtrl.dispose();
    _truckPlateCtrl.dispose();
    _customsSealCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLedger() async {
    final fileId = widget.importFileId;
    if (fileId == null) {
      if (mounted) setState(() => _isLoadingLedger = false);
      return;
    }

    setState(() => _isLoadingLedger = true);
    try {
      final service = ref.read(containerEirServiceProvider);
      final data = await service.getContainerLedger(fileId);
      if (mounted) {
        setState(() {
          _ledgerData = data;
          _isLoadingLedger = false;
          if (_selectedContainerId == null && data != null && data.items.isNotEmpty) {
            final activeItem = data.items.firstWhere(
              (item) => !item.isDemurrageStopped,
              orElse: () => data.items.first,
            );
            _selectedContainerId = activeItem.containerId;
            _selectedContainerNumber = activeItem.containerNumber;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLedger = false);
      }
    }
  }

  Future<void> _submitReturn() async {
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContainerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.requiredContainer, severity: AppSeverity.warning),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final service = ref.read(containerEirServiceProvider);
      final req = ContainerEirReturnRequestModel(
        eirNumber: _eirNumberCtrl.text.trim(),
        emptyReturnDate: _emptyReturnDate,
        eirTimestamp: DateTime.now(),
        eirConditionStatus: _conditionStatus,
        depotName: _depotNameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );

      final success = await service.submitEmptyReturnEir(_selectedContainerId!, req);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.saveSuccessNotice, severity: AppSeverity.success),
          );
          if (widget.importFileId != null) {
            ref.read(demurrageProvider.notifier).fetchTrackings(importFileId: widget.importFileId);
          }
          await _loadLedger();
          _tabController.animateTo(1);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.saveErrorNotice, severity: AppSeverity.danger),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, '${l.saveErrorNotice}: $e', severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final containers = _ledgerData?.items ?? [];

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880, maxHeight: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContainerEirHeader(
                onClose: () => Navigator.of(context).pop(true),
              ),
              Container(
                color: AppTheme.surfaceOf(context),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.cobalt,
                  unselectedLabelColor: AppTheme.textSecondaryOf(context),
                  indicatorColor: AppTheme.cobalt,
                  tabs: [
                    Tab(icon: const Icon(Icons.receipt_long, size: 18), text: l.containerEirDialogTitle),
                    Tab(icon: const Icon(Icons.table_chart, size: 18), text: l.containerLedgerTitle),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ContainerEirFormTab(
                      formKey: _formKey,
                      containers: containers,
                      selectedContainerId: _selectedContainerId,
                      selectedContainerNumber: _selectedContainerNumber,
                      onContainerChanged: (id, number) {
                        setState(() {
                          _selectedContainerId = id;
                          _selectedContainerNumber = number;
                        });
                      },
                      eirNumberCtrl: _eirNumberCtrl,
                      emptyReturnDate: _emptyReturnDate,
                      onDateChanged: (d) => setState(() => _emptyReturnDate = d),
                      conditionStatus: _conditionStatus,
                      onConditionChanged: (status) => setState(() => _conditionStatus = status),
                      depotNameCtrl: _depotNameCtrl,
                      notesCtrl: _notesCtrl,
                      isSubmitting: _isSubmitting,
                      onCancel: () => Navigator.of(context).pop(false),
                      onSubmit: _submitReturn,
                    ),
                    ContainerEirLedgerTab(
                      isLoading: _isLoadingLedger,
                      ledgerData: _ledgerData,
                      onSelectForReturn: (id, number) {
                        setState(() {
                          _selectedContainerId = id;
                          _selectedContainerNumber = number;
                        });
                        _tabController.animateTo(0);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
