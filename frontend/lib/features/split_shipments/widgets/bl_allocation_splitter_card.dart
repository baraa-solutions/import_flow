import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';

/// Card form for splitting Master B/L into partial consignments.
class BlAllocationSplitterCard extends StatefulWidget {
  final String initialParentBl;
  final String? initialSku;
  final double? maxQuantity;
  final Function(Map<String, dynamic> payload) onConfirmSplit;
  final VoidCallback onCancel;

  const BlAllocationSplitterCard({
    super.key,
    required this.initialParentBl,
    this.initialSku,
    this.maxQuantity,
    required this.onConfirmSplit,
    required this.onCancel,
  });

  @override
  State<BlAllocationSplitterCard> createState() =>
      _BlAllocationSplitterCardState();
}

class _BlAllocationSplitterCardState extends State<BlAllocationSplitterCard> {
  late final TextEditingController _parentBlController;
  late final TextEditingController _splitBlController;
  late final TextEditingController _skuController;
  late final TextEditingController _qtyController;
  late final TextEditingController _customsPoolController;
  late final TextEditingController _freightPoolController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _parentBlController = TextEditingController(text: widget.initialParentBl);
    _splitBlController = TextEditingController(
      text: widget.initialParentBl.isNotEmpty ? '${widget.initialParentBl}-A' : '',
    );
    _skuController = TextEditingController(text: widget.initialSku ?? '');
    _qtyController = TextEditingController(
      text: widget.maxQuantity != null ? widget.maxQuantity!.toStringAsFixed(0) : '',
    );
    _customsPoolController = TextEditingController(text: '0');
    _freightPoolController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _parentBlController.dispose();
    _splitBlController.dispose();
    _skuController.dispose();
    _qtyController.dispose();
    _customsPoolController.dispose();
    _freightPoolController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final allocatedQty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final totalQty = widget.maxQuantity ?? allocatedQty;

    widget.onConfirmSplit({
      'parent_bl_number': _parentBlController.text.trim().toUpperCase(),
      'split_bl_number': _splitBlController.text.trim().toUpperCase(),
      'item_sku': _skuController.text.trim(),
      'allocated_quantity': allocatedQty,
      'total_item_quantity': totalQty > 0 ? totalQty : allocatedQty,
      'customs_cost_pool': double.tryParse(_customsPoolController.text.trim()) ?? 0.0,
      'freight_cost_pool': double.tryParse(_freightPoolController.text.trim()) ?? 0.0,
      'currency': 'EGP',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.call_split, color: AppTheme.cobalt, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'تجزئة بوليصة الشحن وتوزيع الكميات',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _parentBlController,
                      decoration: const InputDecoration(labelText: 'بوليصة الشحن الرئيسية'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _splitBlController,
                      decoration: const InputDecoration(labelText: 'بوليصة الشحن الجزئية المستهدفة'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(labelText: 'رمز الصنف / المادة'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'الكمية المخصصة في هذا الجزء',
                        helperText: widget.maxQuantity != null
                            ? 'الحد الأقصى المتاح: ${widget.maxQuantity!.toStringAsFixed(0)}'
                            : null,
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) return 'كمية غير صالحة';
                        if (widget.maxQuantity != null && val > widget.maxQuantity!) {
                          return 'تتجاوز الكمية المتاحة';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _customsPoolController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'مجمع الرسوم الجمركية للتوزيع (جنيه)'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _freightPoolController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'مجمع نولون الشحن للتوزيع (جنيه)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'إلغاء',
                    variant: AppButtonVariant.secondary,
                    onPressed: widget.onCancel,
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'اعتماد التجزئة والتوزيع',
                    icon: Icons.check,
                    variant: AppButtonVariant.primary,
                    onPressed: _handleSubmit,
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
