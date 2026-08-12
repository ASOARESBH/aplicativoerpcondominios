import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../security/secure_storage_service.dart';

/// Cliente do Portal do Colaborador.
///
/// Não reutiliza o token do morador e sempre obtém o token de colaborador do
/// armazenamento seguro antes de chamadas autenticadas.
class EmployeeApiClient {
  EmployeeApiClient(this._storage)
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout:
                const Duration(milliseconds: AppConstants.connectTimeoutMs),
            receiveTimeout:
                const Duration(milliseconds: AppConstants.receiveTimeoutMs),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) => status != null && status < 500,
          ),
        );

  final SecureStorageService _storage;
  final Dio _dio;

  Future<Response<dynamic>> login({
    required String email,
    required String password,
    int? tenantId,
  }) {
    return _dio.post(
      AppConstants.endpointColaborador,
      queryParameters: {'action': AppConstants.actionLoginColaborador},
      data: {
        'email': email,
        'senha': password,
        if (tenantId != null) 'tenant_id': tenantId,
        'dispositivo': 'ERP Condomínios Mobile',
      },
    );
  }

  Future<Response<dynamic>> get(
    String action, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final token = await _requireToken();
    return _dio.get(
      AppConstants.endpointColaborador,
      queryParameters: {'action': action, ...?queryParameters},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<Response<dynamic>> post(
    String action, {
    Map<String, dynamic>? data,
  }) async {
    final token = await _requireToken();
    return _dio.post(
      AppConstants.endpointColaborador,
      queryParameters: {'action': action},
      data: data ?? const <String, dynamic>{},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  /// Envio multipart para evidências fotográficas. O Content-Type é delegado ao
  /// FormData, preservando o limite e a validação de MIME no servidor.
  Future<Response<dynamic>> postForm(String action, FormData data) async {
    final token = await _requireToken();
    return _dio.post(
      AppConstants.endpointColaborador,
      queryParameters: {'action': action},
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<String> _requireToken() async {
    final token = await _storage.getColaboradorToken();
    if (token == null || token.isEmpty) {
      throw StateError(
          'A sessão do colaborador expirou. Faça login novamente.');
    }
    return token;
  }
}
