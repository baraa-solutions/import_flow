import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/customs_clearance_quotations_provider.dart';
import 'quotation_dialogs.dart';
import 'smart_clearance_extractor_dialog.dart';

class SmartExtractorLauncher {
  static Future<void> launch(
    BuildContext context,
    WidgetRef ref, {
    int? targetRfqId,
  }) async {
    await showSmartClearanceExtractorDialog(
      context,
      ref,
      targetRfqId: targetRfqId,
      onExtracted: (extracted) async {
        int? rfqId = targetRfqId;
        if (rfqId == null) {
          final rfqs = ref.read(customsClearanceQuotationsProvider).value ?? [];
          final activeRfqs = rfqs.where((r) => r.status != 'Awarded' && r.status != 'Cancelled').toList();
          if (activeRfqs.isNotEmpty) {
            rfqId = await showDialog<int>(
              context: context,
              builder: (ctx) {
                int? selected;
                return StatefulBuilder(
                  builder: (ctx, setPickerState) {
                    final l = ctx.l10n;
                    return Dialog(
                      backgroundColor: AppTheme.surfaceOf(ctx),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
                      child: SelectionArea(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.link_rounded, color: AppTheme.cobalt),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        l.isArabic ? 'ربط عرض السعر المستخرج بطلب أسعار' : 'Link Extracted Quote to RFQ',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l.isArabic
                                      ? 'اختر طلب عرض الأسعار المستهدف لإضافة هذا العرض إليه:'
                                      : 'Select the target RFQ to attach this quotation to:',
                                  style: TextStyle(color: AppTheme.textSecondaryOf(ctx), fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                SearchableDropdownField<int>(
                                  value: selected,
                                  labelText: l.isArabic ? 'طلب عرض السعر (RFQ)' : 'Target RFQ',
                                  searchHintText: l.searchPlaceholder,
                                  items: activeRfqs
                                      .map((r) => SearchableDropdownItem<int>(
                                            value: r.rfqId,
                                            label: '${r.rfqCode} - ${r.title}',
                                          ))
                                      .toList(),
                                  onChanged: (val) => setPickerState(() => selected = val),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    AppButton(
                                      label: l.cancel,
                                      variant: AppButtonVariant.secondary,
                                      size: AppButtonSize.small,
                                      onPressed: () => Navigator.pop(ctx, null),
                                    ),
                                    const SizedBox(width: 8),
                                    AppButton(
                                      label: l.confirm,
                                      variant: AppButtonVariant.primary,
                                      size: AppButtonSize.small,
                                      onPressed: selected != null ? () => Navigator.pop(ctx, selected) : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        }

        if (!context.mounted) return;
        if (rfqId != null) {
          showAddQuotationDialog(context, ref, rfqId, prefill: extracted);
        } else {
          showCreateRfqDialog(context, ref, initialPortName: extracted['port_name']?.toString());
        }
      },
    );
  }
}
