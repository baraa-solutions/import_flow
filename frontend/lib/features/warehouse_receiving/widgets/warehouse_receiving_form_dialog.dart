import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/grn_line_balance.dart';
import '../models/warehouse_receiving_model.dart';
import '../providers/goods_in_transit_provider.dart';
import '../providers/warehouse_receiving_provider.dart';
import 'ops_ui_kit.dart';

/// Controllers of one GRN line. All quantities are typed by the user (or copied from a
/// PO line / an existing GRN): nothing is invented.
class GrnLineControllers {
  final String poNumber;
  final TextEditingController code;
  final TextEditingController name;
  final TextEditingController invoiced;
  final TextEditingController accepted;
  final TextEditingController shortage;
  final TextEditingController damaged;

  GrnLineControllers({
    this.poNumber = '',
    String code = '',
    String name = '',
    String invoiced = '',
    String accepted = '',
    String shortage = '0',
    String damaged = '0',
  })  : code = TextEditingController(text: code),
        name = TextEditingController(text: name),
        invoiced = TextEditingController(text: invoiced),
        accepted = TextEditingController(text: accepted),
        shortage = TextEditingController(text: shortage),
        damaged = TextEditingController(text: damaged);

  /// A line copied from a PO line: accepted = invoiced, shortage = damaged = 0.
  factory GrnLineControllers.fromPoLine({
    required String poNumber,
    required String code,
    required String name,
    required num quantity,
  }) {
    final qty = quantity.toStringAsFixed(0);
    return GrnLineControllers(poNumber: poNumber, code: code, name: name, invoiced: qty, accepted: qty);
  }

  factory GrnLineControllers.fromItem(GrnItemModel item, {String poNumber = ''}) => GrnLineControllers(
        poNumber: poNumber,
        code: item.itemCode,
        name: item.itemName,
        invoiced: '${item.invoicedQty}',
        accepted: '${item.acceptedQty}',
        shortage: '${item.shortageQty}',
        damaged: '${item.damagedQty}',
      );

  List<TextEditingController> get all => [code, name, invoiced, accepted, shortage, damaged];

  /// Quantities, or null while any of the four fields is empty or invalid.
  GrnLineQuantities? get quantities {
    final inv = parseGrnQty(invoiced.text);
    final acc = parseGrnQty(accepted.text);
    final sh = parseGrnQty(shortage.text);
    final dm = parseGrnQty(damaged.text);
    if (inv == null || acc == null || sh == null || dm == null) return null;
    return GrnLineQuantities(invoiced: inv, accepted: acc, shortage: sh, damaged: dm);
  }

  Map<String, dynamic> toPayload() {
    final q = quantities!;
    return {
      'item_code': code.text.trim(),
      'item_name': name.text.trim(),
      'invoiced_qty': q.invoiced,
      'accepted_qty': q.accepted,
      'shortage_qty': q.shortage,
      'damaged_qty': q.damaged,
    };
  }

  void dispose() {
    for (final c in all) {
      c.dispose();
    }
  }
}

/// Create / edit / clone form of a Goods Receiving Note.
///
/// There is no "draft": the backend turns every create into a real GRN and moves the file
/// to the next stage (plan FE-03), so the form offers a single save action.
class WarehouseReceivingFormDialog extends ConsumerStatefulWidget {
  final WarehouseReceivingModel? recordToEdit;
  final bool isCloneDraft;
  const WarehouseReceivingFormDialog({super.key, this.recordToEdit, this.isCloneDraft = false});

  @override
  ConsumerState<WarehouseReceivingFormDialog> createState() => _WarehouseReceivingFormDialogState();
}

class _WarehouseReceivingFormDialogState extends ConsumerState<WarehouseReceivingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedImportFileId;
  late TextEditingController _whCtrl;
  late TextEditingController _plateCtrl;
  late TextEditingController _driverCtrl;
  late TextEditingController _sealCtrl;
  bool _sealIntact = true;

  bool _alertSentToWarehouse = false;
  bool _isLoading = false;

  final List<GrnLineControllers> _lines = [];

  bool get _isEdit => widget.recordToEdit != null && !widget.isCloneDraft;

  @override
  void initState() {
    super.initState();
    final r = widget.recordToEdit;
    // A clone copies header data only: the user picks the file (its PO lines fill the form).
    _selectedImportFileId = widget.isCloneDraft ? null : r?.importFileId;
    _whCtrl = TextEditingController(text: r?.warehouseName ?? '');
    _plateCtrl = TextEditingController(text: r?.truckPlateNumber ?? '');
    _driverCtrl = TextEditingController(text: r?.driverName ?? '');
    _sealCtrl = TextEditingController(text: r?.sealNumber ?? '');
    _sealIntact = r?.sealIntact ?? true;
    if (r != null && !widget.isCloneDraft) {
      for (final item in r.grnItems) {
        _addLine(GrnLineControllers.fromItem(item));
      }
    }
    // Live load: the file and PO pickers must not show a stale list.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    });
  }

  void _addLine(GrnLineControllers line) {
    for (final c in line.all) {
      c.addListener(_onLineChanged);
    }
    _lines.add(line);
  }

  void _onLineChanged() {
    if (mounted) setState(() {});
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index).dispose();
    });
  }

  void _clearLines() {
    for (final l in _lines) {
      l.dispose();
    }
    _lines.clear();
  }

  void _onImportFileSelected(int? fileId) {
    if (fileId == null) return;
    setState(() => _selectedImportFileId = fileId);
    // Editing a saved GRN never replaces its lines.
    if (_isEdit) return;

    // Prefill from the PO lines of the selected file only (FE-02: match by the file id).
    final poList = ref.read(purchaseOrdersProvider).purchaseOrders;
    final linkedPos = poList.where((p) => p.importFileId == fileId);
    setState(() {
      _clearLines();
      for (final po in linkedPos) {
        for (final item in po.items) {
          _addLine(GrnLineControllers.fromPoLine(
            poNumber: po.poNumber,
            code: item.itemCode ?? '',
            name: item.descriptionAr,
            quantity: item.quantity,
          ));
        }
      }
    });
  }

  @override
  void dispose() {
    _whCtrl.dispose();
    _plateCtrl.dispose();
    _driverCtrl.dispose();
    _sealCtrl.dispose();
    _clearLines();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.wrNoLinesValidator), backgroundColor: AppTheme.crimson));
      return;
    }
    setState(() => _isLoading = true);
    final nav = Navigator.of(context);

    try {
      // No `status`: the server decides it (and a create always issues a real GRN).
      final payload = <String, dynamic>{
        'import_file_id': _selectedImportFileId,
        'warehouse_name': _whCtrl.text.trim(),
        'truck_plate_number': _plateCtrl.text.trim(),
        'driver_name': _driverCtrl.text.trim(),
        'seal_number': _sealCtrl.text.trim(),
        'seal_intact': _sealIntact,
        'grn_items': _lines.map((l) => l.toPayload()).toList(),
      };

      final notifier = ref.read(warehouseReceivingProvider.notifier);
      if (_isEdit) {
        await notifier.updateRecord(widget.recordToEdit!.receivingId, payload);
      } else {
        await notifier.createRecord(payload);
        if (_selectedImportFileId != null) {
          ref.read(goodsInTransitProvider.notifier).confirmWarehouseReceipt(_selectedImportFileId!);
        }
      }

      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.warehouseReceivingFinalSuccessSnack), backgroundColor: AppTheme.emerald),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorText.of(l10n, e)), backgroundColor: AppTheme.crimson),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final dialogTitle = widget.isCloneDraft
        ? l10n.cloneWarehouseReceivingDialogTitle
        : (widget.recordToEdit == null ? l10n.warehouseReceivingNewDialogTitle : l10n.warehouseReceivingEditDialogTitle);
    final dialogWidth = (MediaQuery.of(context).size.width - 32).clamp(320.0, 880.0);

    return AlertDialog(
      titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 8),
      actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
      title: OpsSectionHeader(title: dialogTitle, icon: Icons.warehouse),
      content: SelectionArea(
        child: SizedBox(
          width: dialogWidth,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDispatchBanner(l10n),
                  const SizedBox(height: 14),
                  _buildDetailsSection(l10n, importFiles),
                  const SizedBox(height: 14),
                  _buildLinesHeader(l10n),
                  const SizedBox(height: 8),
                  _buildLines(l10n),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l10n.cancel,
          variant: AppButtonVariant.secondary,
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        AppButton(
          label: l10n.warehouseReceivingSaveFinalBtn,
          variant: AppButtonVariant.success,
          icon: Icons.check_circle_outline,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _submit,
        ),
      ],
    );
  }

  BoxDecoration _panelDecoration() => BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderOf(context)),
      );

  Widget _buildDetailsSection(AppLocalizations l10n, List<ImportFileModel> importFiles) {
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.wrGrnDetailsSection,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context)),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: SearchableDropdownField<int?>(
                  value: _selectedImportFileId,
                  labelText: l10n.warehouseReceivingImportFileLabel,
                  items: importFiles
                      .map((f) => SearchableDropdownItem<int?>(
                            value: f.importFileId,
                            label:
                                '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " - PO: ${f.poNumber!}" : ""}',
                          ))
                      .toList(),
                  onChanged: _onImportFileSelected,
                  validator: (v) => v == null ? l10n.warehouseReceivingSelectFileValidator : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _copyField(_whCtrl, l10n.warehouseReceivingWarehouseNameLabel, required: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _copyField(_plateCtrl, l10n.warehouseReceivingTruckPlateLabel)),
              const SizedBox(width: 8),
              Expanded(child: _copyField(_driverCtrl, l10n.warehouseReceivingDriverNameLabel)),
              const SizedBox(width: 8),
              Expanded(child: _copyField(_sealCtrl, l10n.warehouseReceivingSealNumberLabel, ltr: true)),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                    title: Text(
                      l10n.warehouseReceivingSealIntactSwitch,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    value: _sealIntact,
                    onChanged: (val) => setState(() => _sealIntact = val),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _copyField(TextEditingController ctrl, String label, {bool required = false, bool ltr = false}) {
    return TextFormField(
      controller: ctrl,
      textDirection: ltr ? TextDirection.ltr : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: context.l10n.warehouseReceivingCopyFieldTooltip,
          onPressed: () => CopyHelper.copy(context, ctrl.text),
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? context.l10n.warehouseReceivingWarehouseNameValidator : null
          : null,
    );
  }

  Widget _buildDispatchBanner(AppLocalizations l10n) {
    return OpsInfoBanner(
      icon: Icons.mark_email_unread_outlined,
      severity: AppSeverity.warning,
      title: l10n.warehouseReceivingDispatchAlertTitle,
      message: l10n.warehouseReceivingDispatchAlertDesc,
      actions: AppButton(
        label: _alertSentToWarehouse ? l10n.warehouseReceivingDispatchSentBtn : l10n.warehouseReceivingDispatchSendBtn,
        variant: _alertSentToWarehouse ? AppButtonVariant.success : AppButtonVariant.warning,
        size: AppButtonSize.small,
        icon: _alertSentToWarehouse ? Icons.check : Icons.send,
        onPressed: () {
          setState(() => _alertSentToWarehouse = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.warehouseReceivingDispatchSuccessSnack), backgroundColor: AppTheme.emerald),
          );
        },
      ),
    );
  }

  Widget _buildLinesHeader(AppLocalizations l10n) {
    return OpsSectionHeader(
      title: l10n.warehouseReceivingMultiPoHeader,
      icon: Icons.list_alt,
      trailing: AppButton(
        label: l10n.warehouseReceivingAddItemBtn,
        icon: Icons.add,
        variant: AppButtonVariant.ghost,
        size: AppButtonSize.small,
        onPressed: () => setState(() => _addLine(GrnLineControllers())),
      ),
    );
  }

  Widget _buildLines(AppLocalizations l10n) {
    if (_lines.isEmpty) {
      return OpsStateView.empty(
        compact: true,
        icon: Icons.playlist_add,
        message: l10n.wrNoLinesHint,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildLine(l10n, i, _lines[i]),
        ],
      ],
    );
  }

  Widget _qtyField(TextEditingController ctrl, String label, {String? Function(String?)? extra}) {
    return Expanded(
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        validator: (v) {
          if (parseGrnQty(v) == null) return context.l10n.wrQtyInvalid;
          return extra?.call(v);
        },
      ),
    );
  }

  Widget _buildLine(AppLocalizations l10n, int index, GrnLineControllers line) {
    final q = line.quantities;
    final balance = q?.balance;
    String? balanceText;
    AppSeverity balanceSeverity = AppSeverity.success;
    if (q != null) {
      if (balance == GrnLineBalance.unbalanced) {
        balanceText = l10n.wrLineUnbalanced(q.received, q.invoiced);
        balanceSeverity = AppSeverity.danger;
      } else if (balance == GrnLineBalance.excess) {
        balanceText = l10n.wrLineExcess(q.accepted - q.invoiced);
        balanceSeverity = AppSeverity.warning;
      }
    }

    return Container(
      padding: const EdgeInsetsDirectional.all(10),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (line.poNumber.isNotEmpty)
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 8),
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    l10n.warehouseReceivingPoLabel(line.poNumber),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.cobalt),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.crimson),
                tooltip: l10n.wrRemoveLineTooltip,
                onPressed: _isLoading ? null : () => _removeLine(index),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.code,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.wrItemCodeLabel,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.wrItemCodeRequired : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.name,
                  decoration: InputDecoration(
                    labelText: l10n.warehouseReceivingItemNameLabel,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _qtyField(line.invoiced, l10n.warehouseReceivingInvoicedQtyLabel),
              const SizedBox(width: 8),
              _qtyField(line.accepted, l10n.warehouseReceivingAcceptedQtyLabel),
              const SizedBox(width: 8),
              _qtyField(line.shortage, l10n.warehouseReceivingShortageQtyLabel),
              const SizedBox(width: 8),
              _qtyField(
                line.damaged,
                l10n.warehouseReceivingDamagedQtyLabel,
                extra: (_) {
                  final cur = line.quantities;
                  if (cur != null && !cur.isValid) return l10n.wrLineUnbalancedShort;
                  return null;
                },
              ),
            ],
          ),
          if (balanceText != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OpsStatusChip(
                  label: balanceText,
                  severity: balanceSeverity,
                  icon: balanceSeverity == AppSeverity.danger ? Icons.error_outline : Icons.info_outline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
