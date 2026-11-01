import 'package:flutter/material.dart';
import '../../../../core/widgets/app_search_field.dart';

class DepositLedgerToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onRefresh;

  const DepositLedgerToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 250,
            child: AppSearchField(
              controller: searchController,
              hint: 'بحث برقم الحاوية أو الخط...',
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 14),
          const Text('حالة الاسترداد: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          DropdownButton<String>(
            value: selectedStatus,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('كافة الحالات')),
              DropdownMenuItem(value: 'OVERDUE_30_DAYS', child: Text('🔴 متأخرة عن 30 يوماً')),
              DropdownMenuItem(value: 'CLAIM_SUBMITTED', child: Text('🔵 تم تقديم المطالبة والـ EIR')),
              DropdownMenuItem(value: 'PENDING_RETURN', child: Text('🟡 قيد الإرجاع (لم تسلم)')),
              DropdownMenuItem(value: 'REFUNDED_FULL', child: Text('🟢 مستردة بالكامل')),
              DropdownMenuItem(value: 'REFUNDED_PARTIAL', child: Text('🟠 مستردة جزئياً')),
            ],
            onChanged: onStatusChanged,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث القائمة',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}
