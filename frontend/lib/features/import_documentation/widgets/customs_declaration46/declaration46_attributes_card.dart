import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../idoc_ui_b.dart';

class Declaration46AttributesCard extends StatelessWidget {
  final TextEditingController declaration46NoCtrl;
  final TextEditingController submissionDateCtrl;
  final TextEditingController acidNumberCtrl;
  final TextEditingController form4NumberCtrl;
  final TextEditingController blNumberCtrl;
  final String? selectedOffice;
  final String? selectedChannel;
  final ValueChanged<String?> onOfficeChanged;
  final ValueChanged<String?> onChannelChanged;
  final VoidCallback onSelectDate;
  final double maxWidth;

  const Declaration46AttributesCard({
    super.key,
    required this.declaration46NoCtrl,
    required this.submissionDateCtrl,
    required this.acidNumberCtrl,
    required this.form4NumberCtrl,
    required this.blNumberCtrl,
    required this.selectedOffice,
    required this.selectedChannel,
    required this.onOfficeChanged,
    required this.onChannelChanged,
    required this.onSelectDate,
    required this.maxWidth,
  });

  static const List<String> customsOffices = [
    'Alexandria Port Customs',
    'El Dekheila Port Customs',
    'Port Said Customs',
    'Damietta Port Customs',
    'Sokhna Port Customs',
    'Cairo Airport Cargo Customs',
    '6th of October Dry Port Customs',
    '10th of Ramadan Dry Port Customs',
    'Adabiya Port Customs',
  ];

  static const List<String> channelOptions = [
    'Red Channel',
    'Yellow Channel',
    'Green Channel',
  ];

  static String officeLabel(AppLocalizations l, int index) {
    switch (index) {
      case 0:
        return l.ccDecOffice0;
      case 1:
        return l.ccDecOffice1;
      case 2:
        return l.ccDecOffice2;
      case 3:
        return l.ccDecOffice3;
      case 4:
        return l.ccDecOffice4;
      case 5:
        return l.ccDecOffice5;
      case 6:
        return l.ccDecOffice6;
      case 7:
        return l.ccDecOffice7;
      default:
        return l.ccDecOffice8;
    }
  }

  static String channelLabel(AppLocalizations l, String code) {
    switch (code) {
      case 'Red Channel':
        return l.ccDecChRed;
      case 'Yellow Channel':
        return l.ccDecChYellow;
      case 'Green Channel':
        return l.ccDecChGreen;
      default:
        return code;
    }
  }

  Widget _copyField(
    BuildContext context,
    Key key,
    TextEditingController ctrl,
    String label,
    IconData icon,
    AppLocalizations l, {
    bool bold = false,
    bool ltr = false,
    Color? accent,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: key,
      controller: ctrl,
      textDirection: ltr ? TextDirection.ltr : null,
      style: bold ? TextStyle(fontWeight: FontWeight.bold, color: accent) : null,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: accent),
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: l.customsDeclCopyValueTooltip,
          onPressed: () => CopyHelper.copy(context, ctrl.text),
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _fieldsRow(double width, double breakpoint, List<Widget> fields, {List<int>? flex}) {
    if (width < breakpoint) {
      return Column(
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            fields[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(flex: flex?[i] ?? 1, child: fields[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IdocBSectionCard(
      icon: Icons.assignment_outlined,
      title: l.customsDeclAttributesHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldsRow(
            maxWidth,
            600,
            [
              _copyField(
                context,
                const Key('decl46NoField'),
                declaration46NoCtrl,
                l.customsDeclDeclarationNoLabel,
                Icons.pin,
                l,
                bold: true,
                accent: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return l.customsDeclRequiredField;
                  }
                  if (val.trim().length < 3) {
                    return l.customsDeclMinLength;
                  }
                  return null;
                },
              ),
              TextFormField(
                key: const Key('decl46DateField'),
                controller: submissionDateCtrl,
                readOnly: true,
                onTap: onSelectDate,
                validator: (val) => val == null || val.trim().isEmpty ? l.customsDeclRequiredField : null,
                decoration: InputDecoration(
                  labelText: l.customsDeclSubmissionDateLabel,
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_month, size: 18),
                    tooltip: l.customsDeclPickDateTooltip,
                    onPressed: onSelectDate,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            flex: const [2, 1],
          ),
          const SizedBox(height: 16),
          _fieldsRow(
            maxWidth,
            768,
            [
              SearchableDropdownField<String>(
                key: const Key('decl46OfficeDropdown'),
                labelText: l.ccDecOfficeLabel,
                hintText: l.ccDecOfficeHint,
                items: [
                  for (var i = 0; i < customsOffices.length; i++)
                    SearchableDropdownItem<String>(
                      value: customsOffices[i],
                      label: officeLabel(l, i) == customsOffices[i]
                          ? customsOffices[i]
                          : '${officeLabel(l, i)} (${customsOffices[i]})',
                    ),
                ],
                value: selectedOffice,
                isRequired: true,
                validator: (_) => selectedOffice == null ? l.fieldRequired : null,
                onChanged: onOfficeChanged,
              ),
              SearchableDropdownField<String>(
                key: const Key('decl46ChannelDropdown'),
                labelText: l.customsDeclChannelLabel,
                items: [
                  for (final ch in channelOptions)
                    SearchableDropdownItem<String>(
                      value: ch,
                      label: '${channelLabel(l, ch)} ($ch)',
                    ),
                ],
                value: selectedChannel,
                isRequired: true,
                validator: (_) => selectedChannel == null ? l.fieldRequired : null,
                onChanged: onChannelChanged,
              ),
            ],
            flex: const [1, 1],
          ),
          const SizedBox(height: 16),
          _fieldsRow(
            maxWidth,
            768,
            [
              _copyField(context, const Key('decl46AcidField'), acidNumberCtrl, l.customsDeclAcidNumberLabel, Icons.qr_code, l, ltr: true),
              _copyField(context, const Key('decl46Form4Field'), form4NumberCtrl, l.customsDeclForm4NumberLabel, Icons.account_balance, l),
              _copyField(context, const Key('decl46BlField'), blNumberCtrl, l.customsDeclBlNumberLabel, Icons.assignment, l, ltr: true),
            ],
          ),
        ],
      ),
    );
  }
}
