import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../l10n/container_eir_l10n.dart';
import '../models/container_eir_model.dart';
import '../providers/demurrage_provider.dart';
import '../services/container_eir_service.dart';

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
            // Select first active (unreturned) container by default
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
          // Refresh demurrage provider so tracking screens update immediately
          if (widget.importFileId != null) {
            ref.read(demurrageProvider.notifier).fetchTrackings(importFileId: widget.importFileId);
          }
          // Reload local ledger
          await _loadLedger();
          // Switch to ledger tab to see the updated frozen cost
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
    final theme = Theme.of(context);

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880, maxHeight: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment_turned_in, color: AppTheme.cobalt, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.containerEirDialogTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.containerEirDialogSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l.closeBtn,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ),

              // Tab Bar
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

              // Tab Body
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReturnFormTab(l),
                    _buildLedgerTab(l),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturnFormTab(AppLocalizations l) {
    final containers = _ledgerData?.items ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Notice banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.demurrageFreezeNotice,
                      style: const TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Container selection
            if (containers.isNotEmpty) ...[
              InputDecorator(
                decoration: InputDecoration(
                  labelText: l.containerNumberLabel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedContainerId,
                    isDense: true,
                    isExpanded: true,
                    items: containers.map((c) {
                      final badgeText = c.isDemurrageStopped ? ' (${l.statusReturnedStopped})' : '';
                      return DropdownMenuItem<int>(
                        value: c.containerId,
                        child: Text('${c.containerNumber} [${c.containerType}]$badgeText'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedContainerId = val;
                        final matched = containers.firstWhere((e) => e.containerId == val);
                        _selectedContainerNumber = matched.containerNumber;
                      });
                    },
                  ),
                ),
              ),
            ] else ...[
              CustomTextField(
                controller: TextEditingController(text: _selectedContainerNumber ?? ''),
                label: l.containerNumberLabel,
                hint: l.containerNumberHint,
                enabled: false,
                textDirection: TextDirection.ltr,
              ),
            ],
            const SizedBox(height: 16),

            // EIR Number + Copy Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _eirNumberCtrl,
                    label: l.eirNumberLabel,
                    hint: l.eirNumberHint,
                    isRequired: true,
                    textDirection: TextDirection.ltr,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l.requiredEirNumber;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: l.copyEirNumber,
                    onPressed: () => CopyHelper.copy(context, _eirNumberCtrl.text.trim()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date picker & Condition
            Row(
              children: [
                Expanded(
                  child: AppDatePickerField(
                    label: l.returnDateLabel,
                    value: _emptyReturnDate,
                    isRequired: true,
                    onChanged: (d) {
                      if (d != null) setState(() => _emptyReturnDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l.inspectionConditionLabel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _conditionStatus,
                        isDense: true,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(value: 'Sound and Clean', child: Text(l.conditionSoundClean)),
                          DropdownMenuItem(value: 'Damaged', child: Text(l.conditionDamaged)),
                          DropdownMenuItem(value: 'Requires Cleaning', child: Text(l.conditionRequiresCleaning)),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _conditionStatus = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Depot name
            CustomTextField(
              controller: _depotNameCtrl,
              label: l.depotNameLabel,
              hint: l.depotNameHint,
            ),
            const SizedBox(height: 16),

            // Additional Notes
            CustomTextField(
              controller: _notesCtrl,
              label: l.notesLabel,
              hint: l.notesHint,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: l.cancelBtn,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: l.confirmEirBtn,
                  variant: AppButtonVariant.success,
                  icon: Icons.check_circle_outline,
                  isLoading: _isSubmitting,
                  onPressed: _submitReturn,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerTab(AppLocalizations l) {
    if (_isLoadingLedger) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _ledgerData;
    if (data == null || data.items.isEmpty) {
      return Center(
        child: Text(l.noContainersFound, style: const TextStyle(fontSize: 14)),
      );
    }

    return Column(
      children: [
        // KPI Summary Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: AppTheme.surfaceOf(context),
          child: Row(
            children: [
              _buildKpiCard(l.totalContainersLabel, '${data.totalContainers}', AppTheme.cobalt),
              const SizedBox(width: 12),
              _buildKpiCard(l.returnedContainersLabel, '${data.returnedContainers}', AppTheme.flatEmerald),
              const SizedBox(width: 12),
              _buildKpiCard(l.activeContainersLabel, '${data.activeContainers}', AppTheme.crimson),
              const SizedBox(width: 12),
              _buildKpiCard(
                l.totalDemurrageCostLabel,
                '${data.totalDemurrageCostFx.toStringAsFixed(2)} ${data.currency}',
                AppTheme.charcoal,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Containers List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = data.items[index];
              return _buildContainerLedgerCard(l, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: accentColor),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerLedgerCard(AppLocalizations l, ContainerLedgerItemModel item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isDemurrageStopped ? AppTheme.flatEmerald.withValues(alpha: 0.4) : AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Container Number + Copy
              Text(
                item.containerNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: l.copyContainerNumber,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => CopyHelper.copy(context, item.containerNumber),
              ),
              const SizedBox(width: 8),
              Text(
                '[${item.containerType}]',
                style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
              ),
              const Spacer(),

              // Status Badge
              if (item.isDemurrageStopped)
                AppStatusBadge(
                  label: l.statusReturnedStopped,
                  severity: AppSeverity.success,
                  icon: Icons.check_circle_outline,
                )
              else
                AppStatusBadge(
                  label: l.statusActiveAccruing,
                  severity: AppSeverity.danger,
                  icon: Icons.timer,
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Operational Details
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (item.gateOutDate != null)
                Text(
                  '${l.gateOutDateLabel}: ${item.gateOutDate!.toIso8601String().substring(0, 10)}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
              if (item.emptyReturnDate != null)
                Text(
                  '${l.returnDateLabel}: ${item.emptyReturnDate!.toIso8601String().substring(0, 10)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.flatEmerald, fontWeight: FontWeight.w600),
                ),
              if (item.eirNumber != null && item.eirNumber!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l.eirNumberLabel}: ${item.eirNumber}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14),
                      tooltip: l.copyEirNumber,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => CopyHelper.copy(context, item.eirNumber!),
                    ),
                  ],
                ),
              if (item.eirConditionStatus != null)
                Text(
                  '${l.inspectionConditionLabel}: ${item.eirConditionStatus}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Financial Ledger Line
          Row(
            children: [
              Text(
                '${l.individualDemurrageLabel}: ',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
              Text(
                '${item.individualDemurrageCost.toStringAsFixed(2)} ${item.currency}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: item.isDemurrageStopped ? AppTheme.flatEmerald : AppTheme.crimson,
                ),
              ),
              const Spacer(),
              if (!item.isDemurrageStopped)
                AppButton(
                  label: l.confirmEirBtn,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  icon: Icons.assignment_turned_in,
                  onPressed: () {
                    setState(() {
                      _selectedContainerId = item.containerId;
                      _selectedContainerNumber = item.containerNumber;
                    });
                    _tabController.animateTo(0);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
