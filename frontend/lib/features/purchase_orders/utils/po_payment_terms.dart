/// The PO payment-terms options (the values stored in `purchase_orders.payment_terms`) and the
/// mapping of free text read from a document (proforma / AI extraction) onto them.
class PoPaymentTerms {
  PoPaymentTerms._();

  static const String cashInAdvance = 'Cash in Advance / SWIFT';
  static const String letterOfCredit = 'Letter of Credit / LC';
  static const String cashAgainstDocuments = 'CAD / Cash Against Documents';
  static const String openAccount = 'Open Account / Deferred Payment';

  /// Dropdown options, in display order.
  static const List<String> values = [cashInAdvance, letterOfCredit, cashAgainstDocuments, openAccount];

  // Order matters: "Cash Against Documents" must win over the generic "cash" (advance) rule,
  // and documentary collection over open account ("D/A" is deferred but still a collection).
  static final List<(String, RegExp)> _rules = [
    (
      cashAgainstDocuments,
      RegExp(r'\bCAD\b|CASH\s*AGAINST\s*DOC|DOCUMENTARY\s*COLLECTION|\bCOLLECTION\b|\bD\s*/\s*[PA]\b|DOCUMENTS?\s*AGAINST|تحصيل\s*مستندي|مستندات',
          caseSensitive: false),
    ),
    (
      letterOfCredit,
      RegExp(r'\bL\s*/\s*C\b|\bLC\b|LETTER\s*OF\s*CREDIT|DOCUMENTARY\s*CREDIT|اعتماد', caseSensitive: false),
    ),
    (
      openAccount,
      RegExp(r'OPEN\s*ACCOUNT|\bO\s*/\s*A\b|DEFERRED|\bNET\s*\d+|DAYS\s*(AFTER|FROM)|حساب\s*مفتوح|آجل',
          caseSensitive: false),
    ),
    (
      cashInAdvance,
      RegExp(
          r'\bT\s*/\s*T\b|\bTT\b|TELEGRAPHIC|WIRE\s*TRANSFER|BANK\s*TRANSFER|\bSWIFT\b|ADVANCE|PRE-?\s*PAYMENT|PREPAID|AVV\.?\s*MERCE|\bCASH\b|\bCHK\b|\bDBT\b|سويفت|مقدم|تحويل',
          caseSensitive: false),
    ),
  ];

  /// One of [values] for an extracted / legacy text, or null when it cannot be recognised
  /// (the field then stays empty for the user to pick — never an invalid option).
  static String? fromText(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    for (final v in values) {
      if (v.toLowerCase() == text.toLowerCase()) return v;
    }
    for (final (value, pattern) in _rules) {
      if (pattern.hasMatch(text)) return value;
    }
    return null;
  }
}
