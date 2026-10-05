import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../screens/customs_declaration46_screen.dart';
import '../services/customs_declaration46_calculator.dart';
import '../../../core/widgets/buttons/app_button.dart';
import 'idoc_ui.dart';

/// Search and Clone Previous Customs Declaration 46 Dialog (Screen 23 / UX-CLONE-023)
///
/// Allows users to quickly search previous Customs Declaration 46 assessments
/// by declaration number, file code, supplier, company, or HS Code, and select
/// one to clone into a new editable draft.
class SearchAndCloneCustomsDeclaration46Dialog extends StatefulWidget {
  final List<CustomsDeclarationAssessment> assessments;
  final ValueChanged<CustomsDeclarationAssessment> onSelectDeclaration;

  const SearchAndCloneCustomsDeclaration46Dialog({
    super.key,
    required this.assessments,
    required this.onSelectDeclaration,
  });

  @override
  State<SearchAndCloneCustomsDeclaration46Dialog> createState() =>
      _SearchAndCloneCustomsDeclaration46DialogState();
}

class _SearchAndCloneCustomsDeclaration46DialogState
    extends State<SearchAndCloneCustomsDeclaration46Dialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<CustomsDeclarationAssessment> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.assessments;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      if (lower.isEmpty) {
        _filtered = widget.assessments;
      } else {
        _filtered = widget.assessments.where((a) {
          final decl = a.declarationNo.toLowerCase();
          final file = a.importFileCode.toLowerCase();
          final supp = a.supplierName.toLowerCase();
          final comp = a.companyName.toLowerCase();
          final hs = a.hsCode.toLowerCase();
          final hsDesc = a.hsDescription.toLowerCase();
          final ex = a.exemptionTitle.toLowerCase();
          return decl.contains(lower) ||
              file.contains(lower) ||
              supp.contains(lower) ||
              comp.contains(lower) ||
              hs.contains(lower) ||
              hsDesc.contains(lower) ||
              ex.contains(lower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.borderOf(context),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.copy_all,
                      color: AppTheme.wcagCobalt,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.cloneCustomsDeclDialogTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.cloneCustomsDeclDialogSubtitle,
                          style: TextStyle(
                            fontSize: DisplayDensityMode.clampFontSize(12.0),
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _queryController,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: l.customsDeclRegistrySearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _queryController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceAltOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.borderOf(context),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.borderOf(context),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Count strip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l.customsDeclMetricTotalDeclarations}: ${_filtered.length} / ${widget.assessments.length}',
                    style: TextStyle(
                      fontSize: DisplayDensityMode.clampFontSize(11.5),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  if (_filtered.length != widget.assessments.length)
                    IdocUi.fit(AppButton(
                      label: l.customsDeclCloseDialog,
                      variant: AppButtonVariant.ghost,
                      onPressed: () {
                        _queryController.clear();
                        _filter('');
                      },
                    )),
                ],
              ),
              const SizedBox(height: 8),

              // List of declarations
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.idocANoCustomsDeclarationsMatchTheSearch,
                          style: TextStyle(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final a = _filtered[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAltOf(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.borderOf(context),
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: LayoutBuilder(
                              builder: (ctx, box) {
                                final isNarrow = box.maxWidth < 650;
                                final details = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          a.declarationNo,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: AppTheme.wcagCobalt,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            a.importFileCode,
                                            style: TextStyle(
                                              fontSize: DisplayDensityMode.clampFontSize(11.0),
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.wcagCobalt,
                                            ),
                                          ),
                                        ),
                                        if (a.hasExemption)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.emerald.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AppTheme.wcagEmerald,
                                              ),
                                            ),
                                            child: Text(
                                              'EUR.1 (0%)',
                                              style: TextStyle(
                                                fontSize: DisplayDensityMode.clampFontSize(11.0),
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.wcagEmerald,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${a.supplierName} • ${a.companyName}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimaryOf(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${l.customsDeclColHsCode}: ${a.hsCode} | CIF: ${a.cifEgp.egpOrMissing(l.idocBMissing)} | ${l.customsDeclTotalDutiesLabel}: ${a.totalDutiesEgp.egpOrMissing(l.idocBMissing)}',
                                      style: TextStyle(
                                        fontSize: DisplayDensityMode.clampFontSize(11.0),
                                        color: AppTheme.textSecondaryOf(context),
                                      ),
                                    ),
                                  ],
                                );

                                final actionBtn = IdocUi.fit(AppButton(
                                  key: Key('cloneDeclBtn_${a.declarationNo}'),
                                  label: l.searchAndCloneCustomsDeclBtn,
                                  icon: Icons.copy_all,
                                  variant: AppButtonVariant.primary,
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    widget.onSelectDeclaration(a);
                                  },
                                ));

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      details,
                                      const SizedBox(height: 10),
                                      actionBtn,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: details),
                                    const SizedBox(width: 12),
                                    actionBtn,
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
