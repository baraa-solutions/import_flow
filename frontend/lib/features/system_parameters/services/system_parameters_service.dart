import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../models/system_parameter_model.dart';

class SystemParametersService {
  final Dio _dio;

  SystemParametersService(this._dio);

  Future<List<SystemParameterModel>> getParameters() async {
    final response = await _dio.get(ApiConstants.systemParameters);
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((item) => SystemParameterModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<SystemParameterModel> updateParameter({
    required String key,
    required String value,
    required String justification,
  }) async {
    final response = await _dio.put(
      '${ApiConstants.systemParameters}/$key',
      data: {
        'param_value': value,
        'justification': justification,
      },
    );
    return SystemParameterModel.fromJson(response.data as Map<String, dynamic>);
  }
}
