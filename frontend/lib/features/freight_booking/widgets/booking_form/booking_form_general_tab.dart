import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../../shipping_scenarios/models/shipping_scenario_model.dart';
import '../freight_booking_quote_card.dart';

/// General booking section covering file attachment, confirmation number, and evaluated quotes.
class BookingFormGeneralTab extends StatelessWidget {
  final int? selectedImportFileId;
  final TextEditingController bookingConfirmNoController;
  final List<dynamic> importFiles;
  final List<ShippingEvaluationModel> matchingSessions;
  final int? selectedScenarioItemId;
  final String? selectedScenarioProviderName;
  final String vesselName;
  final ValueChanged<int?> onImportFileChanged;
  final void Function(ShippingEvaluationModel session, ShippingScenarioItemModel item) onApplyScenarioQuote;

  const BookingFormGeneralTab({
    super.key,
    required this.selectedImportFileId,
    required this.bookingConfirmNoController,
    required this.importFiles,
    required this.matchingSessions,
    required this.selectedScenarioItemId,
    required this.selectedScenarioProviderName,
    required this.vesselName,
    required this.onImportFileChanged,
    required this.onApplyScenarioQuote,
  });

  Widget _quotesSection(BuildContext context, AppLocalizations l) {
    final pairs = <(ShippingEvaluationModel, ShippingScenarioItemModel)>[
      for (final s in matchingSessions)
        for (final item in s.items) (s, item),
    ];

    return CcFormSection(
      title: l.freightBookingEvaluatedQuotesHeader,
      icon: Icons.local_shipping,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pairs.isEmpty)
            Text(
              l.freightBookingNoEvaluatedQuotes,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            )
          else ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                AppStatusBadge(
                  label: l.freightBookingAvailableQuotesBadge(pairs.length),
                  severity: AppSeverity.info,
                  size: AppStatusBadgeSize.small,
                ),
                Text(
                  l.freightBookingApplyQuoteInstruction,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final pair in pairs)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: FbkQuoteCard(
                  session: pair.$1,
                  item: pair.$2,
                  isSelected: selectedScenarioItemId == pair.$2.itemId ||
                      (selectedScenarioProviderName == pair.$2.providerName &&
                          vesselName == pair.$2.vesselName),
                  onApply: () => onApplyScenarioQuote(pair.$1, pair.$2),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CcFormSection(
          title: l.fbkSectionFile,
          icon: Icons.folder_special,
          child: CcFieldRow(
            children: [
              CcField(
                label: l.freightBookingImportFileLabel,
                child: SearchableDropdownField<int?>(
                  value: selectedImportFileId,
                  labelText: l.freightBookingImportFileLabel,
                  searchHintText: l.freightBookingImportFileHint,
                  hintText: l.fbkSelectHint,
                  decoration: ccInputDecoration(hint: l.fbkSelectHint),
                  validator: (_) => selectedImportFileId == null ? l.fbkValidatorImportFile : null,
                  items: importFiles
                      .map((f) => SearchableDropdownItem<int?>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} (${f.companyName})',
                            subtitle: f.supplierName,
                          ))
                      .toList(),
                  onChanged: onImportFileChanged,
                ),
              ),
              CcField(
                label: l.freightBookingConfirmNoInputLabel,
                child: TextFormField(
                  controller: bookingConfirmNoController,
                  textDirection: TextDirection.ltr,
                  decoration: ccInputDecoration(prefix: Icons.confirmation_number_outlined),
                ),
              ),
            ],
          ),
        ),
        if (selectedImportFileId != null) ...[
          const SizedBox(height: 12),
          _quotesSection(context, l),
        ],
      ],
    );
  }
}
