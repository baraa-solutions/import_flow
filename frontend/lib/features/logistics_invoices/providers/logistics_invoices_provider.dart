import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/logistics_invoice_models.dart';
import '../repositories/logistics_invoices_repository.dart';

// Filter States
final selectedShipmentFilterProvider = StateProvider<int?>((ref) => null);
final invoicePartnerTypeFilterProvider = StateProvider<String>((ref) => 'all');
final invoiceStatusFilterProvider = StateProvider<String>((ref) => 'all');
final invoiceShipmentFilterProvider = StateProvider<int?>((ref) => null);
final invoicePartnerFilterProvider = StateProvider<int?>((ref) => null);

// Invoices List Provider
final logisticsInvoicesListProvider = FutureProvider.autoDispose<List<LogisticsInvoiceModel>>((ref) async {
  final repo = ref.watch(logisticsInvoicesRepositoryProvider);
  final partnerType = ref.watch(invoicePartnerTypeFilterProvider);
  final status = ref.watch(invoiceStatusFilterProvider);
  final selectedShipment = ref.watch(selectedShipmentFilterProvider);
  final tabShipment = ref.watch(invoiceShipmentFilterProvider);
  final shipmentId = selectedShipment ?? tabShipment;
  final partnerId = ref.watch(invoicePartnerFilterProvider);

  return repo.fetchInvoices(
    partnerType: partnerType,
    status: status,
    shipmentId: shipmentId,
    partnerId: partnerId,
  );
});

// Single Invoice Provider
final singleLogisticsInvoiceProvider = FutureProvider.family.autoDispose<LogisticsInvoiceModel, int>((ref, id) async {
  final repo = ref.watch(logisticsInvoicesRepositoryProvider);
  return repo.fetchInvoice(id);
});

// Partner Balance Card Provider
final partnerBalanceCardProvider = FutureProvider.family.autoDispose<PartnerBalanceCardModel, int>((ref, partnerId) async {
  final repo = ref.watch(logisticsInvoicesRepositoryProvider);
  return repo.getPartnerBalanceCard(partnerId);
});

// Partner Open Invoices Provider
final partnerOpenInvoicesProvider = FutureProvider.family.autoDispose<List<LogisticsInvoiceModel>, int>((ref, partnerId) async {
  final repo = ref.watch(logisticsInvoicesRepositoryProvider);
  return repo.getPartnerOpenInvoices(partnerId);
});

// Container Lock Status Provider
final containerLockStatusProvider = FutureProvider.family.autoDispose<ContainerLockStatusModel, ({int shipmentId, String blNumber})>((ref, arg) async {
  final repo = ref.watch(logisticsInvoicesRepositoryProvider);
  return repo.getContainerLockStatus(arg.shipmentId, arg.blNumber);
});

// Three Way Match Provider
final threeWayMatchProvider = FutureProvider.family.autoDispose<ThreeWayMatchModel, int>((ref, invoiceId) async {
  final repo = ref.watch(logisticsInvoicesRepositoryProvider);
  return repo.getThreeWayMatch(invoiceId);
});

// Marine Insurance Policies List Provider
final insurancePoliciesFilterStatusProvider = StateProvider<String>((ref) => 'all');
final insurancePoliciesFilterShipmentProvider = StateProvider<int?>((ref) => null);

final insurancePoliciesListProvider = FutureProvider.autoDispose<List<InsurancePolicyModel>>((ref) async {
  final repo = ref.watch(logisticsInvoicesRepositoryProvider);
  final status = ref.watch(insurancePoliciesFilterStatusProvider);
  final selectedShipment = ref.watch(selectedShipmentFilterProvider);
  final tabShipment = ref.watch(insurancePoliciesFilterShipmentProvider);
  final shipmentId = selectedShipment ?? tabShipment;

  return repo.fetchInsurancePolicies(
    status: status,
    shipmentId: shipmentId,
  );
});

// Clearance Advance Payments List Provider
final clearanceAdvancesFilterShipmentProvider = StateProvider<int?>((ref) => null);
final clearanceAdvancesFilterPartnerProvider = StateProvider<int?>((ref) => null);

final clearanceAdvancesListProvider = FutureProvider.autoDispose<List<ClearanceAdvancePaymentModel>>((ref) async {
  final repo = ref.watch(logisticsInvoicesRepositoryProvider);
  final selectedShipment = ref.watch(selectedShipmentFilterProvider);
  final tabShipment = ref.watch(clearanceAdvancesFilterShipmentProvider);
  final shipmentId = selectedShipment ?? tabShipment;
  final partnerId = ref.watch(clearanceAdvancesFilterPartnerProvider);

  return repo.fetchClearanceAdvances(
    shipmentId: shipmentId,
    partnerId: partnerId,
  );
});

// Payment Vouchers List Provider
final paymentVouchersFilterPartnerProvider = StateProvider<int?>((ref) => null);
final paymentVouchersFilterShipmentProvider = StateProvider<int?>((ref) => null);

final paymentVouchersListProvider = FutureProvider.autoDispose<List<LogisticsPaymentVoucherModel>>((ref) async {
  final repo = ref.watch(logisticsInvoicesRepositoryProvider);
  final partnerId = ref.watch(paymentVouchersFilterPartnerProvider);
  final selectedShipment = ref.watch(selectedShipmentFilterProvider);
  final tabShipment = ref.watch(paymentVouchersFilterShipmentProvider);
  final shipmentId = selectedShipment ?? tabShipment;

  return repo.fetchPaymentVouchers(
    partnerId: partnerId,
    shipmentId: shipmentId,
  );
});
