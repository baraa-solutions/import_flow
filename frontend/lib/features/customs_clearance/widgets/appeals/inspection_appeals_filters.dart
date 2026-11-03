import 'package:flutter/material.dart';

class InspectionAppealsFilters extends StatelessWidget {
  final String selectedAuthority;
  final ValueChanged<String> onAuthorityChanged;
  final String selectedTier;
  final ValueChanged<String> onTierChanged;
  final String selectedResult;
  final ValueChanged<String> onResultChanged;
  final VoidCallback onRefresh;

  const InspectionAppealsFilters({
    super.key,
    required this.selectedAuthority,
    required this.onAuthorityChanged,
    required this.selectedTier,
    required this.onTierChanged,
    required this.selectedResult,
    required this.onResultChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('الجهة الرقابية: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            DropdownButton<String>(
              value: selectedAuthority,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('كافة الجهات')),
                DropdownMenuItem(value: 'GOEIC', child: Text('صادرات وواردات')),
                DropdownMenuItem(value: 'NFSA', child: Text('سلامة الغذاء')),
                DropdownMenuItem(value: 'EDA', child: Text('هيئة الدواء')),
                DropdownMenuItem(value: 'NTRA', child: Text('تنظيم الاتصالات')),
                DropdownMenuItem(value: 'ATOMIC_ENERGY', child: Text('طاقة ذرية')),
              ],
              onChanged: (val) {
                if (val != null) onAuthorityChanged(val);
              },
            ),
            const SizedBox(width: 16),
            const Text('المرحلة: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            DropdownButton<String>(
              value: selectedTier,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('كافة المراحل')),
                DropdownMenuItem(value: 'FIRST_APPEAL', child: Text('التظلم الأول')),
                DropdownMenuItem(value: 'SECOND_APPEAL', child: Text('التظلم الثاني')),
                DropdownMenuItem(value: 'TRIPLICATE_SAMPLE', child: Text('التحكيم الثلاثي')),
              ],
              onChanged: (val) {
                if (val != null) onTierChanged(val);
              },
            ),
            const SizedBox(width: 16),
            const Text('النتيجة: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            DropdownButton<String>(
              value: selectedResult,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('كافة النتائج')),
                DropdownMenuItem(value: 'PENDING', child: Text('🟡 قيد النظر')),
                DropdownMenuItem(value: 'OVERTURNED_CONFORMING', child: Text('🟢 مطابق (تم القبول)')),
                DropdownMenuItem(value: 'UPHELD_REJECTED', child: Text('🔴 مرفوض (تأييد الرفض)')),
              ],
              onChanged: (val) {
                if (val != null) onResultChanged(val);
              },
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث القائمة',
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}
