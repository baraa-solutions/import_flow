import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'extractor_types.dart';

class ExtractorDialogHeader extends StatelessWidget {
  final EntityTarget target;
  final VoidCallback? onClose;

  const ExtractorDialogHeader({
    super.key,
    required this.target,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.orange, size: 22),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic
                        ? 'أداة التكويد والاستخراج الذكي: ${getTargetName(context, target)}'
                        : 'AI Entity Extractor & Registration: ${getTargetName(context, target)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? 'محرك التحليل الذكي للوثائق والتكويد الفوري لقواعد البيانات'
                        : 'Intelligent Document Parsing & Master Data Onboarding Engine',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: onClose ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class ExtractorTargetSelectorBar extends StatelessWidget {
  final EntityTarget selectedTarget;
  final ValueChanged<EntityTarget> onTargetSelected;

  const ExtractorTargetSelectorBar({
    super.key,
    required this.selectedTarget,
    required this.onTargetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              isArabic ? 'توجيه التكويد المباشر إلى:' : 'Direct Entity Target:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
            ),
            const SizedBox(width: 12),
            _buildChip(EntityTarget.supplier, isArabic ? 'مورد أجنبي' : 'Foreign Supplier', Icons.public),
            _buildChip(EntityTarget.company, isArabic ? 'شركة مستوردة' : 'Importing Company', Icons.business_rounded),
            _buildChip(EntityTarget.customsBroker, isArabic ? 'مخلص جمركي' : 'Customs Broker', Icons.badge_rounded),
            _buildChip(EntityTarget.shippingLine, isArabic ? 'خط ملاحي' : 'Shipping Line', Icons.directions_boat_rounded),
            _buildChip(EntityTarget.freightForwarder, isArabic ? 'شحن دولي' : 'Freight Forwarder', Icons.local_shipping_rounded),
            _buildChip(EntityTarget.inlandTransport, isArabic ? 'ناقل بري' : 'Inland Transport', Icons.fire_truck_rounded),
            _buildChip(EntityTarget.inspectionAgency, isArabic ? 'فحص ومعاينة' : 'Inspection Agency', Icons.fact_check_rounded),
            _buildChip(EntityTarget.insuranceCompany, isArabic ? 'شركة تأمين' : 'Insurance Company', Icons.security_rounded),
            _buildChip(EntityTarget.bank, isArabic ? 'بنك معتمد' : 'Authorized Bank', Icons.account_balance),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(EntityTarget target, String label, IconData icon) {
    final isSelected = selectedTarget == target;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.cobalt),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.charcoal,
          ),
        ),
        selected: isSelected,
        selectedColor: AppTheme.cobalt,
        backgroundColor: Colors.white,
        onSelected: (val) {
          if (val) onTargetSelected(target);
        },
      ),
    );
  }
}

class ExtractorInputModeSwitcher extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;

  const ExtractorInputModeSwitcher({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => onIndexChanged(0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selectedIndex == 0 ? AppTheme.emerald : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selectedIndex == 0 ? AppTheme.emerald : Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.content_paste_rounded, size: 16, color: selectedIndex == 0 ? Colors.white : AppTheme.charcoal),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isArabic ? 'لصق نص حر' : 'Paste Free Text',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: selectedIndex == 0 ? Colors.white : AppTheme.charcoal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () => onIndexChanged(1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selectedIndex == 1 ? AppTheme.emerald : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selectedIndex == 1 ? AppTheme.emerald : Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.attach_file_rounded, size: 16, color: selectedIndex == 1 ? Colors.white : AppTheme.charcoal),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isArabic ? 'مستند أو صورة أو ملف' : 'Document or Image File',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: selectedIndex == 1 ? Colors.white : AppTheme.charcoal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ExtractorFormHeader extends StatelessWidget {
  final EntityTarget target;
  final double confidenceScore;
  final VoidCallback onCopy;

  const ExtractorFormHeader({
    super.key,
    required this.target,
    required this.confidenceScore,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(getTargetIcon(target), color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? 'بيانات تكويد ${getTargetName(context, target)}'
                      : '${getTargetName(context, target)} Registration Profile',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (confidenceScore > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: confidenceScore >= 0.8
                      ? AppTheme.emerald.withValues(alpha: 0.15)
                      : AppTheme.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isArabic
                      ? 'دقة التحليل: ${(confidenceScore * 100).toStringAsFixed(0)}%'
                      : 'Extraction Accuracy: ${(confidenceScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: confidenceScore >= 0.8 ? AppTheme.emerald : AppTheme.orange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.cobalt),
              tooltip: isArabic ? 'نسخ البيانات المستخرجة' : 'Copy Extracted Profile',
              onPressed: onCopy,
            ),
          ],
        ),
      ],
    );
  }
}
