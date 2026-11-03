import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../customs_clearance/widgets/cc_dialog_shell.dart';
import 'demurrage_lookups.dart';

/// Interactive section to add and view ancillary port/terminal fees.
class AncillaryFeesSection extends StatefulWidget {
  final List<Map<String, dynamic>> fees;
  final VoidCallback onFeesChanged;

  const AncillaryFeesSection({
    super.key,
    required this.fees,
    required this.onFeesChanged,
  });

  @override
  State<AncillaryFeesSection> createState() => _AncillaryFeesSectionState();
}

class _AncillaryFeesSectionState extends State<AncillaryFeesSection> {
  final TextEditingController _customFeeNameController = TextEditingController();
  final TextEditingController _customFeeAmountController = TextEditingController();
  String _customFeeCurrency = 'USD';

  @override
  void dispose() {
    _customFeeNameController.dispose();
    _customFeeAmountController.dispose();
    super.dispose();
  }

  void _addFee() {
    final name = _customFeeNameController.text.trim();
    final amt = double.tryParse(_customFeeAmountController.text.trim());
    if (name.isNotEmpty && amt != null && amt > 0) {
      setState(() {
        widget.fees.add({
          'fee_name': name,
          'fee_amount': amt,
          'currency': _customFeeCurrency,
        });
        _customFeeNameController.clear();
        _customFeeAmountController.clear();
      });
      widget.onFeesChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CcFormSection(
      title: 'الرسوم الإضافية بالمحطة',
      icon: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SearchableDropdownField<String>(
                  labelText: 'نوع الرسم الإضافي',
                  value: _customFeeNameController.text.isNotEmpty
                      ? _customFeeNameController.text
                      : null,
                  items: DemurrageLookups.ancillaryFeeTypes
                      .map((f) => SearchableDropdownItem(value: f, label: f))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _customFeeNameController.text = v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _customFeeAmountController,
                  decoration: ccInputDecoration(
                    prefix: Icons.attach_money_rounded,
                    hint: 'المبلغ',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: SearchableDropdownField<String>(
                  labelText: 'العملة',
                  value: _customFeeCurrency,
                  items: const [
                    SearchableDropdownItem(value: 'USD', label: 'USD'),
                    SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                  ],
                  onChanged: (c) {
                    if (c != null) setState(() => _customFeeCurrency = c);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: AppButton(
                  label: 'إضافة',
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: _addFee,
                ),
              ),
            ],
          ),
          if (widget.fees.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.fees.asMap().entries.map((entry) {
                final idx = entry.key;
                final fee = entry.value;
                final feeName = fee['fee_name'] ?? fee['fee_type'] ?? 'رسم إضافي';
                final feeAmt = fee['fee_amount'] ?? fee['amount_usd'] ?? 0;
                final feeCurr = fee['currency'] ?? 'USD';
                return Chip(
                  backgroundColor: AppTheme.cobalt.withValues(alpha: 0.08),
                  label: Text(
                    '$feeName: $feeAmt $feeCurr',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() => widget.fees.removeAt(idx));
                    widget.onFeesChanged();
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
