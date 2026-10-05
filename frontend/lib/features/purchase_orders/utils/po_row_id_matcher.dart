import '../models/purchase_order_model.dart';

/// Result of carrying existing row ids over to freshly extracted rows.
class POItemIdMatch {
  const POItemIdMatch({required this.items, required this.keptUnmatched});

  /// Extracted lines (ids carried where matched) followed by [keptUnmatched].
  final List<POLineItemModel> items;

  /// Existing lines that were not in the extraction but have recorded shipments:
  /// they must not be dropped (the backend refuses to remove them).
  final List<POLineItemModel> keptUnmatched;
}

String _norm(String? v) => (v ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// In EDIT mode an AI extraction replaces the row lists. To update lines in place
/// (instead of delete + insert) each extracted line takes the id of the existing line
/// with the same item code, else the same HS code + description. An existing line
/// that is unmatched and in [allocatedItemIds] is kept.
POItemIdMatch carryLineItemIds({
  required List<POLineItemModel> existing,
  required List<POLineItemModel> extracted,
  Set<int> allocatedItemIds = const {},
}) {
  final used = <int>{};
  POLineItemModel? find(bool Function(POLineItemModel e) test) {
    for (final e in existing) {
      if (e.itemId == null || used.contains(e.itemId)) continue;
      if (test(e)) return e;
    }
    return null;
  }

  final result = <POLineItemModel>[];
  for (final x in extracted) {
    final code = _norm(x.itemCode);
    var match = code.isEmpty ? null : find((e) => _norm(e.itemCode) == code);
    if (match == null) {
      final hs = _norm(x.hsCode);
      final desc = _norm(x.descriptionEn?.isNotEmpty == true ? x.descriptionEn : x.descriptionAr);
      if (hs.isNotEmpty && desc.isNotEmpty) {
        match = find((e) =>
            _norm(e.hsCode) == hs &&
            (_norm(e.descriptionEn) == desc || _norm(e.descriptionAr) == desc));
      }
    }
    if (match != null) {
      used.add(match.itemId!);
      result.add(x.copyWith(itemId: match.itemId));
    } else {
      result.add(x);
    }
  }
  final kept = [
    for (final e in existing)
      if (e.itemId != null && !used.contains(e.itemId) && allocatedItemIds.contains(e.itemId)) e,
  ];
  return POItemIdMatch(items: [...result, ...kept], keptUnmatched: kept);
}

/// Same idea for packing rows (item code, else HS code + description); no allocation rule.
List<PackingListItemModel> carryPackingItemIds({
  required List<PackingListItemModel> existing,
  required List<PackingListItemModel> extracted,
}) {
  final used = <int>{};
  PackingListItemModel? find(bool Function(PackingListItemModel e) test) {
    for (final e in existing) {
      if (e.packingItemId == null || used.contains(e.packingItemId)) continue;
      if (test(e)) return e;
    }
    return null;
  }

  return [
    for (final x in extracted)
      () {
        final code = _norm(x.itemCode);
        var m = code.isEmpty ? null : find((e) => _norm(e.itemCode) == code);
        if (m == null && _norm(x.hsCode).isNotEmpty && _norm(x.description).isNotEmpty) {
          m = find((e) => _norm(e.hsCode) == _norm(x.hsCode) && _norm(e.description) == _norm(x.description));
        }
        if (m == null) return x;
        used.add(m.packingItemId!);
        return x.copyWith(packingItemId: m.packingItemId);
      }(),
  ];
}
