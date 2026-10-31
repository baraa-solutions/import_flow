import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/navigation_provider.dart';
import '../models/freight_quotation_model.dart';
import 'freight_rfq_details_dialog.dart';
import 'freight_rfq_load_dialog.dart';

class FreightHeaderActions extends ConsumerWidget {
  final List<FreightRFQRequestModel> rfqs;
  final ValueChanged<FreightRFQRequestModel> onRfqLoaded;
  final VoidCallback onResetForm;

  const FreightHeaderActions({
    super.key,
    required this.rfqs,
    required this.onRfqLoaded,
    required this.onResetForm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = context.l10n.isArabic;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: Text(isArabic ? 'استدعاء طلب مسجل' : 'Load Saved RFQ'),
          onPressed: () => FreightRfqLoadDialog.show(
            context,
            ref,
            rfqs: rfqs,
            onLoadRfq: onRfqLoaded,
            onViewDetails: (rfq) => FreightRfqDetailsDialog.show(context, ref, rfq: rfq),
          ),
        ),
        const SizedBox(width: 6),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: Text(isArabic ? 'طلب جديد' : 'New RFQ'),
          onPressed: onResetForm,
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.amber.shade300,
            side: BorderSide(color: Colors.amber.shade300),
          ),
          icon: const Icon(Icons.analytics_outlined, size: 18),
          label: Text(isArabic ? 'دراسات النولون والسجلات' : 'Freight Studies & Log'),
          onPressed: () => selectNavigationIndex(ref, 4),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}
