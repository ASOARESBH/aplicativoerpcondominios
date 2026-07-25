import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../models/morador_model.dart';

/// Datasource remoto para autenticação
class AuthRemoteDataSource {
  final DioClient _dioClient;

  AuthRemoteDataSource(this._dioClient);

  /// Realiza o login do morador via API
  Future<LoginResponseModel> login({
    required String cpf,
    required String password,
    String? baseUrl,
  }) async {
    try {
      if (baseUrl != null) {
        await _dioClient.updateBaseUrl(baseUrl);
      } else {
        await _dioClient.initBaseUrl();
      }

      final response = await _dioClient.dio.post(
        AppConstants.endpointLogin,
        queryParameters: {'action': 'login'},
        data: {
          'cpf': cpf,
          'senha': password,
        },
      );

      final loginResponse = LoginResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );

      if (!loginResponse.sucesso) {
        throw ValidationException(loginResponse.mensagem);
      }

      return loginResponse;
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error as AppException;
      throw NetworkException(e.message ?? 'Erro de conexão.');
    }
  }

  /// Verifica a validade da sessão atual
  Future<bool> verifySession() async {
    try {
      await _dioClient.initBaseUrl();
      final response = await _dioClient.dio.get(
        AppConstants.endpointVerifySession,
      );
      final data = response.data as Map<String, dynamic>;
      return data['sucesso'] == true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return false;
      if (e.error is AppException) throw e.error as AppException;
      throw NetworkException(e.message ?? 'Erro de conexão.');
    }
  }

  /// Realiza o logout
  Future<void> logout() async {
    try {
      await _dioClient.initBaseUrl();
      await _dioClient.dio.post(AppConstants.endpointLogout);
    } catch (_) {
      // Ignora erros no logout — limpa sessão local de qualquer forma
    }
  }

  /// Solicita recuperação de senha
  Future<void> requestPasswordRecovery(String email) async {
    try {
      await _dioClient.initBaseUrl();
      final response = await _dioClient.dio.post(
        AppConstants.endpointPasswordRecovery,
        data: {'email': email},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['sucesso'] != true) {
        throw ValidationException(
          data['mensagem']?.toString() ?? 'Erro ao solicitar recuperação.',
        );
      }
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error as AppException;
      throw NetworkException(e.message ?? 'Erro de conexão.');
    }
  }
}
