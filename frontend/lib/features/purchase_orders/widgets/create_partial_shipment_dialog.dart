import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../l10n/po_fulfillment_l10n.dart';
import '../models/purchase_order_model.dart';
import '../providers/purchase_orders_provider.dart';
import 'po_fulfillment_progress_widget.dart';

/// Show dialog to allocate a partial shipment batch (EPIC-PO-PART).
Future<dynamic> showCreatePartialShipmentDialog(
  BuildContext context, {
  required PurchaseOrderModel po,
  int? preselectedLineItemId,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => CreatePartialShipmentDialog(
      po: po,
      preselectedLineItemId: preselectedLineItemId,
    ),
  );
}

class CreatePartialShipmentDialog extends ConsumerStatefulWidget {
  final PurchaseOrderModel po;
  final int? preselectedLineItemId;

  const CreatePartialShipmentDialog({
    super.key,
    required this.po,
    this.preselectedLineItemId,
  });

  @override
  ConsumerState<CreatePartialShipmentDialog> createState() =>
      _CreatePartialShipmentDialogState();
}

class _CreatePartialShipmentDialogState
    extends ConsumerState<CreatePartialShipmentDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _batchNoController;
  late final TextEditingController _quantityController;
  late final TextEditingController _fobAmountController;
  late final TextEditingController _notesController;

  int? _selectedLineItemId;
  int? _selectedImportFileId;
  DateTime _shippingDate = DateTime.now();
  String _allocationStatus = 'IN_TRANSIT';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedLineItemId = widget.preselectedLineItemId;
    _selectedImportFileId = widget.po.importFileId;

    _batchNoController = TextEditingController();
    _quantityController = TextEditingController();
    _fobAmountController = TextEditingController();
    _notesController = TextEditingController();

    _initializeDefaults();
    _quantityController.addListener(_onQuantityChanged);
  }

  void _initializeDefaults() {
    double initialQty = 0.0;
    double initialFob = 0.0;

    if (_selectedLineItemId != null) {
      final item = widget.po.items.firstWhere(
        (it) => it.itemId == _selectedLineItemId,
        orElse: () => widget.po.items.first,
      );
      initialQty = item.quantity;
      initialFob = item.quantity * item.unitPrice;
    } else {
      initialQty = widget.po.remainingBalanceQuantity > 0
          ? widget.po.remainingBalanceQuantity
          : widget.po.effectiveContractedQuantity;
      initialFob = 0.0;
    }

    if (initialQty > 0) {
      _quantityController.text = initialQty.toStringAsFixed(initialQty % 1 == 0 ? 0 : 2);
    }
    if (initialFob > 0) {
      _fobAmountController.text = initialFob.toStringAsFixed(2);
    }
  }

  void _onLineItemChanged(int? newItemId) {
    setState(() {
      _selectedLineItemId = newItemId;
      if (newItemId != null) {
        final item = widget.po.items.firstWhere(
          (it) => it.itemId == newItemId,
          orElse: () => widget.po.items.first,
        );
        _quantityController.text = item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2);
        final fob = item.quantity * item.unitPrice;
        _fobAmountController.text = fob.toStringAsFixed(2);
      } else {
        final rem = widget.po.remainingBalanceQuantity > 0
            ? widget.po.remainingBalanceQuantity
            : widget.po.effectiveContractedQuantity;
        _quantityController.text = rem.toStringAsFixed(rem % 1 == 0 ? 0 : 2);
        _fobAmountController.text = '0.00';
      }
    });
  }

  void _onQuantityChanged() {
    final qty = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    if (_selectedLineItemId != null) {
      final item = widget.po.items.firstWhere(
        (it) => it.itemId == _selectedLineItemId,
        orElse: () => widget.po.items.first,
      );
      final fob = qty * item.unitPrice;
      _fobAmountController.text = fob.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onQuantityChanged);
    _batchNoController.dispose();
    _quantityController.dispose();
    _fobAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final l = context.l10n;
    final qty = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final fob = double.tryParse(_fobAmountController.text.trim()) ?? 0.0;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.poQuantityRequired,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = <String, dynamic>{
        'po_id': widget.po.poId,
        if (_selectedLineItemId != null) 'po_line_item_id': _selectedLineItemId,
        if (_selectedLineItemId != null) 'po_item_id': _selectedLineItemId,
        if (_selectedImportFileId != null) 'import_file_id': _selectedImportFileId,
        'shipment_batch_no': _batchNoController.text.trim(),
        'shipment_ref': _batchNoController.text.trim(),
        'allocated_quantity': qty,
        'shipped_quantity': qty,
        'allocated_fob_amount': fob,
        'shipped_amount_fob': fob,
        'shipping_date': _shippingDate.toIso8601String(),
        'status': _allocationStatus,
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      };

      final allocation = await ref
          .read(purchaseOrdersProvider.notifier)
          .allocateShipment(widget.po.poId!, payload);

      if (mounted) {
        Navigator.of(context).pop(allocation);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.poAllocationSuccess,
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            '${l.poAllocationFailed}: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final importFilesState = ref.watch(importFilesProvider);
    final importFiles = importFilesState.valueOrNull ?? <ImportFileModel>[];

    final lineItemOptions = <SearchableDropdownItem<int?>>[
      SearchableDropdownItem<int?>(
        value: null,
        label: l.poGeneralAllocationOption,
        icon: Icons.all_inclusive,
      ),
      for (final item in widget.po.items)
        SearchableDropdownItem<int?>(
          value: item.itemId,
          label: '${item.itemCode != null ? "${item.itemCode} - " : ""}${item.descriptionAr} (${item.quantity.toStringAsFixed(0)} ${item.unitOfMeasure})',
          searchValue: '${item.itemCode ?? ""} ${item.descriptionAr}',
          icon: Icons.inventory_2_outlined,
        ),
    ];

    final importFileOptions = <SearchableDropdownItem<int?>>[
      SearchableDropdownItem<int?>(
        value: null,
        label: l.poAssociatedImportFileOptional,
        icon: Icons.folder_open_outlined,
      ),
      for (final f in importFiles)
        SearchableDropdownItem<int?>(
          value: f.importFileId,
          label: '${f.importFileCode} - ${f.displayName}',
          searchValue: '${f.importFileCode} ${f.displayName}',
          icon: Icons.folder_outlined,
        ),
    ];

    final statusOptions = [
      SearchableDropdownItem<String>(
        value: 'IN_TRANSIT',
        label: l.poStatusInTransit,
        icon: Icons.local_shipping_outlined,
      ),
      SearchableDropdownItem<String>(
        value: 'ARRIVED',
        label: l.poStatusArrived,
        icon: Icons.flight_land_outlined,
      ),
      SearchableDropdownItem<String>(
        value: 'CUSTOMS_CLEARED',
        label: l.poStatusCustomsCleared,
        icon: Icons.verified_user_outlined,
      ),
      SearchableDropdownItem<String>(
        value: 'RECEIVED_AT_WAREHOUSE',
        label: l.poStatusWarehouseReceived,
        icon: Icons.warehouse_outlined,
      ),
    ];

    return SelectionArea(
      child: Dialog(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 680,
          constraints: const BoxConstraints(maxHeight: 780),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: AppTheme.cobalt,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.poCreatePartialShipment,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.po.displayName,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress Widget Preview
              POFulfillmentProgressWidget.fromPO(
                po: widget.po,
                isCompact: true,
              ),
              const SizedBox(height: 16),

              // Form Scrollable Area
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Batch No / BL Number
                        CustomTextField(
                          controller: _batchNoController,
                          label: l.poShipmentBatchNo,
                          hint: l.poShipmentBatchNoHint,
                          icon: Icons.confirmation_number_outlined,
                          isRequired: true,
                          textDirection: TextDirection.ltr,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return l.poBatchNumberRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Line Item Selection
                        SearchableDropdownField<int?>(
                          value: _selectedLineItemId,
                          items: lineItemOptions,
                          labelText: l.poTargetLineItem,
                          onChanged: _onLineItemChanged,
                        ),
                        const SizedBox(height: 14),

                        // Associated Import File
                        SearchableDropdownField<int?>(
                          value: _selectedImportFileId,
                          items: importFileOptions,
                          labelText: l.poAssociatedImportFile,
                          onChanged: (newFileId) {
                            setState(() => _selectedImportFileId = newFileId);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Quantities & FOB row
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _quantityController,
                                label: l.poAllocatedQuantity,
                                icon: Icons.straighten_outlined,
                                isRequired: true,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textDirection: TextDirection.ltr,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return l.poQuantityRequired;
                                  }
                                  final n = double.tryParse(val.trim());
                                  if (n == null || n <= 0) {
                                    return l.poQuantityRequired;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _fobAmountController,
                                label: l.poAllocatedFobAmount,
                                icon: Icons.attach_money_outlined,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Shipping Date & Status Row
                        Row(
                          children: [
                            Expanded(
                              child: AppDatePickerField(
                                label: l.poShippingDate,
                                value: _shippingDate,
                                isRequired: true,
                                onChanged: (d) {
                                  if (d != null) {
                                    setState(() => _shippingDate = d);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SearchableDropdownField<String>(
                                value: _allocationStatus,
                                items: statusOptions,
                                labelText: l.poAllocationBatchStatus,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _allocationStatus = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Notes
                        CustomTextField(
                          controller: _notesController,
                          label: l.poAllocationNotes,
                          icon: Icons.notes_outlined,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: l.cancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: l.poSaveAllocationBtn,
                    variant: AppButtonVariant.primary,
                    icon: Icons.check,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
