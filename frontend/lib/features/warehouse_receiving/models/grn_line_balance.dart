/// Per-line quantity rule of a Goods Receiving Note (plan WR-04 / FE-01).
///
/// A line balances when `accepted + shortage + damaged == invoiced`. The only
/// exception is an excess receipt: no shortage, no damage and `accepted > invoiced`.
enum GrnLineBalance { balanced, excess, unbalanced }

class GrnLineQuantities {
  final int invoiced;
  final int accepted;
  final int shortage;
  final int damaged;

  const GrnLineQuantities({
    required this.invoiced,
    required this.accepted,
    required this.shortage,
    required this.damaged,
  });

  int get received => accepted + shortage + damaged;

  /// Signed difference `received - invoiced` (0 when balanced).
  int get difference => received - invoiced;

  GrnLineBalance get balance {
    if (received == invoiced) return GrnLineBalance.balanced;
    if (shortage == 0 && damaged == 0 && accepted > invoiced) return GrnLineBalance.excess;
    return GrnLineBalance.unbalanced;
  }

  bool get isValid => balance != GrnLineBalance.unbalanced;
}

/// Parses a quantity field: a non-negative whole number, or null when invalid or empty.
int? parseGrnQty(String? text) {
  final v = int.tryParse((text ?? '').trim());
  if (v == null || v < 0) return null;
  return v;
}
