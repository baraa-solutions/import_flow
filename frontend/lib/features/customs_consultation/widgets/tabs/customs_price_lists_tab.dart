import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../broker_price_lists_tab.dart';

/// Broker Price Lists & Catalog Tab (تبويب سجل وقوائم أسعار التخليص وعروض المخلصين).
///
/// Encapsulates broker price lists, defined tariffs, and quotation catalog
/// with selection support and clean modular separation.
class CustomsPriceListsTab extends ConsumerWidget {
  const CustomsPriceListsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SelectionArea(
      child: BrokerPriceListsTab(),
    );
  }
}
