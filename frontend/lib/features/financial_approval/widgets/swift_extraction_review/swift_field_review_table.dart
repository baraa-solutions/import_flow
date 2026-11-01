import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/financial_approval_model.dart';
import 'swift_field_status_badge.dart';

class SwiftFieldReviewTable extends StatelessWidget {
  final List<SwiftFieldModel> fields;
  final Map<String, TextEditingController> controllers;
  final String? highlightedFieldKey;
  final String? loadingFieldKey;
  final bool isConfirmed;
  final void Function(SwiftFieldModel) onSelectField;
  final void Function(String fieldKey, String value) onSaveField;
  final void Function(String fieldKey) onReExtractField;

  const SwiftFieldReviewTable({
    super.key,
    required this.fields,
    required this.controllers,
    this.highlightedFieldKey,
    this.loadingFieldKey,
    required this.isConfirmed,
    required this.onSelectField,
    required this.onSaveField,
    required this.onReExtractField,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cloudWhite),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.charcoalSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    context.l10n.faSwiftColField,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    context.l10n.faSwiftColValue,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    context.l10n.faSwiftColConfidence,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    context.l10n.status,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    context.l10n.faSwiftColAction,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: fields.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final f = fields[index];
                final isSelected = highlightedFieldKey == f.fieldKey;
                final isLoading = loadingFieldKey == f.fieldKey;

                return InkWell(
                  onTap: () => onSelectField(f),
                  child: Container(
                    color: isSelected
                        ? AppTheme.orangeLight.withValues(alpha: 0.7)
                        : (index.isEven
                            ? AppTheme.white
                            : AppTheme.charcoalSurface.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        // Column 1: Field Name & Code
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (f.swiftFieldCode != null && f.swiftFieldCode!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      margin: const EdgeInsetsDirectional.only(start: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        f.swiftFieldCode!,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.cobalt,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      f.fieldLabel,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (f.isMandatory)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      margin: const EdgeInsetsDirectional.only(start: 4),
                                      decoration: BoxDecoration(
                                        color: f.isEmpty ? AppTheme.crimsonLight : AppTheme.emeraldLight,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        context.l10n.faSwiftMandatoryMark,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: f.isEmpty ? AppTheme.crimson : AppTheme.wcagEmerald,
                                        ),
                                      ),
                                    ),
                                  if (f.isEditedByUser)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.orangeLight,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        context.l10n.faSwiftManuallyEdited,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.wcagOrange,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Column 2: Editable Value Field
                        Expanded(
                          flex: 5,
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 34,
                                  child: TextFormField(
                                    controller: controllers[f.fieldKey],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: (f.fieldKey.contains('amount') ||
                                              f.fieldKey.contains('date') ||
                                              f.fieldKey.contains('reference') ||
                                              f.fieldKey.contains('swift') ||
                                              f.fieldKey.contains('iban'))
                                          ? 'monospace'
                                          : null,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: f.isEmpty && f.isMandatory ? AppTheme.crimson : AppTheme.textMuted,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5),
                                      ),
                                      suffixIcon: isLoading
                                          ? const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: AppLoadingState.inline(),
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.check, size: 14, color: AppTheme.emerald),
                                              tooltip: context.l10n.faSwiftSaveEdit,
                                              onPressed: () {
                                                final curText = controllers[f.fieldKey]?.text ?? '';
                                                onSaveField(f.fieldKey, curText);
                                              },
                                            ),
                                    ),
                                    onFieldSubmitted: (v) => onSaveField(f.fieldKey, v),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
                                tooltip: context.l10n.faSwiftCopyValue,
                                onPressed: () {
                                  final val = controllers[f.fieldKey]?.text ?? '';
                                  CopyHelper.copy(context, val);
                                },
                              ),
                            ],
                          ),
                        ),

                        // Column 3: Confidence Score Progress
                        SizedBox(
                          width: 80,
                          child: Builder(
                            builder: (context) {
                              final scoreVal = (f.confidenceScore > 1.0 ? f.confidenceScore / 100.0 : f.confidenceScore).clamp(0.0, 1.0);
                              final pct = (scoreVal * 100).round();
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$pct%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: scoreVal >= 0.8
                                          ? AppTheme.wcagEmerald
                                          : (scoreVal >= 0.5 ? AppTheme.wcagOrange : AppTheme.crimson),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: scoreVal,
                                      minHeight: 4,
                                      backgroundColor: AppTheme.cloudWhite,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        scoreVal >= 0.8
                                            ? AppTheme.emerald
                                            : (scoreVal >= 0.5 ? AppTheme.orange : AppTheme.crimson),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        // Column 4: Status Icon & Badge
                        SizedBox(
                          width: 70,
                          child: Center(
                            child: SwiftFieldStatusBadge(field: f),
                          ),
                        ),

                        // Column 5: Re-extract single field
                        SizedBox(
                          width: 45,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.refresh, size: 16, color: AppTheme.cobalt),
                              tooltip: context.l10n.faSwiftReExtractField,
                              onPressed: isLoading ? null : () => onReExtractField(f.fieldKey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
