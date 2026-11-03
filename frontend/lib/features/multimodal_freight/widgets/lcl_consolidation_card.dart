import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../multimodal_freight_provider.dart';

/// Card managing LCL cargo consolidation parameters, CBM rates, and CFS fees.
class LclConsolidationCard extends StatefulWidget {
  final MultimodalFreightRecord? record;
  final Function(Map<String, dynamic> payload) onSave;

  const LclConsolidationCard({
    super.key,
    this.record,
    required this.onSave,
  });

  @override
  State<LclConsolidationCard> createState() => _LclConsolidationCardState();
}

class _LclConsolidationCardState extends State<LclConsolidationCard> {
  late final TextEditingController _cbmController;
  late final TextEditingController _rateController;
  late final TextEditingController _cfsController;
  final _formKey = GlobalKey<FormState>();

  double _calculatedSubtotal = 0.0;

  @override
  void initState() {
    super.initState();
    _cbmController = TextEditingController(
      text: widget.record != null && widget.record!.lclCbm > 0
          ? widget.record!.lclCbm.toStringAsFixed(2)
          : '',
    );
    _rateController = TextEditingController(
      text: widget.record != null && widget.record!.lclRatePerCbm > 0
          ? widget.record!.lclRatePerCbm.toStringAsFixed(2)
          : '',
    );
    _cfsController = TextEditingController(
      text: widget.record != null && widget.record!.lclCfsFee > 0
          ? widget.record!.lclCfsFee.toStringAsFixed(2)
          : '',
    );

    _updateSubtotal();
    _cbmController.addListener(_updateSubtotal);
    _rateController.addListener(_updateSubtotal);
    _cfsController.addListener(_updateSubtotal);
  }

  @override
  void dispose() {
    _cbmController.dispose();
    _rateController.dispose();
    _cfsController.dispose();
    super.dispose();
  }

  void _updateSubtotal() {
    final cbm = double.tryParse(_cbmController.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;
    final cfs = double.tryParse(_cfsController.text.trim()) ?? 0.0;
    setState(() {
      _calculatedSubtotal = (cbm * rate) + cfs;
    });
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave({
      'transport_mode': 'LCL',
      'lcl_cbm': double.tryParse(_cbmController.text.trim()) ?? 0.0,
      'lcl_rate_per_cbm': double.tryParse(_rateController.text.trim()) ?? 0.0,
      'lcl_cfs_fee': double.tryParse(_cfsController.text.trim()) ?? 0.0,
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
                  Icon(Icons.inventory_2_outlined, color: AppTheme.cobalt, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'شحن الحاويات المشترك (LCL) ورسوم محطة الفرز',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cbmController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'حجم الشحنة (CBM) بالمتر المكعب'),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) return 'قيمة CBM مطلوبة وأكبر من صفر';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _rateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'سعر النولون لكل متر مكعب'),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val < 0) return 'سعر غير صالح';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cfsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'رسوم تفريغ محطة الحاويات (CFS)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Live cost preview box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إجمالي نولون الشحن المشترك المقدر:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    Text(
                      '${_calculatedSubtotal.toStringAsFixed(2)} دولار',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.cobalt,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'حفظ بيانات الشحن المشترك',
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
