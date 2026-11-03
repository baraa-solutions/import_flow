import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../multimodal_freight_provider.dart';

/// Card managing Ro-Ro (Roll-on/Roll-off) vehicle specs and Bulk cargo parameters.
class RoroBulkSpecsCard extends StatefulWidget {
  final MultimodalFreightRecord? record;
  final Function(Map<String, dynamic> payload) onSave;

  const RoroBulkSpecsCard({
    super.key,
    this.record,
    required this.onSave,
  });

  @override
  State<RoroBulkSpecsCard> createState() => _RoroBulkSpecsCardState();
}

class _RoroBulkSpecsCardState extends State<RoroBulkSpecsCard> {
  bool _isRoroMode = true;

  late final TextEditingController _roroVehicleTypeController;
  late final TextEditingController _roroDimensionsController;
  late final TextEditingController _bulkCargoTypeController;
  late final TextEditingController _bulkTonnageController;
  late final TextEditingController _notesController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _isRoroMode = widget.record?.transportMode != 'BULK';

    _roroVehicleTypeController = TextEditingController(text: widget.record?.roroVehicleType ?? '');
    _roroDimensionsController = TextEditingController(
      text: widget.record != null && widget.record!.roroDimensionsCbm > 0
          ? widget.record!.roroDimensionsCbm.toStringAsFixed(2)
          : '',
    );
    _bulkCargoTypeController = TextEditingController(text: widget.record?.bulkCargoType ?? '');
    _bulkTonnageController = TextEditingController(
      text: widget.record != null && widget.record!.bulkTonnage > 0
          ? widget.record!.bulkTonnage.toStringAsFixed(2)
          : '',
    );
    _notesController = TextEditingController(text: widget.record?.specialHandlingNotes ?? '');
  }

  @override
  void dispose() {
    _roroVehicleTypeController.dispose();
    _roroDimensionsController.dispose();
    _bulkCargoTypeController.dispose();
    _bulkTonnageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    if (_isRoroMode) {
      widget.onSave({
        'transport_mode': 'RORO',
        'roro_vehicle_type': _roroVehicleTypeController.text.trim().toUpperCase(),
        'roro_dimensions_cbm': double.tryParse(_roroDimensionsController.text.trim()) ?? 0.0,
        'special_handling_notes': _notesController.text.trim(),
      });
    } else {
      widget.onSave({
        'transport_mode': 'BULK',
        'bulk_cargo_type': _bulkCargoTypeController.text.trim().toUpperCase(),
        'bulk_tonnage': double.tryParse(_bulkTonnageController.text.trim()) ?? 0.0,
        'special_handling_notes': _notesController.text.trim(),
      });
    }
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isRoroMode ? Icons.directions_car : Icons.scatter_plot,
                        color: AppTheme.cobalt,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRoroMode ? 'مواصفات شحن السيارات والمعدات المدحرجة' : 'مواصفات شحن البضائع الصب',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('شحن مدحرج'),
                        selected: _isRoroMode,
                        onSelected: (sel) => setState(() => _isRoroMode = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('شحن صب'),
                        selected: !_isRoroMode,
                        onSelected: (sel) => setState(() => _isRoroMode = false),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isRoroMode) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _roroVehicleTypeController,
                        decoration: const InputDecoration(labelText: 'نوع المركبة أو الآلية (شاحنة، حافلة، معدة ثقيلة)'),
                        validator: (v) => _isRoroMode && (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _roroDimensionsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'أبعاد المركبة بالمتر المكعب (CBM)'),
                        validator: (v) {
                          if (!_isRoroMode) return null;
                          final val = double.tryParse(v ?? '');
                          if (val == null || val <= 0) return 'قيمة أكبر من صفر';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _bulkCargoTypeController,
                        decoration: const InputDecoration(labelText: 'نوع البضاعة الصب (حبوب، فحم، حديد، كيماويات)'),
                        validator: (v) => !_isRoroMode && (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _bulkTonnageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'إجمالي الحمولة بالأطنان المترية'),
                        validator: (v) {
                          if (_isRoroMode) return null;
                          final val = double.tryParse(v ?? '');
                          if (val == null || val <= 0) return 'قيمة أكبر من صفر';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'تعليمات التخزين، الرفع، والمناولة الخاصة'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: _isRoroMode ? 'حفظ مواصفات الشحن المدحرج' : 'حفظ مواصفات الشحن الصب',
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
