/// Links an HS code printed on a supplier document (invoice / packing list) to a customs tariff row.
///
/// The printed code stays on the line as printed. A tariff row is linked only when its code is the same
/// number (digits only, so `8415.82.00` == `84158200`). A prefix / heading match is never used: an 8-digit
/// code such as `84158200` must not become the national 10-digit line `8415820010` just because that row
/// comes first, since sibling national lines carry different duty rates. An unlinked line keeps the
/// "tariff not registered" banner so the user picks the national line explicitly.
T? matchTariffForPrintedHs<T>(String? printedHs, Iterable<T> tariffs, String Function(T tariff) hsCodeOf) {
  final printed = digitsOnlyHs(printedHs);
  if (printed.isEmpty) return null;
  for (final t in tariffs) {
    if (digitsOnlyHs(hsCodeOf(t)) == printed) return t;
  }
  return null;
}

String digitsOnlyHs(String? hs) => (hs ?? '').replaceAll(RegExp(r'[^\d]'), '');
