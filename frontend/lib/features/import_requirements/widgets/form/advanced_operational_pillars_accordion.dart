import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../advanced/advanced_pillars.dart';

/// 🏛️ Advanced Operational Pillars Accordion — ImportFlow ERP
///
/// Houses the four specialized compliance pillars (CargoX Pre-ACID Verification,
/// Conditional Shelf Life & EOS Inspection, Regulatory Testing Laboratories,
/// and Hazardous Materials & Dangerous Goods) in an expandable panel.
class AdvancedOperationalPillarsAccordion extends StatefulWidget {
  final String? supplierName;
  final String? supplierCountry;
  final String? cargoxId;
  final String cargoxStatus;
  final ValueChanged<CargoXPreAcidData>? onCargoXChanged;

  final bool isShelflifeApplicable;
  final String? eosSpecNumber;
  final ValueChanged<ShelfLifeEosData>? onShelfLifeChanged;

  final bool samplingRequired;
  final String? labType;
  final ValueChanged<TestingLabTrackData>? onTestingLabChanged;

  final bool isHazmat;
  final String? imoClass;
  final ValueChanged<HazardousMaterialsData>? onHazmatChanged;

  const AdvancedOperationalPillarsAccordion({
    super.key,
    this.supplierName,
    this.supplierCountry,
    this.cargoxId,
    this.cargoxStatus = 'PENDING',
    this.onCargoXChanged,
    this.isShelflifeApplicable = false,
    this.eosSpecNumber,
    this.onShelfLifeChanged,
    this.samplingRequired = false,
    this.labType,
    this.onTestingLabChanged,
    this.isHazmat = false,
    this.imoClass,
    this.onHazmatChanged,
  });

  @override
  State<AdvancedOperationalPillarsAccordion> createState() => _AdvancedOperationalPillarsAccordionState();
}

class _AdvancedOperationalPillarsAccordionState extends State<AdvancedOperationalPillarsAccordion> {
  bool _isExpanded = false;
  int _selectedSubTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cloudWhite),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Toggle Bar
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppTheme.cobalt, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.advancedOperationalPillarsAccordionTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active Safeguard Pills
                  if (widget.cargoxStatus == 'VERIFIED')
                    _buildPill(l10n.cargoXStatusVerified, AppTheme.emerald),
                  if (widget.isShelflifeApplicable)
                    _buildPill(l10n.shelfLifeSubjectCheckbox, AppTheme.orange),
                  if (widget.samplingRequired)
                    _buildPill(l10n.testingLabsTrackHeader, AppTheme.cobalt),
                  if (widget.isHazmat)
                    _buildPill(l10n.hazardousMaterialsHeader, AppTheme.crimson),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.charcoal,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (_isExpanded) ...[
            const Divider(height: 1),
            // Sub Tabs Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: AppTheme.charcoalSurface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSubTab(0, l10n.cargoXPreAcidHeader, Icons.verified_user_outlined),
                    _buildSubTab(1, l10n.shelfLifeEosHeader, Icons.timelapse_outlined),
                    _buildSubTab(2, l10n.testingLabsTrackHeader, Icons.science_outlined),
                    _buildSubTab(3, l10n.hazardousMaterialsHeader, Icons.warning_amber_rounded),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: IndexedStack(
                index: _selectedSubTabIndex,
                children: [
                  CargoXPreAcidCheckCard(
                    supplierName: widget.supplierName,
                    supplierCountry: widget.supplierCountry,
                    initialCargoxId: widget.cargoxId,
                    initialStatus: widget.cargoxStatus,
                    onChanged: widget.onCargoXChanged,
                  ),
                  ShelfLifeEosInspectionCard(
                    initialSubjectToShelfLife: widget.isShelflifeApplicable,
                    initialEosSpecNumber: widget.eosSpecNumber,
                    onChanged: widget.onShelfLifeChanged,
                  ),
                  TestingLaboratoriesTrackCard(
                    initialLaboratory: widget.labType ?? 'GOEIC_LAB',
                    onChanged: widget.onTestingLabChanged,
                  ),
                  HazardousMaterialsCard(
                    initialIsHazardous: widget.isHazmat,
                    initialImdgClass: widget.imoClass ?? 'CLASS_3',
                    onChanged: widget.onHazmatChanged,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPill(String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildSubTab(int index, String label, IconData icon) {
    final isSelected = _selectedSubTabIndex == index;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 14,
          color: isSelected ? AppTheme.white : AppTheme.charcoal,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.white : AppTheme.charcoal,
          ),
        ),
        selected: isSelected,
        selectedColor: AppTheme.cobalt,
        backgroundColor: AppTheme.white,
        side: BorderSide(
          color: isSelected ? AppTheme.cobalt : AppTheme.cloudWhite,
        ),
        onSelected: (_) => setState(() => _selectedSubTabIndex = index),
      ),
    );
  }
}
