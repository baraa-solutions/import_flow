import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../customs_ui.dart';
import '../cc_dialog_shell.dart';

class CustomsInspectionSamplingSection extends StatelessWidget {
  final bool isSampleDrawn;
  final ValueChanged<bool> onSampleDrawnChanged;
  final TextEditingController samplingRecordController;
  final DateTime samplingDate;
  final VoidCallback onPickSamplingDate;
  final Set<String> selectedSampledBodies;
  final List<String> regulatoryAgencyOptions;
  final ValueChanged<Set<String>> onSampledBodiesChanged;
  final TextEditingController goeicCertController;
  final TextEditingController labFeesController;
  final String selectedSampleTestStatus;
  final ValueChanged<String> onSampleTestStatusChanged;
  final InputDecoration Function(String label, {String? hint, IconData? icon, Widget? suffix, String? suffixText}) dec;

  const CustomsInspectionSamplingSection({
    super.key,
    required this.isSampleDrawn,
    required this.onSampleDrawnChanged,
    required this.samplingRecordController,
    required this.samplingDate,
    required this.onPickSamplingDate,
    required this.selectedSampledBodies,
    required this.regulatoryAgencyOptions,
    required this.onSampledBodiesChanged,
    required this.goeicCertController,
    required this.labFeesController,
    required this.selectedSampleTestStatus,
    required this.onSampleTestStatusChanged,
    required this.dec,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return CcFormSection(
      title: l.ccInsSection2,
      icon: Icons.science_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: isSampleDrawn,
            contentPadding: EdgeInsets.zero,
            title: Text(
              l.ccInsSampleSwitchTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            subtitle: Text(
              isSampleDrawn ? l.ccInsSampleSwitchOn : l.ccInsSampleSwitchOff,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
            ),
            activeThumbColor: AppTheme.emerald,
            onChanged: onSampleDrawnChanged,
          ),
          const SizedBox(height: 8),
          if (isSampleDrawn) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: samplingRecordController,
                    textDirection: TextDirection.ltr,
                    decoration: dec(
                      l.ccInsSampleRecordLabel,
                      hint: l.ccInsSampleRecordHint,
                      icon: Icons.numbers_rounded,
                    ),
                    validator: (val) {
                      if (isSampleDrawn && (val == null || val.trim().length < 3)) {
                        return l.ccInsSamplingNoRequired;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: onPickSamplingDate,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: InputDecorator(
                      decoration: dec(l.ccInsSampleDateLabel, icon: Icons.event_note_rounded),
                      child: LtrText(
                        CcFormat.date(samplingDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(l.ccInsBodiesLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            FormField<Set<String>>(
              validator: (_) {
                if (isSampleDrawn && selectedSampledBodies.isEmpty) {
                  return l.ccInsBodiesRequired;
                }
                return null;
              },
              builder: (state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: regulatoryAgencyOptions.map((agency) {
                        final isSelected = selectedSampledBodies.contains(agency);
                        return FilterChip(
                          label: Text(
                            DomainEnums.label(l, DomainEnumType.regulatoryBody, agency),
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.cobaltMedium,
                          checkmarkColor: AppTheme.cobalt,
                          onSelected: (selected) {
                            final updated = Set<String>.from(selectedSampledBodies);
                            if (selected) {
                              updated.add(agency);
                            } else {
                              updated.remove(agency);
                            }
                            onSampledBodiesChanged(updated);
                            state.didChange(updated);
                          },
                        );
                      }).toList(),
                    ),
                    if (state.hasError) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4),
                        child: Text(
                          state.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: goeicCertController,
                    textDirection: TextDirection.ltr,
                    decoration: dec(l.ccInsGoeicLabel, hint: l.ccInsGoeicHint, icon: Icons.verified_rounded),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: labFeesController,
                    textDirection: TextDirection.ltr,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: dec(l.ccInsLabFeesLabel, icon: Icons.payments_rounded, suffixText: 'EGP'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(l.ccInsTestStatusLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSampleStatusChip(
                  context,
                  'Samples Under Testing',
                  l.ccInsStatusTesting,
                  Icons.hourglass_top_rounded,
                  AppTheme.orange,
                ),
                _buildSampleStatusChip(
                  context,
                  'Approved',
                  l.ccInsStatusApproved,
                  Icons.check_circle_rounded,
                  AppTheme.emerald,
                ),
                _buildSampleStatusChip(
                  context,
                  'Rejected',
                  l.ccInsStatusRejected,
                  Icons.cancel_rounded,
                  AppTheme.crimson,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSampleStatusChip(
    BuildContext context,
    String code,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = selectedSampleTestStatus == code;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? color : AppTheme.textSecondaryOf(context)),
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.15),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected ? color : AppTheme.textPrimaryOf(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : AppTheme.borderOf(context),
        width: isSelected ? 1.5 : 1,
      ),
      onSelected: (selected) {
        if (selected) onSampleTestStatusChanged(code);
      },
    );
  }
}
