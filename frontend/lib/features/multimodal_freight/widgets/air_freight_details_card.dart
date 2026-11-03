import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../multimodal_freight_provider.dart';

/// Card displaying Air Freight particulars: AWB, Airline, Flight, and THC fees.
class AirFreightDetailsCard extends StatefulWidget {
  final MultimodalFreightRecord? record;
  final Function(Map<String, dynamic> payload) onSave;

  const AirFreightDetailsCard({
    super.key,
    this.record,
    required this.onSave,
  });

  @override
  State<AirFreightDetailsCard> createState() => _AirFreightDetailsCardState();
}

class _AirFreightDetailsCardState extends State<AirFreightDetailsCard> {
  late final TextEditingController _awbController;
  late final TextEditingController _airlineController;
  late final TextEditingController _flightController;
  late final TextEditingController _thcController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _awbController = TextEditingController(text: widget.record?.awbNumber ?? '');
    _airlineController = TextEditingController(text: widget.record?.airlineCode ?? '');
    _flightController = TextEditingController(text: widget.record?.flightNumber ?? '');
    _thcController = TextEditingController(
      text: widget.record != null ? widget.record!.terminalHandlingCharges.toStringAsFixed(2) : '0.00',
    );
  }

  @override
  void dispose() {
    _awbController.dispose();
    _airlineController.dispose();
    _flightController.dispose();
    _thcController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave({
      'transport_mode': 'AIR',
      'awb_number': _awbController.text.trim().toUpperCase(),
      'airline_code': _airlineController.text.trim().toUpperCase(),
      'flight_number': _flightController.text.trim().toUpperCase(),
      'terminal_handling_charges': double.tryParse(_thcController.text.trim()) ?? 0.0,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.flight_takeoff, color: AppTheme.cobalt, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'بيانات الشحن الجوي ومناولة المطار',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.record?.awbNumber != null && widget.record!.awbNumber!.isNotEmpty)
                    AppButton(
                      label: 'نسخ رقم البوليصة الجوية',
                      icon: Icons.copy,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => CopyHelper.copy(context, widget.record!.awbNumber!),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _awbController,
                      decoration: const InputDecoration(labelText: 'رقم بوليصة الشحن الجوي (AWB)'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب للشحن الجوي' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _airlineController,
                      decoration: const InputDecoration(labelText: 'رمز الناقل الجوي (مثال: MS)'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _flightController,
                      decoration: const InputDecoration(labelText: 'رقم الرحلة الجوية'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _thcController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'رسوم مناولة المحطة بمطار الوصول (THC)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'حفظ بيانات الشحن الجوي',
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
