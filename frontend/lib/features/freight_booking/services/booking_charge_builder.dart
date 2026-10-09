import '../models/freight_booking_model.dart';

/// State snapshot of the freight quote breakdown items (17 priced lines plus
/// the booking cancellation fee).
class FbkQuoteState {
  final bool container40ftApp;
  final double container40ftPrice;
  final String container40ftCur;
  final int container40ftQty;

  final bool container20ftApp;
  final double container20ftPrice;
  final String container20ftCur;
  final int container20ftQty;

  final bool lclCbmApp;
  final double lclCbmPrice;
  final String lclCbmCur;
  final double lclCbmQty;

  final bool dthcApp;
  final double dthcPrice;
  final String dthcCur;

  final bool storagePerWeekApp;
  final double storagePerWeekPrice;
  final String storagePerWeekCur;

  final bool extraDayStorageApp;
  final double extraDayStoragePrice;
  final String extraDayStorageCur;

  final bool solasVgmApp;
  final double solasVgmPrice;
  final String solasVgmCur;

  final bool vgmNotifApp;
  final double vgmNotifPrice;
  final String vgmNotifCur;

  final bool telexReleaseApp;
  final double telexReleasePrice;
  final String telexReleaseCur;

  final bool expressCourierApp;
  final double expressCourierPrice;
  final String expressCourierCur;

  final bool eurAtrApp;
  final double eurAtrPrice;
  final String eurAtrCur;

  final bool insuranceApp;
  final double insurancePrice;
  final String insuranceCur;

  final bool docFeesApp;
  final double docFeesPrice;
  final String docFeesCur;

  final bool waiverApp;
  final double waiverPrice;
  final String waiverCur;

  final bool ics2App;
  final double ics2Price;
  final String ics2Cur;

  final bool otherFeesApp;
  final double otherFeesPrice;
  final String otherFeesCur;

  final bool cancellationApp;
  final double cancellationPrice;
  final String cancellationCur;

  const FbkQuoteState({
    this.container40ftApp = false,
    this.container40ftPrice = 0.0,
    this.container40ftCur = 'USD',
    this.container40ftQty = 1,
    this.container20ftApp = false,
    this.container20ftPrice = 0.0,
    this.container20ftCur = 'USD',
    this.container20ftQty = 0,
    this.lclCbmApp = false,
    this.lclCbmPrice = 0.0,
    this.lclCbmCur = 'USD',
    this.lclCbmQty = 0.0,
    this.dthcApp = false,
    this.dthcPrice = 0.0,
    this.dthcCur = 'USD',
    this.storagePerWeekApp = false,
    this.storagePerWeekPrice = 0.0,
    this.storagePerWeekCur = 'USD',
    this.extraDayStorageApp = false,
    this.extraDayStoragePrice = 0.0,
    this.extraDayStorageCur = 'USD',
    this.solasVgmApp = false,
    this.solasVgmPrice = 0.0,
    this.solasVgmCur = 'USD',
    this.vgmNotifApp = false,
    this.vgmNotifPrice = 0.0,
    this.vgmNotifCur = 'USD',
    this.telexReleaseApp = false,
    this.telexReleasePrice = 0.0,
    this.telexReleaseCur = 'USD',
    this.expressCourierApp = false,
    this.expressCourierPrice = 0.0,
    this.expressCourierCur = 'USD',
    this.eurAtrApp = false,
    this.eurAtrPrice = 0.0,
    this.eurAtrCur = 'USD',
    this.insuranceApp = false,
    this.insurancePrice = 0.0,
    this.insuranceCur = 'USD',
    this.docFeesApp = false,
    this.docFeesPrice = 0.0,
    this.docFeesCur = 'USD',
    this.waiverApp = false,
    this.waiverPrice = 0.0,
    this.waiverCur = 'USD',
    this.ics2App = false,
    this.ics2Price = 0.0,
    this.ics2Cur = 'USD',
    this.otherFeesApp = false,
    this.otherFeesPrice = 0.0,
    this.otherFeesCur = 'USD',
    this.cancellationApp = false,
    this.cancellationPrice = 0.0,
    this.cancellationCur = 'USD',
  });
}

/// Result of building charges from quotation breakdown and allocated equipment.
class BookingChargeBuildResult {
  final List<BookingChargeModel> charges;
  final bool has40ftMismatch;
  final bool has20ftMismatch;

  const BookingChargeBuildResult({
    required this.charges,
    this.has40ftMismatch = false,
    this.has20ftMismatch = false,
  });

  bool get hasError => has40ftMismatch || has20ftMismatch;
}

/// Pure helper that builds booking charges from the quotation breakdown and
/// the allocated containers. This is the single charge-building path.
class BookingChargeBuilder {
  BookingChargeBuilder._();

  static BookingChargeModel _flat(
    String chargeType,
    String unit,
    String currency,
    double price,
  ) =>
      BookingChargeModel(
        chargeType: chargeType,
        unit: unit,
        quantity: 1,
        currency: currency,
        rate: price,
        total: price,
      );

  /// Builds booking charges, dynamically mapping container types to sea freight
  /// charges and strictly validating that allocated equipment matches quoted sizes.
  ///
  /// Sea freight 40ft / 20ft lines use per-size units ('Per 40ft Container',
  /// 'Per 20ft Container') so the backend cost calculation does not overwrite
  /// per-type container quantities with the total container count.
  ///
  /// Never drops a quoted freight line silently. If a quoted size (40ft or 20ft)
  /// has price > 0 and qty > 0 but no matching container is allocated, the line
  /// is kept and a mismatch flag is recorded so the UI can block save.
  static BookingChargeBuildResult build(
    FbkQuoteState s, {
    List<ContainerAllocationModel> containers = const [],
  }) {
    final List<BookingChargeModel> newCharges = [];
    bool has40ftMismatch = false;
    bool has20ftMismatch = false;

    // 40ft / 45ft sea freight
    if (s.container40ftApp && s.container40ftPrice > 0 && s.container40ftQty > 0) {
      final c40 = containers.cast<ContainerAllocationModel?>().firstWhere(
        (c) => c != null && (c.containerType.startsWith('40') || c.containerType.startsWith('45')),
        orElse: () => null,
      );

      final String tag;
      if (c40 != null) {
        tag = c40.containerType;
      } else {
        has40ftMismatch = true;
        // Keep default 40HC tag so line is NEVER silently dropped and freight cost is not understated
        tag = '40HC';
      }

      newCharges.add(BookingChargeModel(
        chargeType: 'Sea Freight 40ft',
        unit: 'Per 40ft Container',
        quantity: s.container40ftQty.toDouble(),
        containerType: tag,
        currency: s.container40ftCur,
        rate: s.container40ftPrice,
        total: s.container40ftPrice * s.container40ftQty,
      ));
    }

    // 20ft sea freight
    if (s.container20ftApp && s.container20ftPrice > 0 && s.container20ftQty > 0) {
      final c20 = containers.cast<ContainerAllocationModel?>().firstWhere(
        (c) => c != null && c.containerType.startsWith('20'),
        orElse: () => null,
      );

      final String tag;
      if (c20 != null) {
        tag = c20.containerType;
      } else {
        has20ftMismatch = true;
        // Keep default 20GP tag so line is NEVER silently dropped and freight total is not understated
        tag = '20GP';
      }

      newCharges.add(BookingChargeModel(
        chargeType: 'Sea Freight 20ft',
        unit: 'Per 20ft Container',
        quantity: s.container20ftQty.toDouble(),
        containerType: tag,
        currency: s.container20ftCur,
        rate: s.container20ftPrice,
        total: s.container20ftPrice * s.container20ftQty,
      ));
    }

    // LCL
    if (s.lclCbmApp && s.lclCbmPrice > 0) {
      final qty = s.lclCbmQty > 0 ? s.lclCbmQty : 1.0;
      newCharges.add(BookingChargeModel(
        chargeType: 'LCL CBM Freight',
        unit: 'Per CBM',
        quantity: qty,
        currency: s.lclCbmCur,
        rate: s.lclCbmPrice,
        total: s.lclCbmPrice * qty,
      ));
    }

    // Surcharges & additional fees
    if (s.dthcApp && s.dthcPrice > 0) {
      newCharges.add(_flat('DTHC (Destination THC)', 'Per Shipment', s.dthcCur, s.dthcPrice));
    }
    if (s.storagePerWeekApp && s.storagePerWeekPrice > 0) {
      newCharges.add(_flat('Storage per one week', 'Per Week', s.storagePerWeekCur, s.storagePerWeekPrice));
    }
    if (s.extraDayStorageApp && s.extraDayStoragePrice > 0) {
      newCharges.add(_flat('Extra day storage', 'Per Day', s.extraDayStorageCur, s.extraDayStoragePrice));
    }
    if (s.solasVgmApp && s.solasVgmPrice > 0) {
      newCharges.add(_flat('SOLAS/VGM Fees', 'Per Container', s.solasVgmCur, s.solasVgmPrice));
    }
    if (s.vgmNotifApp && s.vgmNotifPrice > 0) {
      newCharges.add(_flat('VGM Notification Fee', 'Per Container', s.vgmNotifCur, s.vgmNotifPrice));
    }
    if (s.telexReleaseApp && s.telexReleasePrice > 0) {
      newCharges.add(_flat('Telex Release', 'Per Shipment', s.telexReleaseCur, s.telexReleasePrice));
    }
    if (s.expressCourierApp && s.expressCourierPrice > 0) {
      newCharges.add(_flat('Express Courier', 'Per Shipment', s.expressCourierCur, s.expressCourierPrice));
    }
    if (s.eurAtrApp && s.eurAtrPrice > 0) {
      newCharges.add(_flat('EUR.1 / ATR Certificate', 'Per Certificate', s.eurAtrCur, s.eurAtrPrice));
    }
    if (s.insuranceApp && s.insurancePrice > 0) {
      newCharges.add(_flat('Marine Insurance', 'Per Policy', s.insuranceCur, s.insurancePrice));
    }
    if (s.docFeesApp && s.docFeesPrice > 0) {
      newCharges.add(_flat('Document Fees', 'Per Shipment', s.docFeesCur, s.docFeesPrice));
    }
    if (s.waiverApp && s.waiverPrice > 0) {
      newCharges.add(_flat('Waiver Letter Fee', 'Per Letter', s.waiverCur, s.waiverPrice));
    }
    if (s.ics2App && s.ics2Price > 0) {
      newCharges.add(_flat('ICS2 Filing Fee', 'Per Filing', s.ics2Cur, s.ics2Price));
    }
    if (s.otherFeesApp && s.otherFeesPrice > 0) {
      newCharges.add(_flat('Other Fees', 'Per Shipment', s.otherFeesCur, s.otherFeesPrice));
    }
    if (s.cancellationApp && s.cancellationPrice > 0) {
      newCharges.add(_flat('Booking Cancellation', 'Per Shipment', s.cancellationCur, s.cancellationPrice));
    }

    return BookingChargeBuildResult(
      charges: newCharges,
      has40ftMismatch: has40ftMismatch,
      has20ftMismatch: has20ftMismatch,
    );
  }
}

/// Charges for [s]; pass [containers] to tag sea-freight lines with the booked
/// container type. Delegates to [BookingChargeBuilder.build].
List<BookingChargeModel> buildChargesFromQuote(
  FbkQuoteState s, {
  List<ContainerAllocationModel> containers = const [],
}) =>
    BookingChargeBuilder.build(s, containers: containers).charges;

/// Collects distinct currencies across all applicable quote breakdown items.
Set<String> collectApplicableCurrencies(FbkQuoteState s) {
  return buildChargesFromQuote(s)
      .map((c) => c.currency.trim().toUpperCase())
      .where((cur) => cur.isNotEmpty)
      .toSet();
}

/// Returns true if more than one distinct currency is used by applicable quote items.
bool hasMixedCurrencies(FbkQuoteState s) {
  return collectApplicableCurrencies(s).length > 1;
}
