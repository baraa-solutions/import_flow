import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/container_eir_model.dart';

final containerEirServiceProvider = Provider<ContainerEirService>((ref) {
  return ContainerEirService(ref.read(dioProvider));
});

class ContainerEirService {
  final Dio _dio;

  ContainerEirService(this._dio);

  /// Fetches the operational and financial container ledger for an import file.
  Future<ContainerLedgerResponseModel?> getContainerLedger(int fileId) async {
    try {
      final res = await _dio.get('/containers/import-file/$fileId/ledger');
      if (res.data is Map<String, dynamic>) {
        return ContainerLedgerResponseModel.fromJson(res.data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      rethrow;
    }
  }

  /// Submits EIR empty return receipt and freezes demurrage calculation for this container.
  Future<bool> submitEmptyReturnEir(int containerId, ContainerEirReturnRequestModel req) async {
    try {
      final res = await _dio.post(
        '/containers/$containerId/empty-return-eir',
        data: req.toJson(),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      rethrow;
    }
  }

  /// Registers container customs gate-out milestone.
  Future<bool> submitGateOut(int containerId, ContainerGateOutRequestModel req) async {
    try {
      final res = await _dio.post(
        '/containers/$containerId/gate-out',
        data: req.toJson(),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      rethrow;
    }
  }
}
