import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../external_service_providers/models/partner_model.dart';

/// Header banner and Recipient selector bar for FreightRfqDialog
class FreightRfqHeader extends StatelessWidget {
  final String titleCode;
  final VoidCallback onClose;

  const FreightRfqHeader({
    super.key,
    required this.titleCode,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(12),
          topEnd: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined, color: AppTheme.cobalt, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.freightRfqTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${l.importFileIdLabel}: $titleCode',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Recipient filter bar for FreightRfqDialog
class FreightRfqRecipientBar extends StatelessWidget {
  final List<PartnerModel> partners;
  final TextEditingController recipientController;
  final ValueChanged<String?> onSelectPartner;
  final ValueChanged<String> onSubmitRecipient;

  const FreightRfqRecipientBar({
    super.key,
    required this.partners,
    required this.recipientController,
    required this.onSelectPartner,
    required this.onSubmitRecipient,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cloudWhite,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_outlined, color: AppTheme.cobalt, size: 20),
          const SizedBox(width: 8),
          Text(l.freightRfqRecipient, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                if (partners.isNotEmpty) ...[
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField<String?>(
                      value: recipientController.text.isNotEmpty ? recipientController.text : null,
                      labelText: l.freightRfqSelectLineHint,
                      searchHintText: l.search,
                      items: partners
                          .map((p) => SearchableDropdownItem<String?>(
                                value: p.partnerName,
                                label: p.partnerName,
                                subtitle: p.partnerType,
                              ))
                          .toList(),
                      onChanged: onSelectPartner,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: recipientController,
                    decoration: InputDecoration(
                      hintText: l.freightRfqTypePersonHint,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, size: 18, color: AppTheme.cobalt),
                        tooltip: l.freightRfqUpdateTextTooltip,
                        onPressed: () => onSubmitRecipient(recipientController.text),
                      ),
                    ),
                    onSubmitted: onSubmitRecipient,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(l.freightRfqUpdateBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.cobalt,
              side: const BorderSide(color: AppTheme.cobalt),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: () => onSubmitRecipient(recipientController.text),
          ),
        ],
      ),
    );
  }
}
