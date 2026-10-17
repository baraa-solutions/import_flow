import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/customs_tariff_provider.dart';

/// Widget displaying the chronological timeline of HS Code decisions, rates, and validity periods.
/// Ensures users can see the historical evolution and that past studies are protected from retroactive changes.
class HsCodeTimelineWidget extends ConsumerStatefulWidget {
  final String hsCode;
  final String? countryCode;
  final double? currentDutyRate;
  final VoidCallback? onClose;

  const HsCodeTimelineWidget({
    super.key,
    required this.hsCode,
    this.countryCode,
    this.currentDutyRate,
    this.onClose,
  });

  @override
  ConsumerState<HsCodeTimelineWidget> createState() => _HsCodeTimelineWidgetState();
}

class _HsCodeTimelineWidgetState extends ConsumerState<HsCodeTimelineWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _versions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void didUpdateWidget(covariant HsCodeTimelineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hsCode != widget.hsCode) {
      _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    if (widget.hsCode.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ref.read(customsTariffProvider.notifier).fetchTariffHistory(widget.hsCode);
      if (!mounted) return;
      if (res != null && res['versions'] is List) {
        setState(() {
          _versions = (res['versions'] as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _versions = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تحميل سجل التعديلات: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppTheme.cobalt, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'التسلسل الزمني وسجل القرارات الجمركية (بند ${widget.hsCode})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'تحديث السجل',
                onPressed: _fetchHistory,
              ),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.crimson, fontSize: 13),
            )
          else if (_versions.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blueGrey, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا توجد نسخ تاريخية متعددة لهذا البند الجمركي حتى الآن. الإصدار الحالي هو الساري.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _versions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final v = _versions[index];
                  final bool isCurrent = v['is_current'] == true || index == 0;
                  final String effFrom = v['effective_from'] ?? 'غير محدد';
                  final String effTo = v['effective_to'] ?? 'ساري حتى الآن';
                  final double duty = (v['customs_duty_rate'] as num?)?.toDouble() ?? 0.0;
                  final double vat = (v['vat_rate'] as num?)?.toDouble() ?? 14.0;
                  final String category = v['customs_category'] ?? '';
                  final String notes = v['notes'] ?? '';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? (isDark ? const Color(0xFF132B45) : const Color(0xFFEFF6FF))
                          : (isDark ? Colors.black12 : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent ? AppTheme.cobalt : const Color(0xFFCBD5E1),
                        width: isCurrent ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isCurrent ? AppTheme.cobalt : Colors.blueGrey,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isCurrent ? 'الإصدار الساري حالياً' : 'نسخة تاريخية سابقة',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.date_range, size: 14, color: Colors.blueGrey),
                            const SizedBox(width: 4),
                            Text(
                              'من: $effFrom  إلى: $effTo',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'ضريبة الوارد: ${duty.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: isCurrent ? AppTheme.cobalt : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'القيمة المضافة: ${vat.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            if (category.isNotEmpty) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  category,
                                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            notes,
                            style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey),
                          ),
                        ],
                      ],
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
