import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../providers/customs_tariff_provider.dart';
import 'duty_calc_invoice_line_item.dart';
import 'duty_calculator_state.dart';

/// Card listing all individual invoice line items with HS codes, values, origins,
/// exemption settings, and interactive exemption checklist automation.
class DutyCalcInvoiceLinesCard extends StatelessWidget {
  final DutyCalculatorState state;
  final bool isArabic;
  final bool isDark;
  final WidgetRef ref;
  final int? initialImportFileId;

  const DutyCalcInvoiceLinesCard({
    super.key,
    required this.state,
    required this.isArabic,
    required this.isDark,
    required this.ref,
    required this.initialImportFileId,
  });

  @override
  Widget build(BuildContext context) {
    final registeredTariffs =
        ref.watch(customsTariffProvider).valueOrNull ?? [];
    final hsDropdownItems = registeredTariffs
        .map((t) => SearchableDropdownItem<String>(
              value: t.hsCode,
              label: '[${t.hsCode}] ${t.hsDescription}',
              subtitle: isArabic
                  ? 'الوارد: ${t.customsDutyRate}% | ض.م: ${t.vatRate}%'
                  : 'Duty: ${t.customsDutyRate}% | VAT: ${t.vatRate}%',
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lines Table Title & Add Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'سطور الفاتورة:' : 'Invoice Line Items:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
                fontSize: 13,
              ),
            ),
            AppButton(
              label: isArabic ? 'إضافة صنف +' : 'Add Item +',
              icon: Icons.add,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: state.addLine,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Multi-Lines Input List
        ...state.multiLines.asMap().entries.map((entry) {
          return DutyCalcInvoiceLineItem(
            key: ValueKey(entry.key),
            index: entry.key,
            line: entry.value,
            state: state,
            isArabic: isArabic,
            isDark: isDark,
            registeredTariffs: registeredTariffs,
            hsDropdownItems: hsDropdownItems,
            ref: ref,
            initialImportFileId: initialImportFileId,
          );
        }),
      ],
    );
  }
}
