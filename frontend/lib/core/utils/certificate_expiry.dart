/// Renewal state of a dated certificate / token (Trello TJ6Guorp).
enum CertificateExpiryState { notSet, valid, expiringSoon, expired }

/// Days left until [expiry] counted on local calendar days (no UTC / time-of-day drift):
/// < 0 expired, 0..[warningDays] expiring soon, above that valid.
class CertificateExpiry {
  CertificateExpiry._();

  static const int warningDays = 30;

  static int? daysLeft(DateTime? expiry, {DateTime? today}) {
    if (expiry == null) return null;
    final t = today ?? DateTime.now();
    final from = DateTime(t.year, t.month, t.day);
    final to = DateTime(expiry.year, expiry.month, expiry.day);
    return to.difference(from).inDays;
  }

  static CertificateExpiryState state(DateTime? expiry, {DateTime? today}) {
    final days = daysLeft(expiry, today: today);
    if (days == null) return CertificateExpiryState.notSet;
    if (days < 0) return CertificateExpiryState.expired;
    if (days <= warningDays) return CertificateExpiryState.expiringSoon;
    return CertificateExpiryState.valid;
  }

  static String label(DateTime? expiry, {required bool isArabic, DateTime? today}) {
    final days = daysLeft(expiry, today: today);
    switch (state(expiry, today: today)) {
      case CertificateExpiryState.notSet:
        return isArabic ? 'غير محدد' : 'Not configured';
      case CertificateExpiryState.expired:
        return isArabic ? 'منتهي' : 'Expired';
      case CertificateExpiryState.expiringSoon:
        return isArabic ? 'متبقي للتجديد $days يوم' : 'Renew in $days d';
      case CertificateExpiryState.valid:
        return isArabic ? 'صالح ($days يوم)' : 'Valid ($days d)';
    }
  }

  /// The soonest expiry among [dates] (null entries ignored), for a single table badge.
  static DateTime? soonest(Iterable<DateTime?> dates) {
    DateTime? best;
    for (final d in dates) {
      if (d != null && (best == null || d.isBefore(best))) best = d;
    }
    return best;
  }

  static DateTime? parse(dynamic raw) => raw == null ? null : DateTime.tryParse(raw.toString());

  static String? toJsonDate(DateTime? d) => d?.toIso8601String().split('T').first;
}
